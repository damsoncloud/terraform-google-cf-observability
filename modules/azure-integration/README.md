# Azure integration

Submodule of [cf-observability](../../README.md) integrating Microsoft Sentinel and Microsoft Defender for Cloud through Workload Identity Federation from the customer's
Microsoft Entra ID tenant. It is called by cf-observability when its `azure_integration` input is set, and creates the tenant's Workload Identity pool and:

* for Microsoft Sentinel, when `sentinel` is true: its provider and service account, and an organisation-level Security Command Centre notification config publishing all
  the active, unmuted findings to a topic, whose subscription the service account consumes,
* for Microsoft Defender for Cloud, when `defender_for_cloud` is set: its providers, the federation of the service accounts created by cf-organization's
  `defender-for-cloud` submodule, the log hydration bucket, and a sink publishing the audit logs to a topic consumed by Defender for Cloud. The organisation-level log sink
  routes the logs of the whole organisation to the project, so the audit logs of the whole organisation are published.

Its `perimeter_ingress_rules` output holds the ingress rules of the service accounts, used from Azure, which cf-observability adds to the VPC Service Controls perimeter.

The connectors are created in Azure after the installation, with the Workload Identity pool and the project.

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| defender\_for\_cloud | The organisation-level part of the Microsoft Defender for Cloud integration, e.g. the `defender_for_cloud` output of cf-organization; not set up when null: `service_accounts`, their emails by name; `log_collection_role`, the custom role consuming the audit log subscription. | ```object({ service_accounts = map(string) log_collection_role = string })``` | n/a | yes |
| organization\_id | ID of the organisation, whose Security Command Centre findings are published for Microsoft Sentinel. | `string` | n/a | yes |
| project\_id | ID of the project of the integration, e.g. the Observability project. | `string` | n/a | yes |
| project\_number | Number of the project, for the VPC Service Controls ingress rules. | `string` | n/a | yes |
| region | Region of the regional resources, e.g. Defender for Cloud's log hydration bucket. | `string` | n/a | yes |
| scc\_location | Security Command Centre location of the findings published for Microsoft Sentinel: `eu`, `sa` or `us` with data residency, `global` otherwise. | `string` | n/a | yes |
| sentinel | Whether the Microsoft Sentinel integration is set up. | `bool` | n/a | yes |
| tenant\_id | ID of the customer's Microsoft Entra ID tenant, naming the Workload Identity pool. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| perimeter\_ingress\_rules | Ingress rules of the integration's service accounts, used from Azure, into the VPC Service Controls perimeter, by rule title. |
| workload\_identity\_pool | Resource name of the Workload Identity pool of the Azure tenant, configured in the Microsoft Sentinel and Defender for Cloud connectors. |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->
