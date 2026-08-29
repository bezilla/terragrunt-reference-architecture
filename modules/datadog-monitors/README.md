# datadog-monitors

Datadog monitors as data: one `for_each` factory taking a map of monitor definitions (metric/event/query alerts with thresholds, priority, and paging targets). **Collapses many near-identical monitor modules** into a single data-driven module. Notification targets are a variable with generic defaults — no team handle baked in. Provider (API/app keys) is configured by the caller.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.8 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 3.40 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | 3.91.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [datadog_monitor.this](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name, used in monitor names and tags (e.g. "prod"). | `string` | n/a | yes |
| <a name="input_monitors"></a> [monitors](#input\_monitors) | Map of monitors to create, keyed by an id. One module, many monitor definitions — this<br/>collapses what would otherwise be many near-identical monitor modules into a<br/>single data-driven factory. Each entry:<br/>  - name:            human-readable monitor name (environment is prefixed automatically)<br/>  - type:            Datadog monitor type ("metric alert", "event-v2 alert", "query alert", ...)<br/>  - query:           the monitor query<br/>  - message:         alert body (notification targets are appended automatically)<br/>  - critical:        critical threshold<br/>  - warning:         optional warning threshold<br/>  - priority:        optional 1..5<br/>  - notify\_targets:  optional per-monitor override of notification\_targets<br/>  - tags:            optional extra tags | <pre>map(object({<br/>    name           = string<br/>    type           = string<br/>    query          = string<br/>    message        = string<br/>    critical       = number<br/>    warning        = optional(number)<br/>    priority       = optional(number)<br/>    notify_targets = optional(list(string))<br/>    tags           = optional(list(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_notification_targets"></a> [notification\_targets](#input\_notification\_targets) | Default Datadog notification handles appended to every monitor message (e.g.<br/>"@slack-acme-alerts", "@pagerduty-Platform"). Per-monitor overrides are also supported.<br/>Kept as a variable with generic defaults so no team handle or address is baked into the module. | `list(string)` | <pre>[<br/>  "@slack-platform-alerts"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_monitor_ids"></a> [monitor\_ids](#output\_monitor\_ids) | Datadog monitor IDs, keyed by the input map key. |
<!-- END_TF_DOCS -->
