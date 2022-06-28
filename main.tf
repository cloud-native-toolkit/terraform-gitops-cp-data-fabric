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
  type  = "base"
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
