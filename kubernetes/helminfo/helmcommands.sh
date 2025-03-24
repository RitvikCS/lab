helm create homepage
helm lint homepage/

helm install --dry-run --debug homepage homepage/
helm install homepage ./homepage

helm repo index . --url https://RitvikCS.github.io/homepage-helm
