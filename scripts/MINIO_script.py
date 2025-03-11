from minio import Minio
from urllib.parse import urlparse
from argparse import ArgumentParser
from termcolor import colored

import os
import json
import sys

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


parser = ArgumentParser()
parser.add_argument("--credentials", action="store", default=None)
# parser.add_argument("--create", action="store_true", default=None)
# parser.add_argument("--delete", action="store_true", default=None)
# parser.add_argument("--list", action="store_true", default=None)
# parser.add_argument("--upload", action="store", default=None)
# parser.add_argument("--remove", action="store", default=None)
# parser.add_argument("--bucket", action="store", default=None)
args = parser.parse_args()

if not args.credentials:
  parser.print_usage()
  sys.exit(1)
try:
  with open(args.credentials, "r") as f:
    credentials = json.load(f)
except Exception as e:
  print(f"Could load credentials from {args.credentials}: {e!r}")
  sys.exit(1)

client = Minio(
  "s3.k3s.virtualorfeo.it",
  access_key=credentials["accessKey"],
  secret_key=credentials["secretKey"],
  cert_check=False,
)

# Generate a test file
file_name = "testfile.txt"

if not os.path.exists(file_name):
    with open(file_name, "w") as f:
        f.write("This is a test file for MinIO upload.\n")
        f.write("Line 2: More sample data.\n")
        f.write("Line 3: Testing file generation.\n")
        print(f"Test file '{file_name}' has been created successfully.")

else:
    print(f"Test file '{file_name}' already exists")


# Make the bucket if it doesn't exist.
bucket_name = "test"

found = client.bucket_exists(bucket_name)
if not found:
    client.make_bucket(bucket_name)
    print("Created bucket", bucket_name)
else:
    print("Bucket", bucket_name, "already exists")

# List the existing buckets
print("List the buckets contained")
buckets = client.list_buckets()
for listed_bucket in buckets:
    print(listed_bucket.name, listed_bucket.creation_date.strftime("%Y-%m-%d %H:%M:%S"))

# Upload the test file on the bucket
destination_name = "test-uploaded"
print(f"Upload the file {file_name} as {destination_name} in the {bucket_name}")
client.fput_object(bucket_name, destination_name, file_name)

# List the files
objects = client.list_objects(bucket_name)
print(f"List the files contained in the bucket {bucket_name}")
for object in objects:
    print(object._object_name, object._last_modified.strftime("%Y-%m-%d %H:%M:%S"), object._size)