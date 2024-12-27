FROM python:3.9.10

ARG VERSION

WORKDIR /timeplus
ADD ./requirements.txt /timeplus
RUN pip3 install -r requirements.txt
ADD ./bluesky /timeplus/bluesky/

EXPOSE 5001

ENTRYPOINT ["uvicorn", "bluesky.service:app", "--host", "0.0.0.0", "--port", "5001", "--http", "h11"]