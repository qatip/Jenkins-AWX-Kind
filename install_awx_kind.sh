#!/usr/bin/env bash
# install_awx_kind_3node.sh (hardened)
set -euo pipefail

# ---------- Safe user/env detection ----------
RUN_AS="${SUDO_USER:-${USER:-$(id -un)}}"
HOME_DIR="$(getent passwd "$RUN_AS" | cut -d: -f6 || echo "/home/$RUN_AS")"
export USER="$RUN_AS"
export HOME="$HOME_DIR"
: "${KUBECONFIG:=$HOME/.kube/config}"; export KUBECONFIG

AWX_NAMESPACE="awx"
OPERATOR_TAG="2.19.1"
AWX_ADMIN_USER="admin"
AWX_ADMIN_PASS="ChangeMe123!"     # change for non-demo
HTTP_NODEPORT="30080"
HTTPS_NODEPORT="30443"

echo "[1/10] Install Docker & basics..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release jq
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
fi

# Ensure RUN_AS is in docker group for future logins
if ! id -nG "$RUN_AS" | grep -qw docker; then
  echo "[fix] Adding $RUN_AS to docker group"
  sudo usermod -aG docker "$RUN_AS"
fi

# Decide how to invoke kind in THIS shell
KIND="kind"
if ! docker ps >/dev/null 2>&1; then
  echo "[note] Docker socket not available to $RUN_AS; using 'sudo kind'"
  KIND="sudo kind"
fi

echo "[2/10] Install kubectl (if needed)..."
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

echo "[3/10] Install KinD (if needed)..."
if ! command -v kind >/dev/null 2>&1; then
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
fi

echo "[4/10] Create 3-node KinD cluster (if missing) with NodePort mappings..."
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: ${HTTP_NODEPORT}
    hostPort: ${HTTP_NODEPORT}
    protocol: TCP
  - containerPort: ${HTTPS_NODEPORT}
    hostPort: ${HTTPS_NODEPORT}
    protocol: TCP
- role: worker
- role: worker
EOF

if ! ${KIND} get clusters 2>/dev/null | grep -q '^awx-kind$'; then
  ${KIND} create cluster --name awx-kind --config kind-config.yaml
else
  echo "[*] KinD cluster 'awx-kind' already exists, skipping creation."
fi

echo "[4b/10] Export kubeconfig for ${RUN_AS} and set context..."
mkdir -p "$HOME/.kube"

# Try exporting with the same KIND invoker (handles sudo/non-sudo builds)
if ! ${KIND} export kubeconfig --name awx-kind --kubeconfig "$KUBECONFIG" >/dev/null 2>&1; then
  echo "[fix] Export via sudo then copy to $KUBECONFIG"
  sudo kind export kubeconfig --name awx-kind --kubeconfig /root/.kube/config
  sudo cp /root/.kube/config "$KUBECONFIG"
  sudo chown "$(id -u "$RUN_AS")":"$(id -g "$RUN_AS")" "$KUBECONFIG"
  chmod 600 "$KUBECONFIG"
fi

# Ensure kubectl uses the KinD context (avoid localhost:8080 fallback)
kubectl config use-context kind-awx-kind >/dev/null
kubectl cluster-info --context kind-awx-kind >/dev/null

echo "[5/10] Install local-path-provisioner & set default StorageClass..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl annotate sc local-path storageclass.kubernetes.io/is-default-class=true --overwrite || true

echo "[6/10] Create namespace '${AWX_NAMESPACE}'..."
kubectl create namespace "${AWX_NAMESPACE}" >/dev/null 2>&1 || true

echo "[7/10] Install AWX Operator (tag: ${OPERATOR_TAG})..."
kubectl apply -k "https://github.com/ansible/awx-operator/config/default?ref=${OPERATOR_TAG}" -n "${AWX_NAMESPACE}"
kubectl -n "${AWX_NAMESPACE}" rollout status deploy/awx-operator-controller-manager --timeout=300s

echo "[8/10] Create/refresh admin password secret..."
kubectl -n "${AWX_NAMESPACE}" delete secret awx-admin >/dev/null 2>&1 || true
kubectl -n "${AWX_NAMESPACE}" create secret generic awx-admin --from-literal=password="${AWX_ADMIN_PASS}"

echo "[9/10] Apply minimal AWX custom resource..."
cat > awx.yaml <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
spec:
  admin_user: ${AWX_ADMIN_USER}
  admin_password_secret: awx-admin
  service_type: NodePort
  nodeport_port: ${HTTP_NODEPORT}
EOF
kubectl -n "${AWX_NAMESPACE}" apply -f awx.yaml

echo "[*] Waiting for awx-web to be ready..."
for _ in {1..60}; do
  READY="$(kubectl -n "${AWX_NAMESPACE}" get deploy awx-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ "$READY" == "1" ]] && break
  echo -n "."
  sleep 10
done
echo

echo "[10/10] Cluster state:"
kubectl get nodes -o wide
kubectl -n "${AWX_NAMESPACE}" get pods,svc,pvc

HOST_IP=$(hostname -I | awk '{print $1}')
cat <<EOT

----------------------------------------------------------------
 AWX URL:        http://<YOUR_AWX_VM_PUBLIC_IP>:${HTTP_NODEPORT}
 (VM host IP):   ${HOST_IP}
 Admin user:     ${AWX_ADMIN_USER}
 Admin password: ${AWX_ADMIN_PASS}
 Namespace:      ${AWX_NAMESPACE}
 Kube context:   kind-awx-kind
 Logs:           kubectl -n ${AWX_NAMESPACE} logs deploy/awx-web -f
----------------------------------------------------------------
Notes:
• Works under sudo or as a normal user.
• Uses 'sudo kind' automatically if Docker socket isn’t available to this shell.
• Always leaves a valid kubeconfig for ${RUN_AS} at ${KUBECONFIG} (600 perms) and selects the context.
EOT
