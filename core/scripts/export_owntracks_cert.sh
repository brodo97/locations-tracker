#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${OUT_DIR:-${CORE_DIR}/certs}"
CERT_NAME="${CERT_NAME:-spacewar cert}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found." >&2
    exit 1
  fi
}

get_output() {
  local name="$1"
  terraform -chdir="${CORE_DIR}" output -no-color -raw "$name" 2>/dev/null || true
}

require_cmd terraform
require_cmd openssl
require_cmd curl

mkdir -p "${OUT_DIR}"

cert_arn="$(get_output iot_certificate_arn)"
cert_pem="$(get_output iot_certificate_pem)"
private_key="$(get_output iot_certificate_private_key)"
public_key="$(get_output iot_certificate_public_key)"

if [[ -z "${cert_arn}" || -z "${cert_pem}" || -z "${private_key}" ]]; then
  echo "Error: IoT certificate outputs are empty." >&2
  echo "Make sure in core/terraform.tfvars you have enable_iot_core=true and iot_create_certificate=true, then run terraform apply." >&2
  exit 1
fi

cert_id="${cert_arn##*/}"
cert_file="${OUT_DIR}/${cert_id}-certificate.pem.crt"
private_key_file="${OUT_DIR}/${cert_id}-private.pem.key"
public_key_file="${OUT_DIR}/${cert_id}-public.pem.key"
root_ca_file="${OUT_DIR}/AmazonRootCA1.pem"
p12_file="${OUT_DIR}/owntracks.p12"

printf '%s\n' "${cert_pem}" > "${cert_file}"
printf '%s\n' "${private_key}" > "${private_key_file}"
printf '%s\n' "${public_key}" > "${public_key_file}"
chmod 600 "${private_key_file}"

curl -fsSL "https://www.amazontrust.com/repository/AmazonRootCA1.pem" -o "${root_ca_file}"

openssl pkcs12 -legacy -export \
  -in "${cert_file}" \
  -inkey "${private_key_file}" \
  -name "${CERT_NAME}" \
  -out "${p12_file}"

echo "Created files in ${OUT_DIR}:"
echo "- ${cert_file}"
echo "- ${private_key_file}"
echo "- ${public_key_file}"
echo "- ${root_ca_file}"
echo "- ${p12_file}"
