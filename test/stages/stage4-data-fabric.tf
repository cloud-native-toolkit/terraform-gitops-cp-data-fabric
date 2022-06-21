module "cp-data-fabric" {
  source = "./module"

  depends_on = [
    module.cpd-dv-provision,
    module.aws-s3-bucket,
    module.aws_s3_instance
  ]

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  cpd_namespace = "cp4d"
  # module.cp4d-instance.namespace
  s3_bucket_id = module.aws_s3_instance.s3_bucket_id
  s3_bucket_region = module.aws_s3_instance.s3_bucket_region
  s3_bucket_url = module.aws_s3_instance.s3_bucket_id
}
