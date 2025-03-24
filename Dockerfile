FROM mcr.microsoft.com/azure-functions/python:4-python3.9

# Set working directory
WORKDIR /app

# Copy application code
COPY example-flask-crud .

# Install requirements
RUN pip install --no-cache-dir -r requirements.txt

# Create a startup script to initialize the database and start the app
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'cd /app' >> /app/start.sh && \
    echo 'python -c "from app import db; db.create_all()"' >> /app/start.sh && \
    echo 'python -m flask run --host=0.0.0.0 --port=80' >> /app/start.sh && \
    chmod +x /app/start.sh

# Set environment variables
ENV FLASK_APP=crudapp.py
ENV PYTHONUNBUFFERED=1
ENV AzureWebJobsScriptRoot=/app
ENV FLASK_ENV=production

# Expose port 80
EXPOSE 80

# Command to run the application with database initialization
CMD ["/app/start.sh"] 