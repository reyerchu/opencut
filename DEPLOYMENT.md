# OpenCut Deployment Guide for Apache Server

## Overview
This guide will help you deploy OpenCut to your Apache server at https://opencut.defintek.io.

## Prerequisites
- Apache server with mod_proxy and mod_proxy_http enabled
- Docker and Docker Compose installed
- SSL certificate for your domain
- PostgreSQL database (can be local or remote)
- Redis instance (can be local or remote)

## Deployment Options

### Option 1: Docker Compose (Recommended)
This is the easiest way to deploy the entire application stack.

### Option 2: Manual Build
Build the application locally and deploy the static files.

## Option 1: Docker Compose Deployment

### 1. Clone and Setup
```bash
# Clone the repository to your server
git clone <repository-url> /var/www/opencut
cd /var/www/opencut

# Create environment file
cp apps/web/.env.example apps/web/.env
```

### 2. Configure Environment Variables
Edit `apps/web/.env`:
```env
DATABASE_URL="postgresql://username:password@your-db-host:5432/opencut"
BETTER_AUTH_URL=https://opencut.defintek.io
BETTER_AUTH_SECRET=your-production-secret-key-here
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
UPSTASH_REDIS_REST_URL=http://localhost:8079
UPSTASH_REDIS_REST_TOKEN=example_token
NODE_ENV=production
PORT=3333
```

### 3. Start the Application
```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### 4. Apache Configuration
Create `/etc/apache2/sites-available/opencut.conf`:
```apache
<VirtualHost *:80>
    ServerName opencut.defintek.io
    Redirect permanent / https://opencut.defintek.io/
</VirtualHost>

<VirtualHost *:443>
    ServerName opencut.defintek.io
    DocumentRoot /var/www/opencut
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /path/to/your/certificate.crt
    SSLCertificateKeyFile /path/to/your/private.key
    SSLCertificateChainFile /path/to/your/chain.crt
    
    # Proxy to Docker container (using port 3333)
    ProxyPreserveHost On
    ProxyPass / http://localhost:3333/
    ProxyPassReverse / http://localhost:3333/
    
    # Security headers
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    
    # Logs
    ErrorLog ${APACHE_LOG_DIR}/opencut_error.log
    CustomLog ${APACHE_LOG_DIR}/opencut_access.log combined
</VirtualHost>
```

### 5. Enable Apache Modules and Site
```bash
# Enable required modules
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod ssl
sudo a2enmod headers
sudo a2enmod rewrite

# Enable the site
sudo a2ensite opencut

# Test configuration
sudo apache2ctl configtest

# Restart Apache
sudo systemctl restart apache2
```

## Option 2: Manual Build Deployment

### 1. Build the Application
```bash
# Install dependencies
cd apps/web
npm install

# Build for production
npm run build

# Export static files (if using static export)
npm run export
```

### 2. Deploy to Apache Document Root
```bash
# Copy built files to Apache document root
sudo cp -r apps/web/out/* /var/www/opencut/

# Set permissions
sudo chown -R www-data:www-data /var/www/opencut
sudo chmod -R 755 /var/www/opencut
```

## Database Setup

### PostgreSQL Setup
```sql
-- Create database and user
CREATE DATABASE opencut;
CREATE USER opencut WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE opencut TO opencut;

-- Run migrations
-- The application will handle migrations automatically on startup
```

### Redis Setup
```bash
# Install Redis
sudo apt update
sudo apt install redis-server

# Configure Redis
sudo nano /etc/redis/redis.conf

# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

## Monitoring and Maintenance

### Health Checks
- Application: https://opencut.defintek.io/api/health
- Database: Check PostgreSQL logs
- Redis: Check Redis logs

### Logs
```bash
# Application logs
docker-compose logs -f web

# Apache logs
sudo tail -f /var/log/apache2/opencut_error.log
sudo tail -f /var/log/apache2/opencut_access.log

# Database logs
docker-compose logs -f db
```

### Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

## Troubleshooting

### Common Issues

1. **Port 3333 not accessible**
   - Check if Docker containers are running: `docker-compose ps`
   - Check container logs: `docker-compose logs web`

2. **Database connection issues**
   - Verify DATABASE_URL in .env file
   - Check if PostgreSQL is running and accessible

3. **SSL certificate issues**
   - Verify certificate paths in Apache configuration
   - Check certificate validity: `openssl x509 -in certificate.crt -text -noout`

4. **Permission issues**
   - Ensure proper file permissions: `sudo chown -R www-data:www-data /var/www/opencut`

### Performance Optimization

1. **Enable Apache caching**
```apache
# Add to VirtualHost configuration
<LocationMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg)$">
    ExpiresActive On
    ExpiresDefault "access plus 1 month"
</LocationMatch>
```

2. **Enable Gzip compression**
```apache
# Add to VirtualHost configuration
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>
```

## Security Considerations

1. **Firewall Configuration**
```bash
# Allow only necessary ports
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 22
sudo ufw enable
```

2. **Regular Updates**
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Docker images
docker-compose pull
docker-compose up -d
```

3. **Backup Strategy**
```bash
# Database backup
docker-compose exec db pg_dump -U opencut opencut > backup.sql

# Application backup
tar -czf opencut-backup-$(date +%Y%m%d).tar.gz /var/www/opencut
``` 