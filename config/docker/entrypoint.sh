#!/bin/bash
# =====================================================
# 🚪 SYMFONY DOCKER ENTRYPOINT
# =====================================================
#
# MISSION : 1 conteneur = Symfony prêt (dev/prod)
# WORKFLOW :
# 1. Debug vars (.env.local → Docker env)
# 2. Apache config (envsubst template)
# 3. SSL certs auto-générés
# 4. Projet auto-créé (symfony new || migration)
# 5. Permissions (www-data + 775 var/)
# 6. Composer install + assets compile
# 7. **QUALITY TOOLS** : PHPStan/Rector/CS-Fixer auto
# 8. Server start (apache2/php-fpm)
# =====================================================

set -e  # 💥 Stop on error (Docker logs propres)

# =====================================================
# 🔍 DEBUG : Env vars (Makefile → Docker)
# =====================================================
echo "=== 🧪 VARIABLES DOCKER ==="
echo "PROJECT_NAME = ${PROJECT_NAME}"
echo "SYMFONY_VERSION = ${SYMFONY_VERSION}"
echo "WEBSERVER = ${WEBSERVER}"
echo "=================================="

# Defaults sécurisés
PROJECT_NAME=${PROJECT_NAME:-symfony}
PROJECT_PATH="/var/www/html/${PROJECT_NAME}"
WEBSERVER=${WEBSERVER:-apache}

# =====================================================
# 🔧 ROOT PERMISSIONS + SYMFONY CLI CACHE (AVANT symfony new)
# =====================================================
echo "🔐 Root permissions..."

# Symfony CLI + Composer (root → www-data)
mkdir -p /.symfony5 /.symfony6 /tmp/composer-tmp /root/.composer
chown -R www-data:www-data /.symfony* /tmp /root/.composer

# UID/GID synchro (src/ volumes)
usermod -u ${HOST_UID:-1000} -o www-data
groupmod -g ${HOST_GID:-1000} -o www-data 2>/dev/null || true
chown -R www-data:www-data /var/www/html

echo "✅ UID${HOST_UID:-1000} + Symfony cache prêt"

# =====================================================
# 🌐 APACHE : Config dynamique (envsubst)
# =====================================================
if [ "${WEBSERVER}" = "apache" ]; then
    APACHE_TMPL="/etc/apache2/sites-available/apache-standalone.conf.tmpl"
    APACHE_CONF="/etc/apache2/sites-enabled/000-default.conf"
    export PROJECT_NAME  # 🎯 envsubst requiert

    echo "🔧 Apache config → ${PROJECT_NAME}..."
    if [ -f "${APACHE_TMPL}" ]; then
        envsubst < "${APACHE_TMPL}" > "${APACHE_CONF}" && \
        a2dissite 000-default 2>/dev/null || true && \
        a2ensite 000-default && \
        echo "✅ Apache: DocumentRoot ${PROJECT_PATH}/public"
    else
        echo "❌ Template ${APACHE_TMPL} manquant → Apache par défaut"
    fi
else
    echo "ℹ️ Nginx"
fi

# =====================================================
# 🔒 SSL : Certs auto (dev)
# =====================================================
if [ -f "/generate-cert.sh" ]; then
    chmod +x /generate-cert.sh
    /generate-cert.sh  # mkcert localhost/*.localhost
fi

# =====================================================
# 📦 PROJET SYMFONY : Création/Migration/Auto-wait
# =====================================================
echo "📂 Projet: ${PROJECT_NAME} → ${PROJECT_PATH}"
mkdir -p "${PROJECT_PATH}"

if [ ! -f "${PROJECT_PATH}/composer.json" ]; then
    SYMFONY_VERSION=${SYMFONY_VERSION:-lts}

    # 🔄 MIGRATION racine → sous-dossier
    if [ -f "/var/www/html/composer.json" ]; then
        echo "📦 Migration racine → ${PROJECT_NAME}/"
        shopt -s dotglob
        mv /var/www/html/* "${PROJECT_PATH}/" 2>/dev/null || true
        rm -rf /var/www/html/*  # Nettoyage racine
        echo "✅ Migration OK"
    # 🚀 AUTO-CRÉATION Symfony
    elif [ "$SYMFONY_VERSION" != "false" ]; then
        echo "🆕 symfony new ${SYMFONY_VERSION} --webapp..."
        cd /tmp && symfony new symfony-temp --webapp --version="${SYMFONY_VERSION}" --no-git
        shopt -s dotglob
        cp -a /tmp/symfony-temp/. "${PROJECT_PATH}/"
        rm -rf /tmp/symfony-temp
        chown -R www-data:www-data "${PROJECT_PATH}"
        echo "✅ Symfony ${SYMFONY_VERSION} créé"
    else
        echo "⚠️ Projet manquant → attente dev..."
        sleep 30  # ⏳ Hot reload bind mount
    fi
fi

# =====================================================
# 🚫 SAFETY : Vérif finale composer.json
# =====================================================
if [ ! -f "${PROJECT_PATH}/composer.json" ]; then
    echo "❌ AUCUN PROJET → démarrage serveur quand même"
    exec "$@"  # Apache/FPM anyway
fi
echo "✅ Projet OK: ${PROJECT_PATH}/composer.json"

# =====================================================
# 🔧 PERMISSIONS (Symfony best practices)
# =====================================================
echo "🔐 Permissions..."

# Scripts + console
find "${PROJECT_PATH}" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
[ -f "${PROJECT_PATH}/bin/console" ] && chmod +x "${PROJECT_PATH}/bin/console"

# var/ (Symfony cache/sessions)
[ -d "${PROJECT_PATH}/var" ] && {
    chown -R www-data:www-data "${PROJECT_PATH}/var"
    chmod -R 775 "${PROJECT_PATH}/var"
}

# public/ (755 dirs, 644 files)
[ -d "${PROJECT_PATH}/public" ] && {
    find "${PROJECT_PATH}/public" -type d -exec chmod 755 {} \;
    find "${PROJECT_PATH}/public" -type f -exec chmod 644 {} \;
}

# vendor/ (644 +x bin/)
[ -d "${PROJECT_PATH}/vendor" ] && {
    find "${PROJECT_PATH}/vendor" -type d -exec chmod 755 {} \;
    find "${PROJECT_PATH}/vendor" -type f -exec chmod 644 {} \;
    find "${PROJECT_PATH}/vendor/bin" -type f -exec chmod +x {} \;
}

# =====================================================
# 📦 COMPOSER : Auto-install si manquant
# =====================================================
if [ ! -f "${PROJECT_PATH}/vendor/autoload.php" ]; then
    echo "🎼 composer install --optimize..."
    cd "${PROJECT_PATH}"
    composer install --no-interaction --optimize-autoloader --no-dev
    echo "✅ Vendor prêt"
fi

# =====================================================
# 🎨 ASSETMAPPER : Auto-compile (Symfony 7+)
# =====================================================
if [ -f "${PROJECT_PATH}/importmap.php" ]; then
    if [ ! -d "${PROJECT_PATH}/public/assets" ] || [ -z "$(ls -A ${PROJECT_PATH}/public/assets)" ]; then
        echo "🎨 importmap:install + asset-map:compile..."
        cd "${PROJECT_PATH}"
        php bin/console importmap:install 2>/dev/null || true
        php bin/console asset-map:compile 2>/dev/null || true
        echo "✅ Assets compilés"
    fi
fi

# =====================================================
# 🧪 QUALITY TOOLS AUTO (PHPStan + Rector + CS-Fixer)
# =====================================================
if [ ! -f "${PROJECT_PATH}/vendor/bin/rector" ] || [ ! -f "${PROJECT_PATH}/vendor/bin/phpstan" ]; then
    echo "🔬 Installation quality tools..."
    cd "${PROJECT_PATH}"

    # Plugins autorisés + dev tools
    composer config allow-plugins.phpstan/extension-installer true --no-plugins
    composer require --dev \
        "phpstan/phpstan:^1.12" \
        "phpstan/extension-installer" \
        "rector/rector:^1.2" \
        "friendsofphp/php-cs-fixer:^3.48" \
        --ignore-platform-reqs --no-interaction

    # Clean rebuild
    rm -rf vendor/ composer.lock 2>/dev/null || true
    composer install --no-cache --ignore-platform-reqs --no-interaction
    composer dump-autoload --optimize

    # 📄 Configs PRO auto-générées
    cat > "${PROJECT_PATH}/rector.php" << 'EOF'
<?php declare(strict_types=1);
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\SetList;
return RectorConfig::configure()
    ->withPaths([__DIR__.'/src', __DIR__.'/tests'])
    ->withPreparedSets(codeQuality: true, deadCode: true, typeDeclarations: true);
EOF

    cat > "${PROJECT_PATH}/phpstan.neon" << 'EOF'
parameters:
    level: 7
    paths: [src, tests]
EOF

    echo "✅ Quality tools + configs (PHPStan 7 + Rector S6/7)"
    chmod +x "${PROJECT_PATH}/vendor/bin/"* 2>/dev/null || true
fi

touch /tmp/entrypoint-ready

echo "🎉 Entrypoint terminé → Server START"
exec "$@"  # apache2-foreground | php-fpm
