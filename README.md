# Laboratorio VR · Base de datos (PostgreSQL)

Base de datos del panel docente del simulador de electrónica en realidad virtual.

Es uno de 3 repositorios que van uno al lado del otro:

```
carpeta/
├── Aplicacion_tesis/     frontend (React) + Nginx
├── proyecto-backend/     Django + Docker Compose (deploy/)
└── proyecto-db/          este repositorio
```

Las tablas las crea Django con sus migraciones (`python manage.py migrate`).
Aquí van la imagen de Docker de PostgreSQL, los scripts de respaldo y la
documentación de las tablas (se completan en la fase de Docker).
