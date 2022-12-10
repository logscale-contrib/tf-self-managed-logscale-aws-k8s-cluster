output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}
output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
output "eks_cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}
output "karpenter_queue_name" {
  value = module.karpenter.queue_name
}
output "karpenter_instance_profile_name" {
  value = module.karpenter.instance_profile_name
}

output "karpenter_irsa_arn" {
  value = module.karpenter.irsa_arn
}
output "cluster_version" {
  value = module.eks.cluster_version
}
# output "eks_karpenter_iam_role_name" {
#   value = module.eks.eks_managed_node_groups["karpenter"].iam_role_name
# }
# output "eks_karpenter_iam_role_arn" {
#   value = module.eks.eks_managed_node_groups["karpenter"].iam_role_arn
# }
