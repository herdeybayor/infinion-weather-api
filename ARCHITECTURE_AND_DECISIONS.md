# Architecture & Design Decisions

## Assessment Requirements

The task was straightforward:
1. Create ACR using Terraform
2. Setup a CI/CD pipeline (GitHub Actions)
3. Deploy AKS cluster
4. Deploy the API to AKS
5. Implement security best practices
6. Document the deployment

This document explains the technical approach taken to meet these requirements.

---

## Infrastructure Architecture

### Why Terraform for Infrastructure?

Managing Azure resources via Terraform provides:
- **Reproducibility** - Exact same infrastructure can be spun up or torn down consistently
- **Auditability** - Git history shows exactly what infrastructure exists and when it changed
- **Idempotency** - Running `terraform apply` multiple times produces the same result
- **No manual drift** - Everything is code; no "undocumented" changes in the portal

### Modular Design

Four focused modules instead of monolithic code:

**Network Module**: Handles VNet, subnet, and security group isolation. Changes to networking don't affect Kubernetes configuration.

**ACR Module**: Container registry with managed identity setup. Can be reused in other projects.

**AKS Module**: Kubernetes cluster with dual node pools. System pool runs Kubernetes infrastructure; application pool runs workloads.

**RBAC Module**: Service principal and role assignments. One responsibility: identity and access.

This structure makes the codebase maintainable. If someone reports an ACR issue, the fix is isolated to one module. If the networking needs adjustment, other infrastructure isn't affected.

### Node Pool Strategy

Two separate node pools serve different purposes:

**System Pool** (2 nodes): Runs coredns, kube-proxy, and other Kubernetes control plane components. Isolated from application workloads.

**Application Pool** (2-3 nodes, autoscaling): Runs the weather API. Can scale independently based on demand.

This separation allows the system to handle node maintenance without dropping the application service.

### Network Isolation

The VNet is sized at 10.0.0.0/16 with a single subnet 10.0.1.0/24. This is sufficient for the deployment and allows room for expansion.

The Network Security Group enforces:
- **Inbound**: HTTP (80) and HTTPS (443) only
- **Outbound**: All traffic allowed (application needs external API calls)

This deny-by-default approach is a security baseline. Nothing gets through unless explicitly allowed.

### Identity & Authentication

**Managed Identities** are used instead of storing credentials:
- AKS cluster has a managed identity that can call Azure APIs (no secrets needed)
- AKS has permission to pull images from ACR via role assignment
- GitHub Actions uses a service principal with credentials in GitHub Secrets

Managed identities have several advantages:
- No password rotation needed
- Credentials are never visible to developers
- Azure manages the lifecycle
- No accidental credential leaks in logs or Git history

---

## Containerization

### Multi-Stage Docker Build

The Dockerfile has two stages:

**Stage 1 (Build)**: Uses the ASP.NET Core SDK to compile the application. This layer is large (~2GB) but only used for compilation.

**Stage 2 (Runtime)**: Copies the compiled binaries from stage 1 and uses the smaller ASP.NET Core runtime base image. Final image: ~200MB.

Why this matters:
- Image pulls are faster (200MB vs 2GB)
- Registry storage is smaller
- Network bandwidth is reduced
- Container startup time improves

### Security Context

Containers run as a non-root user (UID 1001):
- Limits damage if the application is compromised
- Prevents privilege escalation to the container host
- Enforced at the Kubernetes level (even if the Dockerfile doesn't specify it)

The root filesystem is read-only:
- Prevents attackers from writing malicious files to disk
- Forces explicit volume mounts for data directories
- Makes the container immutable once running

Application writes to `/tmp` and `/app/cache` via `emptyDir` volumes (temporary storage that disappears when the pod terminates).

### Health Checks

The Dockerfile includes a HEALTHCHECK probe on the `/weatherforecast` endpoint. This allows:
- Docker to detect if the application is responsive
- Kubernetes to know when a pod is ready to receive traffic
- Automatic restart if the application becomes unresponsive

---

## CI/CD Pipeline (GitHub Actions)

### Build & Push Strategy

The workflow builds the Docker image and tags it twice:

1. **Commit SHA tag** (e.g., `abc1234...`): Immutable reference to the exact code version
2. **Latest tag**: Convenience tag for quick local testing

Both tags reference the same image (no duplicate builds). The commit SHA approach means any issue can be traced back to the exact code version in Git.

### Authentication

The workflow uses a service principal stored as GitHub Secrets:

```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "..."
}
```

The service principal has `Contributor` role on the resource group, allowing it to:
- Authenticate with ACR to push images
- Access AKS to deploy applications
- Manage Kubernetes resources

### Image Pull Secrets

The workflow dynamically creates a Kubernetes secret for pulling images from the private ACR:

```bash
kubectl create secret docker-registry acr-secret \
  --docker-server=$REGISTRY \
  --docker-username=$CLIENT_ID \
  --docker-password=$CLIENT_SECRET \
  -n infinion
```

Using `--dry-run=client -o yaml | kubectl apply -f -` ensures idempotency—running the workflow multiple times doesn't fail if the secret already exists.

### Deployment Flow

Each push to `main` triggers:
1. Build Docker image with platform specification (`linux/amd64`)
2. Push to ACR with commit SHA and latest tags
3. Apply Kubernetes manifests (namespace, service account, configmap, network policy, etc.)
4. Update the deployment with the new image
5. Wait for rollout to complete
6. Verify pods are running

The entire pipeline takes about 3-4 minutes from code push to live service.

---

## Kubernetes Deployment

### Manifest Organization

Eight separate manifest files, each with a single responsibility:

- `namespace.yaml` - Creates the `infinion` namespace for resource isolation
- `service-account.yaml` - Pod identity with ACR pull permissions
- `configmap.yaml` - Application configuration
- `deployment.yaml` - Application pods with 2 replicas
- `service.yaml` - LoadBalancer exposing port 80 to pod port 8080
- `network-policy.yaml` - Traffic rules (deny-by-default)
- `resource-quota.yaml` - Namespace-level resource limits
- `ingress.yaml` - (Optional) HTTP routing with TLS

Separate files mean:
- Easy to find what you're looking for
- Git diffs are focused (changes to one resource don't clutter others)
- You can apply subsets of manifests if needed
- Multiple team members can work on different resources

### High Availability

**2 replicas minimum**: If one pod crashes, the other continues serving traffic.

**Rolling updates**: When deploying a new version, Kubernetes brings up one new pod while the old one keeps running, then terminates the old one. Zero-downtime deployments.

**Pod anti-affinity**: Kubernetes tries to spread replicas across different nodes. If one node fails, the service stays up.

**Health probes**:
- Liveness probe: Restarts unhealthy containers
- Readiness probe: Removes unhealthy pods from the load balancer

### Resource Management

Each pod requests and limits CPU/memory:

```yaml
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 500m
  memory: 512Mi
```

**Requests**: Kubernetes uses these to decide which node can fit the pod. If a node doesn't have 100m CPU available, the pod doesn't schedule there.

**Limits**: If a pod exceeds these, Kubernetes kills it. This prevents one bad pod from consuming all cluster resources and affecting other workloads.

### Network Policy

The NetworkPolicy uses a deny-by-default approach:

**Ingress**: Allow TCP port 8080 from any source (the LoadBalancer sends traffic here)

**Egress**:
- DNS (UDP 53) - For external hostname resolution and API calls
- HTTP (TCP 80) - For external API calls
- HTTPS (TCP 443) - For external API calls

Anything not explicitly allowed is denied. This limits the blast radius if the application is compromised.

### Service Exposure

The service is of type `LoadBalancer`:
- Creates an Azure LoadBalancer resource
- Maps external port 80 to pod port 8080
- Provides a public IP address
- Azure handles the load balancing between pod replicas

This is simpler than using an Ingress controller for a single service.

---

## What Wasn't Included (And Why)

### Persistent Storage

The weather API is stateless and doesn't need a database. Adding PostgreSQL, MongoDB, or other persistence would:
- Add complexity beyond the assessment scope
- Introduce additional cost
- Require backup and recovery procedures

For a read-only API, statelessness is the right choice.

### Monitoring & Logging

The deployment doesn't include Prometheus/Grafana metrics or centralized logging. In production:
- Azure Monitor would track cluster health
- Application Insights would monitor application metrics
- Log Analytics would aggregate and search logs

These add significant infrastructure that wasn't required for the assessment.

### Service Mesh (Istio)

Service meshes handle traffic management, mTLS, and observability at scale. For 2 application pods:
- Complexity exceeds the value provided
- Extra resource consumption
- Overkill for this workload size

NetworkPolicies and built-in Kubernetes features are sufficient.

### HTTPS/TLS

Early attempts used Ingress with Let's Encrypt certificates. The external DNS validation failed due to network routing issues, while internal validation worked. The assessment scope was met with HTTP via LoadBalancer:
- Simple, works reliably
- Security best practices for containerization are implemented (non-root, read-only FS, network policies)
- HTTPS would require DNS setup and ingress controller complexity outside the core assessment

For production, Azure App Gateway or similar would handle TLS termination.

---

## Key Design Principles

**Infrastructure as Code**: Everything is declarative and version-controlled. No manual portal changes.

**Security by Default**: Non-root containers, read-only filesystems, network policies, managed identities, private registries.

**High Availability**: Multiple replicas, multiple node pools, spread across availability zones.

**Automation**: GitHub Actions handles build, push, and deploy. No manual intervention.

**Separation of Concerns**: Terraform modules, Kubernetes manifests, and pipeline stages each have one job.

**Reproducibility**: Exact same infrastructure can be deployed repeatedly. Failures can be recovered from.

---

## Production Considerations

This deployment meets the assessment requirements and follows cloud-native best practices. To move to production:

1. Add HTTPS with TLS certificates (Azure App Gateway or Ingress controller)
2. Implement monitoring (Azure Monitor, Application Insights)
3. Configure log aggregation (Azure Log Analytics)
4. Add rate limiting / API gateway
5. Implement backup and disaster recovery procedures
6. Cost optimization (reserved instances, spot VMs)
7. Set up staging environment with similar configuration

The foundation is solid. These additions are about operational maturity, not architectural changes.
