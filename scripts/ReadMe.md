# PROVIDED EXAMPLE SCRIPTS

In this directory you will find some implementation of the scripts mentioned in the guide.  

## The Testing *venv*

Create a *venv* then install the requirements:

```bash
python -m venv .MINIO \
source .MINIO/bin/activate \
pip install -r requirements.txt
```

## MINIO_script.py

This script is made to test the *Python* *API* to operate on *MinIO*. It requires the creation of a *venv* with the packages specified by the `requireents.txt` file. You can edit however you like following the original [quickstart guide](https://min.io/docs/minio/linux/developers/python/minio-py.html) or the [*Python* *API* reference page](https://min.io/docs/minio/linux/developers/python/API.html).  

To run it, you need to pass the path to the `credentials.json` file containing the *access* and *secret* keys as a variable in this way:

```bash
./MINIO_script.py --credentials=/path/to/your/credentials.json
```

you can check [in the bucket page for *MinIO*](https://minio.k3s.virtualorfeo.it/buckets) whether a bucket was made and whether the test file was uploaded. 

## Synchro scripts

These *bash* scripts get a list of the files present in *MinIO* and *NOMAD*, compares the names, downloads and uploads the missing files from one or the other. One deals with one direction, the other one deals with the opposite one.  

This can easily be implemented better, but they serve the purpose of an example well.
