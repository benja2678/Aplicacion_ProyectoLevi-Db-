#!/bin/sh
# ------------------------------------------------------------------
# Crea un respaldo de toda la base de datos (alumnos, sesiones y la cuenta del
# profesor) en la carpeta proyecto-db/backups/.
#
# Uso (con el sistema encendido):
#   sh proyecto-db/scripts/respaldar.sh
#
# Resultado: backups/laboratorio_AAAA-MM-DD_HHMMSS.sql.gz
# Es un archivo SQL comprimido; se puede mirar con:  zcat archivo.sql.gz | less
# Para recuperarlo: scripts/restaurar.sh
# ------------------------------------------------------------------
set -e

db_dir=$(cd "$(dirname "$0")/.." && pwd)
compose_file="$db_dir/../proyecto-backend/deploy/docker-compose.yml"
backup_dir="$db_dir/backups"

[ -f "$compose_file" ] || {
    echo "ERROR: no encuentro $compose_file" >&2
    echo "  proyecto-db y proyecto-backend deben estar en la misma carpeta." >&2
    exit 1
}

mkdir -p "$backup_dir"
file="$backup_dir/laboratorio_$(date +%Y-%m-%d_%H%M%S).sql.gz"
tmp="$file.parcial"

# pg_dump se ejecuta DENTRO del contenedor de la base de datos (allí ya conoce el
# usuario y el nombre de la base). -Z 6 comprime la salida en formato gzip.
# --clean hace que, al restaurar, primero se borren las tablas y luego se recreen.
if docker compose -f "$compose_file" exec -T db \
        sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --no-privileges -Z 6' \
        > "$tmp" && gzip -t "$tmp" 2>/dev/null; then
    mv "$tmp" "$file"
    echo "Respaldo creado: $file ($(du -h "$file" | cut -f1))"
else
    rm -f "$tmp"
    echo "ERROR: no se pudo crear el respaldo. ¿Está encendida la base de datos? (docker compose ps)" >&2
    exit 1
fi
