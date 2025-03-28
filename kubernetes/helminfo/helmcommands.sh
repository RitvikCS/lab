curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# How to get helm values
helm show values prometheus-comunity/kube-prometheus-stack >prometheus-default-values.yaml

# How to upgrade helm
helm upgrade prometheus-stack prometheus-comunity/kube-prometheus-stack -n monitoring --values values.yaml

helm create homepage
helm lint homepage/

helm install --dry-run --debug homepage homepage/
helm install homepage ./homepage

helm repo index . --url https://RitvikCS.github.io/homepage-helm
