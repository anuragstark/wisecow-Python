# Use a modern, minimal Python image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=4499

# Create a non-root user
RUN adduser --disabled-password --gecos "" wisecow

# Set work directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
# Upgrade core packages to fix Trivy CVE vulnerabilities
RUN pip install --no-cache-dir --upgrade pip wheel==0.46.2 jaraco.context==6.1.0
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Change ownership
RUN chown -R wisecow:wisecow /app

# Switch to non-root user
USER wisecow

# Expose port
EXPOSE 4499

# Run gunicorn server
CMD ["gunicorn", "--bind", "0.0.0.0:4499", "--workers", "2", "app:app"]