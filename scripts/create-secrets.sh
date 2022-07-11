#!/usr/bin/env bash

NAMESPACE="$1"
SECRET_NAME="$2"
DEST_DIR="$3"

export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"


if [[ -z "${VAL_AWS_ACCESS_KEY}" ]] || [[ -z "${VAL_AWS_SECRET_KEY}" ]] || [[ -z "${VAL_S3_BUCKET_ID}" ]] || [[ -z "${VAL_S3_BUCKET_REGION}" ]] || [[ -z "${VAL_S3_BUCKET_URL}" ]]; then
  echo "VAL_AWS_ACCESS_KEY, VAL_AWS_SECRET_KEY, VAL_S3_BUCKET_ID, VAL_S3_BUCKET_REGION, and VAL_S3_BUCKET_URL are required as environment variables"
  exit 1
fi

if [[ -z "${KEY_AWS_ACCESS_KEY}" ]]; then
  KEY_AWS_ACCESS_KEY="aws_access_key"
fi

if [[ -z "${KEY_AWS_SECRET_KEY}" ]]; then
  KEY_AWS_SECRET_KEY="aws_secret_key"
fi

if [[ -z "${KEY_S3_BUCKET_ID}" ]]; then
  KEY_S3_BUCKET_ID="aws_s3_bucket_id"
fi

if [[ -z "${KEY_S3_BUCKET_REGION}" ]]; then
  KEY_S3_BUCKET_REGION="aws_region"
fi

if [[ -z "${KEY_S3_BUCKET_URL}" ]]; then
  KEY_S3_BUCKET_URL="aws_s3_bucket_url"
fi

echo "**create secret**"

kubectl create secret generic "${SECRET_NAME}" \
  --from-literal="${KEY_AWS_ACCESS_KEY}=${VAL_AWS_ACCESS_KEY}" \
  --from-literal="${KEY_AWS_SECRET_KEY}=${VAL_AWS_SECRET_KEY}" \
  --from-literal="${KEY_S3_BUCKET_ID}=${VAL_S3_BUCKET_ID}" \
  --from-literal="${KEY_S3_BUCKET_REGION}=${VAL_S3_BUCKET_REGION}" \
  --from-literal="${KEY_S3_BUCKET_URL}=${VAL_S3_BUCKET_URL}" \
  -n "${NAMESPACE}"
