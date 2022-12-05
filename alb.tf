
module "cert_manager_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${var.uniqueName}_cert-manager_cw-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["alb-manager:cw-aws-load-balancer-controller"]
    }
  }


}

resource "helm_release" "alb-manager" {
  depends_on = [
    module.eks,
    module.cert_manager_irsa,
    helm_release.promcrds,
    helm_release.cert-manager
  ]
  namespace        = "alb-manager"
  create_namespace = true

  name       = "cw"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.*"


  values = [<<EOF
region: ${var.region}
vpcId: ${var.vpc_id}
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

clusterName: ${var.uniqueName}
enableCertManager: true

rbac:
    serviceAccount:
        create: true
        name: alb-manager

podDisruptionBudget: 
    maxUnavailable: 1

EOF 
  ]

}
