locals {
  name          = "cpd-data-fabric"
  job_name      = "datafabric-setup-job"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/${local.job_name}"
  service_url   = "http://${local.name}.${var.namespace}"
  values_content = {
    aws_access_key = var.access_key
    aws_secret_key = var.secret_key
    s3_bucket_id = var.s3_bucket_id
    s3_bucket_region = var.s3_bucket_region
    s3_bucket_url = "https://s3.${var.s3_bucket_region}.amazonaws.com"
  }
  layer = "services"
  type  = "base"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
  cpd_namespace = var.cpd_namespace
  
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"
}

module "aws_s3_instance" {
  source = "github.com/cloud-native-toolkit/terraform-aws-s3-instance.git"
  bucket_prefix = "datafabric"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "aws-s3-bucket"{
  source = "github.com/cloud-native-toolkit/terraform-aws-s3-bucket.git"
  bucket_id = module.aws_s3_instance.s3_bucket_id
  file_path = "Datafiles/aws/"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource null_resource create_yaml {
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
