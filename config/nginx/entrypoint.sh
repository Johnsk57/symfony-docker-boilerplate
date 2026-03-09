#!/bin/sh
# =====================================================
# 🌐 NGINX ENTRYPOINT - SYMFONY STACK ORCHESTRATEUR
# =====================================================
#
# MISSION : Nginx + dépendances (phpMyAdmin/pgAdmin)
# WORKFLOW :
# 1. gettext pour envsubst
# 2. Nginx config dynamique (PROJECT_NAME)
# 3. SSL certs auto-générés
# 4. **SMART WAIT** : phpMyAdmin/pgAdmin ready
# 5. Nginx foreground (daemon off)
# =====================================================

set -e  # 💥 Fail fast (Docker logs propres)

# =====================================================
# 📦 GETTEXT : envsubst pour templates
# =====================================================
if ! command -v envsubst > /dev/null 2>&1; then
    echo "📦 Installation gettext (envsubst)..."
    apk add --no-cache gettext > /dev/null 2>&1
    echo "✅ gettext prêt"
fi

# =====================================================
# 🎛️  VARS : Docker → script
# =====================================================
PROJECT_NAME=${PROJECT_NAME:-symfony}
PROJECT_PATH="/var/www/html/${PROJECT_NAME}"

# =====================================================
# 🌐 NGINX : Config dynamique via envsubst
# =====================================================
NGINX_TMPL="/etc/nginx/nginx.conf.tmpl"
NGINX_CONF="/etc/nginx/conf.d/default.conf"
export PROJECT_NAME  # 🎯 envsubst variable

echo "🔧 Nginx config → ${PROJECT_NAME}..."
if [ -f "${NGINX_TMPL}" ]; then
    envsubst '${PROJECT_NAME}' < "${NGINX_TMPL}" > "${NGINX_CONF}" && \
    echo "✅ Nginx: root ${PROJECT_PATH}/public;"
    nginx -t  # 💡 Test syntaxe
else
    echo "❌ Template ${NGINX_TMPL} manquant → Nginx par défaut"
    exit 1
fi

# =====================================================
# 🔒 SSL : Certs dev (mkcert)
# =====================================================
if [ -f "/generate-cert.sh" ]; then
    echo "🔑 Génération SSL certs..."
    chmod +x /generate-cert.sh && /generate-cert.sh
    echo "✅ Certs localhost/*.localhost"
fi

# =====================================================
# ⏳ SMART WAIT : Dépendances DB GUIs
# =====================================================
# phpMyAdmin (MariaDB stack)
if [ "${DATABASE:-mariadb}" = "mariadb" ]; then
    echo "⏳ Attente phpMyAdmin..."
    timeout 30 sh -c 'until getent hosts phpmyadmin >/dev/null 2>&1; do sleep 1; echo "."; done; echo "✅ phpMyAdmin UP"' || \
    echo "⚠️ phpMyAdmin timeout → continue"
fi

# pgAdmin (PostgreSQL stack)
if [ "${DATABASE}" = "postgresql" ]; then
    echo "⏳ Attente pgAdmin..."
    timeout 30 sh -c 'until getent hosts pgadmin >/dev/null 2>&1; do sleep 1; echo "."; done; echo "✅ pgAdmin UP"' || \
    echo "⚠️ pgAdmin timeout → continue"
fi

# =====================================================
# 🚀 NGINX FOREGROUND (daemon off)
# =====================================================
echo "🌐 Nginx démarrage → https://localhost"
exec nginx -g 'daemon off;'
# 💡 nginx -g daemon off = PID 1 + logs Docker
