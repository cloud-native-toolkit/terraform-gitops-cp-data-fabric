module "cpd-dv-provision" {
  source = "github.com/cloud-native-toolkit/terraform-gitops-cp-data-virtualization"

  depends_on = [
    module.cp4d-dv-service
  ]


  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  cpd_namespace = "cp4d"
}