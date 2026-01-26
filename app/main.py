import boto3
import feedparser
import hashlib
import os

# YAPILANDIRMA (Terraform'da verdiğin isimlerle aynı olmalı)
S3_BUCKET_NAME = "ses-proje-media-storage-unique-id"
DYNAMODB_TABLE = "ProcessedNews"
RSS_URL = "https://www.webtekno.com/rss.xml" # Örnek bir kaynak
REGION = "eu-central-1"

# AWS Servis Bağlantıları
s3 = boto3.client('s3', region_name=REGION)
polly = boto3.client('polly', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def is_already_processed(news_id):
    """Haber daha önce işlendi mi?"""
    response = table.get_item(Key={'NewsID': news_id})
    return 'Item' in response

def mark_as_processed(news_id, title):
    """Haberi işlendi olarak işaretle."""
    table.put_item(Item={'NewsID': news_id, 'Title': title})

def text_to_speech(text, filename):
    """Metni Polly ile sese çevir ve S3'e yükle."""
    print(f"Ses dosyası oluşturuluyor: {filename}")
    
    response = polly.synthesize_speech(
        Text=text,
        OutputFormat='mp3',
        VoiceId='Filiz' # Türkçe kadın sesi (Veya 'Burcu')
    )

    if "AudioStream" in response:
        # Geçici olarak yerele kaydet, S3'e yükle ve yereli sil
        with open(filename, 'wb') as file:
            file.write(response['AudioStream'].read())
        
        s3.upload_file(filename, S3_BUCKET_NAME, filename)
        os.remove(filename)
        print(f"S3'e yüklendi: {S3_BUCKET_NAME}/{filename}")

def start_process():
    feed = feedparser.parse(RSS_URL)
    
    # Sadece ilk 3 haberi alalım (Test aşaması için ideal)
    for entry in feed.entries[:3]:
        news_id = hashlib.md5(entry.link.encode()).hexdigest()
        
        if is_already_processed(news_id):
            print(f"Atlanıyor (Zaten var): {entry.title}")
            continue

        # BEDROCK OLMADAN ÖZETLEME: Başlık + Özet (İlk 500 karakter)
        clean_summary = entry.summary[:500].split('<')[0] # HTML etiketlerini basitçe temizle
        full_text = f"Haberin başlığı: {entry.title}. Detaylar şöyle: {clean_summary}"
        
        filename = f"{news_id}.mp3"
        text_to_speech(full_text, filename)
        mark_as_processed(news_id, entry.title)

if __name__ == "__main__":
    start_process()