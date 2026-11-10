#!/bin/sh
# ------------------------------------------------------------------
# Recupera un respaldo hecho con respaldar.sh.
#
# ¡CUIDADO! Reemplaza TODOS los datos actuales por los del respaldo.
# Por seguridad, antes hace un respaldo nuevo del estado actual.
#
# Uso (con el sistema encendido):
#   sh proyecto-db/scripts/restaurar.sh proyecto-db/backups/laboratorio_2026-11-10_190000.sql.gz
# ------------------------------------------------------------------
set -e

db_dir=$(cd "$(dirname "$0")/.." && pwd)
compose_file="$db_dir/../proyecto-backend/deploy/docker-compose.yml"

if [ $# -ne 1 ]; then
    echo "Uso: sh $0 RUTA/DEL/RESPALDO.sql.gz" >&2
    echo "Respaldos disponibles:" >&2
    ls -1 "$db_dir/backups/" 2>/dev/null | sed 's/^/  /' >&2 || true
    exit 1
fi

file=$1
[ -f "$file" ] || { echo "ERROR: no existe el archivo $file" >&2; exit 1; }
gzip -t "$file" 2>/dev/null || { echo "ERROR: $file no es un respaldo .sql.gz válido" >&2; exit 1; }
[ -f "$compose_file" ] || { echo "ERROR: no encuentro $compose_file" >&2; exit 1; }

echo "ATENCIÓN: se borrarán los datos actuales y se reemplazarán por los de:"
echo "  $file"
printf "Escribe SI (en mayúsculas) para continuar: "
read -r answer
[ "$answer" = "SI" ] || { echo "Cancelado. No se cambió nada."; exit 0; }

echo "== Respaldo de seguridad del estado actual"
sh "$db_dir/scripts/respaldar.sh"

echo "== Deteniendo el backend mientras se restaura"
docker compose -f "$compose_file" stop backend

# Todo en una sola transacción: si algo falla, la base queda como estaba.
echo "== Restaurando"
if gunzip -c "$file" | docker compose -f "$compose_file" exec -T db \
        sh -c 'psql -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 --single-transaction' >/dev/null; then
    result=0
    echo "Restauración terminada."
else
    result=1
    echo "ERROR: la restauración falló; la base de datos quedó como estaba." >&2
fi

echo "== Encendiendo el backend"
docker compose -f "$compose_file" start backend
exit $result
