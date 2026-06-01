# Plugin Geyce

Accede a la información de las aplicaciones de Geyce (jConta, jNomina, jGestion...) desde Claude Cowork. El plugin combina la skill `geyce-sql` con el conector remoto **Geyce**, permitiendo responder preguntas sobre contabilidad española y gestión laboral traduciéndolas a consultas SQL eficientes contra las bases de datos de Geyce.

## Componentes

| Componente | Nombre | Descripción |
|------------|--------|-------------|
| Skill | `geyce-sql` | Conocimiento experto sobre el modelo de datos de ContaASP (jConta), jNomina y jGestion. Cubre saldos, asientos, extractos, facturas, libros de IVA, balances, P&G, terceros, retenciones IRPF, modelos fiscales (111, 115, 123, 347, 349), cobros/pagos, inmovilizado, amortizaciones, nóminas, resumen de costes laborales, devengos, deducciones, costes empresa, cotizaciones SS, bonificaciones, FOGASA, formación profesional, conceptos retributivos y facturación de despachos (facturas/albaranes, clientes, expedientes, colaboradores y comisiones). |
| MCP Server | `geyce` | Conector HTTP remoto contra `https://contaasp-api.azurewebsites.net/mcp-remoto`. Expone herramientas para listar bases de datos y tablas, describir estructuras, obtener relaciones y muestras, y ejecutar consultas SELECT contra las BBDD de Geyce. |

## Requisitos

- Cuenta válida en los servicios web de Geyce con permisos sobre los aplicativos consultados.
- Autenticación contra el conector remoto en el primer uso (el cliente MCP gestionará el flujo OAuth/login del endpoint).

## Instalación

1. Descarga el archivo `geyce.plugin` que se entrega con este paquete.
2. En Claude Cowork, instala el plugin desde el archivo `.plugin` (botón "Instalar plugin" en la tarjeta del archivo).
3. Acepta la conexión al servidor MCP `geyce` cuando Claude lo solicite la primera vez que uses la skill.

## Uso

La skill se activa de forma automática cuando le hagas a Claude preguntas como:

- "Dame el saldo de proveedores a 31/03/2025 de la empresa X."
- "Lista las facturas emitidas en el segundo trimestre."
- "¿Qué se ha contabilizado en la cuenta 6230 este año?"
- "Resumen de costes laborales del primer trimestre por trabajador."
- "Calcula el coste real de empresa por departamento."
- "Muestra el modelo 347 con operaciones superiores a 3.005,06 €."

Cuando falten datos imprescindibles (empresa, ejercicio, periodo) Claude te los pedirá antes de lanzar la consulta.

## Aplicativos cubiertos

- **jConta (ContaASP)** — contabilidad: asientos, IVA, balances, modelos fiscales, terceros, inmovilizado, amortizaciones, cobros/pagos.
- **jNomina (laboral)** — nóminas: cálculos, devengos, deducciones, costes empresa, cotizaciones SS, FOGASA, formación, IRPF de nómina, finiquitos y atrasos.
- **jGestion (jExpe)** — gestión de despachos: facturas, albaranes y facturas calculadas, clientes y colaboradores, expedientes, comisiones, honorarios, suplidos, estado VeriFactu y entidad de cobro.
- **Maestros compartidos (easp)** — datos fiscales y de dirección de terceros (NIFES), inmovilizado, formas de pago y catálogos comunes.

## Detalle técnico

La skill incluye tres referencias detalladas en `skills/geyce-sql/references/` que se cargan bajo demanda:

- `jconta.md` — modelo de datos completo de ContaASP y patrones de consulta contables.
- `laboral.md` — modelo de datos de jNomina y patrones de consulta de nómina.
- `jgestion.md` — modelo de datos de jGestion (jExpe) y patrones de consulta de facturación de despachos.

El conector expone las siguientes herramientas MCP: `execute_select`, `list_databases`, `list_tables`, `describe_table`, `get_sample_data`, `search_columns`, `get_relationships` y `whoami`. En la mayoría de los casos basta con `execute_select`.

## Autor

Geyce Software.
