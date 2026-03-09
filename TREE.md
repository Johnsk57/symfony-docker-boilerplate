## 📁 Structure du Projet
```
.
|-- .env
|-- .github
|   `-- workflows
|       |-- quality.yml
|       `-- update-tree.yml
|-- .gitignore
|-- LICENCE
|-- Makefile
|-- README.md
|-- TREE.md
|-- config
|   |-- apache
|   |   |-- apache-standalone.conf.tmpl
|   |   |-- certs
|   |   |   `-- .gitkeep
|   |   |-- ssl.sh
|   |   |-- upstream-mariadb.conf
|   |   `-- upstream-postgresql.conf
|   |-- composer
|   |   |-- .htaccess
|   |   |-- keys.dev.pub
|   |   `-- keys.tags.pub
|   |-- docker
|   |   |-- Dockerfile.apache
|   |   |-- Dockerfile.php-fpm
|   |   |-- docker-compose.apache.yml
|   |   |-- docker-compose.common.yml
|   |   |-- docker-compose.mariadb.yml
|   |   |-- docker-compose.nginx.yml
|   |   |-- docker-compose.postgresql.yml
|   |   `-- entrypoint.sh
|   |-- nginx
|   |   |-- certs
|   |   |   `-- .gitkeep
|   |   |-- entrypoint.sh
|   |   |-- nginx.conf.tmpl
|   |   |-- ssl.sh
|   |   |-- upstream-mariadb.conf
|   |   `-- upstream-postgresql.conf
|   `-- php
|       `-- config.ini
`-- logs
    |-- http
    |   `-- .gitkeep
    |-- mariadb
    |   `-- .gitkeep
    |-- nginx
    |   `-- .gitkeep
    `-- postgres
        `-- .gitkeep

16 directories, 35 files
```
*Auto-généré via GitHub Actions*
