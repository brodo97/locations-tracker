output "api_gateway_invoke_url" {
  description = "API Gateway base invoke URL. Use this as OwnTracks HTTP method's URL."
  value       = module.api_gateway.invoke_url
}
