# Tablas de la base de datos

La base de datos (PostgreSQL 16) tiene **2 tablas propias** del laboratorio,
`students` y `sessions`, y las tablas que Django necesita para el login y el panel de
administración. Todas las crea Django con sus migraciones (`proyecto-backend/lab/migrations/`).

```
        students                                   sessions
┌──────────────────────────┐          ┌──────────────────────────────────┐
│ id                  (PK) │          │ id                          (PK) │
│ nombre                   │          │ participant_code                 │
│ asignatura               │  mismo   │ experiment_id                    │
│ codigo_participante (UQ) │◄────────►│ started_at                       │
│ creado_en                │  código  │ log  (JSON completo de Unity)    │
└──────────────────────────┘          │ source                           │
                                      │ received_at                      │
                                      └──────────────────────────────────┘
       PK = llave primaria · UQ = valor único · sin llave foránea entre ellas
```

## `students` — alumnos

Los registra el profesor desde el panel web.

| Columna | Tipo | Qué guarda |
|---|---|---|
| `id` | `uuid` (PK) | identificador aleatorio que se genera solo |
| `nombre` | `varchar(200)` | nombre del alumno |
| `asignatura` | `varchar(200)` | asignatura (puede quedar vacía) |
| `codigo_participante` | `varchar(50)`, **único** | código que el alumno usa en el visor (A001, B002…). Se guarda siempre en MAYÚSCULAS |
| `creado_en` | `timestamp with time zone` | cuándo se registró |

## `sessions` — sesiones del simulador

Cada fila es una sesión de práctica en el visor Meta Quest. Llega sola desde Unity
(`source = 'visor'`) o la sube el profesor con "Cargar sesiones" (`source = 'importada'`).

| Columna | Tipo | Qué guarda |
|---|---|---|
| `id` | `varchar(255)` (PK) | `participantCode_experimentId_startedAt`, por ejemplo `A001_T0_2026-11-05T10:31:12` |
| `participant_code` | `varchar(50)`, con índice | código del alumno, copiado del JSON |
| `experiment_id` | `varchar(50)` | experimento realizado (T0, T1…), copiado del JSON |
| `started_at` | `varchar(40)` | hora de inicio **tal cual la escribe Unity**, copiada del JSON |
| `log` | `jsonb` | el registro completo de la sesión (`SessionLog` de Unity), sin modificar |
| `source` | `varchar(10)` | `visor` o `importada` |
| `received_at` | `timestamp with time zone` | cuándo llegó al servidor |

**Restricción `unique_session`:** no puede haber dos filas con el mismo
(`participant_code`, `experiment_id`, `started_at`).

### Decisiones de diseño

**¿Por qué guardar el JSON completo (`log`)?**
El registro de Unity tiene listas anidadas (eventos y tareas) que el panel necesita
completas para calcular tiempo, mediciones, correctas y errores. Guardarlo entero en
una columna `jsonb` conserva la información original sin pérdidas y, si Unity agrega
campos nuevos, no hay que cambiar la base de datos. Las 3 columnas que se usan para
buscar y evitar duplicados se copian aparte.

**¿Por qué `started_at` es texto y no fecha?**
Unity escribe la hora local sin zona horaria (`2026-11-05T10:31:12`). Convertirla a
fecha obligaría a suponer una zona y podría alterar el valor, y ese texto es parte del
identificador de la sesión. Por eso se guarda exactamente como llega.

**¿Por qué no hay llave foránea entre `students` y `sessions`?**
Una sesión puede llegar **antes** de que el profesor registre al alumno (por ejemplo, si
el operador escribe un código nuevo en el visor). Con llave foránea esa sesión sería
rechazada y se perdería. Sin ella, la sesión se guarda igual y aparece en la ficha del
alumno en cuanto el profesor lo crea con ese código. Además, borrar un alumno no borra
sus sesiones.

La unión se hace por el código: `UPPER(sessions.participant_code) = students.codigo_participante`.

**¿Cómo se evita guardar dos veces la misma sesión?**
El visor reintenta el envío si no recibe respuesta (por ejemplo, si se cortó la red),
así que la misma sesión puede llegar varias veces. La restricción `unique_session` lo
impide: el backend responde **409** ("ya existía") y Unity la da por entregada.

## Tablas de Django

| Tabla | Qué guarda |
|---|---|
| `auth_user` | la cuenta del profesor. La contraseña no se guarda: solo un *hash* (PBKDF2) |
| `token_blacklist_outstandingtoken` | los tokens de renovación (refresh) entregados al iniciar sesión |
| `token_blacklist_blacklistedtoken` | los tokens invalidados al cerrar sesión |
| `cache_table` | conteo de intentos de login (límite de 5 por minuto) |
| `django_migrations` | qué migraciones ya se aplicaron |
| `django_session`, `django_admin_log`, `django_content_type`, `auth_permission`, `auth_group`, `auth_group_permissions`, `auth_user_groups`, `auth_user_user_permissions` | uso interno de Django y del panel `/admin/` |

## Consultas de ejemplo

Para abrir la consola de PostgreSQL, ver el README.

```sql
-- Cuántas sesiones tiene cada alumno
SELECT st.nombre, st.codigo_participante, COUNT(se.id) AS sesiones
FROM students st
LEFT JOIN sessions se ON UPPER(se.participant_code) = st.codigo_participante
GROUP BY st.id
ORDER BY st.nombre;

-- Sesiones de códigos que todavía no tienen alumno registrado
SELECT se.participant_code, COUNT(*) AS sesiones
FROM sessions se
WHERE NOT EXISTS (
    SELECT 1 FROM students st WHERE st.codigo_participante = UPPER(se.participant_code)
)
GROUP BY se.participant_code;

-- Leer datos de dentro del JSON (las 10 sesiones más recientes)
SELECT id,
       log->>'experimentTitle'             AS experimento,
       (log->>'durationSeconds')::float    AS segundos,
       (log->>'completed')::boolean        AS completada,
       jsonb_array_length(log->'events')   AS eventos
FROM sessions
ORDER BY received_at DESC
LIMIT 10;
```
