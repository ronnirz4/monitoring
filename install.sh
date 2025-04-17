# Create install.sh content
install_sh = """#!/bin/bash

set -e

echo "🚀 Creating 'monitoring' namespace..."
kubectl create namespace monitoring || echo "Namespace already exists"

echo "📦 Adding Helm repos and updating..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "📦 Installing Prometheus..."
helm install prometheus prometheus-community/prometheus --namespace monitoring

echo "💾 Creating Prometheus Persistent Volume..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data/prometheus
EOF

echo "💾 Creating Prometheus PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
EOF

echo "🛠️ Creating Prometheus custom values.yaml for scrape configs..."
cat <<EOF > values.yaml
server:
  persistentVolume:
    enabled: true
    existingClaim: prometheus-pvc
    storageClass: ""
    size: 5Gi

alertmanager:
  persistentVolume:
    enabled: false

serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'teamcity'
        static_configs:
          - targets: ['host.minikube.internal:8111']
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['prometheus-kube-state-metrics.monitoring.svc.cluster.local:8080']
      - job_name: 'node-exporter'
        static_configs:
          - targets: ['prometheus-prometheus-node-exporter.monitoring.svc.cluster.local:9100']
EOF

echo "🔄 Upgrading Prometheus with new scrape configs..."
helm upgrade prometheus prometheus-community/prometheus -f values.yaml -n monitoring

echo "📦 Creating Grafana PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
EOF

echo "🛠️ Creating Grafana custom values.yaml..."
cat <<EOF > grafana-values.yaml
adminUser: admin
adminPassword: admin

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true

persistence:
  enabled: true
  existingClaim: grafana-pvc
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  size: 5Gi

securityContext:
  runAsUser: 472
  fsGroup: 472

sidecar:
  dashboards:
    enabled: false

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers: []
EOF

echo "📦 Installing Grafana..."
helm install grafana grafana/grafana --namespace monitoring -f grafana-values.yaml

echo "✅ Installation complete!"
echo "🌐 To access Prometheus: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "🌐 To access Grafana:   kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "➡️ Then open http://localhost:3000 (user: admin / pass: admin)"
"""

# Save to file
with open("/mnt/data/install.sh", "w") as f:
    f.write(install_sh)

"/mnt/data/install.sh"

