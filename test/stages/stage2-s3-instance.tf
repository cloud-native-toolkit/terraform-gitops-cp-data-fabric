module "aws_s3_instance" {
  source = "github.com/cloud-native-toolkit/terraform-aws-s3-instance.git"
  bucket_prefix = "datafabric"
  access_key = var.access_key
  secret_key = var.secret_key
  region = "ap-south-1"
}
