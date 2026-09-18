# GKE Deployment & Lifecycle Management Guide

This directory contains the production Kubernetes manifests for `qualityAirApp`, configured for **zero-downtime rolling upgrades**, **automatic pod healing**, and **instant rollbacks**.

---

## 📁 Manifest Structure

- [`deployment.yaml`](deployment.yaml): Defines 2 replicas, resource limits, readiness/liveness probes (`/health`), and a zero-downtime `RollingUpdate` strategy.
- [`service.yaml`](service.yaml): Exposes the pods externally using a Google Cloud Network Load Balancer on port `80`.
- [`hpa.yaml`](hpa.yaml): Horizontal Pod Autoscaler (Min: 2, Max: 5, Target CPU: 50%).
- [`kustomization.yaml`](kustomization.yaml): Packages the resources together and allows dynamic image tag updates.

---

## 🚀 1. Initial Deployment

From the `qualityAirApp` folder (or repository root):

```bash
# Apply both Deployment and Service into namespace 'quality-air'
kubectl apply -k k8s/

# Monitor the deployment rollout
kubectl rollout status deployment/quality-air-app -n quality-air

# Check running pods
kubectl get pods -n quality-air -o wide
```

---

## 🔄 2. Three Ways to Upgrade & Rebuild Pods

Choose the workflow that best fits your situation:

### Approach A: Rebuilding with the SAME tag (e.g., `:latest`)
If you rebuilt and pushed a new image to Artifact Registry using the same `:latest` tag:
```bash
# Triggers an immediate zero-downtime rolling restart of all pods
kubectl rollout restart deployment/quality-air-app -n quality-air

# Watch the new pods replace the old pods
kubectl rollout status deployment/quality-air-app -n quality-air
```
> **Why this works**: `imagePullPolicy: Always` forces GKE to download the newest image from Artifact Registry instead of using the local node cache.

---

### Approach B: Updating to a NEW tag via CLI (CI/CD Pipeline Style)
If you tagged your image with a new version (e.g., `:v1.0.1` or a Git commit SHA):
```bash
export NEW_IMAGE="europe-west1-docker.pkg.dev/myproject-329912/quality-air-repo/quality-air-app:v1.0.1"

# Update image directly via kubectl
kubectl set image deployment/quality-air-app quality-air-app="${NEW_IMAGE}" -n quality-air

# Watch the rollout
kubectl rollout status deployment/quality-air-app -n quality-air
```

---

### Approach C: Declarative GitOps (Edit YAML and Apply)
1. In [`kustomization.yaml`](kustomization.yaml), change `newTag: latest` to `newTag: v1.0.1` (or edit `image:` directly in [`deployment.yaml`](deployment.yaml)).
2. Apply the change:
   ```bash
   kubectl apply -k k8s/
   ```
3. Kubernetes compares the desired state with the actual state and automatically starts rolling updates.

---

## 🛡️ 3. How Zero-Downtime Rolling Update Works

In [`deployment.yaml`](deployment.yaml), the strategy is configured as:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Creates 1 new pod first
    maxUnavailable: 0  # NEVER destroys an old pod until the new one is Ready
```

1. GKE starts a **new pod** with the updated image.
2. GKE tests the new pod using the **`readinessProbe`** (`GET /health`).
3. Only when `/health` returns **HTTP 200**, GKE starts routing traffic to the new pod.
4. GKE then terminates **one old pod**.
5. The process repeats until all pods run the new version.
6. **Result**: Your users experience **zero dropped requests or downtime**.

---

## ⏪ 4. Instant Rollback (If a Release Fails)

If a new version has a bug or fails to start, roll back to the previous stable revision instantly:

```bash
# 1. View rollout history revisions
kubectl rollout history deployment/quality-air-app -n quality-air

# 2. Roll back to the immediately preceding revision
kubectl rollout undo deployment/quality-air-app -n quality-air

# 3. Or roll back to a specific revision (e.g., revision 2)
kubectl rollout undo deployment/quality-air-app --to-revision=2 -n quality-air
```

---

## 📊 5. Useful Monitoring & Debugging Commands

```bash
# View pod events (e.g. image pull errors, probe failures)
kubectl describe deployment quality-air-app -n quality-air
kubectl describe pods -l app=quality-air-app -n quality-air

# Stream logs from all deployment pods simultaneously
kubectl logs -l app=quality-air-app -n quality-air -f --prefix

# Scale replicas up manually if needed
kubectl scale deployment quality-air-app --replicas=4 -n quality-air
```

---

## 📈 6. Horizontal Pod Autoscaler (HPA)

The HPA automatically adjusts the number of pods based on CPU consumption:
- **Minimum Replicas**: `2`
- **Maximum Replicas**: `5`
- **Target CPU Utilization**: `50%` (relative to the requested `100m` CPU, i.e. scaling triggers when average pod CPU exceeds `50m`)

### Watch Autoscaling Live
Open a dedicated terminal to monitor the HPA:
```bash
kubectl get hpa quality-air-hpa -n quality-air -w
```

### Test HPA with the Load Generator
In another terminal, launch a high-throughput stress test against your GKE service:
```bash
export GKE_IP=$(kubectl get svc quality-air-service -n quality-air -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

python3 ../load_generator.py -u "http://${GKE_IP}" -c 30 -d 120 --mode stress-fast
```
Watch as the HPA scales the deployment from **2** up to **3, 4, or 5** pods automatically!

