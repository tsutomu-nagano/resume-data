FROM python:3.10

RUN apt -y update

COPY ./requirements.txt requirements.txt 

RUN pip install -r requirements.txt

WORKDIR /home
