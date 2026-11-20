# Damson Cloud GCP Cloud Foundations: observability

Terraform module of the Damson Cloud GCP Cloud Foundations creating the observability of a Google Cloud organisation:

* centralised logging: an intercepting organisation-level log sink routes the logs to the Observability project, whose sink routes them to a Log Analytics-enabled
  log bucket with a linked BigQuery dataset, readable by the common environment's viewers group,
* optionally, the ingress rules of the organisation-level log sink and the Security Command Centre notifications into the Observability project, added to the VPC
  Service Controls perimeter of cf-organization,
* alerts to the common environment's SREs group on the centralised logging sinks' errors and on security-relevant changes (organisation and folder IAM
  policies, service account keys, organisation policies), counted by metrics scoped to the centralised logging bucket, as log-based alerting policies cannot
  scan the entries of the organisation, the folders or the other projects,
* email notifications of the critical and high Security Command Centre findings ([`modules/scc-notifications`](modules/scc-notifications)), set up by default,
* the [billing disabler](https://github.com/damsoncloud/gcp.billing-disabler): a Cloud Run service, running as cf-organization's service account, to which the budget
  notifications of the projects enabling it in cf-gcp-project are pushed, with alerts on its events to the SREs and, for the disabled projects, to the billing administrators.

## Usage

```hcl
module "observability" {
  source  = "damsoncloud/cf-observability/google"
  version = "X.Y.Z"

  organization_id          = "123456789012"
  domain                   = "example.com"
  folders                  = module.hierarchy.folders
  observability_project_id = module.organization.observability_project_id
  tf_bootstrap_email       = module.bootstrap.tf_bootstrap_email

  billing_disabler_email       = module.organization.billing_disabler_email
  billing_notification_channel = module.organization.billing_notification_channel
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_disabler\_dry\_run | Whether the billing disabler only logs the projects whose billing it would disable. | `bool` | `false` | no |
| billing\_disabler\_email | Email of the billing disabler's service account, running its Cloud Run service, e.g. the `billing_disabler_email` output of cf-organization, which grants it its roles and `tf-bootstrap` the Service Account User role on it. | `string` | n/a | yes |
| billing\_disabler\_image\_path | Container image of the billing disabler, without the tag. | `string` | `"ghcr.io/damsoncloud/gcp.billing-disabler"` | no |
| billing\_disabler\_image\_tag | Tag of the billing disabler's container image, pinned to a reviewed version. | `string` | `"1.1.6"` | no |
| billing\_notification\_channel | ID of the billing administrators' notification channel (`projects/<project>/notificationChannels/<id>`), e.g. the `billing_notification_channel` output of cf-organization, notified of the projects whose billing is disabled. | `string` | n/a | yes |
| domain | Domain of the organisation's groups, e.g. `example.com` for `gcp-cmn-sres@example.com`. It prefixes the alerting policies' names, to tell apart the alerts of several organisations. | `string` | n/a | yes |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. The common environment's short name prefixes the resources' names (`<common short name>-cf-observability`) and names its groups. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| log\_exclusions | Exclusions of the organisation-level log sink by name: `filter`, the logs not routed to the Observability project; `description`. | ```map(object({ filter = string description = optional(string) }))``` | ```{ "apps-script": { "description": "Excludes the Apps Script logs.", "filter": "resource.type = \"app_script_function\"" } }``` | no |
| log\_retention\_days | Retention of the centralised logging bucket, in days. | `number` | `30` | no |
| observability\_project\_id | ID of the Observability project, e.g. the `observability_project_id` output of cf-organization. | `string` | n/a | yes |
| organization\_id | ID of the organisation, whose logs are routed to the Observability project. | `string` | n/a | yes |
| region | Region of the regional resources, e.g. the centralised logging bucket. | `string` | `"europe-west4"` | no |
| scc\_notifications | Email notifications of the organisation's Security Command Centre findings to the common environment's SREs group ([`modules/scc-notifications`](modules/scc-notifications)); not set up when null, e.g. when the findings reach a SIEM: `location`, the Security Command Centre location, `eu`, `sa` or `us` with data residency, `global` otherwise; `severities`, those of the notified active and unmuted findings. | ```object({ location = optional(string, "eu") severities = optional(list(string), ["CRITICAL", "HIGH"]) })``` | `{}` | no |
| security\_alerts | Alerts on security-relevant audit log entries of the whole organisation, by a key of lowercase letters, digits and underscores, notified to the common environment's SREs group: `display_name`; `filter`, the Logging query of the entries; `severity`, `CRITICAL`, `ERROR` or `WARNING`; `description`, the alert's guidance. The defaults alert on changes of the organisation and folder IAM policies, on the creation or upload of service account keys, and on changes of organisation policies and custom constraints, attempts denied included. | ```map(object({ display_name = string filter = string severity = optional(string, "WARNING") description = optional(string, "") }))``` | ```{ "organization_iam": { "description": "The organisation and folder IAM policies are set authoritatively by the foundations, so a change made otherwise is reverted by their next deployment.", "display_name": "organisation or folder IAM policy changed", "filter": "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND protoPayload.serviceName = \"cloudresourcemanager.googleapis.com\" AND protoPayload.methodName = \"SetIamPolicy\" AND resource.type = (\"organization\" OR \"folder\")" }, "organization_policies": { "description": "The organisation policies are part of the foundations' security baseline; an unexpected change, or an exception, weakens it.", "display_name": "organisation policy changed", "filter": "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND ((protoPayload.serviceName = \"orgpolicy.googleapis.com\" AND protoPayload.methodName = (\"google.cloud.orgpolicy.v2.OrgPolicy.CreatePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.UpdatePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.DeletePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.CreateCustomConstraint\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.UpdateCustomConstraint\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.DeleteCustomConstraint\")) OR (protoPayload.serviceName = \"cloudresourcemanager.googleapis.com\" AND protoPayload.methodName = (\"SetOrgPolicy\" OR \"ClearOrgPolicy\")))" }, "service_account_keys": { "description": "Service account keys are long-lived credentials, whose creation is denied by the organisation policies outside the legacy folder.", "display_name": "service account key created", "filter": "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND protoPayload.serviceName = \"iam.googleapis.com\" AND protoPayload.methodName = (\"google.iam.admin.v1.CreateServiceAccountKey\" OR \"google.iam.admin.v1.UploadServiceAccountKey\")" } }``` | no |
| sres\_group\_suffix | Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), notified of the alerts. | `string` | `"sres"` | no |
| tf\_bootstrap\_email | Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap, granted the Service Account User role on the service accounts the module attaches to resources. | `string` | n/a | yes |
| viewers\_group\_suffix | Suffix of the common environment's viewers group (`gcp-<common short name>-<suffix>`), which can read all the logs of the centralised logging bucket. | `string` | `"viewers"` | no |
| vpc\_service\_controls | The VPC Service Controls perimeter around the Observability project, to which the ingress rule of the organisation-level log sink is added; not added when null: `perimeter_name`, the perimeter's resource name, e.g. the `perimeter_name` output of cf-organization's vpc-service-controls submodule; `mode`, the submodule's mode: the rule is added to the dry-run configuration, and to the enforced one too when `enforced`. | ```object({ perimeter_name = string mode = optional(string, "dry_run") })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| billing\_disabler\_topic | ID of the billing disabler's topic (`projects/<project>/topics/<name>`), to which cf-gcp-project connects the budgets of the projects enabling the billing disabler. |
| log\_bucket | ID of the centralised logging bucket (`projects/<project>/locations/<region>/buckets/<bucket>`). |
| log\_linked\_dataset | ID of the BigQuery dataset linked to the centralised logging bucket. |
| organization\_sink\_writer\_identity | Writer identity of the organisation-level log sink, which writes the logs into the Observability project. |
| scc\_notifications\_topic | ID of the topic the Security Command Centre findings are published to, e.g. for a further subscription; null when the notifications are not set up. |
| sres\_notification\_channel | ID of the notification channel of the common environment's SREs group (`projects/<project>/notificationChannels/<id>`). |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->

## Releases

Releases are dispatched manually on `main` with the [`release.yaml`](.github/workflows/release.yaml) workflow, choosing the part of the version to increase. It calls the
[`github-release.yaml`](https://github.com/damsoncloud/dcp.sdlc#reusable-workflows) reusable workflow, which creates the GitHub release and its tag. The Terraform Registry
publishes the new version from the tag.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Development

The repository uses [devenv](https://devenv.sh) with the shared [devenvbase](https://github.com/damsoncloud/dcp.sdlc/blob/main/devenvbase/README.md), pinned to a
[dcp.sdlc](https://github.com/damsoncloud/dcp.sdlc) release in `devenv.yaml`.

* `devenv shell` starts the shell.
* `devenv test` runs the git hooks and tests.
* `terraform_docs` regenerates the inputs and outputs above, which the `terraform-docs` git hook also does on commit.

The weekly `dcp.sdlc check` workflow opens an issue when a newer dcp.sdlc release is available. Upgrade with `devenv shell -- dcp_sdlc_upgrade_pr`, which also updates
the devenv inputs, runs the tests and opens a pull request.

## Licence

[Apache License 2.0](LICENSE)
