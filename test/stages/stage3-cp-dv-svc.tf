module "cp4d-dv-service" {
    source = "github.com/cloud-native-toolkit/terraform-gitops-cp-data-virt-svc"

    depends_on = [
        module.db2u,
        module.gitops_cp_wml
    ]

    gitops_config = module.gitops.gitops_config
    git_credentials = module.gitops.git_credentials
    server_name = module.gitops.server_name
    namespace = module.gitops_namespace.name
    operator_namespace = "cpd-operators"
    cpd_namespace = "cp4d"
    kubeseal_cert = module.gitops.sealed_secrets_cert
    instance_version = "1.7.8"
    
}