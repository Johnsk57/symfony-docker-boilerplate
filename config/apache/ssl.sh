#!/bin/bash
# =====================================================
# 🔑 SSL CERTS GENERATOR - APACHE DEV
# =====================================================
#
# MISSION : Self-signed certs Apache localhost/*.localhost
# OUTPUT : /etc/ssl/certs/local/selfsigned.crt + .key
# USAGE : Apache VHosts (SSLCertificateFile)
# VALIDITÉ : 365 jours (dev uniquement)
# =====================================================

# 📁 Répertoire Apache standard
CERTS_DIR="/etc/ssl/certs/local"

# =====================================================
# 🔍 CHECK : Certs existants → Skip régénération
# =====================================================
if [ ! -f "$CERTS_DIR/selfsigned.crt" ] || [ ! -f "$CERTS_DIR/selfsigned.key" ]; then
    echo "🔧 Génération SSL Apache dev (localhost)..."

    # 📁 Créer dossier Apache
    mkdir -p "$CERTS_DIR"

    # 🎯 CERT AUTO-SIGNÉ + SANs multi-domaines
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$CERTS_DIR/selfsigned.key" \
        -out "$CERTS_DIR/selfsigned.crt" \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:maildev.localhost,DNS:phpmyadmin.localhost,DNS:pgadmin.localhost"
    # 💡 SANs = navigateurs modernes OK (Chrome/Firefox)

    echo "✅ Certs générés :"
    echo "   📄 $CERTS_DIR/selfsigned.crt"
    echo "   🔑 $CERTS_DIR/selfsigned.key"
    echo "   🌐 Valable : localhost + *.localhost (365j)"
else
    echo "✅ Certs Apache existants → skip"
    echo "   📁 $CERTS_DIR/"
fi

# =====================================================
# 🔐 PERMISSIONS SÉCURISÉES (www-data)
# =====================================================
chmod 644 "$CERTS_DIR/selfsigned.crt" 2>/dev/null || true
chmod 600 "$CERTS_DIR/selfsigned.key" 2>/dev/null || true
chown www-data:www-data "$CERTS_DIR/selfsigned.crt" "$CERTS_DIR/selfsigned.key" 2>/dev/null || true

echo "🔒 SSL Apache prêt → https://localhost"
