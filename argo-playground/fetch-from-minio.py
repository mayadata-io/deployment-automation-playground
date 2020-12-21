import os
from minio import Minio
from minio.error import S3Error

import datetime

print("*****************************************************");
print("Fetching the files in the most recently created MinIO bucket.......");
print("*****************************************************");

def comparator(bucket):
    return bucket.creation_date

def main():
    # Create a client with the MinIO server, its access key
    # and secret key.
    client = Minio(
        "3.133.140.118:31030",
        access_key="HKJSDF98jkd76hjsDJKSDjk",
        secret_key="kd89jk3298sdkjHJKDSds89ds/87sd87*",
        secure=False,
    )

    buckets = client.list_buckets()
    buckets_sorted = buckets.sort(key=comparator, reverse=True)
    newest_bucket = buckets_sorted[0];

    # bucket doesn't already exist, so create it
    client.make_bucket(new_bucket_str)

    # Upload '/home/user/Photos/asiaphotos.zip' as object name
    # 'asiaphotos-2015.zip' to bucket 'new_bucket_str'.
    for root, dirs, files in os.walk("./files-to-upload/"):
        for filename in files:
            full_path_to_file = "./files-to-upload/" + filename;
            client.fput_object(new_bucket_str, filename, full_path_to_file);
            print(full_path_to_file + " is successfully uploaded as" + " object " + filename + " to bucket \'"  + new_bucket_str + "\'.")


if __name__ == "__main__":
    try:
        main()
    except S3Error as exc:
        print("error occurred.", exc)