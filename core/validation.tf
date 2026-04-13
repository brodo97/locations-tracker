check "iot_core_region_supported" {
  assert {
    condition     = !var.enable_iot_core || !contains(var.iot_core_unsupported_regions, local.iot_effective_region)
    error_message = "AWS IoT Core is configured in '${local.iot_effective_region}', which is in iot_core_unsupported_regions. Choose a fallback by setting iot_core_region to a supported region (example: eu-west-1)."
  }
}

check "at_least_one_ingestion_mode" {
  assert {
    condition     = var.enable_api_gateway || var.enable_iot_core
    error_message = "At least one ingestion mode must be enabled. Set enable_api_gateway=true and/or enable_iot_core=true."
  }
}
