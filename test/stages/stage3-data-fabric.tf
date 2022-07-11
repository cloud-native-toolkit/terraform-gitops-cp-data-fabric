module "cp-data-fabric" {
  source = "./module"

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  cpd_namespace = "cp4d"
  # module.cp4d-instance.namespace
  s3_bucket_id = module.aws_s3_instance.s3_bucket_id
  s3_bucket_region = "ap-south-1"
  access_key = var.access_key
  secret_key = var.secret_key
}
