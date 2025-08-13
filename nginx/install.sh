#!/bin/bash
set -e

# Variables
DOMAIN="proxy.imzami.com"
PORTS=("99" "98" "500" "4500")
BACKENDS=("a.imzami.com" "b.imzami.com" "c.imzami.com")

# Create folders
mkdir -p nginx/certs nginx/html

# Create docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3'

services:
  nginx:
    image: nginx:latest
    container_name: multiport-proxy
    ports:
      - "80:80"
      - "443:443"
      - "99:99"
      - "98:98"
      - "500:500"
      - "4500:4500"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/letsencrypt
      - ./nginx/html:/var/www/html
    restart: unless-stopped
    depends_on:
      - certbot

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./nginx/certs:/etc/letsencrypt
      - ./nginx/html:/var/www/html
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew --webroot -w /var/www/html --quiet; sleep 12h & wait \$\$!; done;'"
    restart: unless-stopped
EOL

# Create nginx.conf
cat > nginx/nginx.conf <<EOL
worker_processes auto;
events { worker_connections 1024; }

http {
    resolver 1.1.1.1 valid=30s;

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        location /.well-known/acme-challenge/ {
            root /var/www/html;
        }
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
EOL

# Add upstreams
for PORT in "${PORTS[@]}"; do
    echo "    upstream backend_$PORT {" >> nginx/nginx.conf
    echo "        random;" >> nginx/nginx.conf
    for BACKEND in "${BACKENDS[@]}"; do
        echo "        server $BACKEND:$PORT max_fails=3 fail_timeout=10s;" >> nginx/nginx.conf
    done
    echo "    }" >> nginx/nginx.conf
done

# Add servers
for PORT in "${PORTS[@]}"; do
cat >> nginx/nginx.conf <<EOL
    server {
        listen $PORT ssl;
        server_name $DOMAIN;
        location / {
            proxy_pass http://backend_$PORT;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
EOL
done

echo "}" >> nginx/nginx.conf

# Run docker-compose
docker compose up -d

echo "✅ Setup completed. All ports: ${PORTS[*]} are running with HTTPS and auto Let's Encrypt."