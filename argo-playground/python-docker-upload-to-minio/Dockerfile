FROM python:3

WORKDIR /usr/src/upload-to-minio-app/

COPY file1.txt ./files-to-upload/
COPY file2.txt ./files-to-upload/
COPY file3.txt ./files-to-upload/
COPY upload-to-minio.py ./

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

CMD [ "python", "./upload-to-minio.py" ]