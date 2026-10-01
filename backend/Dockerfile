FROM python:3.12-slim
WORKDIR /srv/app
# requirements.txt 即锁文件，版本只认这一处
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
