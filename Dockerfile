# ------------------------------------------------------------------
# Imagen de la base de datos: PostgreSQL 16 oficial.
#
# No se usa sola: la arranca docker compose (proyecto-backend/deploy/), que le
# entrega el nombre de la base, el usuario y la contraseña (POSTGRES_DB,
# POSTGRES_USER, POSTGRES_PASSWORD) y el volumen donde se guardan los datos.
#
# Las tablas NO se crean aquí: las crea Django con sus migraciones al arrancar
# el backend (ver TABLAS.md).
# ------------------------------------------------------------------
FROM postgres:16

# Docker revisa cada 5 segundos si PostgreSQL ya acepta conexiones. El backend
# espera a que esto dé "healthy" antes de arrancar (depends_on en docker-compose).
# Se pregunta por red (-h 127.0.0.1) y no por el socket interno, porque durante
# la primera inicialización PostgreSQL arranca un rato solo con el socket.
HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=10 \
    CMD pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1
