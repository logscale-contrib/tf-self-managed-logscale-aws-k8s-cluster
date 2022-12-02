output "eks_cluster_id" {
  value = module.eks.cluster_id
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

# output "eks_karpenter_iam_role_name" {
#   value = module.eks.eks_managed_node_groups["karpenter"].iam_role_name
# }
# output "eks_karpenter_iam_role_arn" {
#   value = module.eks.eks_managed_node_groups["karpenter"].iam_role_arn
# }
