_default:
  just --list

# Gets the K3s Config and puts it in `~/.kube/config` so that kubectl works locally
get-k3s-config:
  docker cp k3s-server-1:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Starts up nginx and cert-manager within the cluster
services: nginx-ingress cert-manager

# Installs the nginx-ingress chart
nginx-ingress:
  helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace --wait

# Installs the cert-manager and trust-manager chart
cert-manager:
  helm repo add jetstack https://charts.jetstack.io
  helm upgrade --install \
    cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.13.2 \
    --set installCRDs=true \
    --set prometheus.enabled=false
  helm upgrade -i -n cert-manager trust-manager jetstack/trust-manager --wait
  kubectl apply -f ca/cert-manager.yaml 

# Copys the k3s.local CA certificate for installing locally
get-ca-cert:
  kubectl get secrets -n cert-manager root-secret --template="{{{{index .data \"tls.crt\" | base64decode}}" > k3s.ca.crt

# Installs the mastodon chart
mastodon:
  helm upgrade --install --namespace mastodon mastodon mastodon --create-namespace --wait

# Gets the mastodon password for the `testodon@kubernetes.default.svc` user
get-mastodon-password:
  kubectl -n mastodon exec -it deployment/mastodon-web -- tootctl accounts modify testodon --reset-password

# Installs the pixelfed chart
pixelfed:
  helm upgrade --install --namespace pixelfed pixelfed pixelfed --create-namespace --wait
