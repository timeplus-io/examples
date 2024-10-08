FROM python:3.9.10

ARG VERSION

WORKDIR /timeplus
ADD ./requirements.txt /timeplus
RUN pip3 install -r requirements.txt
ADD ./service.py /timeplus/
ADD ./is_ddos.py /timeplus/
ADD ./Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv /timeplus/

EXPOSE 5001

ENTRYPOINT ["uvicorn", "service:app", "--host", "0.0.0.0", "--port", "5001", "--http", "h11"]