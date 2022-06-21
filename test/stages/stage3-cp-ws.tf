# module "cp-watson-studio" {
#   source = "github.com/cloud-native-toolkit/terraform-gitops-cp-watson-studio.git"

#   depends_on = [
#     module.gitops_cp_wkc
#   ]

#   gitops_config = module.gitops.gitops_config
#   git_credentials = module.gitops.git_credentials
#   server_name = module.gitops.server_name
#   namespace = module.gitops_namespace.name
#   kubeseal_cert = module.gitops.sealed_secrets_cert
#   operator_namespace= "cpd-operators"
#   # module.gitops_cp4d_operator.namespace
#   cpd_namespace = "cp4d"
#   # module.cp4d-instance.namespace
# }