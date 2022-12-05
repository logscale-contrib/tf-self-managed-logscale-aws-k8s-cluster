
resource "helm_release" "promcrds" {
  depends_on = [
    module.eks
  ]
  namespace        = "kube-system"
  create_namespace = true

  name       = "prom-crds"
  chart      = "prometheus-operator-crds"
  version    = "0.60.1"
  repository = "https://charts.appscode.com/stable/"


}
