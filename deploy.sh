#!/bin/bash

# OpenCut Deployment Script for Apache Server
# This script automates the deployment process

set -e

echo "🚀 Starting OpenCut deployment..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (use sudo)"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create deployment directory
DEPLOY_DIR="/var/www/opencut"
echo "📁 Creating deployment directory: $DEPLOY_DIR"
mkdir -p $DEPLOY_DIR

# Copy project files
echo "📋 Copying project files..."
cp -r . $DEPLOY_DIR/
cd $DEPLOY_DIR

# Create environment file if it doesn't exist
if [ ! -f "apps/web/.env" ]; then
    echo "⚙️  Creating environment file..."
    cp apps/web/.env.example apps/web/.env
    echo "⚠️  Please edit apps/web/.env with your production settings"
fi

# Enable required Apache modules
echo "🔧 Enabling Apache modules..."
a2enmod proxy
a2enmod proxy_http
a2enmod ssl
a2enmod headers
a2enmod rewrite
a2enmod expires
a2enmod deflate

# Copy Apache configuration
echo "📝 Setting up Apache configuration..."
cp apache-config/opencut.conf /etc/apache2/sites-available/

# Enable the site
echo "🌐 Enabling Apache site..."
a2ensite opencut

# Test Apache configuration
echo "🧪 Testing Apache configuration..."
if apache2ctl configtest; then
    echo "✅ Apache configuration is valid"
else
    echo "❌ Apache configuration has errors. Please fix them before continuing."
    exit 1
fi

# Start Docker services
echo "🐳 Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check if services are running
echo "🔍 Checking service status..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Services are running"
else
    echo "❌ Some services failed to start. Check logs with: docker-compose logs"
    exit 1
fi

# Restart Apache
echo "🔄 Restarting Apache..."
systemctl restart apache2

# Test the application
echo "🧪 Testing application..."
sleep 10
if curl -f http://localhost:3333/api/health > /dev/null 2>&1; then
    echo "✅ Application is responding"
else
    echo "⚠️  Application health check failed. Check logs with: docker-compose logs web"
fi

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit apps/web/.env with your production settings"
echo "2. Update SSL certificate paths in /etc/apache2/sites-available/opencut.conf"
echo "3. Configure your domain DNS to point to this server"
echo "4. Test the application at https://opencut.defintek.io"
echo ""
echo "📊 Useful commands:"
echo "- View logs: docker-compose logs -f"
echo "- Restart services: docker-compose restart"
echo "- Update application: git pull && docker-compose up -d --build"
echo "- Check status: docker-compose ps" 