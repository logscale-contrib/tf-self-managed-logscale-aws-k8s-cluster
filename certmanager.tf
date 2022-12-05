
resource "helm_release" "cert-manager" {
  depends_on = [
    module.eks,
    helm_release.promcrds
  ]
  namespace        = "cert-manager"
  create_namespace = true

  name       = "cw"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.9.*"


  values = [<<EOF
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
  - key: "eks.amazonaws.com/compute-type"
    operator: "Equal"
    value: "fargate"
    
installCRDs: true

replicaCount: 2
webhook:
  replicaCount: 2
cainjector:
  replicaCount: 2
serviceAccount:
  create: true
  name: cert-manager
admissionWebhooks:
  certManager:
    enabled: true

prometheus:
  enabled: true
  servicemonitor:
    enabled: true

webhook:
    securePort: 8443
EOF 
  ]
  
}
