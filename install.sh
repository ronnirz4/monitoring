#!/bin/bash

# Exit on any error
set -e

# Step 1: Create the monitoring namespace
echo "Creating the monitoring namespace..."
kubectl create namespace monitoring || echo "Namespace 'monitoring' already exists."

# Step 2: Install Prometheus using Helm (if not already installed)
echo "Installing Prometheus using Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus --namespace monitoring || echo "Prometheus is already installed."

# Step 3: Apply Persistent Volume (PV) and Persistent Volume Claim (PVC)
echo "Applying Persistent Volume (PV) and Persistent Volume Claim (PVC)..."
kubectl apply -f prometheus-pv.yaml
kubectl apply -f prometheus-pvc.yaml

# Step 4: Check logs for errors and fix permissions inside the pod
echo "Checking Prometheus server logs..."
POD_NAME=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n monitoring -c prometheus-server || true

echo "Fixing permissions inside Prometheus pod..."
kubectl exec -it $POD_NAME -n monitoring -- /bin/sh -c "mkdir -p /data && chown -R 65534:65534 /data"

# Step 5: Check pod status
echo "Checking pod status..."
kubectl get pods -n monitoring

# Step 6: Port forward to access Prometheus UI
echo "Port forwarding Prometheus UI on localhost:9090..."
kubectl port-forward -n monitoring pod/$POD_NAME 9090:9090 &

echo "Prometheus is now accessible at http://localhost:9090"
