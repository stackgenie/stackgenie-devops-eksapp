## Service Account role to manage Route53
module "iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.3.0"

  name        = "${var.environment}-${var.owner}-${random_id.id.hex}"
  description = "EKS Service account policy for Route53"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

module "iam_assumable_role_with_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true
  role_name = "${var.environment}-${var.owner}-${random_id.id.hex}"
  provider_url = module.eks.cluster_oidc_issuer_url
  role_policy_arns = [
    module.iam_policy.arn,
  ]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:external-dns:external-dns"
  ]
}
