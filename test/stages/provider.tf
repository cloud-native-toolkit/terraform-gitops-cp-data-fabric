provider "aws" {
  region     = var.s3_bucket_region
  access_key = var.access_key
  secret_key = var.secret_key
}