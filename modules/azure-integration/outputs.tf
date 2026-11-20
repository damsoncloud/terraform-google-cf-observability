output "workload_identity_pool" {
  description = "Resource name of the Workload Identity pool of the Azure tenant, configured in the Microsoft Sentinel and Defender for Cloud connectors."
  value       = google_iam_workload_identity_pool.azure.name
}

output "perimeter_ingress_rules" {
  description = "Ingress rules of the integration's service accounts, used from Azure, into the VPC Service Controls perimeter, by rule title."
  value = merge(
    var.sentinel ? {
      "Microsoft Sentinel" = {
        identities = [google_service_account.sentinel[0].member]
        resources  = ["projects/${var.project_number}"]
        service    = "pubsub.googleapis.com"
        method     = "*"
      }
    } : {},
    local.defender_for_cloud ? {
      # The posture management reads the resources of every project in the perimeter, and the agentless scanning snapshots their disks
      "Microsoft Defender for Cloud" = {
        identities = concat(
          [for email in values(var.defender_for_cloud.service_accounts) : "serviceAccount:${email}"],
          [
            "serviceAccount:mdc-agentless-scanning@guardians-prod-diskscanning.iam.gserviceaccount.com",
            "serviceAccount:service-220551266886@compute-system.iam.gserviceaccount.com",
          ],
        )
        resources = ["*"]
        service   = "*"
        method    = "*"
      }
    } : {},
  )
}
