
resource null_resource write_outputs {
  provisioner "local-exec" {
    command = "echo \"$${OUTPUT}\" > gitops-output.json"

    environment = {
      OUTPUT = jsonencode({
        name        = module.cp-data-fabric.name
        cpd_namespace= module.cp-data-fabric.cpd_namespace
        branch      = module.cp-data-fabric.branch
        namespace   = module.cp-data-fabric.namespace
        server_name = module.cp-data-fabric.server_name
        layer       = module.cp-data-fabric.layer
        layer_dir   = module.cp-data-fabric.layer == "infrastructure" ? "1-infrastructure" : (module.cp-data-virtualization.layer == "services" ? "2-services" : "3-applications")
        type        = module.cp-data-fabric.type
      })
    }
  }
}
