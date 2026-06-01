# Referencia de Tablas — jGestion

Documentacion del modelo de datos SQL Server utilizado por **jGestion** (aplicativo de gestion de despachos / facturacion). Pensado como referencia para agentes que necesiten entender la estructura de datos, construir consultas o interpretar peticiones de usuario sobre facturacion, albaranes, clientes y expedientes de un despacho.

> Para datos de **contabilidad** (asientos, IVA, balances, modelos fiscales), ver `jconta.md`. Para **nomina / costes laborales**, ver `laboral.md`, ambos en este mismo directorio.

> Este documento cubre las tablas del **listado de facturas** (facturas, albaranes y facturas calculadas) y sus relaciones. Se ampliara con mas areas del aplicativo segun se vayan documentando.

---

## Arquitectura de Bases de Datos

A diferencia de jconta (que particiona por ejercicio en `ctasp{year}`), **jGestion almacena todos sus datos en la base maestra compartida `easp`**, sin particion por ano. El ejercicio no determina la BD: las facturas de todos los anos conviven en la misma tabla `factura` y se filtran por fecha.

| Base de datos | Alcance | Particionada por ano |
|---------------|---------|----------------------|
| `easp` | **Unica**. Tablas de jGestion (`factura`, `clientes`, `rebuts`, `expe`, ...) y maestros compartidos (`NIFES`, `PROVINCIA`, ...) | **No** |

Cuando uses `execute_select`, pasa `database: "easp"` (o referencia cross-database `[easp].[dbo].factura`). El parametro `year` de las herramientas MCP solo sirve para resolver la conexion; las tablas de jGestion no dependen de el.

---

## Glosario de Conceptos

| Concepto | Descripcion |
|----------|-------------|
| **Despacho / Asesor** | Entidad multi-inquilino del aplicativo. Codigo numerico (`frasesor` / `clasesor` / `exasesor` / `rebasesor`). **Toda consulta filtra por asesor** |
| **Factura** | Documento de facturacion del despacho. Fila de la tabla `factura`. Identificada por (asesor, serie, numero) |
| **Albaran** | Documento previo a la factura. Misma tabla `factura` con `frentidad = '2'` |
| **Factura calculada** | Factura provisional/estimada. `frentidad = '9'` |
| **Serie** | Serie de facturacion (`frserie`). Cadena corta; puede ser nula/blanca |
| **Entidad (gEntidad)** | Tipo de documento. Mapea a `frentidad`: `'1'`=Facturas, `'2'`=Albaranes, `'9'`=Facturas calculadas |
| **Cliente** | Tercero al que se factura. Fila de `clientes`, identificado por (asesor, codigo, colectivo) |
| **Colectivo** | `clcolectivo` / `frcolectivo`: clasifica el tercero. `1` = clientes principales, `3` = colaboradores. Otros valores = otros colectivos |
| **Colaborador** | Tercero (colectivo 3) que aporta trabajo y cobra comision. La comision se calcula con su `cldescuento` |
| **Expediente** | Caso/dossier del despacho al que se asocia la factura (`frexpediente` -> `expe.exexpediente`) |
| **Tipo de expediente** | Los 3 primeros caracteres del codigo de expediente |
| **Recibo (rebut)** | Registro de cobro/recibo de una factura (tabla `rebuts`). Una factura puede tener varios |
| **Entidad de cobro** | Entidad bancaria/financiera del recibo (`rebent`). Solo se obtiene al agrupar por entidad |
| **Responsable / Comercial / Representante** | Roles asociados a una factura, cliente o expediente. Permiten filtrar y agrupar |
| **VeriFactu (estado VF)** | Estado de envio del documento al sistema VeriFactu de la AEAT (`frestadovf`) |
| **Honorarios / Suplidos** | Desglose del importe: honorarios profesionales vs. gastos suplidos (anticipados por cuenta del cliente) |
| **Saldo pendiente** | Importe no cobrado de la factura (`frsaldopdte`). `0` = cobrada |
| **Rotura / Agrupacion** | Subtotal que se emite cada vez que cambia el valor de la columna por la que se agrupa |

---

## Mapa de Relaciones

```
easp (base maestra, sin particion por ano)
============================================

FACTURA (nucleo de facturacion)
 frcodigo (PK)
 frasesor   ────────── despacho (multi-tenant) ──────────┐
 frcliente  ─┐                                            │
 frcolectivo │                                            │
 frserie     │                                            │
 frfactura   │                                            │
 frcif ──────┼──────> easp.NIFES.danifcif (tercero)       │
 frexpediente├──┐                                         │
             │  │                                         │
CLIENTES <───┘  │                                         │
 clasesor  <────┼──── frasesor = clasesor                 │
 clcodigo  <────┘     frcliente = clcodigo                │
 clcolectivo  <────── frcolectivo = clcolectivo           │
 clcomercial / clrepresentante / clresponsable            │
 clcolaborador / clformato / clemail / cldescuento        │
                                                          │
EXPE (expedientes)  <──┐                                  │
 exasesor   <──────────┼──── frasesor = exasesor          │
 exexpediente <────────┘     frexpediente = exexpediente  │
 exresponsable / excomercial / exrepresentante            │
 exforfra / excolaborador                                 │
                                                          │
REBUTS (recibos/cobros) <── solo al agrupar por entidad ──┘
 rebasesor  <──── frasesor      = rebasesor
 rebserie   <──── frserie       = rebserie
 rebfactura <──── frfactura     = rebfactura
 rebcliente <──── frcliente     = rebcliente
 rebfechaidisco <─ frfechafactura = rebfechaidisco
 rebent  (entidad de cobro)
```

**JOIN base del listado** (siempre):
```sql
factura
LEFT JOIN clientes
       ON factura.frasesor    = clientes.clasesor
      AND factura.frcliente   = clientes.clcodigo
      AND factura.frcolectivo = clientes.clcolectivo
```

**JOIN adicional con `rebuts`** (solo si se agrupa por entidad; obliga a `SELECT DISTINCT`):
```sql
LEFT JOIN rebuts
       ON factura.frasesor       = rebuts.rebasesor
      AND factura.frserie        = rebuts.rebserie
      AND factura.frfactura      = rebuts.rebfactura
      AND factura.frcliente      = rebuts.rebcliente
      AND factura.frfechafactura = rebuts.rebfechaidisco
```

---

## Tablas por Dominio Funcional

### 1. FACTURA (easp) — Facturas, albaranes y facturas calculadas

Tabla central del aplicativo (134 columnas en total). Cada fila es un documento de facturacion. Aqui se documentan las columnas que usa el listado de facturas.

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `frcodigo` | int | NO | ID interno del documento (PK) |
| `frasesor` | int | NO | Codigo de despacho/asesor (multi-tenant). **Filtro obligatorio** |
| `frentidad` | varchar(1) | SI | Tipo de documento: `'1'`=Factura, `'2'`=Albaran, `'9'`=Factura calculada |
| `frcolectivo` | int | SI | Colectivo del cliente (`1`=principal, `3`=colaborador). FK con `clientes.clcolectivo` |
| `frserie` | varchar(10) | SI | Serie de factura. Puede venir con espacios (RTRIM); blanca/nula = sin serie |
| `frfactura` | int | SI | Numero de factura (numerico, aunque se muestre como texto) |
| `frfechafactura` | datetime | SI | Fecha de factura. Filtro principal por rango de fechas |
| `frfecoperacion` | datetime | SI | Fecha de operacion (alternativa a la de factura) |
| `frcliente` | varchar(15) | SI | Codigo de cliente. FK con `clientes.clcodigo` |
| `frnombre` | varchar(120) | SI | Nombre / razon social del cliente (denormalizado en la factura) |
| `frcif` | varchar(15) | SI | NIF/CIF del cliente. Enlaza con `easp.NIFES.danifcif` |
| `frexpediente` | varchar(15) | SI | Codigo de expediente. FK con `expe.exexpediente` |
| `frhonorarios` | float | SI | Importe de honorarios profesionales |
| `frsuplidos` | float | SI | Importe de suplidos (gastos anticipados por cuenta del cliente) |
| `frsuplidosiva` | float | SI | Suplidos con IVA |
| `frbaseimponible` | float | SI | Base imponible total |
| `friva` | float | SI | Cuota de IVA total |
| `frirpf` | float | SI | Retencion de IRPF |
| `frliquido` | float | SI | Total liquido de la factura (importe a cobrar) |
| `frimportefra` | float | SI | Importe de la factura (campo alternativo a frliquido para orden) |
| `frdescuento` | float | SI | Descuento aplicado |
| `frsaldopdte` | float | SI | Saldo pendiente de cobro. `0` = cobrada |
| `frfechacobro` | datetime | SI | Fecha de cobro |
| `frvencimiento` | datetime | SI | Fecha de vencimiento |
| `frcolaborador` | varchar(15) | SI | Codigo de colaborador (colectivo 3). Base del calculo de comision |
| `frresponsable` | varchar(25) | SI | Responsable asignado a la factura |
| `frestado` | varchar(1) | SI | Estado de la factura |
| `frestadovf` | char(1) | SI | Estado VeriFactu (ver tabla de estados mas abajo) |
| `frseimprime` | varchar(1) | SI | `'S'` = pendiente de imprimir |
| `frenviosemail` | int | SI | Numero de envios por email (`>0` = enviada) |
| `frnumerofraalb` | int | SI | Numero de factura del albaran convertido (`>0` = albaran convertido a factura) |

**Clave logica de una factura:** (`frasesor`, `frserie`, `frfactura`) — y a efectos de cruce con recibos tambien `frcliente` + `frfechafactura`.

**Estados VeriFactu** (`frestadovf`):

| Valor | Descripcion |
|-------|-------------|
| `'C'` | Aceptada |
| `'A'` | Aceptada con errores |
| `'E'` | Error |
| `'X'` | Anulada |
| `''` / NULL | No enviada |

### 2. CLIENTES (easp) — Terceros del despacho

Maestro de clientes/colaboradores del despacho (173 columnas). Clave logica (`clasesor`, `clcodigo`, `clcolectivo`).

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `clasesor` | int | NO | Codigo de despacho/asesor. FK con `factura.frasesor` |
| `clcodigo` | varchar(15) | NO | Codigo de cliente. FK con `factura.frcliente` |
| `clcolectivo` | int | NO | Colectivo: `1`=cliente principal, `3`=colaborador. FK con `factura.frcolectivo` |
| `clnombre` | varchar(30) | SI | Nombre del cliente |
| `clcif` | varchar(15) | SI | NIF/CIF del cliente |
| `clcomercial` | varchar(3) | SI | Codigo de comercial asignado |
| `clrepresentante` | varchar(3) | SI | Codigo de representante asignado |
| `clresponsable` | varchar(25) | SI | Responsable asignado |
| `clcolaborador` | varchar(15) | SI | Colaborador asignado |
| `clformato` | varchar(2) | SI | Formato de factura del cliente |
| `clemail` | varchar(80) | SI | Email del cliente (filtro con/sin email) |
| `cldescuento` | float | SI | Porcentaje de descuento. Para **colaboradores (colectivo 3)** = % de comision |

**Nota:** el JOIN del listado usa el cliente principal (mismo colectivo que la factura, normalmente 1) para traer `clcomercial` y `clrepresentante`. Los filtros avanzados por responsable/comercial/representante/colaborador/formato se hacen con subqueries a `clientes` forzando `clcolectivo = 1`.

### 3. EXPE (easp) — Expedientes

Casos/dossieres del despacho (84 columnas). Se usa solo via subquery para filtros avanzados por expediente. Clave logica (`exasesor`, `exexpediente`).

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `exasesor` | int | NO | Codigo de despacho/asesor. FK con `factura.frasesor` |
| `exexpediente` | varchar(15) | SI | Codigo de expediente. FK con `factura.frexpediente` |
| `exresponsable` | varchar(25) | SI | Responsable del expediente |
| `excomercial` | varchar(3) | SI | Comercial del expediente |
| `exrepresentante` | varchar(3) | SI | Representante del expediente |
| `exforfra` | varchar(2) | SI | Formato de factura del expediente |
| `excolaborador` | varchar(15) | SI | Colaborador del expediente |

### 4. REBUTS (easp) — Recibos / cobros

Recibos de cobro de las facturas (86 columnas). Se incluye en el listado **solo cuando se agrupa por entidad de cobro**. Como una factura puede tener varios recibos, el JOIN obliga a `SELECT DISTINCT`.

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `rebasesor` | int | SI | Codigo de despacho/asesor. FK con `factura.frasesor` |
| `rebserie` | varchar(10) | SI | Serie de la factura del recibo. FK con `factura.frserie` |
| `rebfactura` | int | SI | Numero de factura del recibo. FK con `factura.frfactura` |
| `rebcliente` | varchar(15) | SI | Cliente del recibo. FK con `factura.frcliente` |
| `rebfechaidisco` | datetime | SI | Fecha de la factura. FK con `factura.frfechafactura` |
| `rebent` | varchar(4) | SI | Entidad de cobro (codigo). Columna de agrupacion por entidad |

---

## Patrones de Consulta Comunes

### Filtro base obligatorio (asesor + tipo documento)

Toda consulta de facturas arranca por estos dos filtros:

```sql
WHERE factura.frasesor = :asesor
  AND factura.frentidad = :frentidad   -- '1' Facturas, '2' Albaranes, '9' Calculadas
```

> Valores de `frentidad`: `'1'` = Facturas, `'2'` = Albaranes, `'9'` = Facturas calculadas. Si el usuario no especifica, asume facturas (`'1'`).

### Listado de facturas de un periodo

```sql
SELECT factura.frserie, factura.frfactura, factura.frfechafactura,
       factura.frcliente, factura.frnombre, factura.frbaseimponible,
       factura.friva, factura.frliquido, factura.frsaldopdte
FROM factura
LEFT JOIN clientes
       ON factura.frasesor    = clientes.clasesor
      AND factura.frcliente   = clientes.clcodigo
      AND factura.frcolectivo = clientes.clcolectivo
WHERE factura.frasesor = :asesor
  AND factura.frentidad = '1'
  AND factura.frfechafactura >= :fecha_desde
  AND factura.frfechafactura <= :fecha_hasta
ORDER BY factura.frserie, factura.frfactura
```

### Facturas cobradas / no cobradas

El estado de cobro se deriva de `frsaldopdte`:

| El usuario pide | Condicion |
|-----------------|-----------|
| **Cobradas** | `frsaldopdte = 0.0` |
| **No cobradas / pendientes** | `frsaldopdte <> 0.0` |
| Ambas | Sin filtro |

### Filtro por serie blanca

Una serie vacia significa "sin serie" y se filtra como blanca o nula:

```sql
(factura.frserie = ' ' OR factura.frserie IS NULL)
```

### Filtro por tipo de expediente (prefijos)

El tipo de expediente son los 3 primeros caracteres del codigo. Se filtra con `LIKE 'XXX%'`. Pueden combinarse hasta 3 prefijos con `OR`:

```sql
(factura.frexpediente LIKE :tipo1   -- 'ABC%'
 OR factura.frexpediente LIKE :tipo2
 OR factura.frexpediente LIKE :tipo3)
```

### Filtros avanzados via subquery (cliente / expediente)

Los filtros por responsable, comercial, representante, colaborador o formato se resuelven con subqueries (no se hace JOIN para estos):

```sql
-- A nivel cliente (siempre colectivo 1)
factura.frcliente IN (
    SELECT clcodigo FROM clientes
    WHERE clasesor = :asesor AND clcolectivo = 1
      AND clcomercial = :comercial)

-- A nivel expediente
factura.frexpediente IS NOT NULL AND factura.frexpediente IN (
    SELECT exexpediente FROM expe
    WHERE exasesor = :asesor AND exresponsable = :responsable)
```

### Filtro por email del cliente

```sql
-- Con email
factura.frcliente IN (
    SELECT clcodigo FROM clientes
    WHERE clasesor = :asesor AND clcolectivo = 1
      AND clemail IS NOT NULL AND clemail <> '')

-- Sin email -> clemail IS NULL OR clemail = ''
```

### Estados VeriFactu (combinables con OR)

```sql
(factura.frestadovf = 'C'                                   -- aceptada
 OR factura.frestadovf = 'A'                                -- aceptada con errores
 OR factura.frestadovf = 'E'                                -- error
 OR factura.frestadovf = 'X'                                -- anulada
 OR (factura.frestadovf = '' OR factura.frestadovf IS NULL))-- no enviada
```

### Envio por email / albaran convertido

| El usuario pide | Condicion |
|-----------------|-----------|
| Enviada por email | `frenviosemail > 0` |
| No enviada por email | `frenviosemail = 0 OR frenviosemail IS NULL` |
| Albaran convertido a factura | `frnumerofraalb > 0` |
| Albaran no convertido | `frnumerofraalb = 0 OR frnumerofraalb IS NULL` |

### Calculo de la comision del colaborador

La comision NO esta almacenada: se calcula a partir del descuento del colaborador (colectivo 3):

```sql
-- 1) Obtener el % de comision del colaborador
SELECT cldescuento FROM clientes
WHERE clasesor = :asesor AND clcolectivo = 3 AND clcodigo = :colaborador

-- 2) comision = honorarios * cldescuento / 100   (redondeado a 2 decimales)
```

Solo aplica si la factura tiene `frcolaborador` y `frhonorarios <> 0`. Si no hay colaborador o descuento, la comision es `0`.

### Agrupaciones (roturas) y orden

Para subtotales por grupo, agrupa por la columna correspondiente y emite un total en cada cambio de valor (o usa `GROUP BY` directamente). Columnas habituales de agrupacion:

| Agrupacion | Columna |
|------------|---------|
| Cliente | `factura.frcliente` |
| Nombre cliente | `factura.frnombre` |
| Expediente | `factura.frexpediente` |
| Tipo expediente | `factura.frexpediente` (3 primeros chars) |
| Colaborador | `factura.frcolaborador` |
| Responsable | `factura.frresponsable` |
| Comercial | `clientes.clcomercial` |
| Representante | `clientes.clrepresentante` |
| Entidad | `rebuts.rebent` (requiere JOIN con rebuts + DISTINCT) |

El orden tipico es por `frserie, frfactura`; al agrupar, antepon las columnas de grupo en el `ORDER BY`.

### Razon social / datos del tercero (cross-database con NIFES)

`factura.frnombre` ya trae el nombre denormalizado, pero para datos fiscales completos del tercero se cruza `frcif` con `easp.NIFES`:

```sql
SELECT danifcif,
       RTRIM(datapell1) + ' ' + RTRIM(datapell2) + ' ' + RTRIM(datnombre) AS razon_social,
       datemail, dattel, datpobla
FROM NIFES
WHERE danifcif = :frcif
```

---

## Notas Importantes

### Multi-tenant por asesor
**Toda** consulta de jGestion debe filtrar por `frasesor` (= `clasesor` = `exasesor` = `rebasesor`). Es el discriminador de despacho; omitirlo mezcla datos de despachos distintos.

### Sin particion por ano
No existe `easp{year}`: todas las facturas (de cualquier ejercicio) estan en la misma tabla `factura`. El "ano" se filtra por `frfechafactura`, no por nombre de BD.

### frfactura es numerico
`frfactura` es `int` en BD. Los filtros por rango de numero de factura son numericos, no de texto.

### Importes en float
Los importes (`frhonorarios`, `frbaseimponible`, `friva`, `frliquido`, `cldescuento`, ...) son `float` en BD. Ten en cuenta la imprecision binaria del tipo `float` al comparar igualdades (p.ej. `frsaldopdte = 0.0`).

### RTRIM en serie
`frserie` (y `rebserie`) pueden contener espacios a la derecha; usa `RTRIM()` al comparar o mostrar.

### DISTINCT al agrupar por entidad
El JOIN con `rebuts` puede multiplicar filas (varios recibos por factura). Por eso, al agrupar por entidad de cobro conviene usar `SELECT DISTINCT`.
