# AWS Load Balancer Controller: cada Ingress con ingressClassName "alb"
# aprovisiona y administra el Application Load Balancer compartido.
#
# AWS Academy: no se crean roles IAM ni OIDC provider. El controller usa
# las credenciales de LabRole del nodo vía IMDS.
resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # WAF y Shield no están habilitados en AWS Academy Learner Lab.
  set {
    name  = "enableShield"
    value = "false"
  }

  set {
    name  = "enableWaf"
    value = "false"
  }

  set {
    name  = "enableWafv2"
    value = "false"
  }
}
