data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "eks" {
  description             = "${var.uniqueName} EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

}
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.uniqueName}/secrets"
  target_key_id = aws_kms_key.eks.key_id
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.0"

  cluster_name    = var.uniqueName
  cluster_version = "1.23"

  cloudwatch_log_group_retention_in_days = 7
  cluster_enabled_log_types              = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_alias.eks.arn
    resources        = ["secrets"]
  }]


  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  vpc_id            = var.vpc_id
  subnet_ids        = var.vpc_public_subnets
  cluster_ip_family = "ipv6"
  eks_managed_node_group_defaults = {
    # We are using the IRSA created below for permissions
    # However, we have to provision a new cluster with the policy attached FIRST
    # before we can disable. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the new cluster
    iam_role_attach_cni_policy = true
  }

  # create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
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

  eks_managed_node_groups = {
    karpenter = {
      instance_types = var.eks_general_instance_type

      min_size     = var.eks_general_min_size
      max_size     = var.eks_general_max_size
      desired_size = var.eks_general_desired_size

      labels = {
        "beta.crowdstrike.com/pool" = "system"
      }

      # labels = var.tags
      iam_role_additional_policies = [
        # Required by Karpenter
        "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
      tags = {
        # This will tag the launch template created for use by Karpenter
        "karpenter.sh/discovery/${var.uniqueName}" = var.uniqueName
      }

    }
  }
  enable_irsa = true
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    # Control plane invoke Karpenter webhook
    ingress_karpenter_webhook_tcp = {
      description                   = "Control plane invoke Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery/${var.uniqueName}" = var.uniqueName
    "aws-alb"                                  = true
  }
  create_cluster_primary_security_group_tags = false
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

module "vpc_cni_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.5.0"
  role_name             = "${var.uniqueName}_vpc_cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true
  create_cni_ipv6_iam_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
