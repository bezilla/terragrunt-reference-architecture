variable "environment" {
  description = "Environment name, used in monitor names and tags (e.g. \"prod\")."
  type        = string
  nullable    = false
}

variable "notification_targets" {
  description = <<-EOT
    Default Datadog notification handles appended to every monitor message (e.g.
    "@slack-acme-alerts", "@pagerduty-Platform"). Per-monitor overrides are also supported.
    Kept as a variable with generic defaults so no team handle or address is baked into the module.
  EOT
  type        = list(string)
  default     = ["@slack-platform-alerts"]
  nullable    = false
}

variable "monitors" {
  description = <<-EOT
    Map of monitors to create, keyed by an id. One module, many monitor definitions — this
    consolidates what were eleven near-identical monitor modules in the source system into a
    single data-driven factory. Each entry:
      - name:            human-readable monitor name (environment is prefixed automatically)
      - type:            Datadog monitor type ("metric alert", "event-v2 alert", "query alert", ...)
      - query:           the monitor query
      - message:         alert body (notification targets are appended automatically)
      - critical:        critical threshold
      - warning:         optional warning threshold
      - priority:        optional 1..5
      - notify_targets:  optional per-monitor override of notification_targets
      - tags:            optional extra tags
  EOT
  type = map(object({
    name           = string
    type           = string
    query          = string
    message        = string
    critical       = number
    warning        = optional(number)
    priority       = optional(number)
    notify_targets = optional(list(string))
    tags           = optional(list(string), [])
  }))
  nullable = false

  validation {
    condition     = length(var.monitors) > 0
    error_message = "Provide at least one monitor."
  }
}
