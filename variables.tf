
variable "gitops_config" {
  type        = object({
    boostrap = object({
      argocd-config = object({
        project = string
        repo = string
        url = string
        path = string
      })
    })
    infrastructure = object({
      argocd-config = object({
        project = string
        repo = string
        url = string
        path = string
      })
      payload = object({
        repo = string
        url = string
        path = string
      })
    })
    services = object({
      argocd-config = object({
        project = string
        repo = string
        url = string
        path = string
      })
      payload = object({
        repo = string
        url = string
        path = string
      })
    })
    applications = object({
      argocd-config = object({
        project = string
        repo = string
        url = string
        path = string
      })
      payload = object({
        repo = string
        url = string
        path = string
      })
    })
  })
  description = "Config information regarding the gitops repo structure"
}

variable "git_credentials" {
  type = list(object({
    repo = string
    url = string
    username = string
    token = string
  }))
  description = "The credentials for the gitops repo(s)"
  sensitive   = true
}

variable "namespace" {
  type        = string
  description = "The namespace where the application should be deployed"
}

variable "kubeseal_cert" {
  type        = string
  description = "The certificate/public key used to encrypt the sealed secrets"
  default     = ""
}

variable "server_name" {
  type        = string
  description = "The name of the server"
  default     = "default"
}

variable "cpd_namespace" {
  type        = string
  description = "CPD namespace"
  default = "cp4d"
}

variable "operator_namespace" {
  type        = string
  description = "Namespace for cpd operators"
  default = "cpd-operators"
}

variable "s3_bucket_id" {
  description = "The name of the bucket."
  default     = ""
}

variable "s3_bucket_region" {
  type        = string
  default     = "ap-south-1"
  description = "Please set the region where the resouces to be created "
}

variable "s3_bucket_url" {
  type        = string
  default     = ""
  description = "Please set the bucket url where the resouces to be created "
}

variable "access_key" {
  type        = string
  description= " Refer https://docs.aws.amazon.com/powershell/latest/userguide/pstools-appendix-sign-up.html"
}

variable "secret_key" {
  type        = string
  description= " Refer https://docs.aws.amazon.com/powershell/latest/userguide/pstools-appendix-sign-up.html"
 }

variable "wkc_inst_name" {
  type        = string
  description = "WKC Instance name"
  default = "wkc-cr"
}

variable "ws_inst_name" {
  type        = string
  description = "WS Instance name"
  default = "ws-cr"
}

variable "wml_inst_name" {
  type        = string
  description = "WML Instance name"
  default = "ibm-cpd-wml-operator-subscription"
}

variable "dv_svc_inst_name" {
  type        = string
  description = "DV Instance name"
  default = "ibm-dv-operator-catalog-subscription"
}
