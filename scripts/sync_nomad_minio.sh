#!/bin/bash

# Export the credentials
export $(cat .env | xargs)

# Configuration
MINIO_ALIAS="minio_q"
MINIO_BUCKET="nomad"
NOMAD_API="http://localhost/nomad-oasis/api/v1/uploads"
TOKEN=$nomad_token  # Use the provided token

# Get list of files in MinIO
echo "Fetching file list from MinIO..."
MINIO_FILES=$(mc ls ${MINIO_ALIAS}/${MINIO_BUCKET} | awk '{print $NF}')

# Get list of files already uploaded to NOMAD
echo "Fetching existing uploads from NOMAD..."
NOMAD_FILES=$(curl -s -X GET "${NOMAD_API}" -H "Authorization: Bearer ${TOKEN}" | jq -r '.data[].upload_name')

# Upload new files
for file in ${MINIO_FILES}; do
    if echo "${NOMAD_FILES}" | grep -q "${file}"; then
        echo "Skipping ${file}, already in NOMAD."
    else
        echo "Uploading ${file} from MinIO directly to NOMAD..."
        mc cat "${MINIO_ALIAS}/${MINIO_BUCKET}/${file}" | curl -X POST "${NOMAD_API}" -F "file=@-" -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: multipart/form-data"
    fi
done

echo "Sync complete."
