locals {
  arn_prefix_elasticmapreduce = "arn:${var.arn_partition}:elasticmapreduce:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
}
/*
reduced permissions role for EMR. Some permissions can be limited to clusters,
while others must have access to all EMR in order to operate correctly.
*/
resource "aws_iam_policy" "emr_creator_minimal_policy" {
  name   = var.aws_emr_creator_policy_name
  policy = data.aws_iam_policy_document.emr_creator_policy.json
  tags   = var.tags
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "emr_creator_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:AddInstanceGroups",
      "elasticmapreduce:AddJobFlowSteps",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:DescribeJobFlows",
      "elasticmapreduce:DescribeStep",
      "elasticmapreduce:ListBootstrapActions",
      "elasticmapreduce:ListInstances",
      "elasticmapreduce:ListInstanceGroups",
      "elasticmapreduce:ListSteps",
      "elasticmapreduce:TerminateJobFlows"
    ]
    resources = (
      length(var.tamr_emr_cluster_ids) == 0 ?
      ["${local.arn_prefix_elasticmapreduce}:cluster/*"] :
      [for emr_id in var.tamr_emr_cluster_ids :
        "${local.arn_prefix_elasticmapreduce}:cluster/${emr_id}"
      ]
    )
    dynamic "condition" {
      for_each = var.emr_abac_valid_tags
      content {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${condition.key}"
        values   = condition.value
      }
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:RunJobFlow",
    ]
    resources = [
      "${local.arn_prefix_elasticmapreduce}:*"
    ]
    dynamic "condition" {
      for_each = var.emr_abac_valid_tags
      content {
        test     = "StringEquals"
        variable = "aws:RequestTag/${condition.key}"
        values   = condition.value
      }
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = length(var.tamr_emr_role_arns) > 0 ? var.tamr_emr_role_arns : ["arn:${var.arn_partition}:iam::${data.aws_caller_identity.current.account_id}:role/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:DescribeRepository",
      "elasticmapreduce:DescribeSecurityConfiguration"
    ]
    resources = ["${local.arn_prefix_elasticmapreduce}:*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:ListClusters"
    ]
    resources = ["*"]
  }

}

//Attach the above policy to an existing user
resource "aws_iam_role_policy_attachment" "emr_creator_policy_attachment" {
  role       = var.aws_role_name
  policy_arn = aws_iam_policy.emr_creator_minimal_policy.arn
}

// IAM role policy attachment(s) that attach additional policy ARNs to Tamr user IAM role
resource "aws_iam_role_policy_attachment" "additional_user_policies" {
  count      = length(var.additional_policy_arns)
  role       = var.aws_role_name
  policy_arn = element(var.additional_policy_arns, count.index)
}
