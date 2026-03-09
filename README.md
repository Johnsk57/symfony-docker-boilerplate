<div align="center">

<img src="https://symfony.com/logos/symfony_black_03.svg" width="80" alt="Symfony Logo" />

# Symfony Docker Starter Kit

**Lance un projet Symfony production-ready en moins de 2 minutes.**  
Multi-webserver · Multi-database · HTTPS · Qualité de code intégrée

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PHP](https://img.shields.io/badge/PHP-8.4-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![Symfony](https://img.shields.io/badge/Symfony-6.4%20|%207.x-000000?logo=symfony)](https://symfony.com/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Quality Gate](https://github.com/JohnsK57/symfony-docker-boilerplate/actions/workflows/quality.yml/badge.svg)](https://github.com/JohnsK57/symfony-docker-boilerplate/actions/workflows/quality.yml)

</div>

---

## Pourquoi ce starter ?

La plupart des stacks Docker Symfony sont soit trop simples, soit trop rigides.  
Celle-ci est **modulaire, opinionnée sur la qualité, et opérationnelle dès le premier `make init`**.

| ✅ Ce que tu obtiens | ❌ Ce que tu n'as pas à faire |
|---|---|
| HTTPS + sous-domaines auto-configurés | Générer des certificats à la main |
| Choix Apache **ou** Nginx | Toucher aux configs serveur |
| MariaDB **ou** PostgreSQL | Jongler entre plusieurs `docker-compose.yml` |
| Symfony CLI incluse dans le conteneur | Installer Symfony CLI localement |
| Projet vierge **ou** migration auto détectée | Configurer l'arborescence manuellement |
| Composer install + AssetMapper auto au démarrage | Lancer les commandes d'init à la main |
| PHPStan + Rector + CS-Fixer auto-installés | Configurer les outils de qualité un par un |
| Quality Gate CI sur chaque push (GitHub Actions) | Monter un pipeline CI from scratch |
| Logs persistés par service | Chercher où sont tes logs |
| Permissions `var/`, `public/`, `vendor/` gérées automatiquement | Déboguer des erreurs 403/500 liées aux droits |

---

## Stack

```
PHP 8.4 · Composer · Symfony CLI
Apache 2.4  ou  Nginx 1.27  (au choix)
MariaDB 11.7 + phpMyAdmin 5.2  /  PostgreSQL 17 + pgAdmin 4  (au choix)
MailDev 2.1 — capture d'emails en local
OPcache + xDebug (port 9003)
PHPStan ^1.12 · Rector ^1.2 · PHP-CS-Fixer ^3.48
GitHub Actions — Quality Gate + TREE.md auto-généré
Makefile — toutes les commandes simplifiées
```

---

## 🚀 Démarrage rapide

### Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Git
- `make` — voir installation ci-dessous si besoin

<details>
<summary><strong>Installer make</strong></summary>

| OS | Commande |
|---|---|
| Linux / WSL2 | `sudo apt install make` |
| macOS | `brew install make` *(ou inclus avec Xcode CLI Tools)* |
| Windows | `choco install make` ou `winget install GnuWin32.Make` |

> **Sans make ?** Toutes les commandes `make xxx` ont leur équivalent `docker compose` documenté plus bas.

</details>

### Installation

```bash
git clone https://github.com/JohnsK57/symfony-docker-boilerplate.git
cd symfony-docker-boilerplate
make init
```

`make init` te guide interactivement : choix du webserver, de la base de données, version de Symfony. C'est tout.  
Au démarrage, le conteneur **créé automatiquement** un projet Symfony vierge si aucun projet n'est détecté.

---

### Configuration manuelle (sans `make init`)

Créer un fichier `.env.local` à la racine :

```dotenv
# Nom du projet (préfixe des conteneurs Docker)
PROJECT_NAME=symfony

# Version Symfony cible
SYMFONY_VERSION=lts        # ou 7.2, 7.1, 6.4

# Serveur web
WEBSERVER=nginx            # ou apache

# Base de données
DATABASE=mariadb           # ou postgresql

# Credentials DB (optionnel — valeurs par défaut ci-dessous)
# DB_NAME=symfony
# DB_USER=symfony
# DB_PASSWORD=symfony
# DB_ROOT_PASSWORD=root
```

Puis lance la stack :

```bash
# ✅ Recommandé — gère tout automatiquement
make up
```

```bash
# 🔧 Équivalent sans make (exemple avec nginx + mariadb)
docker compose -p symfony_docker_starter_kit \
  -f config/docker/docker-compose.common.yml \
  -f config/docker/docker-compose.mariadb.yml \
  -f config/docker/docker-compose.nginx.yml \
  --env-file .env.local \
  up -d
```

> 💡 La stack combine 3 fichiers docker-compose dynamiquement selon tes choix WEBSERVER et DATABASE. make up résout cette composition automatiquement — adapte les fichiers -f si tu utilises nginx ou postgresql.

---

## Services & URLs

Les services sont accessibles via **sous-domaines HTTPS** (proxy Apache/Nginx intégré).  
Les ports directs sont disponibles pour les clients SQL/SMTP.

### Stack MariaDB

| Service | URL | Credentials par défaut |
|---|---|---|
| **App Symfony** | https://localhost | — |
| **MailDev** | https://maildev.localhost | — |
| **phpMyAdmin** | https://phpmyadmin.localhost | user: `symfony` / pass: `symfony` |
| **MariaDB** *(client SQL)* | `127.0.0.1:3306` | user: `symfony` / pass: `symfony` |

### Stack PostgreSQL

| Service | URL | Credentials par défaut |
|---|---|---|
| **App Symfony** | https://localhost | — |
| **MailDev** | https://maildev.localhost | — |
| **pgAdmin** | https://pgadmin.localhost | `admin@localhost.com` / `password_admin` |
| **PostgreSQL** *(client SQL)* | `127.0.0.1:5432` | user: `symfony` / pass: `symfony` |

> 💡 Tous les credentials sont surchargeables dans `.env.local` (`DB_USER`, `DB_PASSWORD`, `PGADMIN_PASSWORD`...).

> 📧 **MAILER_DSN Symfony** : `smtp://mail:1025` (réseau Docker interne)

---

## ⚠️ Certificat HTTPS auto-signé

Au premier accès à `https://localhost`, le navigateur affiche un avertissement. C'est **normal et attendu** en développement local.

- **Chrome / Edge** : *Avancé → Continuer vers localhost* — une seule validation suffit pour tous les `*.localhost`
- **Firefox** : peut demander une confirmation par sous-domaine

---

## Commandes `make`

### Docker

```bash
make init        # Configuration interactive + démarrage complet
make up          # Démarrer la stack
make down        # Arrêter
make restart     # Redémarrer
make logs        # Suivre les logs en temps réel
make status      # Afficher le statut des conteneurs
make bash        # Shell dans le conteneur PHP
make help        # Lister toutes les commandes disponibles
```

### Nettoyage

```bash
make clean       # Supprime les conteneurs/images Docker orphelins (docker system prune)
make reset       # Réinitialise tout (⚠️ données perdues)
```

### Qualité de code

> 🤖 **`make quality` s'exécute automatiquement à chaque `git push` via GitHub Actions** — uniquement si un projet Symfony est détecté dans `www/`. Sur un template vide ou un fork, le workflow passe vert instantanément sans démarrer Docker.

```bash
make phpstan           # Analyse statique — level 7
make rector            # Suggestions de refactoring (dry-run)
make php-cs-fixer      # Vérification du style (dry-run)
make php-cs-fixer-fix  # Correction automatique du style
make quality           # PHPStan + Rector + CS-Fixer enchaînés
```

---

## Intégrer un projet Symfony existant

Le conteneur **détecte automatiquement** un projet existant dans `www/` au démarrage et migre l'arborescence si nécessaire.

```bash
git clone https://github.com/JohnsK57/symfony-docker-boilerplate.git mon-projet
cd mon-projet

# Dépose ton projet dans www/
cp -r /chemin/vers/ton/projet/* www/

# Lance — la détection est automatique
make init

# Vérifie la qualité du code
make quality
```

---

## Structure du projet

> 📂 L'arborescence est auto-générée par GitHub Actions à chaque push : **[voir TREE.md](TREE.md)**

---

## Troubleshooting

<details>
<summary><strong>Port 80 ou 443 déjà utilisé</strong></summary>

Surcharge les ports dans `.env.local` :

```dotenv
HTTP_PORT=8080
HTTPS_PORT=8443
```
</details>

<details>
<summary><strong>Les emails ne s'affichent pas dans MailDev</strong></summary>

Vérifie que le `MAILER_DSN` dans ton `.env` Symfony est :

```dotenv
MAILER_DSN=smtp://mail:1025
```

`mail` est le nom du service Docker (réseau interne), pas `localhost`.
</details>

<details>
<summary><strong>xDebug ne se connecte pas</strong></summary>

Assure-toi que ton IDE écoute sur le port `9003` et que `XDEBUG_MODE=debug` est défini dans `.env.local`.
</details>

<details>
<summary><strong>Le Quality Gate échoue sur GitHub</strong></summary>

Le workflow ne lance les tests que si `www/*/composer.json` est présent dans le repo.  
Sur un fork ou template vide, il passe vert automatiquement sans démarrer Docker.
</details>

---

## Contribuer

Les PRs sont les bienvenues ! Pour des changements importants, ouvre d'abord une issue pour en discuter.

1. Fork le repo
2. Crée ta branche (`git checkout -b feature/ma-feature`)
3. Commit (`git commit -m 'feat: ajout de X'`)
4. Push (`git push origin feature/ma-feature`)
5. Ouvre une Pull Request

---

## Licence

[MIT](LICENSE) © JohnsK57 2026