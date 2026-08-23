FROM python:3.12-slim

WORKDIR /app
COPY backend/ops/security-gateway/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY tooling/security_gateway.py ./security_gateway.py

USER nobody
EXPOSE 8443
CMD ["python", "security_gateway.py"]
