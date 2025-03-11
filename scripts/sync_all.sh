#!/bin/bash

# Paths to the original scripts
SYNC_MINIO_TO_NOMAD="./sync_nomad_minio.sh"
SYNC_NOMAD_TO_MINIO="./sync_minio_nomad.sh"

# Ensure both scripts are executable
chmod +x "$SYNC_MINIO_TO_NOMAD" "$SYNC_NOMAD_TO_MINIO"

# Run MinIO to NOMAD sync
echo "Starting sync from MinIO to NOMAD..."
"$SYNC_MINIO_TO_NOMAD"
echo "MinIO to NOMAD sync completed."

# Run NOMAD to MinIO sync
echo "Starting sync from NOMAD to MinIO..."
"$SYNC_NOMAD_TO_MINIO"
echo "NOMAD to MinIO sync completed."

echo "Bidirectional sync process finished."
