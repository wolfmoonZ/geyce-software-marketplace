---
name: geyce-sql
description: |
  Consulta las BBDD de Geyce vía el conector Geyce: contabilidad (ContaASP / jconta)
  y nóminas (jNomina / laboral). Traduce peticiones sobre contabilidad española y gestión
  laboral en consultas SQL eficientes contra SQL Server.
  USAR SIEMPRE que el usuario pida datos contables, fiscales o laborales: saldos, asientos,
  extractos, facturas, libros de IVA, balances, P&G, terceros, retenciones IRPF, modelos
  fiscales (111, 115, 123, 347, 349), cobros/pagos, inmovilizado, amortizaciones, nóminas,
  resumen de costes laborales, devengos, deducciones, costes empresa, cotizaciones SS,
  bonificaciones, FOGASA, formación profesional, conceptos retributivos.
  También cuando se mencionen tablas o campos de ContaASP/jNomina, o se pida "consultar
  la contabilidad", "ver asientos", "buscar facturas", "ver nóminas", "calcular costes
  de personal", "resumen de costes" o variantes.
---

# Skill: geyce-sql — Consultas a las Bases de Datos de Geyce

Esta skill te permite responder a peticiones del usuario sobre datos contables, fiscales y
laborales, construyendo consultas SQL contra las bases de datos de Geyce a través del
conector `geyce`. Cubre dos aplicativos:

- **jconta (ContaASP)** — contabilidad: asientos, IVA, balances, modelos fiscales, terceros, inmovilizado.
- **laboral (jNomina)** — nóminas: cálculos, devengos, deducciones, costes empresa, cotizaciones SS.

## Antes de consultar: identifica aplicativo, empresa y periodo

Toda consulta necesita estos datos:

- **Aplicativo**: jconta o laboral. Determina la base de datos (ver siguiente sección).
- **Empresa** (`empcodigo`): identifica la entidad. Existe tanto en jconta como en laboral.
- **Ejercicio**: año. En **jconta** determina la BD (`ctasp{year}`); en **laboral** es solo un campo (`hispejercicio`).
- **Periodo (solo laboral)**: meses 1-12 de inicio y fin.

Si el usuario no los proporciona, pregunta antes de consultar. Si ya los ha mencionado en la conversación, reutilízalos sin volver a preguntar.

Para listar empresas en jconta:
```sql
-- En la base de datos ctasp{year}
SELECT empcodigo, empestructura FROM EMPRESA
```

Para listar empresas en laboral:
```sql
-- En la base de datos laboral
SELECT empcodigo, empnombre, empnif FROM [laboral].[dbo].EMPRESA
```

## Selección de aplicativo

Antes de construir una consulta, identifica a qué aplicativo pertenecen los datos. Esto determina la BD a usar y la referencia a leer.

| Pista en la pregunta del usuario | Aplicativo | Referencia |
|---|---|---|
| Saldos, asientos, IVA, balances, P&G, modelos fiscales (111, 115, 123, 347, 349), facturas, terceros contables, inmovilizado, amortizaciones, cobros/pagos | **jconta** | `references/jconta.md` |
| Nóminas, trabajadores, devengos, deducciones, costes empresa, cotizaciones SS, IRPF de nómina, finiquitos, atrasos, conceptos salariales/retributivos, centros y departamentos laborales, contratos, FOGASA, formación profesional, resumen de costes laborales | **laboral** | `references/laboral.md` |

Si la pregunta cruza ambos (p.ej. "qué se ha contabilizado de la nómina de marzo"), normalmente se resuelve consultando jconta — las cuentas 640/642/4760 reflejan lo de nómina. Solo entras en laboral cuando piden el detalle por trabajador, concepto retributivo o cotización.

## Arquitectura de bases de datos

Las BDs de Geyce siguen distintos patrones según el aplicativo:

| Aplicativo | Base de datos | Particionada por año |
|---|---|---|
| jconta (ContaASP) | `ctasp{year}` (ej: `ctasp2024`, `ctasp2025`) | **Sí**, una BD por ejercicio fiscal |
| laboral (jNomina) | `laboral` | **No**, BD única; el ejercicio es un campo |
| Maestra compartida | `easp` | No (terceros NIFES, provincias, dominios, formas de pago, inmovilizado) |

Cuando uses `mcp__geyce__execute_select`, pasa el parámetro `database` correspondiente:
- Tablas contables del ejercicio: `database: "ctasp{year}"`
- Tablas de nómina: `database: "laboral"`
- Tablas maestras compartidas: `database: "easp"`

Para consultas cross-database (p.ej. nómina + datos personales en NIFES), haz consultas separadas y combina resultados en tu respuesta.

## Referencia de tablas

Consulta el fichero del aplicativo correspondiente para la documentación completa de tablas, campos, relaciones y patrones de consulta:

- [`references/jconta.md`](references/jconta.md) — contabilidad ContaASP
- [`references/laboral.md`](references/laboral.md) — nóminas jNomina

A continuación un resumen de las tablas principales y reglas más importantes de cada aplicativo, para tener a mano lo más usado sin abrir las referencias.

### Tablas principales — jconta (ctasp{year})

| Tabla | Función |
|-------|---------|
| **ASIENTOS** | Apuntes contables. Tabla central. Cada fila = una línea de asiento |
| **PCUENTAS** | Plan de cuentas: cuentas y subcuentas por empresa/ejercicio |
| **PCACUMULADOS** | Saldos mensuales pre-calculados (puede estar vacía) |
| **EMPRESA** | Datos de configuración de la empresa |
| **EJERCICIO** | Configuración del ejercicio (números de asientos especiales) |
| **IVACABECERA** | Cabeceras de facturas de IVA |
| **IVALINEAS** | Líneas de detalle de factura IVA (desglose por tipo impositivo) |
| **COBROPAGO** | Cobros y pagos (vencimientos) |
| **DIARIOS** | Catálogo de diarios |
| **DEPARTAMENTOS** | Dimensión analítica: departamentos |
| **PROYECTOS** | Dimensión analítica: proyectos |
| **ACTIVIDADES** | Dimensión analítica: actividades económicas |
| **ESTRUCTURA** | Definición de la estructura del balance |
| **PCEPIGRAFE** | Epígrafes del balance con fórmulas |
| **PREFIJOS** | Prefijos de cuenta por modelo fiscal (110, 115, 123) |
| **PCLOCALES** | Locales asociados a cuentas (relevante para modelo 115 - alquileres) |
| **EQLIBROIYG** | Equivalencias cuenta-código AEAT para libros de IVA e Ingresos/Gastos |
| **DEFCOLIYG** | Definición columnas AEAT del libro de Ingresos y Gastos |

### Tablas maestras (easp)

| Tabla | Función |
|-------|---------|
| **NIFES** | Datos fiscales y dirección de terceros (por NIF/CIF). Compartida con laboral para datos personales del trabajador |
| **PROVINCIA** | Catálogo de provincias |
| **CDP** | Dominios de empresas |
| **BDSCARGADAS** | Ejercicios cargados por dominio |
| **TRANSACCIONES** | Catálogo de tipos de transacción IVA |
| **FORMACOBPAG** | Formas de cobro/pago |
| **PCINMOV** | Bienes de inversión (inmovilizado). Fichas de activo y bienes de inversión |
| **PCMORANUAL** | Amortizaciones anuales por bien. Tipo `'C'` = contable, `'F'` = fiscal. Soporta listados de amortizaciones y correcciones fiscales |

### Tablas principales — laboral

| Tabla | Función |
|-------|---------|
| **HISPERSO** | Cabecera de cada cálculo de nómina (1 fila = trabajador/periodo/proceso). Tabla central. PK lógica `hispcodigo` |
| **HISRETRI** | Devengos (líneas retributivas). FK `hisrcalculo → hispcodigo` |
| **HISDEDUC** | Deducciones (SS trabajador, IRPF, embargos…). FK `hisdcalculo → hispcodigo` |
| **HISCOSTES** | Costes empresa por concepto (cuota patronal, FOGASA, FP, desemp, bonif…). FK `hisccalculo → hispcodigo` |
| **HISINCIDEN** | Incidencias del cálculo (`HISITIPHISI='ER'` = exoneración / ERTE) |
| **TRABAJADOR** | Maestro de trabajadores (cruce con NIFES de easp por `tranif`) |
| **TRABAJOTR** | Atributos extra del trabajador por relación |
| **TRACONTRATO** | Datos contractuales (fechas inicio/fin, jubilado activo) |
| **EMPRESA** (laboral) | Empresas en el ámbito de nómina (tabla **distinta** de la EMPRESA de contaasp) |
| **CENTROS / CENDPTO** | Estructura organizativa: centros y departamentos |
| **TRACOSTANALITIC** | % de distribución analítica del coste por trabajador |
| **SSCUOTAS** | Porcentajes de cotización SS por régimen y periodo |
| **VALORESDIR** | Mapeo de conceptos contables → tabla destino + rango de conceptos de nómina |

Detalle completo de campos, relaciones y patrones en `references/laboral.md`.

## Reglas críticas para construir consultas — jconta

Estas son las reglas que más importan para evitar errores. Interiorizarlas evita el 90% de los
problemas con las consultas.

### 1. Cálculo de saldos

El saldo se calcula siempre desde ASIENTOS con esta fórmula:
```sql
SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE -asiimporte END) AS saldo
```
El campo `asiimporte` es siempre positivo; el signo lo determina `asidebehaber` ('D' = debe, 'H' = haber).

Para un balance completo (debe, haber y saldo):
```sql
SELECT
    asicuenta,
    SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE 0 END) AS total_debe,
    SUM(CASE WHEN asidebehaber = 'H' THEN asiimporte ELSE 0 END) AS total_haber,
    SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE -asiimporte END) AS saldo
FROM ASIENTOS
WHERE asiempresa = '{empresa}' AND asiejercicio = {year}
GROUP BY asicuenta
```

### 2. Períodos especiales (apertura y cierre)

Los asientos del diario 31 son especiales y normalmente deben excluirse de consultas de meses normales:

- **Apertura** (mes lógico 0): `asidiario = 31 AND asiasiento = 1 AND MONTH(asifecha) = 1 AND DAY(asifecha) = 1`
- **Cierre ejercicio** (mes 13): penúltimo asiento del diario 31
- **Cierre contabilidad** (mes 14): último asiento del diario 31

Para consultas de meses normales (1-12), excluye el diario 31:
```sql
WHERE MONTH(asifecha) BETWEEN {mes_desde} AND {mes_hasta}
  AND asidiario <> 31
```

Si el usuario pide incluir apertura o cierre, inclúyelos explícitamente.

### 3. Inversión de civemirep (facturas emitidas/recibidas)

Este campo está **invertido** en la base de datos. Es la fuente de error más común:

| El usuario pide | Valor en BD (`civemirep`) |
|-----------------|--------------------------|
| Facturas **emitidas** | `'R'` |
| Facturas **recibidas** | `'S'` |
| Ambas | Sin filtro |

### 4. Nombres de campo por tabla (prefijos)

Cada tabla usa un prefijo propio en sus campos. Esto es crítico para JOINs:

| Tabla | Prefijo | Ejemplos |
|-------|---------|----------|
| ASIENTOS | `asi` | `asiempresa`, `asiejercicio`, `asicuenta`, `asisubcuenta`, `asiimporte`, `asidebehaber` |
| PCUENTAS | `pcu` | `pcuempresa`, `pcuejercicio`, `pcucuenta`, `pcusubcuenta`, `pcudesc`, `pcunif` |
| IVACABECERA | `civ` | `civempresa`, `civejercicio`, `civfecha`, `civemirep`, `civnif`, `civimporte` |
| IVALINEAS | `liv` | `livcodi`, `livbase`, `livporiva`, `livimpiva`, `livtransaccion` |
| COBROPAGO | `cob` | `cobempresa`, `cobejerasto`, `cobnumasto`, `cobimporte`, `cobvto`, `cobestado` |
| PCACUMULADOS | `pca` | `pcaempresa`, `pcaejercicio`, `pcacuenta`, `pcasubcuenta` |

JOIN correcto entre ASIENTOS y PCUENTAS (para obtener descripción de cuenta):
```sql
SELECT a.asicuenta, a.asisubcuenta, p.pcudesc,
    SUM(CASE WHEN a.asidebehaber = 'D' THEN a.asiimporte ELSE -a.asiimporte END) AS saldo
FROM ASIENTOS a
LEFT JOIN PCUENTAS p
    ON p.pcuempresa = a.asiempresa
    AND p.pcuejercicio = a.asiejercicio
    AND p.pcucuenta = a.asicuenta
    AND p.pcusubcuenta = a.asisubcuenta
WHERE a.asiempresa = '{empresa}' AND a.asiejercicio = {year}
GROUP BY a.asicuenta, a.asisubcuenta, p.pcudesc
```

### 5. Subcuenta '0' = cuenta principal

Cuando `pcusubcuenta = '0'` o `asisubcuenta = '0'`, es la cuenta principal sin desglose por tercero.
Las subcuentas con valor distinto de '0' representan desglose por tercero concreto.

### 6. Filtros habituales

Casi toda consulta sobre datos contables necesita estos filtros:
```sql
WHERE asiempresa = '{empresa}' AND asiejercicio = {year}
```

### 7. RTRIM en ciertos campos

Algunos campos tienen espacios a la derecha. Usa `RTRIM()` al comparar:
- `RTRIM(civserie)` en IVACABECERA
- `RTRIM(actactividad)` en ACTIVIDADES

## Reglas críticas para construir consultas — laboral

Detalle completo en `references/laboral.md`. Lo imprescindible:

### 1. La cabecera siempre es HISPERSO; los detalles cuelgan de ella

Toda consulta de nómina arranca filtrando HISPERSO por empresa/periodo/proceso y hace JOIN a HISRETRI/HISDEDUC/HISCOSTES por `{prefijo}calculo = hispcodigo`. No hay forma de consultar las tablas de detalle sin pasar por HISPERSO.

### 2. Filtros base por empresa/ejercicio/periodo/proceso

```sql
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)  -- Recibos, Pagas, Finiquitos, Atrasos
```

### 3. Filtro de colectivo

`hispcolectivo`: **90 = profesionales, 2 = autónomos, otros = trabajadores por cuenta ajena**. Si el usuario no especifica, asume trabajadores por cuenta ajena.

### 4. Procesos típicos

`hispproceso`: 1=Recibos, 2=Pagas, 3=Finiquitos, 4=Atrasos, 5=Anticipos, 6=Atra.pagas, 7-10=variantes nivel 2/3, 11-30=Libres. Para "nóminas mensuales" basta `IN (1, 2)`. Para "resumen de costes completo" se suelen incluir `1..10`.

### 5. Multi-año: condición compuesta (no BETWEEN)

Si el periodo cruza años, usa la condición de la regla 4 de `references/laboral.md`. Un único `BETWEEN` daría resultados incorrectos.

### 6. Exoneración ER y EXCL65 cambian el coste real

Para coste real exacto hay que excluir bonificaciones de filas con `HISITIPHISI='ER'` (LEFT JOIN a subquery DISTINCT de HISINCIDEN) y separar bases/bonif según `HISPEXCL65='S'`. Si el usuario solo quiere "totales aproximados", se puede ignorar; si pide "el resumen oficial", redirigirlo al endpoint `/resumen-costes`.

### 7. ⚠️ HISDEDUC mezcla deducciones reales con conceptos agregados — NO sumes `hisdcuota` a saco

HISDEDUC contiene deducciones reales **y también** conceptos agregados/informativos (totalizadores, bases, cuotas patronales informativas). Si haces `SUM(hd.hisdcuota)` sin filtro, doble-cuentas. Patrones correctos:

- **Total deducciones del trabajador**: filtrar `hd.hisdconcepto = 90451` (DEDUCCIONES = total agregado).
- **Equivalente matemático** (lo que hace jNomina): `total_deducciones = total_devengado − total_liquido`.
- **Sumar por concepto contable concreto**: usar VALORESDIR como Rosetta (define qué tabla y qué rango compone cada totalización).

Códigos de control conocidos: `90400`, `90410`, `90430-90439`, `90441`, `90445`, `90446`, `90451`. Detalle completo en `references/laboral.md` regla 5.bis.

> Misma trampa en HISRETRI (conceptos `TDEVEN`, `LIQUID`) y HISCOSTES (`COSEMP`). Cuando dudes, pasa por VALORESDIR.

### 8. Cross-database para nombre del trabajador

`TRABAJADOR.tranif` se cruza con `[easp].[dbo].NIFES.danifcif` para obtener nombre y apellidos por separado.

## Terminología contable → Cuentas del PGC

Cuando el usuario use términos contables coloquiales, tradúcelos a las cuentas correspondientes
del Plan General Contable (PGC). Esta tabla cubre los casos más habituales:

### Terceros (Balance — Grupo 4)

| El usuario dice | Cuentas a consultar | Notas |
|-----------------|---------------------|-------|
| **Proveedores** | `4000` + `4100` | 4000 = Proveedores, 4100 = Acreedores por prestaciones de servicios. Consultar ambas salvo que el usuario especifique |
| **Clientes** | `4300` + `4400` | 4300 = Clientes, 4400 = Deudores. Consultar ambas salvo que el usuario especifique |
| **Acreedores** | `4100` | Acreedores por prestaciones de servicios |
| **Deudores** | `4400` | Deudores varios |
| **Hacienda (deudor)** | `4700` – `4709` | HP deudora por IVA, retenciones, etc. |
| **Hacienda (acreedor)** | `4750` – `4759` | HP acreedora por IVA, retenciones, IRPF, IS, etc. |
| **IVA soportado** | `4720` | IVA soportado deducible |
| **IVA repercutido** | `4770` | IVA repercutido |
| **Seguridad Social** | `4760` | Organismos de la Seguridad Social acreedores |
| **Personal / Nóminas** | `4650` + `4660` | Remuneraciones pendientes de pago |

### Gastos (Pérdidas y Ganancias — Grupo 6)

| El usuario dice | Cuentas a consultar | Notas |
|-----------------|---------------------|-------|
| **Gastos** (genérico) | Grupo `6` (`asicuenta LIKE '6%'`) | Todas las cuentas del grupo 6 |
| **Compras** | `600` – `609` | Compras de mercaderías, materias primas, etc. |
| **Servicios exteriores** | `620` – `629` | Incluye alquileres (621), reparaciones (622), servicios profesionales (623), transportes (624), primas de seguros (625), servicios bancarios (626), publicidad (627), suministros (628), otros servicios (629) |
| **Gastos de personal** | `640` – `649` | Sueldos (640), indemnizaciones (641), SS a cargo empresa (642) |
| **Gastos financieros** | `660` – `669` | Intereses de deudas (662), diferencias de cambio negativas (668) |
| **Amortizaciones** | `680` – `689` | Amortización del inmovilizado |
| **Alquiler / Arrendamientos** | `6210` | Arrendamientos y cánones |
| **Suministros (luz, agua, gas)** | `6280` | Suministros |
| **Profesionales independientes** | `6230` | Servicios de profesionales independientes |
| **Seguros** | `6250` | Primas de seguros |
| **Transportes** | `6240` | Transportes |
| **Publicidad** | `6270` | Publicidad, propaganda y relaciones públicas |

### Ingresos (Pérdidas y Ganancias — Grupo 7)

| El usuario dice | Cuentas a consultar | Notas |
|-----------------|---------------------|-------|
| **Ingresos** / **Ventas** (genérico) | Grupo `7` (`asicuenta LIKE '7%'`) | Todas las cuentas del grupo 7 |
| **Ventas de mercaderías** | `700` – `709` | Ventas, devoluciones, rappels |
| **Prestaciones de servicios** | `705` | Ingresos por servicios |
| **Ingresos financieros** | `760` – `769` | Intereses a favor, diferencias de cambio positivas |
| **Subvenciones** | `740` – `749` | Subvenciones a la explotación |
| **Otros ingresos** | `750` – `759` | Ingresos por arrendamientos, comisiones, etc. |

### Otros grupos relevantes

| El usuario dice | Cuentas a consultar | Notas |
|-----------------|---------------------|-------|
| **Tesorería / Bancos / Caja** | Grupo `57` | 570 = Caja, 572 = Bancos |
| **Inmovilizado** | Grupo `2` (`asicuenta LIKE '2%'`) | Inmovilizado material (21x), intangible (20x), financiero (25x) |
| **Existencias** | Grupo `3` | Mercaderías (300), materias primas (310), etc. |
| **Capital / Fondos propios** | Grupo `1` | Capital (100), reservas (11x), resultado (129) |
| **Préstamos / Deudas** | Grupo `17` + `52` | 170 = deudas LP con entidades de crédito, 520 = deudas CP |
| **Resultado del ejercicio** | `129` | Pérdidas y ganancias |

### Regla general de interpretación

Cuando el usuario pida algo como "proveedores" o "clientes" sin especificar cuenta:
1. **Consulta siempre las cuentas combinadas** (ej: 4000 + 4100 para proveedores, 4300 + 4400 para clientes)
2. **Presenta los resultados separados** por cuenta para que el usuario vea el desglose
3. **Incluye un total combinado** al final
4. Si el usuario pide "gastos" o "ingresos" genéricos, agrupa por cuenta principal (primeros 4 dígitos) para dar una visión clara

## Patrones de consulta frecuentes — jconta

### Saldo de una cuenta a una fecha
```sql
SELECT
    SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE -asiimporte END) AS saldo
FROM ASIENTOS
WHERE asiempresa = '{empresa}' AND asiejercicio = {year}
  AND asicuenta = '{cuenta}'
  AND asifecha <= '{fecha}'
  AND asidiario <> 31
```

### Extracto de movimientos de una cuenta
```sql
SELECT asifecha, asiasiento, asidesc, asidebehaber, asiimporte, asisubcuenta
FROM ASIENTOS
WHERE asiempresa = '{empresa}' AND asiejercicio = {year}
  AND asicuenta = '{cuenta}'
  AND asifecha BETWEEN '{fecha_desde}' AND '{fecha_hasta}'
  AND asidiario <> 31
ORDER BY asifecha, asiasiento
```

### Listado de facturas emitidas
```sql
SELECT c.civfecha, c.civdocumento, RTRIM(c.civserie) AS serie,
       c.civnif, c.civdesc, c.civimporte, c.civimpiva
FROM IVACABECERA c
WHERE c.civempresa = '{empresa}' AND c.civejercicio = {year}
  AND c.civemirep = 'R'  -- R = emitidas (invertido!)
ORDER BY c.civfecha
```

### Datos de un tercero por NIF
```sql
-- En base de datos easp
SELECT danifcif, RTRIM(datapell1) + ' ' + RTRIM(datapell2) + ' ' + RTRIM(datnombre) AS razon_social,
       RTRIM(datsiglas) + ' ' + RTRIM(datvia) + ' ' + RTRIM(datnum) AS direccion,
       dattel, datemail, datpobla, datcpos
FROM NIFES
WHERE danifcif = '{nif}'
```

### Saldo anterior + movimientos (patrón de balance)
Para informes tipo balance de sumas y saldos:
1. **Saldo anterior**: suma de asientos desde apertura hasta mes anterior al solicitado
2. **Movimientos del periodo**: suma de asientos del periodo solicitado
3. **Saldo final**: saldo anterior + movimientos

### Consulta de cobros/pagos pendientes
```sql
SELECT c.cobvto, c.cobimporte, c.cobcobropago, c.cobestado,
       a.asicuenta, a.asisubcuenta, a.asidesc
FROM COBROPAGO c
JOIN ASIENTOS a ON a.asiempresa = c.cobempresa
  AND a.asiejercicio = c.cobejerasto AND a.asiasiento = c.cobnumasto
WHERE c.cobempresa = '{empresa}' AND c.cobejerasto = {year}
  AND c.cobestado <> 'C'  -- Pendientes (C = cerrado/liquidado)
ORDER BY c.cobvto
```

### Fichas de activo inmovilizado
```sql
-- En base de datos easp
SELECT pcielemento, pcidesc, pcicuenta, pcisubcuenta, pcifecalta, pciadquis,
       pcicoefapli, pciperapli, pcitipoamort, pcifecbaja
FROM PCINMOV
WHERE pciempresa = {empresa}
  AND pcifecbaja IS NULL  -- Excluir bajas por defecto
ORDER BY pcicuenta, pcisubcuenta
```

### Listado de amortizaciones
```sql
-- Combinar PCINMOV (easp) con PCMORANUAL (easp)
-- PCMORANUAL tiene tipo 'C' (contable) y 'F' (fiscal)
SELECT i.pcielemento, i.pcidesc, i.pcicuenta, i.pciadquis,
       m.pcmcoefamort, m.pcmamortanual, m.pcmamortacum, m.pcmamortpdte
FROM [easp].[dbo].[PCINMOV] i
LEFT JOIN [easp].[dbo].[PCMORANUAL] m
    ON m.pcmelemento = i.pcielemento AND m.pcmtipo = 'C' AND m.pcmamorejer = {year}
WHERE i.pciempresa = {empresa}
  AND i.pcifecbaja IS NULL
ORDER BY i.pcicuenta, i.pcisubcuenta, i.pciarticulo
```

Para amortizaciones fiscales, usar `pcmtipo = 'F'`. La diferencia dineraria es `amort_contable - amort_fiscal`.
Consulta `references/jconta.md` para los filtros completos (por cuentas, elementos, fechas, actividad) y los tipos de corrección fiscal.

## Patrones de consulta frecuentes — laboral

Detalle completo y variantes en `references/laboral.md`. Aquí los más usados:

### Listado de trabajadores con nómina en un periodo

```sql
SELECT DISTINCT
    hp.hisptrabajador, t.tranif, t.tranombre, hp.hispcentro
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].TRABAJADOR t
    ON t.tracodiemp = hp.hispcodiemp AND t.tracodigo = hp.hisptrabajador
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
ORDER BY t.tracodigo
```

### Resumen de costes laborales por trabajador (consulta estrella)

Devuelve por trabajador: devengado bruto, deducciones, líquido, coste empresa SS y coste real. Esqueleto del "Resumen de Costes" tipo jNomina.

```sql
WITH retri AS (
    SELECT hp.hisptrabajador, SUM(hr.hisrimporte) AS total_devengado
    FROM [laboral].[dbo].HISPERSO hp
    INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
    WHERE hp.hispcodiemp = :empresa
      AND hp.hispejercicio = :year
      AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
      AND hp.hispproceso IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    GROUP BY hp.hisptrabajador
),
deduc AS (
    -- Filtrar por hisdconcepto = 90451 (DEDUCCIONES total agregado).
    -- Sumar hd.hisdcuota sin filtro doble-cuenta. Ver regla 7.
    SELECT hp.hisptrabajador, SUM(hd.hisdcuota) AS total_deducciones
    FROM [laboral].[dbo].HISPERSO hp
    INNER JOIN [laboral].[dbo].HISDEDUC hd ON hd.hisdcalculo = hp.hispcodigo
    WHERE hp.hispcodiemp = :empresa
      AND hp.hispejercicio = :year
      AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
      AND hp.hispproceso IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
      AND hd.hisdconcepto = 90451
    GROUP BY hp.hisptrabajador
),
costes AS (
    SELECT hp.hisptrabajador,
           SUM(hc.HISCCOSTEPAT) AS coste_ss_empresa,
           SUM(hc.HISCBONIF) AS bonificaciones,
           SUM(hc.HISCFOGASA + hc.HISCFORPRO + hc.HISCDESEMP
               + hc.HISCEPIILT + hc.HISCEPIIMS + hc.HISCHOREXT) AS otros_costes
    FROM [laboral].[dbo].HISPERSO hp
    INNER JOIN [laboral].[dbo].HISCOSTES hc ON hc.hisccalculo = hp.hispcodigo
    WHERE hp.hispcodiemp = :empresa
      AND hp.hispejercicio = :year
      AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
      AND hp.hispproceso IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    GROUP BY hp.hisptrabajador
)
SELECT t.tracodigo, t.tranif, t.tranombre,
       r.total_devengado,
       d.total_deducciones,
       (r.total_devengado - d.total_deducciones) AS total_liquido,
       c.coste_ss_empresa, c.bonificaciones, c.otros_costes,
       (r.total_devengado + c.coste_ss_empresa + c.otros_costes - c.bonificaciones)
           AS coste_real_empresa
FROM [laboral].[dbo].TRABAJADOR t
INNER JOIN retri r ON r.hisptrabajador = t.tracodigo
LEFT JOIN deduc d ON d.hisptrabajador = t.tracodigo
LEFT JOIN costes c ON c.hisptrabajador = t.tracodigo
WHERE t.tracodiemp = :empresa
ORDER BY t.tracodigo
```

> El `coste_real_empresa` aquí es una aproximación. Si el usuario pide el cálculo "oficial" (con ajustes ER, MEI, contingencias excluidas), redirígelo al endpoint `POST /api/v1/resumen-costes` en lugar de reescribirlo a SQL puro.

### Top conceptos retributivos del periodo

```sql
SELECT TOP 20
    hr.hisrconcepto,
    MAX(hr.hisrdescripcion) AS descripcion,
    SUM(ABS(hr.hisrimporte)) AS importe_total
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
GROUP BY hr.hisrconcepto
HAVING SUM(ABS(hr.hisrimporte)) > 0
ORDER BY importe_total DESC
```

### Datos personales del trabajador (cross-database easp)

```sql
-- En base de datos easp
SELECT n.danifcif,
       RTRIM(n.datapell1) + ' ' + RTRIM(n.datapell2) + ', ' + RTRIM(n.datnombre) AS nombre_completo
FROM [easp].[dbo].NIFES n
WHERE n.danifcif = :nif
```

## Herramientas disponibles del conector Geyce

Usa estas herramientas MCP según lo que necesites:

| Herramienta | Cuándo usarla |
|-------------|---------------|
| `execute_select` | Para ejecutar consultas SQL de lectura. Es la herramienta principal |
| `list_databases` | Para ver qué bases de datos (ejercicios) existen |
| `list_tables` | Para listar tablas de una BD específica |
| `describe_table` | Para ver la estructura de una tabla si necesitas verificar campos |
| `get_sample_data` | Para ver datos de ejemplo de una tabla |
| `search_columns` | Para buscar un campo por nombre en todas las tablas |
| `get_relationships` | Para ver las FK de una tabla |

En la mayoría de los casos, `execute_select` es todo lo que necesitas. Las demás son útiles
cuando el usuario pregunta algo que no está cubierto en esta documentación o necesitas explorar.

## Estrategia de consulta

Cuando el usuario pide información:

1. **Identifica el aplicativo**: jconta (contabilidad) o laboral (nóminas). Ver tabla en "Selección de aplicativo".
2. **Identifica qué datos necesita**: ¿saldos?, ¿facturas?, ¿nóminas de un trabajador?, ¿coste empresa?
3. **Verifica que tienes empresa y, si aplica, ejercicio/periodo**: si no, pregunta. En jconta el ejercicio determina la BD; en laboral es solo un campo.
4. **Elige las tablas correctas**: usa los resúmenes de arriba; para casos complejos abre `references/jconta.md` o `references/laboral.md`.
5. **Construye la consulta** aplicando las reglas críticas del aplicativo correspondiente.
6. **Usa la BD correcta**:
   - jconta → `ctasp{year}`
   - laboral → `laboral`
   - maestros compartidos → `easp`
7. **Ejecuta con `execute_select`** pasando el parámetro `database`.
8. **Presenta los resultados** de forma clara al usuario.

Para consultas complejas que involucren múltiples tablas de distintas BDs, haz consultas separadas y combina los resultados al presentarlos. Es habitual cruzar laboral con NIFES de easp para obtener nombre y apellidos del trabajador.
