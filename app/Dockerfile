# 1. Hafif bir Python imajı seçiyoruz
FROM python:3.9-slim

# 2. Çalışma dizinini belirliyoruz
WORKDIR /app

# 3. Bağımlılıkları kopyalayıp yüklüyoruz
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Uygulama kodunu kopyalıyoruz
COPY main.py .

# 5. Konteyner çalıştığında scripti başlatıyoruz
CMD ["python", "main.py"]