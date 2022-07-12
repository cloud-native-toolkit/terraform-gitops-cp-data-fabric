module "cp-watson-studio" {
  source = "github.com/cloud-native-toolkit/terraform-gitops-cp-watson-studio.git"

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
  operator_namespace= "cpd-operators"
  # module.gitops_cp4d_operator.namespace
  cpd_namespace = "cp4d"
  # module.cp4d-instance.namespace
  storage_vendor = "ocs"
  storage_class = "ocs-storagecluster-cephfs"
  instance_version = "4.0.9"
  sub_syncwave = "-16"
  inst_syncwave = "-14"
}
