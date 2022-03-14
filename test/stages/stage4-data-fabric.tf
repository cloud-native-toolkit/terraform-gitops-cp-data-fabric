module "cp-data-fabric" {
  source = "./module"

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  cpd_namespace = "gitops-cp4d-instance"
  # module.cp4d-instance.namespace
  s3_bucket_id       = module.aws-s3-bucket.s3_bucket_id
  s3_bucket_region   = module.aws-s3-bucket.s3_bucket_region
}
