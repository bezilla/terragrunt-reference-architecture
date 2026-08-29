output "otlp_grpc_endpoint" {
  description = "In-cluster OTLP/gRPC endpoint applications send telemetry to."
  value       = "otel-gateway.${var.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "In-cluster OTLP/HTTP endpoint applications send telemetry to."
  value       = "otel-gateway.${var.namespace}.svc.cluster.local:4318"
}

output "namespace" {
  description = "Namespace the observability layer is deployed into."
  value       = var.namespace
}

output "transport_mode" {
  description = "Whether telemetry flows direct-with-persistent-queue or over the Kafka bus."
  value       = var.kafka.enabled ? "kafka-bus" : "direct"
}
