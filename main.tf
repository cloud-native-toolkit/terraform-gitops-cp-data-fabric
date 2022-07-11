locals {
  name          = "cpd-data-fabric"
  job_name      = "datafabric-setup-job"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/${local.job_name}"
  secrets_dir   = "${path.cwd}/.tmp/${local.name}/chart/secrets"
  service_url   = "http://${local.name}.${var.namespace}"
  values_content = {
    cpd_namespace = var.cpd_namespace
    operator_namespace = var.operator_namespace
  }
  layer = "services"
  operator_type  = "operators"
  base_type = "base"
  type = "instances"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
  cpd_namespace = var.cpd_namespace
  operator_namespace = var.operator_namespace
  secret_name="aws-details" 
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"
}

module setup_service_account {
  source = "github.com/cloud-native-toolkit/terraform-gitops-service-account.git"

  gitops_config = var.gitops_config
  git_credentials = var.git_credentials
  namespace = var.cpd_namespace
  name = "data-fabric-sa"
  server_name = var.server_name  
}

module setup_rbac {
  depends_on = [module.setup_service_account]
  source = "github.com/cloud-native-toolkit/terraform-gitops-rbac.git?ref=v1.7.1"

  gitops_config             = var.gitops_config
  git_credentials           = var.git_credentials
  service_account_namespace = var.cpd_namespace
  service_account_name      = "data-fabric-sa"
  namespace                 = var.cpd_namespace
  rules                     = [
    {
      apiGroups = ["cpd.ibm.com"]
      resources = ["ibmcpds"]
      verbs = ["get", "watch", "list"]
    },
    {
      apiGroups = ["wkc.cpd.ibm.com"]
      resources = ["wkc"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["ws.cpd.ibm.com"]
      resources = ["ws"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["wml.cpd.ibm.com"]
      resources = ["wmlbases"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["rbac.authorization.k8s.io"]
      resources = ["roles"]
      verbs = ["get", "watch", "list", "create", "patch"]
    },
    {
      apiGroups = ["rbac.authorization.k8s.io"]
      resources = ["rolebindings"]
      verbs = ["get", "watch", "list", "create", "patch"]
    },
    {
      apiGroups = ["db2u.databases.ibm.com"]
      resources = ["bigsqls"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["db2u.databases.ibm.com"]
      resources = ["db2uclusters"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["db2u.databases.ibm.com"]
      resources = ["dvs"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["db2u.databases.ibm.com"]
      resources = ["dvservices"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["apiextensions.k8s.io"]
      resources = ["customresourcedefinitions"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = ["apps"]
      resources = ["statefulsets"]
      verbs = ["create", "delete", "get", "list", "patch", "update"]
    },
    {
      apiGroups = [""]
      resources = ["pods"]
      verbs = ["get", "list", "watch"]
    },
    {
      apiGroups = [""]
      resources = ["pods/log"]
      verbs = ["get", "list", "watch"]
    }
  ]
  server_name               = var.server_name
  cluster_scope             = true
}

resource null_resource create_secrets_yaml {

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-secrets.sh '${local.cpd_namespace}' '${local.secret_name}' '${local.secrets_dir}'"

    environment = {
      BIN_DIR = module.setup_clis.bin_dir
      KEY_AWS_ACCESS_KEY = "aws_access_key"
      VAL_AWS_ACCESS_KEY = var.access_key
      KEY_AWS_SECRET_KEY = "aws_secret_key"
      VAL_AWS_SECRET_KEY = var.secret_key
      KEY_S3_BUCKET_ID = "aws_s3_bucket_id"
      VAL_S3_BUCKET_ID = var.s3_bucket_id
      KEY_S3_BUCKET_REGION = "aws_region"
      VAL_S3_BUCKET_REGION = var.s3_bucket_region
      KEY_S3_BUCKET_URL = "aws_s3_bucket_url"
      VAL_S3_BUCKET_URL = "https://s3.${var.s3_bucket_region}.amazonaws.com"
    }
  }
}

module seal_secrets {
  depends_on = [null_resource.create_secrets_yaml]

  source = "github.com/cloud-native-toolkit/terraform-util-seal-secrets.git"

  source_dir    = local.secrets_dir
  dest_dir      = local.yaml_dir
  kubeseal_cert = var.kubeseal_cert
  label         = local.secret_name
}

resource null_resource create_yaml {
  depends_on = [module.seal_secrets]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.job_name}' '${local.yaml_dir}'"

    environment = {
      VALUES_CONTENT = yamlencode(local.values_content)
    }
  }
}

resource null_resource setup_gitops {
  depends_on = [null_resource.create_yaml]

  triggers = {
    name = local.name
    namespace = var.cpd_namespace
    yaml_dir = local.yaml_dir
    server_name = var.server_name
    layer = local.layer
    type = local.type
    git_credentials = yamlencode(var.git_credentials)
    gitops_config   = yamlencode(var.gitops_config)
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --delete --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }
}
