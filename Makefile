# =============================================================================
# SYMFONY DOCKER STARTER — MAKEFILE
# =============================================================================
# Ce Makefile orchestre le cycle de vie d'une stack Symfony dockerisée.
#
# Stack composée de :
#   - Un serveur web      : Apache (défaut) ou Nginx
#   - Un runtime PHP      : PHP intégré (Apache) ou PHP-FPM (Nginx)
#   - Une base de données : MariaDB + phpMyAdmin  |  PostgreSQL + pgAdmin
#   - MailDev             : serveur mail de développement
#
# Configuration persistée dans .env.local (généré automatiquement).
# Les fichiers docker-compose sont situés dans config/docker/.
#
# Usage rapide :
#   make init     → configuration interactive + démarrage
#   make up       → démarrer la stack existante
#   make down     → arrêter la stack
#   make bash     → ouvrir un shell dans le conteneur PHP
# =============================================================================

# -----------------------------------------------------------------------------
# Commande de base docker compose pointant sur le fichier commun à tous les
# profils. Les fichiers spécifiques (webserver, database) sont ajoutés
# dynamiquement dans chaque cible en fonction du contenu de .env.local.
# -----------------------------------------------------------------------------
-include .env
COMPOSE_PROJECT_NAME ?= symfony_docker_starter_kit

COMPOSE_COMMON = docker compose -p $(COMPOSE_PROJECT_NAME) -f config/docker/docker-compose.common.yml

# -----------------------------------------------------------------------------
# Valeurs par défaut utilisées quand .env.local n'existe pas encore.
# Peuvent être surchargées en exportant les variables avant d'appeler make,
# ou en modifiant directement .env.local après un premier `make init`.
# -----------------------------------------------------------------------------
DEFAULT_PROJECT_NAME ?= symfony
DEFAULT_SYMFONY_VERSION ?= lts
DEFAULT_WEBSERVER ?= apache
DEFAULT_DATABASE ?= mariadb

# La cible `help` s'affiche quand on tape `make` sans argument.
.DEFAULT_GOAL := help

# =============================================================================
# AIDE
# =============================================================================

.PHONY: help
help: ## Affiche les commandes disponibles
	@echo ""
	@echo "Commandes disponibles :"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# GESTION DE LA CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# ensure-env : Prérequis silencieux inclus dans certaines cibles qui ont
# besoin de lire la configuration. Si .env.local est absent (premier lancement
# ou après un `make reset`), il est créé automatiquement avec les valeurs par
# défaut définies ci-dessus.
# test-env : Savoir si le .env.local existe bien inclus dans certaines cibles
# qui ont besoin que la configuration soit active
# -----------------------------------------------------------------------------
.PHONY: ensure-env test-env
ensure-env:
	@if [ ! -f .env.local ]; then \
		echo "📋 Création de .env.local avec valeurs par défaut..."; \
		echo "# Configuration générée automatiquement" > .env.local; \
		echo "PROJECT_NAME=$(DEFAULT_PROJECT_NAME)" >> .env.local; \
		echo "SYMFONY_VERSION=$(DEFAULT_SYMFONY_VERSION)" >> .env.local; \
		echo "WEBSERVER=$(DEFAULT_WEBSERVER)" >> .env.local; \
		echo "DATABASE=$(DEFAULT_DATABASE)" >> .env.local; \
		echo "✅ .env.local créé"; \
		echo ""; \
	fi
test-env:
	@if [ ! -f .env.local ]; then \
	  echo "❌ Aucune configuration → lance 'make init' d'abord"; \
	  exit 1; \
	fi

# =============================================================================
# INITIALISATION
# =============================================================================

# -----------------------------------------------------------------------------
# init : Point d'entrée principal pour un premier lancement ou une
# reconfiguration. Déroulement :
#
#   1. Si .env.local existe → propose de conserver, changer ou réinitialiser.
#   2. Détecte automatiquement un projet Symfony dans www/ via composer.json,
#      ou propose d'en créer un nouveau.
#   3. Demande interactivement : version Symfony, serveur web, base de données.
#   4. Écrit la configuration dans .env.local.
#   5. Lance `make up` (avec REBUILD=1 si la configuration a changé).
# -----------------------------------------------------------------------------
.PHONY: init
init: ensure-env ## Configuration interactive + demarrage automatique
	@echo ""
	@echo "=== SYMFONY DOCKER STARTER - CONFIGURATION ==="
	@echo ""
	@FORCE_REBUILD=0; \
	SYMFONY_VERSION=""; \
	PROJECT_FOUND=false; \
	PROJECT_DIR=""; \
	DONE=false; \
	\
	if [ -f .env.local ]; then \
	  . ./.env.local; \
	  PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	  WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	  DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	  echo "⚠️  Configuration existante détectée"; \
	  echo ""; \
	  echo "  Projet actuel : $$PROJECT_NAME"; \
	  if [ -d "www/$$PROJECT_NAME" ]; then \
	    echo "  Dossier       : www/$$PROJECT_NAME/ (existe)"; \
	  fi; \
	  echo ""; \
	  echo "Options :"; \
	  echo "  1) Démarrer avec la configuration actuelle ($$PROJECT_NAME)"; \
	  echo "  2) Changer de projet (existant ou nouveau — $$PROJECT_NAME conservé dans www/)"; \
	  echo "  3) Réinitialiser complètement (SUPPRIME le ou les projet(s) dans www/)"; \
	  read -p "Choisir [1]: " CHOICE; \
	  case $$CHOICE in \
	    1) \
	      echo "🚀 Démarrage avec la configuration actuelle..."; \
	      $(MAKE) up; \
	      DONE=true; \
	      ;; \
	    2) \
	      $(MAKE) down; \
	      FORCE_REBUILD=1; \
	      ;; \
	    3) \
	      echo ""; \
	      echo "⚠️  ATTENTION : Que voulez-vous supprimer ?"; \
	      echo "  1) Uniquement www/$$PROJECT_NAME/ (autres projets conservés)"; \
	      echo "  2) TOUS les projets dans www/"; \
	      read -p "Choisir [1]: " DEL_CHOICE; \
	      case $$DEL_CHOICE in \
	        2) \
	          read -p "Confirmer la suppression de TOUS les projets ? (yes/N): " CONFIRM; \
	          if [ "$$CONFIRM" != "yes" ]; then \
	            echo "❌ Annulé"; exit 1; \
	          fi; \
	          $(MAKE) down; \
	          docker run --rm \
	            -v "$$(pwd)/www:/mnt/www" \
	            alpine sh -c "rm -rf /mnt/www/*"; \
	          echo "✅ Tous les projets supprimés"; \
	          ;; \
	        *) \
	          read -p "Confirmer la suppression de www/$$PROJECT_NAME/ ? (yes/N): " CONFIRM; \
	          if [ "$$CONFIRM" != "yes" ]; then \
	            echo "❌ Annulé"; exit 1; \
	          fi; \
	          $(MAKE) down; \
	          docker run --rm \
	            -v "$$(pwd)/www:/mnt/www" \
	            alpine sh -c "rm -rf /mnt/www/$$PROJECT_NAME"; \
	          echo "✅ Projet $$PROJECT_NAME supprimé"; \
	          ;; \
	      esac; \
	      echo ""; \
	      FORCE_REBUILD=1; \
	      ;; \
	  esac; \
	fi; \
	[ "$$DONE" = "true" ] && exit 0; \
	\
	echo ""; \
	echo "📂 Sélection du projet..."; \
	echo ""; \
	\
	EXISTING=""; \
	if [ -d "www" ]; then \
	  for dir in www/*/; do \
	    if [ -f "$${dir}composer.json" ]; then \
	      EXISTING="$$EXISTING $$(basename $$dir)"; \
	    fi; \
	  done; \
	fi; \
	\
	if [ -n "$$EXISTING" ]; then \
	  echo "Projets existants dans www/ :"; \
	  IDX=1; \
	  for p in $$EXISTING; do \
	    echo "  $$IDX) $$p"; \
	    IDX=$$((IDX+1)); \
	  done; \
	  echo "  $$IDX) Créer un nouveau projet"; \
	  echo ""; \
	  read -p "Choisir [1]: " SEL; \
	  SEL=$${SEL:-1}; \
	  IDX=1; \
	  for p in $$EXISTING; do \
	    if [ "$$IDX" = "$$SEL" ]; then \
	      PROJECT_DIR="$$p"; \
	      PROJECT_FOUND=true; \
	      break; \
	    fi; \
	    IDX=$$((IDX+1)); \
	  done; \
	fi; \
	if [ "$$PROJECT_FOUND" = "false" ] && [ -f "www/composer.json" ]; then \
	  echo "⚠️  Projet Symfony détecté à la racine de www/"; \
	  read -p "Nom du projet (dossier à créer) [symfony]: " PROJECT_DIR; \
	  PROJECT_DIR=$${PROJECT_DIR:-symfony}; \
	  echo "📦 Déplacement du projet dans www/$$PROJECT_DIR/..."; \
	  mkdir -p "www/$$PROJECT_DIR"; \
	  find www -maxdepth 1 -mindepth 1 ! -name "$$PROJECT_DIR" -exec mv {} "www/$$PROJECT_DIR/" \; 2>/dev/null || true; \
	  PROJECT_FOUND=true; \
	fi; \
	\
	if [ "$$PROJECT_FOUND" = "false" ]; then \
	  read -p "Nom du nouveau projet [symfony]: " PROJECT_DIR; \
	  PROJECT_DIR=$${PROJECT_DIR:-symfony}; \
	  echo ""; \
	  echo "Version Symfony :"; \
	  echo "  1) lts"; \
	  echo "  2) 7.2"; \
	  echo "  3) 7.1"; \
	  echo "  4) 6.4"; \
	  read -p "Choisir [1]: " VERS; \
	  case $$VERS in \
	    2) SYMFONY_VERSION="7.2" ;; \
	    3) SYMFONY_VERSION="7.1" ;; \
	    4) SYMFONY_VERSION="6.4" ;; \
	    *) SYMFONY_VERSION="lts" ;; \
	  esac; \
	fi; \
	\
	echo ""; \
	echo "Serveur web :"; \
	echo "  1) Apache"; \
	echo "  2) Nginx"; \
	read -p "Choisir [1]: " WEB; \
	case $$WEB in \
	  2) WEBSERVER="nginx" ;; \
	  *) WEBSERVER="apache" ;; \
	esac; \
	\
	echo ""; \
	echo "Base de données :"; \
	echo "  1) MariaDB + phpMyAdmin"; \
	echo "  2) PostgreSQL + pgAdmin"; \
	read -p "Choisir [1]: " DB; \
	case $$DB in \
	  2) DATABASE="postgresql" ;; \
	  *) DATABASE="mariadb" ;; \
	esac; \
	\
	echo "" > .env.local; \
	echo "# Configuration générée par make init" >> .env.local; \
	echo "PROJECT_NAME=$$PROJECT_DIR" >> .env.local; \
	if [ -n "$$SYMFONY_VERSION" ]; then \
	  echo "SYMFONY_VERSION=$$SYMFONY_VERSION" >> .env.local; \
	fi; \
	echo "WEBSERVER=$$WEBSERVER" >> .env.local; \
	echo "DATABASE=$$DATABASE" >> .env.local; \
	\
	echo ""; \
	echo "✅ Configuration enregistrée dans .env.local"; \
	echo ""; \
	echo "  Projet   : $$PROJECT_DIR"; \
	if [ -n "$$SYMFONY_VERSION" ]; then \
	  echo "  Symfony  : $$SYMFONY_VERSION (sera installé au démarrage)"; \
	else \
	  echo "  Symfony  : Projet existant"; \
	fi; \
	echo "  Serveur  : $$WEBSERVER"; \
	echo "  Database : $$DATABASE"; \
	echo ""; \
	echo "🚀 Démarrage des conteneurs..."; \
	echo ""; \
	if [ "$$FORCE_REBUILD" = "1" ]; then \
	  $(MAKE) up REBUILD=1; \
	else \
	  $(MAKE) up; \
	fi


# =============================================================================
# CYCLE DE VIE DE LA STACK
# =============================================================================

# -----------------------------------------------------------------------------
# up : Construit (si nécessaire) et démarre tous les conteneurs.
#
# Les fichiers docker-compose sont composés dynamiquement :
#   docker-compose.common.yml + docker-compose.<DATABASE>.yml + docker-compose.<WEBSERVER>.yml
#
# Passer REBUILD=1 force un `docker build --no-cache` et supprime l'image
# docker-php:latest avant reconstruction (utile après un changement de config
# ou de version PHP).
# -----------------------------------------------------------------------------
.PHONY: up
up: ensure-env ## Demarrer la stack
	@echo "🔧 Chargement de la configuration..."
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	echo "📦 Projet : $$PROJECT_NAME"; \
	echo "🌐 Serveur : $$WEBSERVER"; \
	echo "💾 Database : $$DATABASE"; \
	echo ""; \
	BUILD_OPTS=""; \
	if [ "$(REBUILD)" = "1" ]; then \
		echo "🔧 Rebuild complet sans cache..."; \
		echo "🗑️  Suppression des anciennes images..."; \
		docker rmi -f docker-php:latest 2>/dev/null || true; \
		BUILD_OPTS="--no-cache"; \
	fi; \
	$(COMPOSE_COMMON) --env-file .env.local \
		-f config/docker/docker-compose.$${DATABASE}.yml \
		-f config/docker/docker-compose.$${WEBSERVER}.yml \
		build $$BUILD_OPTS && \
	$(COMPOSE_COMMON) --env-file .env.local \
		-f config/docker/docker-compose.$${DATABASE}.yml \
		-f config/docker/docker-compose.$${WEBSERVER}.yml \
		up -d; \
	echo ""; \
	echo "  ⏳ entrypoint en cours..."; \
	CONTAINER_ID=$$($(COMPOSE_COMMON) --env-file .env.local \
        -f config/docker/docker-compose.$${DATABASE}.yml \
        -f config/docker/docker-compose.$${WEBSERVER}.yml \
        ps -q php 2>/dev/null || \
        $(COMPOSE_COMMON) --env-file .env.local \
        -f config/docker/docker-compose.$${DATABASE}.yml \
        -f config/docker/docker-compose.$${WEBSERVER}.yml \
        ps -q php-fpm); \
    until [ "$$(docker inspect --format='{{.State.Health.Status}}' $$CONTAINER_ID 2>/dev/null)" = "healthy" ]; do \
        echo "  ⏳ ..."; \
        sleep 5; \
    done; \
	echo "✅ Stack démarrée !"
	@echo ""
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	HTTPS_PORT=$${HTTPS_PORT:-8443}; \
	echo "Projet : $$PROJECT_NAME"; \
	echo ""; \
	echo "Accès :"; \
	echo "  Application : https://localhost"; \
	echo "  MailDev     : https://maildev.localhost"; \
	if [ "$$DATABASE" = "mariadb" ]; then \
		echo "  phpMyAdmin  : https://phpmyadmin.localhost"; \
	else \
		echo "  pgAdmin     : https://pgadmin.localhost"; \
	fi
	@echo ""

# -----------------------------------------------------------------------------
# down : Arrête et supprime les conteneurs de la stack courante.
# Si .env.local est absent, tente un `docker compose down` générique.
# -----------------------------------------------------------------------------
.PHONY: down
down: ## Arreter tous les conteneurs
	@echo "🛑 Arrêt projet 'docker' (avec .env si présent)..."
	docker compose --project-name $(COMPOSE_PROJECT_NAME) down --remove-orphans
	@echo "✅ Conteneurs arrêtés"

# -----------------------------------------------------------------------------
# restart : Raccourci down + up (pratique après une modification de config).
# -----------------------------------------------------------------------------
.PHONY: restart
restart: down up ## Redemarrer la stack

# =============================================================================
# OBSERVATION ET DÉBOGAGE
# =============================================================================

# -----------------------------------------------------------------------------
# logs : Suit les logs de tous les conteneurs en temps réel (Ctrl+C pour quitter).
# -----------------------------------------------------------------------------
.PHONY: logs
logs: test-env ## Afficher les logs de tous les conteneurs
	@. ./.env.local; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml logs -f

# -----------------------------------------------------------------------------
# bash : Ouvre un shell interactif dans le conteneur PHP.
#   - Apache → bash dans le conteneur "php"
#   - Nginx  → bash dans le conteneur "php-fpm"
# -----------------------------------------------------------------------------
.PHONY: bash
bash: test-env ## Se connecter au conteneur PHP
	@. ./.env.local; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	if [ "$$WEBSERVER" = "apache" ]; then \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php bash; \
	else \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php-fpm bash; \
	fi

# -----------------------------------------------------------------------------
# status : Affiche l'état (Up/Exit/…) de chaque conteneur de la stack.
# -----------------------------------------------------------------------------
.PHONY: status
status: test-env ## Afficher le statut des conteneurs
	@. ./.env.local; \
		DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
		WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml ps;

# =============================================================================
# COMMANDES SYMFONY / COMPOSER
# =============================================================================

# -----------------------------------------------------------------------------
# composer : Exécute une commande Composer dans le conteneur PHP, dans le
# répertoire du projet Symfony.
# Exemple : make composer CMD="require symfony/mailer"
# -----------------------------------------------------------------------------
.PHONY: composer
composer: test-env ## Executer Composer (ex: make composer CMD="require symfony/mailer")
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	if [ "$$WEBSERVER" = "apache" ]; then \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php sh -c "cd /var/www/html/$$PROJECT_NAME && composer $(CMD)"; \
	else \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php-fpm sh -c "cd /var/www/html/$$PROJECT_NAME && composer $(CMD)"; \
	fi

# -----------------------------------------------------------------------------
# console : Exécute une commande via `php bin/console` dans le conteneur PHP.
# Exemple : make console CMD="cache:clear"
#           make console CMD="doctrine:migrations:migrate"
# -----------------------------------------------------------------------------
.PHONY: console
console: test-env ## Executer Symfony console (ex: make console CMD="cache:clear")
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	if [ "$$WEBSERVER" = "apache" ]; then \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php sh -c "cd /var/www/html/$$PROJECT_NAME && php bin/console $(CMD)"; \
	else \
		$(COMPOSE_COMMON) --env-file .env.local -f config/docker/docker-compose.$${DATABASE}.yml -f config/docker/docker-compose.$${WEBSERVER}.yml exec php-fpm sh -c "cd /var/www/html/$$PROJECT_NAME && php bin/console $(CMD)"; \
	fi

# =============================================================================
# QUALITÉ DE CODE
# =============================================================================

# -----------------------------------------------------------------------------
# phpstan : Analyse statique avec PHPStan (niveau configuré dans phpstan.neon,
# recommandé : level 7 ou plus). Analyse les dossiers src/ et tests/.
# -----------------------------------------------------------------------------
.PHONY: phpstan
phpstan: test-env ## Analyse statique PHPStan (level 7+)
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	if [ "$$WEBSERVER" = "apache" ]; then \
	   $(COMPOSE_COMMON) --env-file .env.local \
	     -f config/docker/docker-compose.$${DATABASE}.yml \
	     -f config/docker/docker-compose.$${WEBSERVER}.yml \
	     exec php sh -c "cd /var/www/html/$$PROJECT_NAME && vendor/bin/phpstan analyse src/ tests/"; \
	else \
	   $(COMPOSE_COMMON) --env-file .env.local \
	     -f config/docker/docker-compose.$${DATABASE}.yml \
	     -f config/docker/docker-compose.$${WEBSERVER}.yml \
	     exec php-fpm sh -c "cd /var/www/html/$$PROJECT_NAME && vendor/bin/phpstan analyse src/ tests/"; \
	fi

# -----------------------------------------------------------------------------
# rector : Lance Rector en mode dry-run (aperçu des refactorisations sans
# modifier les fichiers). La config doit être définie dans rector.php.
# Retirer --dry-run pour appliquer les changements directement.
# -----------------------------------------------------------------------------
.PHONY: rector
rector: test-env ## Rector refacto (dry-run)
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	if [ "$$WEBSERVER" = "apache" ]; then \
	   $(COMPOSE_COMMON) --env-file .env.local \
	     -f config/docker/docker-compose.$${DATABASE}.yml \
	     -f config/docker/docker-compose.$${WEBSERVER}.yml \
	     exec php sh -c "cd /var/www/html/$$PROJECT_NAME && vendor/bin/rector process src/ --dry-run"; \
	else \
	   $(COMPOSE_COMMON) --env-file .env.local \
	     -f config/docker/docker-compose.$${DATABASE}.yml \
	     -f config/docker/docker-compose.$${WEBSERVER}.yml \
	     exec php-fpm sh -c "cd /var/www/html/$$PROJECT_NAME && vendor/bin/rector process src/ --dry-run"; \
	fi

# -----------------------------------------------------------------------------
# php-cs-fixer : Vérifie le style du code via .php-cs-fixer.dist.php en
# mode dry-run (aucun fichier modifié, affiche seulement les différences).
# Silencieusement ignoré si l'outil est absent dans vendor/.
# Utiliser `php-cs-fixer-fix` pour appliquer les corrections.
# -----------------------------------------------------------------------------
.PHONY: php-cs-fixer
php-cs-fixer: test-env ## Vérification style code (dry-run)
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	CONTAINER=$$([ "$$WEBSERVER" = "apache" ] && echo "php" || echo "php-fpm"); \
	SHELL=$$([ "$$WEBSERVER" = "apache" ] && echo "bash" || echo "sh"); \
	$(COMPOSE_COMMON) --env-file .env.local \
	  -f config/docker/docker-compose.$${DATABASE}.yml \
	  -f config/docker/docker-compose.$${WEBSERVER}.yml \
	  exec $$CONTAINER $$SHELL -c "cd /var/www/html/$$PROJECT_NAME && \
	  if [ -f vendor/bin/php-cs-fixer ]; then \
	    echo '🧹 PHP-CS-Fixer'; \
	    vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php --dry-run src/ tests/; \
	  else \
	    echo '⏭️  PHP-CS-Fixer skip'; \
	  fi"

# -----------------------------------------------------------------------------
# php-cs-fixer-fix : Applique automatiquement les corrections de style
# définies dans .php-cs-fixer.dist.php sur src/ et tests/.
# ATTENTION : les fichiers sont modifiés en place — pensez à commiter d'abord.
# -----------------------------------------------------------------------------
.PHONY: php-cs-fixer-fix
php-cs-fixer-fix: test-env ## Correction style code (auto-fix)
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	CONTAINER=$$([ "$$WEBSERVER" = "apache" ] && echo "php" || echo "php-fpm"); \
	SHELL=$$([ "$$WEBSERVER" = "apache" ] && echo "bash" || echo "sh"); \
	$(COMPOSE_COMMON) --env-file .env.local \
	  -f config/docker/docker-compose.$${DATABASE}.yml \
	  -f config/docker/docker-compose.$${WEBSERVER}.yml \
	  exec $$CONTAINER $$SHELL -c "cd /var/www/html/$$PROJECT_NAME && \
	  if [ -f vendor/bin/php-cs-fixer ]; then \
	    echo '✨ PHP-CS-Fixer AUTO-FIX'; \
	    vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php src/ tests/; \
	  else \
	    echo '⏭️  PHP-CS-Fixer skip (outil absent)'; \
	  fi"

# -----------------------------------------------------------------------------
# tools-check : Vérifie que PHPStan, Rector et PHP-CS-Fixer sont présents
# dans vendor/ ET que le conteneur PHP est en cours d'exécution.
# Retourne "tools_ok=true" ou "tools_ok=false" sur stdout.
# Utilisé par `quality` pour décider de lancer ou non les outils.
# -----------------------------------------------------------------------------
.PHONY: tools-check
tools-check: test-env
	@. ./.env.local; \
	PROJECT_NAME=$${PROJECT_NAME:-$(DEFAULT_PROJECT_NAME)}; \
	DATABASE=$${DATABASE:-$(DEFAULT_DATABASE)}; \
	WEBSERVER=$${WEBSERVER:-$(DEFAULT_WEBSERVER)}; \
	CONTAINER=$$([ "$$WEBSERVER" = "apache" ] && echo "php" || echo "php-fpm"); \
	$(COMPOSE_COMMON) --env-file .env.local \
	  -f config/docker/docker-compose.$${DATABASE}.yml \
	  -f config/docker/docker-compose.$${WEBSERVER}.yml \
	  exec -T $$CONTAINER sh -c \
	  "[ -f /var/www/html/$$PROJECT_NAME/vendor/bin/phpstan ] && [ -f /var/www/html/$$PROJECT_NAME/vendor/bin/rector ] && [ -f /var/www/html/$$PROJECT_NAME/vendor/bin/php-cs-fixer ]" \
	&& echo 'tools_ok=true' || echo 'tools_ok=false'

# -----------------------------------------------------------------------------
# quality : Enchaîne PHPStan + Rector + PHP-CS-Fixer.
# Si les outils sont absents (tools-check → false), la cible est ignorée avec
# un avertissement — comportement permissif pour les projets sans ces outils
# ou pour une intégration CI non bloquante.
# -----------------------------------------------------------------------------
.PHONY: quality
quality: test-env ## 🧹 Quality (seulement si outils présents)
	@if [ "$$($(MAKE) --no-print-directory tools-check)" = "tools_ok=true" ]; then \
	  $(MAKE) phpstan && \
	  $(MAKE) rector && \
	  $(MAKE) php-cs-fixer && \
	  echo "✅ Qualité testée !"; \
	else \
	  echo "⚠️ Outils absents ou container stoppé → quality abandonnée"; \
	  exit 0; \
	fi

# =============================================================================
# MAINTENANCE
# =============================================================================

# -----------------------------------------------------------------------------
# clean : Supprime les conteneurs, images et volumes Docker orphelins via
# `docker system prune`. Ne touche pas aux fichiers du projet ni à .env.local.
# -----------------------------------------------------------------------------
.PHONY: clean
clean: ## Nettoyer Docker (images/conteneurs inutilises)
	@docker system prune -f
	@echo "✅ Nettoyage effectué"

# -----------------------------------------------------------------------------
# reset : Réinitialisation COMPLÈTE et DESTRUCTIVE de l'environnement :
#   - Arrête les conteneurs (make down)
#   - Supprime .env.local
#   - Vide www/, data/ et logs/ via un conteneur Alpine (droits root)
#
# ATTENTION : toutes les données non sauvegardées sont perdues.
# Le fichier .env (valeurs par défaut) est conservé.
# Relancer `make init` après un reset pour reconfigurer l'environnement.
# -----------------------------------------------------------------------------
.PHONY: reset
reset: test-env ## Supprimer la configuration et les données
	@echo "⚠️  ATTENTION : Suppression de .env.local, data/, logs/ et www/"
	@read -p "Confirmer ? (y/N): " CONFIRM; \
	if [ "$$CONFIRM" = "y" ] || [ "$$CONFIRM" = "Y" ]; then \
		$(MAKE) down; \
		rm -f .env.local; \
		echo "🗑️  Suppression des données via conteneur..."; \
		docker run --rm \
			-v "$$(pwd)/www:/mnt/www" \
			-v "$$(pwd)/data:/mnt/data" \
			-v "$$(pwd)/logs:/mnt/logs" \
			alpine sh -c "rm -rf /mnt/www/* /mnt/data/* && \
			  find /mnt/logs -mindepth 2 -not -name '.gitkeep' -delete"; \
		echo "✅ Réinitialisation effectuée"; \
		echo "⚠️  Le fichier .env (valeurs par défaut) a été conservé"; \
		echo "Relancer 'make init' pour reconfigurer"; \
	else \
		echo "❌ Annulé"; \
	fi