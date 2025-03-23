FROM python:3.9-slim

WORKDIR /app

COPY example-flask-crud/ .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 80

ENV FLASK_APP=crudapp.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=80

CMD ["flask", "run"] 