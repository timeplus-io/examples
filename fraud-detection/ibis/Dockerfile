FROM continuumio/anaconda3

WORKDIR /timeplus

ADD ./requirements-dev.txt /timeplus
COPY ./ibis_framework-10.0.0.dev426.tar.gz /timeplus/ibis_framework-10.0.0.dev426.tar.gz

RUN conda install conda-forge::gcc -y
RUN conda install jupyter -y 

RUN pip install -r requirements-dev.txt && \
    pip install /timeplus/ibis_framework-10.0.0.dev426.tar.gz