# Security Command Centre finding notifications

Submodule of [cf-observability](../../README.md) emailing the Security Command Centre findings of the organisation. It is called by cf-observability when its
`scc_notifications` input is set, which is the default; leave it unset when the findings already reach a SIEM, e.g. Microsoft Sentinel.

An organisation-level notification config publishes the findings to a topic, whose Eventarc trigger runs a workflow logging each finding with its console URL. A
log-based alerting policy on the workflow's entries emails the finding's category, severity and resource, and a link to the finding in the jurisdictional console of the
Security Command Centre location. Security Command Centre Standard cannot export the findings to Cloud Logging, so the workflow reads the published messages instead.

The alerting policy notifies at most once in 5 minutes: when several findings are published at once, e.g. after a first scan, only the first one is emailed.

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| alert\_display\_name | Display name of the alerting policy. | `string` | n/a | yes |
| deployer\_email | Email of the service account applying the module, e.g. `tf-bootstrap`, granted the Service Account User role on the workflow's service account. | `string` | n/a | yes |
| name | Name of the notification config, the topic, the workflow and its trigger. | `string` | n/a | yes |
| notification\_channels | Notification channels of the alerting policy (`projects/<project>/notificationChannels/<id>`). | `list(string)` | n/a | yes |
| organization\_id | ID of the organisation, whose findings are notified. | `string` | n/a | yes |
| project\_id | ID of the project of the topic, the workflow and the alerting policy, e.g. the Observability project. | `string` | n/a | yes |
| region | Region of the workflow and its trigger. | `string` | n/a | yes |
| scc\_location | Security Command Centre location of the findings: `eu`, `sa` or `us` with data residency, `global` otherwise. The findings are linked in the location's jurisdictional console, e.g. `console.eu.cloud.google.com`. | `string` | n/a | yes |
| severities | Severities of the notified findings. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| topic | ID of the topic the findings are published to (`projects/<project>/topics/<name>`). |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->
