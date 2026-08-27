# Human users and groups, entirely data-driven.

resource "aws_iam_group" "this" {
  for_each = var.groups
  name     = each.key
}

resource "aws_iam_group_policy_attachment" "this" {
  for_each = {
    for pair in flatten([
      for gname, g in var.groups : [
        for arn in g.policy_arns : {
          key   = "${gname}:${arn}"
          group = gname
          arn   = arn
        }
      ]
    ]) : pair.key => pair
  }

  group      = aws_iam_group.this[each.value.group].name
  policy_arn = each.value.arn
}

resource "aws_iam_user" "this" {
  for_each = var.users
  name     = each.key
  tags     = var.tags
}

resource "aws_iam_user_group_membership" "this" {
  for_each = var.users

  user   = aws_iam_user.this[each.key].name
  groups = [for g in each.value.groups : aws_iam_group.this[g].name]
}
