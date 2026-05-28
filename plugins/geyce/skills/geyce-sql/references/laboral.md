# Referencia de Tablas — laboral (jNomina)

Documentación del modelo de datos SQL Server del aplicativo de nóminas **jNomina** (BD `laboral`). Pensado como referencia para agentes que necesiten construir consultas sobre nóminas, devengos, deducciones, costes laborales, cotizaciones SS o IRPF de nómina.

> Para datos contables, fiscales o de IVA, ver `jconta.md` en este mismo directorio.

---

## Arquitectura de Base de Datos

A diferencia de contaasp, **laboral usa una única base de datos** (no está particionada por año). El ejercicio se filtra como un campo más dentro de las tablas (`hispejercicio`), no por nombre de BD.

| Base de datos | Alcance | Cómo se conecta |
|---|---|---|
| `laboral` | **Única**. Contiene todo el histórico de nóminas | `database: "laboral"` |
| `easp` | Compartida con contaasp. Datos personales de NIF (NIFES) | `database: "easp"` |

Para cruzar datos personales (nombre, apellidos) con un cálculo de nómina, hay que consultar `[easp].[dbo].NIFES` por el `tranif` del trabajador.

---

## Glosario

| Concepto | Descripción |
|---|---|
| **Empresa** | Entidad pagadora identificada por `empcodigo`. La tabla EMPRESA de `laboral` es **distinta** de la de contaasp aunque comparta `empcodigo` |
| **Trabajador** | Persona con relación laboral, identificada por `tracodigo` dentro de la empresa |
| **Cálculo de nómina** | Una ejecución concreta de nómina para un trabajador en un periodo y proceso. Se identifica por `hispcodigo` (PK lógica de HISPERSO). Las tablas de detalle (HISRETRI/HISDEDUC/HISCOSTES) cuelgan de él |
| **Periodo** | Mes 1-12 |
| **Ejercicio** | Año natural |
| **Proceso** | Tipo de cálculo. 1=Recibos, 2=Pagas, 3=Finiquitos, 4=Atrasos, 5=Anticipos, 6=Atra.pagas, 7=Atra.nivel2, 8=Atra.pag.nivel2, 9=Atra.nivel3, 10=Atra.pag.nivel3, 11-30=Libres definidos por la empresa |
| **Colectivo** | `hispcolectivo`: 90=profesionales, 2=autónomos, **otros=trabajadores por cuenta ajena** |
| **Concepto** | Código numérico que identifica un devengo (HISRETRI), deducción (HISDEDUC) o coste empresa (HISCOSTES) |
| **Régimen SS** | Código del régimen de cotización (general, autónomos, agrario, etc.) más sub-código |
| **EXCL65** | `hispexcl65='S'` indica trabajador excluido por mayor de 65 años. Afecta a bases de cotización y bonificaciones |
| **Incidencia ER** | Filas de HISINCIDEN con `HISITIPHISI='ER'` marcan ERTEs / exoneraciones; modifican cómo se suman bonificaciones y EPI |
| **VALORESDIR** | Tabla "Rosetta" que mapea cada código de concepto contable definido por el usuario al destino (HISRETRI/HISDEDUC/HISCOSTES) y rango de conceptos que lo componen |

---

## Mapa de Relaciones

```
laboral
=======

EMPRESA            TRABAJADOR ──── TRABAJOTR ──── TRACONTRATO
 empcodigo          tracodiemp     trxcodiemp     trccodiemp
 empnif             tracodigo      trxcodigo      trccodigo
 empnombre          tranif         trxrelacion    trcrelacion
                    TRACOLECTIVO   TRXOTR01       trciniciocto
                    TRAREGIMENSS                  trcfincto
                    TRAREGCODI                    TRCJUBILATRABA

HISPERSO (cabecera de cada nómina) ──┐
 hispcodigo (PK lógica) ─────────────┤
 hispcodiemp ──> EMPRESA.empcodigo   │
 hisptrabajador ──> TRABAJADOR.      │
 hispcentro ──> CENTROS              │
 hispdpto ──> CENDPTO                │
 hispejercicio, hispperiodo          │
 hispproceso, hispcolectivo          │
 hispexcl65, hisprelacion            │
                                     │
HISRETRI (devengos) ─────────────────┤
 hisrcalculo ───────────────────────>│
 hisrconcepto, hisrimporte           │
 hisrdescripcion                     │
                                     │
HISDEDUC (deducciones) ──────────────┤
 hisdcalculo ───────────────────────>│
 hisdconcepto, hisdbase              │
 hisdcuota, hisddias / hisddiastp    │
 hisdporcentaje                      │
                                     │
HISCOSTES (costes empresa) ──────────┤
 hisccalculo ───────────────────────>│
 hiscconcepto, HISCBASE              │
 HISCCOSTEPAT, HISCBONIF             │
 HISCEPIILT, HISCEPIIMS              │
 HISCDESEMP, HISCFOGASA              │
 HISCFORPRO, HISCHOREXT, HISCCUOTADI │
                                     │
HISINCIDEN ──────────────────────────┘
 HISICALCULO
 HISITIPHISI ('ER' = exoneración / ERTE)


CENTROS                  CENDPTO                  TRACOSTANALITIC
 cencodiemp               cedcodiemp               tcacodiemp
 cencodigo                cedcodigo                tcacodtrab
 cennombre                cedptocodi               tcaejercicio, tcaperiodo
                          cedptonom                tcatipo='CA'
                                                   tcadeparconta
                                                   TCAPORCEN

SSCUOTAS                                VALORESDIR
 SSCUOREGIMEN                            VADCODIGO
 SSCUOCODI                               VADTAULA (HISRETRI/HISDEDUC/HISCOSTES)
 SSCUOEJERCICIO, SSCUOPERIODO            VADTIPO
 SSCUOBCCEMPR, SSCUOBCCTRAB              VADCONINICIAL, VADCONFINAL
 SSCUO65EMP, SSCUO65TRA                  VADDESCRIP
 SSCUOEXCLUEMP, SSCUOEXCLUTRA            VADCODICONVER


easp (compartida con contaasp)
==============================

NIFES
 danifcif (= TRABAJADOR.tranif)
 datnombre, datapell1, datapell2
```

---

## Tablas

### HISPERSO — Cabecera de cálculos de nómina

Cada fila representa **una nómina concreta**: un trabajador en un periodo con un proceso. Es la tabla central de jNomina, equivalente a ASIENTOS en contabilidad.

| Campo | Descripción |
|---|---|
| `hispcodigo` | PK lógica del cálculo. Las tablas de detalle apuntan aquí vía `{prefijo}calculo` |
| `hispcodiemp` | Código de empresa |
| `hisptrabajador` | Código de trabajador (= `TRABAJADOR.tracodigo`) |
| `hispejercicio` | Año |
| `hispperiodo` | Mes 1-12 |
| `hispproceso` | Tipo de proceso (1=Recibos, 2=Pagas...) |
| `hispcolectivo` | 90=profesionales, 2=autónomos, otros=trabajadores |
| `hispcentro` | Centro de trabajo (FK CENTROS) |
| `hispdpto` | Departamento (FK CENDPTO) |
| `hisprelacion` | Tipo de relación contractual |
| `hispexcl65` | `'S'` si excluido por mayor de 65 |

### HISRETRI — Devengos

Conceptos retributivos: salario base, complementos, plus convenio, dietas, atrasos, etc.

| Campo | Descripción |
|---|---|
| `hisrcalculo` | FK → `HISPERSO.hispcodigo` |
| `hisrconcepto` | Código numérico del concepto |
| `hisrimporte` | Importe (positivo = devengo, puede ser negativo en regularizaciones) |
| `hisrdescripcion` | Descripción del concepto. Puede no existir en BDs antiguas — usar fallback |

### HISDEDUC — Deducciones

Cuotas que se restan del bruto: SS trabajador, IRPF, embargos, anticipos, cuota sindical, bonificaciones del trabajador.

| Campo | Descripción |
|---|---|
| `hisdcalculo` | FK → `HISPERSO.hispcodigo` |
| `hisdconcepto` | Código del concepto |
| `hisdbase` | Base sobre la que se aplica |
| `hisdcuota` | Importe deducido |
| `hisddias` / `hisddiastp` | Días cotizados. Usar `COALESCE(hisddiastp, hisddias)` — varía según el cálculo |
| `hisdporcentaje` | % aplicado |

### HISCOSTES — Costes empresa por concepto

Lo que cuesta a la empresa cada cotización. Una fila por (cálculo, concepto), múltiples columnas con los distintos componentes.

| Campo | Descripción |
|---|---|
| `hisccalculo` | FK → `HISPERSO.hispcodigo` |
| `hiscconcepto` | Código del concepto |
| `HISCBASE` | Base de cotización |
| `HISCCOSTEPAT` | Cuota patronal CC (contingencias comunes) |
| `HISCBONIF` | Bonificación |
| `HISCEPIILT` | EPI por incapacidad temporal |
| `HISCEPIIMS` | EPI por IMS (invalidez, muerte, supervivencia) |
| `HISCDESEMP` | Cuota desempleo |
| `HISCFOGASA` | FOGASA |
| `HISCFORPRO` | Formación profesional |
| `HISCHOREXT` | Horas extra |
| `HISCCUOTADI` | Cuota diaria |

### HISINCIDEN — Incidencias

Marcadores que modifican cómo interpretar las demás tablas para un cálculo concreto.

| Campo | Descripción |
|---|---|
| `HISICALCULO` | FK → `HISPERSO.hispcodigo` |
| `HISITIPHISI` | Tipo de incidencia. `'ER'` = ERTE / exoneración (excluye bonif y EPI del cálculo de coste real) |

### TRABAJADOR — Maestro de personas

| Campo | Descripción |
|---|---|
| `tracodiemp` | Empresa |
| `tracodigo` | Código del trabajador |
| `tranif` | NIF/CIF (para cruce con NIFES en `easp`) |
| `tranombre` | Nombre y apellidos concatenados |
| `TRACOLECTIVO` | Colectivo (90/2/otros) |
| `TRAREGIMENSS` | Régimen SS |
| `TRAREGCODI` | Sub-código del régimen |
| `TRAEXCL65` | `'S'` si exclusión por edad |
| `TRASECCION` | Tipo de exclusión (funcionarios, etc.) |
| `TRARELACION` | Relación contractual activa |

### TRABAJOTR — Atributos extra del trabajador

Campos adicionales por relación. Útil para casos especiales (policía local, etc.).

| Campo | Descripción |
|---|---|
| `TRXCODIEMP`, `TRXCODIGO`, `TRXRELACION` | PK compuesta |
| `TRXOTR01` | `'S'` si es policía local RD 1449/2019 |

### TRACONTRATO — Datos contractuales

| Campo | Descripción |
|---|---|
| `trccodiemp`, `trccodigo`, `trcrelacion` | PK compuesta |
| `trciniciocto` | Fecha inicio contrato |
| `trcfincto` | Fecha fin contrato |
| `TRCJUBILATRABA` | `'S'` si es jubilado activo |

### EMPRESA (laboral)

Maestro de empresas en el ámbito de nómina. **Es una tabla diferente** de la `EMPRESA` de contaasp aunque comparta el campo `empcodigo`. Vive en `[laboral].[dbo]`.

| Campo | Descripción |
|---|---|
| `empcodigo` | Código empresa |
| `empnif` | NIF/CIF |
| `empnombre` | Razón social |

### CENTROS / CENDPTO — Estructura organizativa

Empresa → centros → departamentos.

| Tabla | Campos |
|---|---|
| `CENTROS` | `cencodiemp`, `cencodigo`, `cennombre` |
| `CENDPTO` | `cedcodiemp`, `cedcodigo`, `cedptocodi`, `cedptonom` |

### TRACOSTANALITIC — Distribución analítica

Reparto del coste de un trabajador entre departamentos contables.

| Campo | Descripción |
|---|---|
| `tcacodiemp` | Empresa |
| `tcacodtrab` | Trabajador |
| `tcaejercicio`, `tcaperiodo` | Periodo de aplicación |
| `tcatipo` | `'CA'` para distribución analítica de coste |
| `tcadeparconta` | Departamento contable destino |
| `TCAPORCEN` | % a aplicar |

### SSCUOTAS — Porcentajes de cotización SS

Los % vigentes para cada régimen y periodo. Para obtener el aplicable a una nómina, busca el último entero `<=` al periodo solicitado.

| Campo | Descripción |
|---|---|
| `SSCUOREGIMEN` | Régimen SS |
| `SSCUOCODI` | Sub-código del régimen |
| `SSCUOEJERCICIO`, `SSCUOPERIODO` | Vigencia |
| `SSCUOBCCEMPR` / `SSCUOBCCTRAB` | % CC empresa / trabajador |
| `SSCUO65EMP` / `SSCUO65TRA` | % para mayores de 65 |
| `SSCUOEXCLUEMP` / `SSCUOEXCLUTRA` | % cuando hay exclusión funcionarios |

### VALORESDIR — Mapeo conceptos contables → datos nómina

Configuración que indica, para cada código de concepto contable definido por el usuario, **qué tabla de detalle** (HISRETRI/HISDEDUC/HISCOSTES), **qué tipo** y **qué rango de códigos** lo componen. Es la pieza que permite traducir una nómina a su asiento contable.

| Campo | Descripción |
|---|---|
| `VADCODIGO` | Código del concepto contable |
| `VADTAULA` | Tabla destino (`HISRETRI`, `HISDEDUC`, `HISCOSTES`) |
| `VADTIPO` | Sub-tipo (depende de la tabla) |
| `VADCONINICIAL`, `VADCONFINAL` | Rango de conceptos a sumar |
| `VADDESCRIP` | Descripción |
| `VADCODICONVER` | Código de conversión |

---

## Reglas críticas

### 1. La cabecera siempre es HISPERSO; los detalles cuelgan de ella

Toda consulta de nómina arranca filtrando HISPERSO por empresa/periodo/proceso y hace JOIN a HISRETRI/HISDEDUC/HISCOSTES por `{prefijo}calculo = hispcodigo`. No hay forma de consultar las tablas de detalle "sueltas" sin pasar por HISPERSO.

```sql
SELECT ...
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
```

### 2. `hispcolectivo` para filtrar colectivos

| Colectivo | Condición |
|---|---|
| Trabajadores por cuenta ajena | `hispcolectivo NOT IN (90, 2)` |
| Autónomos | `hispcolectivo = 2` |
| Profesionales | `hispcolectivo = 90` |

Si el usuario no especifica, asume **trabajadores por cuenta ajena** y comprueba si quiere incluir los otros.

### 3. `hispproceso` para filtrar tipos de cálculo

Los procesos típicos en un resumen de costes son `1, 2, 3, 4, 5, 6, 7, 8, 9, 10` (recibos, pagas, finiquitos, atrasos y variantes nivel 2/3). Los códigos 11-30 son procesos libres definibles por la empresa. Si el usuario habla solo de "nóminas mensuales", filtra `hispproceso IN (1, 2)`.

### 4. Filtro multi-año

Si el periodo cruza años (p.ej. junio 2025 a marzo 2026), un único `BETWEEN` no sirve. Hay que generar la condición compuesta:

```sql
WHERE (hp.hispejercicio > :year_from
       OR (hp.hispejercicio = :year_from AND hp.hispperiodo >= :period_from))
  AND (hp.hispejercicio < :year_to
       OR (hp.hispejercicio = :year_to AND hp.hispperiodo <= :period_to))
```

### 5. Días cotizados: usar `COALESCE(hisddiastp, hisddias)`

Algunos cálculos guardan los días en `hisddiastp` y otros en `hisddias`. Siempre coalesce.

### 5.bis. ⚠️ HISDEDUC mezcla deducciones reales con conceptos agregados — NO sumes `hisdcuota` a saco

Esto es una de las trampas más fáciles de pisar. HISDEDUC contiene tres tipos de filas:

1. **Deducciones reales** (cotizaciones del trabajador, IRPF retenido, embargos, anticipos…) — se restan del bruto.
2. **Conceptos agregados/totalizadores** que ya son la suma de otras filas — `90451` (DEDUCCIONES total) es el caso paradigmático.
3. **Conceptos informativos** sobre bases o cuotas patronales que conviven en HISDEDUC pero **no son deducciones del trabajador** (p.ej. `90446`, `90445`).

Si haces `SUM(hd.hisdcuota)` sin filtrar, doble-cuentas. La forma robusta de obtener "total de deducciones" es **una de estas dos**:

**Opción A — usar el código agregado (más simple, lo que descubrió el equipo en producción):**
```sql
SELECT hp.hisptrabajador, SUM(hd.hisdcuota) AS total_deducciones
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISDEDUC hd ON hd.hisdcalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
  AND hd.hisdconcepto = 90451  -- DEDUCCIONES (total agregado)
GROUP BY hp.hisptrabajador
```

**Opción B — calcularlo por diferencia (lo que hace jNomina internamente):**
```
total_deducciones = total_devengado - total_liquido
```
donde `total_devengado` y `total_liquido` se obtienen de HISRETRI vía conceptos agregados o vía VALORESDIR (claves `TDEVEN` y `LIQUID`). Es matemáticamente equivalente y elude todo el problema de saber qué filas son agregadas. Ver `app/services/resumen_contable_service.py:632`.

**Códigos de control conocidos** que aparecen en HISDEDUC y necesitan tratamiento explícito (no sumar en bruto):

| Código | Concepto |
|---|---|
| `90400` | Descuento que se resta de DCGRAL |
| `90410` | Bonificación trabajador |
| `90430-90434` | Anticipos |
| `90435-90439` | Anticipos en especie |
| `90441` | Cuota sindical |
| `90445` | Parte cotización empresa (componente DCGRAL) |
| `90446` | Deducción cotización (informativo) |
| `90451` | **DEDUCCIONES (total agregado)** |

**Misma trampa en HISRETRI y HISCOSTES**: también hay conceptos agregados (`TDEVEN`, `LIQUID` en HISRETRI; `COSEMP` en HISCOSTES). Para una agregación correcta por concepto contable usa **VALORESDIR** como Rosetta — define qué tabla y qué rango de códigos compone cada totalización.

### 6. Exoneración ER: las filas con `HISITIPHISI='ER'` excluyen bonificaciones del coste real

Para un coste real correcto hay que LEFT JOIN a una subquery DISTINCT de HISINCIDEN y descontar `HISCBONIF`/`HISCEPIILT`/`HISCEPIIMS` de las filas marcadas ER. SQL Server no permite subqueries correlacionadas dentro de funciones de agregación, así que el patrón es:

```sql
LEFT JOIN (
    SELECT DISTINCT HISICALCULO
    FROM [laboral].[dbo].HISINCIDEN
    WHERE HISITIPHISI = 'ER'
) er ON er.HISICALCULO = hc.HISCCALCULO
```

Y al sumar:

```sql
SUM(CASE WHEN er.HISICALCULO IS NULL THEN hc.HISCEPIILT ELSE 0 END) AS epiilt_no_er
```

### 7. EXCL65 cambia bases y bonificaciones

Si `hp.HISPEXCL65 = 'S'`, las bonificaciones siguen una regla distinta. Para totales agregados se calculan dos sumas separadas:

```sql
SUM(CASE WHEN hp.HISPEXCL65 IS NULL OR hp.HISPEXCL65 IN ('', 'N')
         THEN hc.HISCBONIF ELSE 0 END) AS bonif_no_excl65,
SUM(CASE WHEN hp.HISPEXCL65 = 'S'
         THEN hc.HISCBONIF ELSE 0 END) AS bonif_excl65
```

### 8. Datos personales: cross-database con `easp`

`TRABAJADOR.tranif` se cruza con `[easp].[dbo].NIFES.danifcif` para obtener nombre y apellidos por separado:

```sql
SELECT n.danifcif, n.datnombre, n.datapell1, n.datapell2
FROM [easp].[dbo].NIFES n
WHERE n.danifcif IN (:nif1, :nif2, ...)
```

---

## Patrones de consulta frecuentes

### Listado de trabajadores con nómina en un periodo

```sql
SELECT DISTINCT
    hp.hisptrabajador,
    t.tranif,
    t.tranombre,
    hp.hispcentro
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].EMPRESA e ON hp.hispcodiemp = e.empcodigo
INNER JOIN [laboral].[dbo].TRABAJADOR t
    ON t.tracodiemp = hp.hispcodiemp
   AND t.tracodigo = hp.hisptrabajador
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
ORDER BY t.tracodigo
```

### Devengos totales por trabajador y concepto

```sql
SELECT hp.hisptrabajador,
       hr.hisrconcepto,
       SUM(hr.hisrimporte) AS total_devengado
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
GROUP BY hp.hisptrabajador, hr.hisrconcepto
```

### Deducciones totales por trabajador y concepto

```sql
SELECT hp.hisptrabajador,
       hd.hisdconcepto,
       SUM(hd.hisdbase) AS total_base,
       SUM(hd.hisdcuota) AS total_cuota,
       SUM(COALESCE(hd.hisddiastp, hd.hisddias)) AS dias_cotizados
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISDEDUC hd ON hd.hisdcalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
GROUP BY hp.hisptrabajador, hd.hisdconcepto
```

### Costes empresa por trabajador y concepto

```sql
SELECT hp.hisptrabajador,
       hc.hiscconcepto,
       SUM(hc.HISCCOSTEPAT) AS cuota_patronal,
       SUM(hc.HISCBONIF) AS bonificaciones,
       SUM(hc.HISCFOGASA) AS fogasa,
       SUM(hc.HISCFORPRO) AS formacion_pro,
       SUM(hc.HISCDESEMP) AS desempleo,
       SUM(hc.HISCHOREXT) AS horas_extra,
       SUM(hc.HISCEPIILT + hc.HISCEPIIMS) AS contingencias_profesionales
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISCOSTES hc ON hc.hisccalculo = hp.hispcodigo
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
GROUP BY hp.hisptrabajador, hc.hiscconcepto
```

### Resumen de costes laborales por trabajador (consulta estrella)

Devuelve por trabajador: devengado bruto, deducciones, líquido, coste empresa SS y coste real. Es el esqueleto del "Resumen de Costes" tipo jNomina.

```sql
WITH retri AS (
    SELECT hp.hisptrabajador,
           SUM(hr.hisrimporte) AS total_devengado
    FROM [laboral].[dbo].HISPERSO hp
    INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
    WHERE hp.hispcodiemp = :empresa
      AND hp.hispejercicio = :year
      AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
      AND hp.hispproceso IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    GROUP BY hp.hisptrabajador
),
deduc AS (
    -- IMPORTANTE: filtrar por hisdconcepto = 90451 (DEDUCCIONES total agregado).
    -- Sumar hd.hisdcuota sin filtro doble-cuenta porque HISDEDUC mezcla
    -- deducciones reales con conceptos agregados/informativos. Ver regla 5.bis.
    SELECT hp.hisptrabajador,
           SUM(hd.hisdcuota) AS total_deducciones
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
SELECT t.tracodigo,
       t.tranif,
       t.tranombre,
       r.total_devengado,
       d.total_deducciones,
       (r.total_devengado - d.total_deducciones) AS total_liquido,
       c.coste_ss_empresa,
       c.bonificaciones,
       c.otros_costes,
       (r.total_devengado + c.coste_ss_empresa + c.otros_costes - c.bonificaciones)
           AS coste_real_empresa
FROM [laboral].[dbo].TRABAJADOR t
INNER JOIN retri r ON r.hisptrabajador = t.tracodigo
LEFT JOIN deduc d ON d.hisptrabajador = t.tracodigo
LEFT JOIN costes c ON c.hisptrabajador = t.tracodigo
WHERE t.tracodiemp = :empresa
ORDER BY t.tracodigo
```

**Notas sobre esta consulta:**
- El INNER JOIN con `retri` deja fuera trabajadores sin nómina en el periodo. Cambia a LEFT JOIN si los quieres incluir con NULLs.
- Para periodos multi-año, sustituye los `BETWEEN` por la condición compuesta de la regla 4.
- El "coste real empresa" aquí es una aproximación. El cálculo exacto de jNomina además aplica:
  - Ajustes por exoneración ER (regla 6) excluyendo bonificaciones de filas marcadas
  - Contingencias excluidas para mayores de 65 (cruzando con SSCUOTAS y reglas en `app/core/bases_cotizacion.py`)
  - Mecanismo MEI (Mecanismo Equidad Intergeneracional) en `app/core/mei_constants.py`
  Si necesitas el cálculo "oficial", llama al endpoint `/resumen-costes` en lugar de reescribirlo a mano.
- Para sumar también la **base de cotización**: añade `SUM(hc.HISCBASE) AS base_cont_comunes` al CTE de costes.

### Top conceptos retributivos del periodo

Los conceptos con mayor peso en la nómina, útil para entender qué partidas dominan los costes.

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

> Si la BD es antigua y `hisrdescripcion` no existe, omite ese campo y vive sin descripciones.

### Datos personales del trabajador (cross-database)

```sql
-- En base de datos easp
SELECT n.danifcif,
       RTRIM(n.datapell1) + ' ' + RTRIM(n.datapell2) + ', ' + RTRIM(n.datnombre)
           AS nombre_completo
FROM [easp].[dbo].NIFES n
WHERE n.danifcif = :nif
```

### Cuotas de cotización SS aplicables

```sql
SELECT TOP 1
    SSCUOBCCEMPR AS pct_cc_empresa,
    SSCUOBCCTRAB AS pct_cc_trabajador,
    SSCUO65EMP   AS pct_65_empresa,
    SSCUO65TRA   AS pct_65_trabajador,
    SSCUOEXCLUEMP AS pct_excl_empresa,
    SSCUOEXCLUTRA AS pct_excl_trabajador
FROM [laboral].[dbo].SSCUOTAS
WHERE SSCUOREGIMEN = :regimen
  AND SSCUOCODI = :regimen_codigo
  AND SSCUOEJERCICIO <= :year
  AND SSCUOPERIODO <= :periodo
ORDER BY SSCUOEJERCICIO DESC, SSCUOPERIODO DESC
```

### Distribución analítica de un trabajador

```sql
SELECT tcacodtrab, tcadeparconta, TCAPORCEN
FROM [laboral].[dbo].TRACOSTANALITIC
WHERE tcatipo = 'CA'
  AND tcacodiemp = :empresa
  AND tcaejercicio = :year
  AND tcaperiodo = :periodo
  AND tcacodtrab = :trabajador
ORDER BY tcadeparconta
```

### Desglose por centro y departamento

```sql
SELECT c.cennombre AS centro,
       cd.cedptonom AS departamento,
       SUM(hr.hisrimporte) AS total_devengado
FROM [laboral].[dbo].HISPERSO hp
INNER JOIN [laboral].[dbo].HISRETRI hr ON hr.hisrcalculo = hp.hispcodigo
LEFT JOIN [laboral].[dbo].CENTROS c
    ON c.cencodiemp = hp.hispcodiemp AND c.cencodigo = hp.hispcentro
LEFT JOIN [laboral].[dbo].CENDPTO cd
    ON cd.cedcodiemp = hp.hispcodiemp
   AND cd.cedcodigo = hp.hispcentro
   AND cd.cedptocodi = hp.hispdpto
WHERE hp.hispcodiemp = :empresa
  AND hp.hispejercicio = :year
  AND hp.hispperiodo BETWEEN :p_ini AND :p_fin
  AND hp.hispproceso IN (1, 2, 3, 4)
GROUP BY c.cennombre, cd.cedptonom
ORDER BY centro, departamento
```

---

## Notas adicionales

### VALORESDIR como puente jconta ↔ laboral

Cuando el usuario pide "el coste contable" o "el asiento de la nómina", el cálculo no es un SUM directo sobre HISCOSTES. Hay que mirar VALORESDIR para ver, por cada concepto contable definido (p.ej. cuenta 640 - sueldos), qué tabla y qué rango de conceptos de nómina lo componen, y luego sumar. El servicio Python lo hace en `_get_importe2()` dentro de `app/services/resumen_contable_service.py`.

Para análisis ad-hoc por SQL, si el usuario solo quiere "totales de nómina" basta con consultar HISRETRI/HISDEDUC/HISCOSTES directamente. Solo necesitas VALORESDIR cuando piden "el resumen contable tal como se contabilizaría en jconta".

### Diferencia con contaasp respecto al ejercicio

En contabilidad, el ejercicio condiciona la BD (`ctasp{year}`). En laboral **no**: la BD es siempre `laboral` y el ejercicio es un campo (`hispejercicio`). Esto simplifica las consultas multi-año pero significa que un usuario hablando de "ejercicio 2025" se refiere a un filtro `WHERE hispejercicio = 2025`, no a una BD distinta.

### Endpoint de referencia

El endpoint `POST /api/v1/resumen-costes` (definido en `app/api/endpoints/resumen_contable.py`) replica la lógica completa de `procesaResumenContableExcel()` de jNomina. Si el usuario pide el resumen "oficial" (con ajustes ER, MEI, contingencias excluidas, etc.), redirígelo al endpoint en lugar de intentar reproducirlo a SQL puro.
