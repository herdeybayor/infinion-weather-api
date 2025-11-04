# ============================================
# Stage 1: Build Stage
# ============================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder

WORKDIR /src

# Copy project files
COPY ["InfinionDevOps.csproj", "./"]

# Restore dependencies
RUN dotnet restore "InfinionDevOps.csproj"

# Copy source code
COPY . .

# Build application
RUN dotnet build "InfinionDevOps.csproj" -c Release -o /app/build

# Publish application
RUN dotnet publish "InfinionDevOps.csproj" -c Release -o /app/publish

# ============================================
# Stage 2: Runtime Stage (Minimal Image)
# ============================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app

# Create non-root user for security
RUN useradd -m -u 1001 appuser

# Copy published application from builder
COPY --from=builder /app/publish .

# Set ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080
EXPOSE 8443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/weatherforecast || exit 1

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Run application
ENTRYPOINT ["dotnet", "InfinionDevOps.dll"]