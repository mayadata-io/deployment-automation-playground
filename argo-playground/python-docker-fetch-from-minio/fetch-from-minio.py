import os
from minio import Minio
from minio.error import S3Error

import functools

import datetime

print("*****************************************************");
print("Fetching the most recently created MinIO bucket.......");
print("*****************************************************");

#def comparator(bucket):
#    return bucket.creation_date

def comparator(bucket):
	print(bucket.creation_date)
	return bucket.creation_date

def findMostRecentlyCreatedBucket(buckets):
	latest_creation_date = buckets[0].creation_date
	most_recently_created_bucket = buckets[0]
	for bucket in buckets:
		if bucket.creation_date > latest_creation_date:
			latest_creation_date = bucket.creation_date
			most_recently_created_bucket = bucket
	return most_recently_created_bucket

def main():
    # Create a client with the MinIO server, its access key
    # and secret key.
    client = Minio(
        os.environ['MINIO_SERVER_AND_PORT'],
        access_key=os.environ['MINIO_ACCESS_KEY'],
        secret_key=os.environ['MINIO_SECRET_KEY'],
        secure=False,
    )

    buckets = client.list_buckets()
    newest_bucket = findMostRecentlyCreatedBucket(buckets)
    # print(newest_bucket.name)

    files_in_bucket = client.list_objects(newest_bucket.name)

    volume_store_base_dir = "/mnt/"

    if not os.path.exists(volume_store_base_dir + "localpv-vol-0/"):
    	os.mkdir(volume_store_base_dir + "localpv-vol-0/")

    if not os.path.exists(volume_store_base_dir + "localpv-vol-0/" + newest_bucket.name):
	    os.mkdir(volume_store_base_dir + "localpv-vol-0/" + newest_bucket.name)
	    
    os.chdir(volume_store_base_dir + "localpv-vol-0/" + newest_bucket.name)

    for obj in files_in_bucket:
    	object_resp = client.fget_object(newest_bucket.name, obj.object_name, "" + obj.object_name)

if __name__ == "__main__":
    try:
        main()
    except S3Error as exc:
        print("error occurred.", exc)
