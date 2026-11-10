# Laboratorio VR · Base de datos (PostgreSQL)

Base de datos del panel docente del simulador de electrónica en realidad virtual.

Es uno de 3 repositorios que van uno al lado del otro:

```
carpeta/
├── Aplicacion_tesis/     frontend (React) + Nginx
├── proyecto-backend/     Django + Docker Compose (deploy/)
└── proyecto-db/          este repositorio
```

No se enciende sola: la arranca el `docker-compose.yml` de `proyecto-backend/deploy/`,
que le entrega el nombre de la base, el usuario y la contraseña (`POSTGRES_DB`,
`POSTGRES_USER`, `POSTGRES_PASSWORD` de `deploy/.env`).

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `Dockerfile` | PostgreSQL 16 oficial + un chequeo que avisa cuándo la base ya acepta conexiones |
| `scripts/respaldar.sh` | guarda un respaldo comprimido en `backups/` |
| `scripts/restaurar.sh` | recupera un respaldo (pide confirmación y antes respalda lo actual) |
| `TABLAS.md` | qué tablas hay y qué guarda cada columna (para la tesis) |

## ¿Y los scripts para crear las tablas?

No hacen falta. Las tablas las crea **Django** con sus migraciones cada vez que arranca
el backend (`python manage.py migrate`). Si además las creara un script SQL aquí, habría
dos lugares definiendo la misma estructura y tarde o temprano no coincidirían.
PostgreSQL solo crea la base vacía y el usuario.

## Dónde quedan los datos

En el volumen de Docker `laboratorio_datos_db`. Los datos **se conservan** al reiniciar,
al apagar con `docker compose down` y al actualizar con `actualizar.sh`.
Solo se borran con `docker compose down -v` o `docker volume rm laboratorio_datos_db`.

La base de datos **no tiene puerto abierto** hacia afuera: solo el backend puede hablarle.

## Respaldos

Con el sistema encendido, desde la carpeta que contiene los 3 repositorios:

```sh
sh proyecto-db/scripts/respaldar.sh
# -> proyecto-db/backups/laboratorio_2026-11-10_190000.sql.gz

sh proyecto-db/scripts/restaurar.sh proyecto-db/backups/laboratorio_2026-11-10_190000.sql.gz
```

- `actualizar.sh` (en `proyecto-backend/deploy/`) hace un respaldo automático antes de actualizar.
- Para un respaldo automático diario, ver `DEPLOY.md` de `proyecto-backend` (sección 10).
- Los respaldos tienen datos de alumnos: **no se suben a git** (`backups/` está en
  `.gitignore`). Conviene copiarlos fuera del servidor de vez en cuando.
- En Windows, ejecútalos desde **Git Bash**.

## Mirar los datos a mano

```sh
docker compose -f proyecto-backend/deploy/docker-compose.yml exec db psql -U laboratorio laboratorio
```

Dentro de `psql`: `\dt` lista las tablas, `\d sessions` muestra una tabla y `\q` sale.
