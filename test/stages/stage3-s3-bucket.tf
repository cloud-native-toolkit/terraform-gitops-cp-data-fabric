module "aws-s3-bucket" {
  source = "github.com/cloud-native-toolkit/terraform-aws-s3-bucket.git"
  bucket_id = module.aws_s3_instance.s3_bucket_id
}
