import os
from minio import Minio
from minio.error import S3Error
import string
import random

print("*****************************************************");
print("Uploading files in ./files-to-upload/ to MinIO.......");
print("*****************************************************");
print("Files to upload:")
for root, dirs, files in os.walk("./files-to-upload/"):
    for filename in files:
        print(filename)
print("*****************************************************");

def random_letter_or_digit():
	x = random.uniform(0.0,1.0);
	letters = string.ascii_lowercase;
	if x > 0.5: # make a random number instead
		letters = string.digits;
	return random.choice(letters);

# make the new bucket name (a random lowercase-letters&numbers string)
def make_new_bucket_string():
    random_bucket_string_length = 25;
    new_bucket_str = '';
    for i in range(0,random_bucket_string_length):
        new_bucket_str += random_letter_or_digit();
    return new_bucket_str;

def main():
    # Create a client with the MinIO server, its access key
    # and secret key.
    client = Minio(
        "3.133.140.118:31030",
        access_key="HKJSDF98jkd76hjsDJKSDjk",
        secret_key="kd89jk3298sdkjHJKDSds89ds/87sd87*",
        secure=False,
    )
    new_bucket_str = make_new_bucket_string();
    found = client.bucket_exists(new_bucket_str);

    while found:
        new_bucket_str = make_new_bucket_string();
        found = client.bucket_exists(new_bucket_str)

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