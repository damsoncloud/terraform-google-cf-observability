# Google Drive inventory export

Submodule of [cf-observability](../../README.md) receiving the Google Drive inventory exported from Google Workspace into BigQuery: a dataset, and the roles of the Google Workspace
service account writing into it. It is called by cf-observability when its `drive_inventory_export` input is set. The export itself is enabled in the Google Workspace admin
console, with the dataset as its destination.

The service account belongs to Google, outside the organisation, so it must be allowed in the `iam.managed.allowedPolicyMembers` constraint, through the
`additional_allowed_members` input of cf-organization's org-policies submodule, and cf-observability adds its ingress rule to the VPC Service Controls perimeter.

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dataset\_id | ID of the dataset. | `string` | n/a | yes |
| project\_id | ID of the project of the dataset, e.g. the Observability project. | `string` | n/a | yes |
| region | Location of the dataset. | `string` | n/a | yes |
| service\_account | Email of the Google Workspace service account exporting the Drive inventory, shown in the Google Workspace admin console. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| dataset | ID of the dataset (`projects/<project>/datasets/<dataset>`), selected as the destination of the export in the Google Workspace admin console. |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->
