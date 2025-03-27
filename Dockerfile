FROM mcr.microsoft.com/azure-functions/python:4-python3.9

WORKDIR /app

# Copy from local directory rather than assuming a specific folder structure
COPY . /app/

# Install dependencies - use requirements.txt from the Flask app
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Create startup script
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'cd /app' >> /app/start.sh && \
    echo 'python -c "from app import db; db.create_all()"' >> /app/start.sh && \
    echo 'python -m flask run --host=0.0.0.0 --port=80' >> /app/start.sh && \
    chmod +x /app/start.sh

ENV FLASK_APP=crudapp.py \
    PYTHONUNBUFFERED=1 \
    AzureWebJobsScriptRoot=/app \
    FLASK_ENV=production

EXPOSE 80

CMD ["/app/start.sh"]
