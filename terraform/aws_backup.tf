data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "test-backup-role" {
  name               = "test_backup_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "test-role-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.test-backup-role.name
}

resource "aws_backup_vault" "test-vault" {
  name        = "test_backup_vault"
}

resource "aws_backup_plan" "backup-test" {
  name = "tf_test_backup_plan"

  rule {
    rule_name         = "tf_example_backup_rule"
    target_vault_name = aws_backup_vault.test-vault.name
    schedule          = "cron(00 17 * * ? *)"

    lifecycle {
      cold_storage_after = 14
      delete_after = 180
    }
  }
}

resource "aws_backup_selection" "backup-selection-test" {
  iam_role_arn = aws_iam_role.test-backup-role.arn
  name         = "test_backup_selection"
  plan_id      = aws_backup_plan.backup-test.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backups"
    value = "Enabled"
  }
} 