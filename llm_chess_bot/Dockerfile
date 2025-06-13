FROM python:3.13-slim AS builder

# Install Python dependencies
RUN pip install --upgrade pip

WORKDIR /timeplus

COPY ./requirements.txt /timeplus/requirements.txt
RUN pip install -r requirements.txt

COPY ./deps/autogen_core-0.5.7.tar.gz /timeplus/autogen_core-0.5.7.tar.gz
RUN pip install /timeplus/autogen_core-0.5.7.tar.gz 

ADD ./main_server.py /timeplus/
ADD ./static/ /timeplus/static/ 

EXPOSE 5001

ENTRYPOINT ["python", "main_server.py"]