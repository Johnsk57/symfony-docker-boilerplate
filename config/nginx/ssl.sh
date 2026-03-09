#!/bin/bash
# =====================================================
# 🔑 SSL CERTS GENERATOR - NGINX/APACHE DEV
# =====================================================
#
# MISSION : Self-signed certs pour localhost/*.localhost
# OUTPUT : /etc/nginx/certs/selfsigned.crt + .key
# USAGE : Apache/Nginx VHosts (envsubst)
# VALIDITÉ : 365 jours (dev)
# =====================================================

# 📁 Répertoire certificats (Nginx/Apache)
CERTS_DIR="/etc/nginx/certs"

# =====================================================
# 🔍 CHECK : Certs existants ? → Skip
# =====================================================
if [ ! -f "$CERTS_DIR/selfsigned.crt" ] || [ ! -f "$CERTS_DIR/selfsigned.key" ]; then
    echo "🔧 Génération SSL dev (localhost)..."

    # 📁 Créer dossier si absent
    mkdir -p "$CERTS_DIR"

    # 🎯 CERT AUTO-SIGNÉ : localhost + SANs
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$CERTS_DIR/selfsigned.key" \
        -out "$CERTS_DIR/selfsigned.crt" \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:maildev.localhost,DNS:phpmyadmin.localhost,DNS:pgadmin.localhost"
    # 💡 SANs = navigateurs modernes (Chrome/Firefox)

    echo "✅ Certs générés :"
    echo "   📄 $CERTS_DIR/selfsigned.crt"
    echo "   🔑 $CERTS_DIR/selfsigned.key"
    echo "   🌐 Valable : localhost + *.localhost (365j)"
else
    echo "✅ Certs existants → skip (rm $CERTS_DIR/* pour régénérer)"
fi

# Permissions sécurisées (www-data/nginx)
chmod 644 "$CERTS_DIR/selfsigned.crt"
chmod 600 "$CERTS_DIR/selfsigned.key"
chown -R www-data:www-data "$CERTS_DIR" 2>/dev/null || true

echo "🔒 SSL prêt → https://localhost"
