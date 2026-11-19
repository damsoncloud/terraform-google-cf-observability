# Damson Cloud GCP Cloud Foundations: observability

Terraform module of the Damson Cloud GCP Cloud Foundations creating the observability of a Google Cloud organisation:

* centralised logging: an intercepting organisation-level log sink routes the logs to the Observability project, whose sink routes them to a Log Analytics-enabled
  log bucket with a linked BigQuery dataset, readable by the common environment's viewers group,
* optionally, the ingress rule of the organisation-level log sink into the Observability project, added to the VPC Service Controls perimeter of cf-organization,
* notification channels and alerting, including log-based alerts on security-relevant changes,
* notifications of critical and high Security Command Centre findings,
* the billing disabler.

## Usage

```hcl
module "observability" {
  source  = "damsoncloud/cf-observability/google"
  version = "X.Y.Z"

  organization_id          = "123456789012"
  domain                   = "example.com"
  folders                  = module.hierarchy.folders
  observability_project_id = module.organization.observability_project_id
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain | Domain of the organisation's groups, e.g. `example.com` for `gcp-cmn-sres@example.com`. It prefixes the alerting policies' names, to tell apart the alerts of several organisations. | `string` | n/a | yes |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. The common environment's short name prefixes the resources' names (`<common short name>-cf-observability`) and names its groups. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| log\_exclusions | Exclusions of the organisation-level log sink by name: `filter`, the logs not routed to the Observability project; `description`. | ```map(object({ filter = string description = optional(string) }))``` | ```{ "apps-script": { "description": "Excludes the Apps Script logs.", "filter": "resource.type = \"app_script_function\"" } }``` | no |
| log\_retention\_days | Retention of the centralised logging bucket, in days. | `number` | `30` | no |
| observability\_project\_id | ID of the Observability project, e.g. the `observability_project_id` output of cf-organization. | `string` | n/a | yes |
| organization\_id | ID of the organisation, whose logs are routed to the Observability project. | `string` | n/a | yes |
| region | Region of the regional resources, e.g. the centralised logging bucket. | `string` | `"europe-west4"` | no |
| sres\_group\_suffix | Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), notified of the alerts. | `string` | `"sres"` | no |
| viewers\_group\_suffix | Suffix of the common environment's viewers group (`gcp-<common short name>-<suffix>`), which can read all the logs of the centralised logging bucket. | `string` | `"viewers"` | no |
| vpc\_service\_controls | The VPC Service Controls perimeter around the Observability project, to which the ingress rule of the organisation-level log sink is added; not added when null: `perimeter_name`, the perimeter's resource name, e.g. the `perimeter_name` output of cf-organization's vpc-service-controls submodule; `mode`, the submodule's mode: the rule is added to the dry-run configuration, and to the enforced one too when `enforced`. | ```object({ perimeter_name = string mode = optional(string, "dry_run") })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| log\_bucket | ID of the centralised logging bucket (`projects/<project>/locations/<region>/buckets/<bucket>`). |
| log\_linked\_dataset | ID of the BigQuery dataset linked to the centralised logging bucket. |
| organization\_sink\_writer\_identity | Writer identity of the organisation-level log sink, which writes the logs into the Observability project. |
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
