# Marketplace `geyce-software`

Marketplace oficial de plugins de Cowork de **Geyce Software**. Los usuarios añaden este marketplace una sola vez en Claude Cowork y a partir de ahí pueden instalar y actualizar los plugins desde la propia UI cada vez que publicamos una nueva versión.

## Plugins publicados

| Plugin | Versión | Descripción |
|--------|---------|-------------|
| `geyce` | 0.1.0 | Acceso a la información de las aplicaciones de Geyce: jConta, jNomina, jGestion... |

## Estructura del repositorio

```
geyce-software/
├── .claude-plugin/
│   └── marketplace.json        # Catálogo: lista de plugins y versiones
├── plugins/
│   └── geyce/                  # Plugin geyce (con su propio plugin.json, skill y .mcp.json)
│       ├── .claude-plugin/plugin.json
│       ├── .mcp.json
│       ├── skills/geyce-sql/...
│       └── README.md
├── release.sh                  # Script de release (subir versiones)
├── .gitignore
└── README.md                   # Este fichero
```

`marketplace.json` es el "catálogo": lista cada plugin con su ruta local (`source`), versión actual, autor y descripción. Cowork lee este fichero al añadir el marketplace y cuando comprueba actualizaciones.

## Publicación (primera vez)

1. Crea un repositorio Git **privado** en la organización de Geyce (GitHub interno, Azure DevOps, GitLab self-hosted...).
2. Sube esta carpeta como contenido raíz del repo:
   ```bash
   cd geyce-software
   git init
   git add .
   git commit -m "chore: inicializa marketplace geyce-software"
   git branch -M main
   git remote add origin <URL_DEL_REPO>
   git push -u origin main
   ```
3. Comparte la URL del repo con los usuarios internos que deban tener acceso.

## Cómo añaden el marketplace los usuarios

Los usuarios solo lo hacen una vez. En Claude Cowork:

1. Ajustes → Plugins → Marketplaces → Añadir marketplace.
2. Pegan la URL del repositorio (por ejemplo `https://github.com/geyce-software/geyce-software-marketplace`).
3. Si el repo es privado, Cowork pedirá autorización (token de GitHub, SSO de la organización o credencial del Git interno, según el caso).
4. Una vez añadido, ven el plugin `geyce` y pulsan **Instalar**.

A partir de ese momento Cowork comprueba periódicamente el `marketplace.json` y avisa cuando hay una nueva versión disponible.

## Publicar una nueva versión

El script `release.sh` automatiza el flujo. Desde la raíz del repo:

```bash
./release.sh geyce 0.2.0
```

Lo que hace internamente:

1. Verifica que el árbol de Git esté limpio.
2. Actualiza `version` en `plugins/geyce/.claude-plugin/plugin.json`.
3. Actualiza `version` del plugin correspondiente en `.claude-plugin/marketplace.json`.
4. Hace `git commit` con mensaje `release(geyce): v0.2.0`.
5. Crea el tag `geyce-v0.2.0`.
6. Hace `git push` y `git push --tags`.

Flags útiles:

- `--no-push` — deja los cambios y el tag en local; los empujas tú cuando quieras.
- `--no-tag` — solo commit, sin tag.

Convenio de versionado (semver):

- **PATCH** (`0.1.0 → 0.1.1`) — correcciones puntuales en la skill o el README, sin cambios de comportamiento.
- **MINOR** (`0.1.0 → 0.2.0`) — nueva funcionalidad compatible: añadir reglas a la skill, nuevos patrones de consulta, nuevas referencias.
- **MAJOR** (`0.1.0 → 1.0.0`) — cambios incompatibles: renombrar la skill, cambiar el endpoint del MCP, cambios que rompen flujos existentes.

## Flujo de trabajo recomendado

1. Trabaja los cambios en una rama (`git checkout -b mejora-modelo-347`).
2. Modifica los archivos del plugin bajo `plugins/geyce/`.
3. Abre Pull Request y revisa internamente.
4. Mergea a `main`.
5. Desde `main` actualizado, lanza `./release.sh geyce <nueva_version>`.
6. Avisa al equipo: Cowork les ofrecerá la actualización en su próximo ciclo de comprobación (o pueden forzar "Buscar actualizaciones").

## Añadir más plugins al marketplace

1. Crea una nueva carpeta `plugins/<nuevo-plugin>/` con su propia estructura (`.claude-plugin/plugin.json`, skills, etc.).
2. Añade su entrada al array `plugins` de `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "nuevo-plugin",
     "source": "./plugins/nuevo-plugin",
     "description": "...",
     "version": "0.1.0",
     "author": { "name": "Geyce Software" }
   }
   ```
3. Commit y push. Los usuarios verán el nuevo plugin en su lista de plugins instalables.

## Contacto

Para incidencias o propuestas, abre un issue en este mismo repositorio.
