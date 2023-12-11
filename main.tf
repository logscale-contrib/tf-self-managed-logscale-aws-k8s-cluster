data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}
data "aws_partition" "current" {}


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


resource "aws_kms_key" "eks" {
  description             = "${var.uniqueName} EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

}

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "19.21.0"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_name                    = var.uniqueName
  cluster_version                 = "1.26"

  cloudwatch_log_group_retention_in_days = 7
  cluster_enabled_log_types              = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {
    # coredns = {
    #   most_recent = true
    # }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                     = var.vpc_id
  subnet_ids                 = var.vpc_private_subnets
  cluster_ip_family          = var.cluster_ip_family
  create_cni_ipv6_iam_policy = var.create_cni_ipv6_iam_policy
  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = true
  create_node_security_group    = true

  eks_managed_node_group_defaults = {
    # We are using the IRSA created below for permissions
    # However, we have to provision a new cluster with the policy attached FIRST
    # before we can disable. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the new cluster
    iam_role_attach_cni_policy = true
  }

  # create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = "admin-caller"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      username = "admin-aws-root"
      groups   = ["system:masters"]
    },
    {
      userarn  = var.aws_admin_arn
      username = "admin-user-role"
      groups   = ["system:masters"]
    },
  ]
  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]

  fargate_profiles = {
    # alb-manager = {
    #   name = "alb-manager"
    #   selectors = [
    #     { namespace = "alb-manager" }
    #   ]
    # }
    # cert-manager = {
    #   name = "cert-manager"
    #   selectors = [
    #     { namespace = "cert-manager" }
    #   ]
    # }
    # external-dns = {
    #   name = "external-dns"
    #   selectors = [
    #     { namespace = "external-dns" }
    #   ]
    # }

    # kube_system = {
    #   name = "kube-system"
    #   selectors = [
    #     { namespace = "kube-system" }
    #   ]
    # }

    karpenter = {
      name = "karpenter"
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    # logscale-operator = {
    #   name = "logscale-operator"
    #   selectors = [
    #     { namespace = "logscale-operator" }
    #   ]
    # }
    # monitoring = {
    #   name = "monitoring"
    #   selectors = [
    #     { namespace = "monitoring" }
    #   ]
    # }
    # otel-operator = {
    #   name = "otel-operator"
    #   selectors = [
    #     { namespace = "otel-operator" }
    #   ]
    # }
    # strimzi-operator = {
    #   name = "strimzi-operator"
    #   selectors = [
    #     { namespace = "strimzi-operator" }
    #   ]
    # }
  }

  # eks_managed_node_groups = {
  #   karpenter = {
  #     instance_types = var.eks_general_instance_type

  #     min_size     = var.eks_general_min_size
  #     max_size     = var.eks_general_max_size
  #     desired_size = var.eks_general_desired_size

  #     labels = {
  #       "beta.crowdstrike.com/pool" = "system"
  #     }

  #     # labels = var.tags
  #     iam_role_additional_policies = [
  #       # Required by Karpenter
  #       "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  #     ]
  #     tags = {
  #       # This will tag the launch template created for use by Karpenter
  #       "karpenter.sh/discovery" = var.uniqueName
  #     }

  #   }
  # }
  enable_irsa = true
  # cluster_security_group_additional_rules = {
  #   egress_nodes_ephemeral_ports_tcp = {
  #     description                = "To node 1025-65535"
  #     protocol                   = "tcp"
  #     from_port                  = 1025
  #     to_port                    = 65535
  #     type                       = "egress"
  #     source_node_security_group = true
  #   }
  # }

  node_security_group_additional_rules = {
  #   # Control plane invoke Karpenter webhook
  #   # ingress_karpenter_webhook_tcp = {
  #   #   description                   = "Control plane invoke Karpenter webhook"
  #   #   protocol                      = "tcp"
  #   #   from_port                     = 8443
  #   #   to_port                       = 8443
  #   #   type                          = "ingress"
  #   #   source_cluster_security_group = true
  #   # }
  #   # ingress_allow_access_from_control_plane_alb = {
  #   #   type                          = "ingress"
  #   #   protocol                      = "tcp"
  #   #   from_port                     = 9443
  #   #   to_port                       = 9443
  #   #   source_cluster_security_group = true
  #   #   description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
  #   # }
  #   # ingress_allow_access_from_control_plane_otel = {
  #   #   type                          = "ingress"
  #   #   protocol                      = "tcp"
  #   #   from_port                     = 443
  #   #   to_port                       = 443
  #   #   source_cluster_security_group = true
  #   #   description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
  #   # }
    ingress_allow_access_from_control_plane_tap = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 8089
      to_port                       = 8089
      source_cluster_security_group = true
      description                   = "Allow access from control plane to linkerd/viz/tap"
    }
  #   ingress_self_all = {
  #     description = "Node to node all ports/protocols"
  #     protocol    = "-1"
  #     from_port   = 0
  #     to_port     = 0
  #     type        = "ingress"
  #     self        = true
  #   }
  #   egress_all = {
  #     description      = "Node all egress"
  #     protocol         = "-1"
  #     from_port        = 0
  #     to_port          = 0
  #     type             = "egress"
  #     cidr_blocks      = ["0.0.0.0/0"]
  #     ipv6_cidr_blocks = ["::/0"]
  #   }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.uniqueName
    "aws-alb"                = true
  }
  create_cluster_primary_security_group_tags = false

}

module "karpenter" {
  source       = "terraform-aws-modules/eks/aws//modules/karpenter"
  version      = "19.21.0"
  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

}



# module "vpc_cni_irsa" {
#   source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version               = "5.9.1"
#   role_name             = "${var.uniqueName}_vpc_cni"
#   attach_vpc_cni_policy = true

#   #ipv4 and ipv6 is mutually exclusive
#   vpc_cni_enable_ipv4 = true
#   # vpc_cni_enable_ipv6   = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-node"]
#     }
#   }

# }


resource "null_resource" "update_kubeconfig" {
  triggers = {}
  depends_on = [
    module.eks
  ]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    # We are removing the deployment provided by the EKS service and replacing it through the self-managed CoreDNS Helm addon
    # However, we are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.region} --name ${var.uniqueName}
    EOT
  }
}
