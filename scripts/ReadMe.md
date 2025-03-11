# PROVIDED EXAMPLE SCRIPTS

In this directory you will find some implementation of the scripts mentioned in the guide.  

## MINIO_script.py

This script is made to test the *Python* *API* to operate on *MinIO*. It requires the creation of a *venv* with the packages specified by the `requireents.txt` file. You can edit however you like following the original [quickstart guide](https://min.io/docs/minio/linux/developers/python/minio-py.html) or the [*Python* *API* reference page](https://min.io/docs/minio/linux/developers/python/API.html).  

To run it, you need to pass the path to the `.env` file containing the *access* and *secret* keys as a variable in this way:

```bash
./MINIO_script.py --credentials=/path/to/your/.env
```


