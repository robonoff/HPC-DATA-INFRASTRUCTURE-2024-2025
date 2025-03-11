#!/bin/bash

# Export the credentials
export $(cat .env | xargs)

# Configuration
MINIO_ALIAS="minio_q"
MINIO_BUCKET="nomad"
NOMAD_API="http://localhost/nomad-oasis/api/v1/uploads"
TOKEN=$nomad_token  # Use the provided token
TEMP_DIR="/tmp/nomad_downloads"

# Create temporary directory
mkdir -p "${TEMP_DIR}"

# Get list of files already uploaded to NOMAD
echo "Fetching existing uploads from NOMAD..."
NOMAD_FILES=$(curl -s -X GET "${NOMAD_API}" -H "Authorization: Bearer ${TOKEN}" | jq -r '.data[].upload_name')

# Get list of files in MinIO
echo "Fetching file list from MinIO..."
MINIO_FILES=$(mc ls ${MINIO_ALIAS}/${MINIO_BUCKET} | awk '{print $NF}')

# Upload missing files from NOMAD to MinIO
for file in ${NOMAD_FILES}; do
    if echo "${MINIO_FILES}" | grep -q "${file}"; then
        echo "Skipping ${file}, already in MinIO."
    else
        echo "Downloading ${file} from NOMAD..."
        curl -s -X GET "${NOMAD_API}/download/${file}" -H "Authorization: Bearer ${TOKEN}" -o "${TEMP_DIR}/${file}"

        echo "Uploading ${file} to MinIO..."
        mc cp "${TEMP_DIR}/${file}" "${MINIO_ALIAS}/${MINIO_BUCKET}/"

        # Clean up
        rm -f "${TEMP_DIR}/${file}"
    fi
done

echo "Sync complete."
