# State bucket and KMS key are managed in terraform/bootstrap/
# Looked up here so app resources can reference their ARNs

data "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate"
}

data "aws_kms_alias" "tfstate_key" {
  name = "alias/${var.project_name}-tfstate"
}
