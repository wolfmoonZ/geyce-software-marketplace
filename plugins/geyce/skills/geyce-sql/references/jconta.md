# Referencia de Tablas — jconta (ContaASP)

Documentacion del modelo de datos SQL Server utilizado por **ContaASP** (aplicativo de contabilidad, jconta). Pensado como referencia para agentes que necesiten entender la estructura de datos, construir consultas o interpretar peticiones de usuario sobre contabilidad espanola.

> Para datos de **nómina / costes laborales / cotizaciones SS**, ver `laboral.md` en este mismo directorio.

---

## Arquitectura de Bases de Datos

ContaASP usa una arquitectura **multi-base de datos**:

| Base de datos | Alcance | Ejemplo |
|---------------|---------|---------|
| `ctasp{year}` | Una por ejercicio fiscal. Contiene todos los datos contables del ano | `ctasp2024`, `ctasp2025` |
| `easp` | Base maestra compartida. Datos de terceros, empresas, inmovilizado, transacciones | Unica |

El cambio de base de datos se realiza via `SecureDatabaseContext` que ejecuta `USE [ctasp{year}]`. Las tablas de `easp` se acceden con nombre completo `[easp].[dbo].[tabla]`.

---

## Glosario de Conceptos

| Concepto | Descripcion |
|----------|-------------|
| **Ejercicio** | Ano fiscal (normalmente coincide con el ano natural). Cada ejercicio tiene su propia BD |
| **Empresa** | Entidad contable identificada por `empcodigo`. Un dominio puede tener multiples empresas |
| **Dominio** | Codigo de 12 caracteres (`cdpcodi`): 6 chars grupo + 6 chars empresa |
| **Asiento** | Registro contable en el libro diario. Un asiento tiene multiples apuntes (lineas) |
| **Apunte** | Linea individual de un asiento: una cuenta, un importe, debe o haber |
| **Cuenta** | Codigo de 3-4 digitos del PGC (Plan General Contable). Ej: `430` = Clientes |
| **Subcuenta** | Desglose de una cuenta para un tercero concreto. `'0'` = cuenta principal sin desglose |
| **Debe/Haber** | Campo `asidebehaber`: `'D'` = cargo (debe), `'H'` = abono (haber) |
| **Diario** | Libro auxiliar. Diario `31` = diario especial de apertura/cierre |
| **Apertura** | Asiento inicial del ejercicio (mes logico 0): `asidiario=31, asiasiento=1` |
| **Cierre ejercicio** | Penultimo asiento del diario 31 (mes logico 13) |
| **Cierre contabilidad** | Ultimo asiento del diario 31 (mes logico 14) |
| **NIF/CIF** | Numero de Identificacion Fiscal. Clave para vincular cuentas con terceros |
| **IVA** | Impuesto sobre el Valor Anadido |
| **IGIC** | Impuesto General Indirecto Canario (equivalente IVA en Canarias) |
| **IRPF** | Impuesto sobre la Renta de las Personas Fisicas (retenciones) |
| **RECC** | Regimen Especial de Criterio de Caja. IVA se devenga en el momento del cobro/pago |
| **Prorrata** | Porcentaje de IVA deducible cuando la empresa tiene actividades exentas y no exentas |
| **Transaccion** | Codigo que clasifica el tipo de operacion IVA (EIN=entrega interior, RIN=recepcion interior, etc.) |
| **Modelo fiscal** | Declaraciones tributarias espanolas: 111 (retenciones trabajo), 115 (alquileres), 123 (capital) |
| **Epigrafe** | Elemento de la estructura del balance (Activo, Pasivo, P&G). Puede tener formulas |
| **Estructura** | Definicion de como se organizan las cuentas en un balance (NIF, NIIF, etc.) |
| **civemirep** | Campo con valores **invertidos** en BD: `'R'` = Emitidas, `'S'` = Recibidas |

---

## Mapa de Relaciones

```
easp (base maestra)
=====================

CDP ──────────────── NIFES            PROVINCIA
 cdpcodi               danifcif         pvcodigo
 cdpnifcif ──────────> danifcif         pvdesc
                        datprov ───────> pvcodigo

BDSCARGADAS                           TRANSACCIONES
 bddominio ──────────> CDP.cdpcodi      tratipo
 bdejer                                 tradesc

FORMACOBPAG                           PCINMOV ────────── PCMORANUAL
 fcpforma                               pciempresa        pcmelemento
 fcpdesc                                 pcielemento ────> pcmelemento


ctasp{year} (por ejercicio)
=============================

EMPRESA
 empcodigo ─────────────────────────────────────────────┐
 empnif ─────────> easp.NIFES.danifcif                   |
                                                         |
ASIENTOS (nucleo contable)                               |
 asiempresa ────────────────────────────────────────────>|
 asiejercicio                                            |
 asicuenta ──────> PCUENTAS.pcucuenta                    |
 asisubcuenta ───> PCUENTAS.pcusubcuenta                 |
 asidiario2 ─────> DIARIOS.diacodigo                     |
 asidepartamento > DEPARTAMENTOS.depdepartamento         |
 asiproyecto ────> PROYECTOS.proproyecto                 |
 asiactividad ───> ACTIVIDADES.actactividad              |
                                                         |
PCUENTAS                                                 |
 pcuempresa ────────────────────────────────────────────>|
 pcuejercicio                                            |
 pcucuenta                                               |
 pcusubcuenta                                            |
 pcunif ─────────> easp.NIFES.danifcif                   |
                                                         |
IVACABECERA (facturas IVA)                               |
 civempresa ────────────────────────────────────────────>|
 civejercicio                                            |
 civcodi ────────> IVALINEAS.livcodi                     |
 civasicodi ─────> ASIENTOS.asicodi                      |
 civnif                                                  |
 civactividad ───> ACTIVIDADES.actactividad              |
                                                         |
IVALINEAS (lineas de factura IVA)                        |
 livcodi ────────> IVACABECERA.civcodi                   |
 livasto ────────> ASIENTOS.asicodi                      |
                                                         |
COBROPAGO (cobros y pagos)                               |
 cobempresa ────────────────────────────────────────────>|
 cobejerasto ────> ASIENTOS.asiejercicio                 |
 cobnumasto ─────> ASIENTOS.asiasiento                   |
 cobcobpagfp ────> easp.FORMACOBPAG.fcpforma             |
                                                         |
ESTRUCTURA (estructura del balance)                      |
 estcodigo                                               |
 estelemento ─── chars 7-10 ──> ASIENTOS.asicuenta      |
                                                         |
PCEPIGRAFE (epigrafes del balance)                       |
 pceestructura ─> ESTRUCTURA.estcodigo                   |
```

---

## Tablas por Dominio Funcional

### 1. Contabilidad General

#### ASIENTOS (ctasp{year}) - Apuntes contables

Tabla central del sistema. Cada fila es un **apunte** (linea de asiento).

| Campo | Descripcion |
|-------|-------------|
| `asicodi` | ID unico del apunte (PK) |
| `asiempresa` | Codigo de empresa |
| `asiejercicio` | Ejercicio fiscal |
| `asiasiento` | Numero de asiento. Agrupa las lineas de un mismo movimiento |
| `asirenumerado` | Numero renumerado (alternativo, post-proceso) |
| `asifecha` | Fecha del apunte |
| `asifechacon` | Fecha de contabilizacion (puede diferir de asifecha) |
| `asicuenta` | Codigo de cuenta (3-4 digitos PGC) |
| `asisubcuenta` | Codigo de subcuenta (`'0'` = cuenta principal) |
| `asidebehaber` | `'D'` = Debe (cargo), `'H'` = Haber (abono) |
| `asiimporte` | Importe del apunte (siempre positivo, el signo lo da asidebehaber) |
| `asidesc` | Concepto/descripcion del apunte |
| `asidiario` | Codigo diario primario. `31` = diario especial apertura/cierre |
| `asidiario2` | Codigo diario secundario/simplificado. FK a DIARIOS |
| `asidocumento` | Referencia de documento |
| `asidepartamento` | Codigo departamento (dimension analitica) |
| `asiproyecto` | Codigo proyecto (dimension analitica) |
| `asiactividad` | Codigo actividad economica (dimension analitica) |
| `asicontraconta` | Cuenta de contrapartida |
| `asicontrasub` | Subcuenta de contrapartida |
| `asistatuspunteo` | Estado de punteo: `'S'`/`'N'`/NULL |
| `asistatuscon` | Estado de conciliacion bancaria: `'S'`/`'N'`/NULL |
| `asiastocas` | Campo de asociacion/enlace |

**Reglas de negocio:**
- El saldo de una cuenta se calcula como: `SUM(CASE WHEN asidebehaber='D' THEN asiimporte ELSE -asiimporte END)`
- Los periodos especiales se detectan combinando `asidiario`, `asiasiento` y `asifecha` (ver seccion "Periodos Especiales")
- El campo `solo_salida` filtra diarios: rangos 1-30 y 61-90 (salida) vs 1-60 (entrada)

#### PCUENTAS (ctasp{year}) - Plan de cuentas

Define las cuentas y subcuentas disponibles para una empresa en un ejercicio.

| Campo | Descripcion |
|-------|-------------|
| `pcuempresa` | Codigo de empresa |
| `pcuejercicio` | Ejercicio fiscal |
| `pcucuenta` | Codigo de cuenta (3-4 digitos) |
| `pcusubcuenta` | Codigo de subcuenta (`'0'` = cuenta principal) |
| `pcudesc` | Descripcion de la cuenta/subcuenta |
| `pcunif` | NIF/CIF del tercero vinculado. Enlaza con `easp.NIFES` |
| `pcuclave110` | Clave para modelos fiscales 110/111/123. Prefijo `@` indica mod 123 |
| `pcu347` | Indicador inclusion modelo 347 (`'S'`/`'N'`) |
| `pcu349` | Indicador inclusion modelo 349 (`'S'`/`'N'`) |

**Clave compuesta:** (pcuempresa, pcuejercicio, pcucuenta, pcusubcuenta)

#### PCACUMULADOS (ctasp{year}) - Saldos acumulados pre-calculados

Saldos mensuales pre-calculados por cuenta. **Puede estar vacia** - algunos informes la ignoran y calculan desde ASIENTOS directamente.

| Campo | Descripcion |
|-------|-------------|
| `pcaempresa` | Codigo de empresa |
| `pcaejercicio` | Ejercicio fiscal |
| `pcacuenta` | Codigo de cuenta |
| `pcasubcuenta` | Codigo de subcuenta |
| `pcatipoacum` | Tipo de acumulado (parametrizado) |
| `pcadebeapert` | Debe apertura (mes 0) |
| `pcadebe1`..`pcadebe12` | Debe mensual (meses 1-12) |
| `pcadebecieejer` | Debe cierre ejercicio (mes 13) |
| `pcadebeciecon` | Debe cierre contabilidad (mes 14) |
| `pcahaberapert` | Haber apertura (mes 0) |
| `pcahaber1`..`pcahaber12` | Haber mensual (meses 1-12) |
| `pcahabercieejer` | Haber cierre ejercicio (mes 13) |
| `pcahaberciecon` | Haber cierre contabilidad (mes 14) |

**Clave compuesta:** (pcaempresa, pcaejercicio, pcacuenta, pcasubcuenta, pcatipoacum)

#### EMPRESA (ctasp{year}) - Datos de la empresa contable

| Campo | Descripcion |
|-------|-------------|
| `empcodigo` | Codigo de empresa (PK) |
| `empnif` | NIF/CIF de la empresa. FK a `easp.NIFES.danifcif`. Se usa para obtener el nombre/razon social |
| `empestructura` | Codigo de estructura del balance (NIF, NIIF, etc.) |
| `empivamensual` | Flag IVA mensual (`'S'`/`'N'`). Afecta calculo periodo fiscal |
| `empgranemp` | Flag gran empresa. Afecta calculo periodo fiscal |
| `empexporta` | Flag exportadora. Afecta calculo periodo fiscal |
| `empprogral` | Porcentaje prorrata general (0-100). Para calculo cuota deducible |

**Importante:** la tabla `EMPRESA` **no contiene el nombre/razon social** de la empresa. Para obtenerlo hay que cruzar `empnif` con `[easp].[dbo].[NIFES].danifcif` y componer la razon social desde `datapell1 + datapell2 + datnombre` (ver patron "Obtener nombre/razon social de una empresa" mas abajo).

**Calculo periodo fiscal:** Si `empivamensual='S'` OR `empgranemp='S'` OR `empexporta='S'` -> periodo mensual ("01"-"12"), sino -> trimestral ("1T"-"4T")

#### EJERCICIO (ctasp{year}) - Configuracion del ejercicio

| Campo | Descripcion |
|-------|-------------|
| `ejeempresa` | Codigo de empresa |
| `ejeejercicio` | Ejercicio fiscal |
| `ejesalida` | Flag de salida (filtro = 1) |
| `ejeastoap` | Numero del asiento de apertura |
| `ejeastoce` | Numero del asiento de cierre de ejercicio |
| `ejeastocc` | Numero del asiento de cierre de contabilidad |

Usado para excluir asientos especiales (apertura/cierre) de ciertos informes.

---

### 2. Dimensiones Analiticas

#### DIARIOS (ctasp{year})

| Campo | Descripcion |
|-------|-------------|
| `diacodigo` | Codigo del diario (PK). FK desde `ASIENTOS.asidiario2` |
| `diadesc` | Descripcion del diario |

#### DEPARTAMENTOS (ctasp{year})

| Campo | Descripcion |
|-------|-------------|
| `depempresa` | Codigo de empresa |
| `depdepartamento` | Codigo de departamento (PK compuesta con empresa). FK desde `ASIENTOS.asidepartamento` |
| `depdesc` | Descripcion del departamento |

#### PROYECTOS (ctasp{year})

| Campo | Descripcion |
|-------|-------------|
| `proempresa` | Codigo de empresa |
| `proproyecto` | Codigo de proyecto (PK compuesta con empresa). FK desde `ASIENTOS.asiproyecto` |
| `prodesc` | Descripcion del proyecto |

#### ACTIVIDADES (ctasp{year})

| Campo | Descripcion |
|-------|-------------|
| `actempresa` | Codigo de empresa |
| `actactividad` | Codigo de actividad (requiere RTRIM). FK desde `ASIENTOS.asiactividad` |
| `actdescripcion` | Descripcion de la actividad |
| `actprincipal` | `'S'` si es la actividad principal de la empresa |
| `actclave` | Clave tipo actividad. Remapeado a codigos AEAT |
| `actepigrafe` | Epigrafe IAE de la actividad |

---

### 3. Estructura del Balance

#### ESTRUCTURA (ctasp{year})

Define como se organizan las cuentas dentro de un tipo de balance (Situacion, P&G, etc.).

| Campo | Descripcion |
|-------|-------------|
| `estcodigo` | Codigo de estructura (ej: "NIF", "NIIF") |
| `estelemento` | Codigo de elemento compuesto (10 chars): char 0 = grupo, chars 1-6 = epigrafe, chars 7-10 = cuenta |
| `esttipo` | `'E'` = epigrafe (agrupador), `'C'` = linea de cuenta |
| `estpertenece` | Codigo del elemento padre (jerarquia) |
| `estacumula` | Regla de acumulacion de saldo: `'S'`=siempre, `'P'`=solo si deudor, `'N'`=solo si acreedor, `'X'`=siempre cero |

**Grupos de balance** (primer caracter de `estelemento`):
- `A` = Activo
- `B` = Pasivo
- `C` = Perdidas y Ganancias
- `D` = Patrimonio Neto
- `H` = Estado de Flujos de Efectivo
- `P` = Pasivo (alternativo)

**Vinculacion con cuentas:** `SUBSTRING(estelemento, 7, 4)` se enlaza con `ASIENTOS.asicuenta` para acumular saldos.

#### PCEPIGRAFE (ctasp{year})

Definicion de los epigrafes (agrupadores) del balance con sus formulas y reglas de visualizacion.

| Campo | Descripcion |
|-------|-------------|
| `pceestructura` | Codigo de estructura. FK a `ESTRUCTURA.estcodigo` |
| `pceelemento` | Codigo del epigrafe |
| `pcedescripcion` | Descripcion del epigrafe |
| `pceformula` | Formula para epigrafes calculados (ej: `C1+C2`, `-RESULTADO`) |
| `pcenegativo` | Regla de signo: `'N'`=cero si positivo, `'P'`=cero si negativo, `'X'`=siempre cero |
| `pcedesglose` | Mostrar cuentas debajo del epigrafe: `'N'`=no desglosar |
| `pceimpresion` | Regla de impresion: `'S'`=siempre, `'N'`=nunca, `'D'`=solo si no cero |

---

### 4. Facturas e IVA

#### IVACABECERA (ctasp{year}) - Cabecera de facturas IVA

Cada fila es una factura registrada en el libro de IVA.

| Campo | Descripcion |
|-------|-------------|
| `civcodi` | Codigo interno factura (PK) |
| `civempresa` | Codigo de empresa |
| `civejercicio` | Ejercicio fiscal |
| `civregistro` | Numero de registro en el libro |
| `civserie` | Serie de factura (puede tener espacios, hacer RTRIM) |
| `civdocumento` | Numero de documento |
| `civfecha` | Fecha de la factura (campo principal) |
| `civfechaop` | Fecha de operacion (alternativa) |
| `civfechareg` | Fecha de registro contable |
| `civnif` | NIF/CIF del tercero (cliente o proveedor) |
| `civdesc` | Descripcion de la factura |
| `civimporte` | Importe total de la factura |
| `civemirep` | Tipo emision/recepcion. **ATENCION: invertido en BD** - `'R'`=Emitidas, `'S'`=Recibidas |
| `civivaigic` | Tipo impuesto: `'I'`=IVA, `'G'`=IGIC, `'A'`=IGI |
| `civregimen` | Regimen fiscal aplicable |
| `civbaseirpf` | Base imponible IRPF |
| `civporirpf` | Porcentaje de retencion IRPF |
| `civimpiva` | Cuota IVA en cabecera |
| `civactividad` | Codigo de actividad |
| `civivaxfreg` | Flag para usar fecha de registro contable |
| `civsiipais` | Codigo pais SII (ISO) |
| `civsiitipo` | Tipo identificacion fiscal SII |
| `civsiitfac` | Tipo factura SII |
| `civrecc` | `'S'` = Regimen Especial Criterio de Caja |
| `civasicodi` | FK al apunte contable en ASIENTOS (`asicodi`) |
| `civesfabus` | Bienes usados: `'V'`=venta, `'C'`=compra |
| `civcodibus` | Codigo factura compra relacionada (bienes usados) |
| `civejerbus` | Ejercicio factura compra relacionada (puede ser otro ano) |
| `civmod110` | Flag inclusion modelo 110 |
| `civmod115` | Flag inclusion modelo 115 |
| `civmod123` | Flag inclusion modelo 123 |
| `civclave110` | Clave del modelo 110 (preferente sobre la calculada) |

#### IVALINEAS (ctasp{year}) - Lineas de detalle de factura IVA

Cada fila es un desglose de impuesto dentro de una factura (una factura puede tener multiples tipos de IVA).

| Campo | Descripcion |
|-------|-------------|
| `livcodi` | FK a `IVACABECERA.civcodi` |
| `livcodilin` | Numero de linea dentro de la factura |
| `livasto` | FK al apunte contable en `ASIENTOS.asicodi` |
| `livbase` | Base imponible de esta linea |
| `livporiva` | Porcentaje de IVA (ej: 21, 10, 4, 0) |
| `livimpiva` | Cuota de IVA |
| `livporrec` | Porcentaje de recargo de equivalencia |
| `livimprec` | Cuota de recargo de equivalencia |
| `livdeducible` | `'S'`/`'N'` - si el IVA es deducible |
| `livtransaccion` | Codigo tipo transaccion (EIN, RIN, DIB, RAS, RRD, RAG, etc.) |
| `livprorrata` | `'S'`/`'N'` - si aplica regla de prorrata |
| `livpordediva` | Porcentaje de deduccion (0-100) |

**Calculo cuota deducible:**
- Si `livprorrata='S'`: `livimpiva * (livpordediva * empprogral / 10000)`
- Si `livprorrata='N'`: `livimpiva * (livpordediva / 100)`
- Solo para facturas recibidas; emitidas siempre NULL

#### COBROPAGO (ctasp{year}) - Cobros y pagos (vencimientos)

Registra cobros y pagos asociados a asientos contables. Critico para RECC.

| Campo | Descripcion |
|-------|-------------|
| `cobcodi` | PK del registro |
| `cobempresa` | Codigo de empresa |
| `cobejerasto` | Ejercicio del asiento vinculado |
| `cobnumasto` | Numero del asiento vinculado |
| `cobimporte` | Importe del cobro/pago |
| `cobvto` | Fecha de vencimiento |
| `cobestado` | Estado: `'C'`=cerrado/liquidado, otros=pendiente |
| `cobcobropago` | Tipo: `'C'`=cobro (para emitidas), `'P'`=pago (para recibidas) |
| `cobcobpagfp` | Codigo forma de pago. FK a `easp.FORMACOBPAG` |
| `cobccc` | Numero de cuenta bancaria (CCC) |

**Calculo proporcional RECC:** `cobimporte / NULLIF(civimporte, 0)` se aplica a base y cuota para obtener la parte proporcional cobrada/pagada.

#### EQLIBROIYG (ctasp{year}) - Equivalencias cuenta-codigo AEAT

Mapea cuentas contables a codigos de clasificacion AEAT para libros de IVA e Ingresos/Gastos.

| Campo | Descripcion |
|-------|-------------|
| `eliempresa` | Codigo de empresa |
| `eliejercicio` | Ejercicio fiscal |
| `elicuenta` | Codigo de cuenta (3+ digitos) |
| `elicolaeat` | Codigo clasificacion AEAT (ej: "G01", "I01", "R01") |

#### DEFCOLIYG (ctasp{year}) - Definicion columnas AEAT

Define las columnas del libro de Ingresos y Gastos segun codificacion AEAT.

| Campo | Descripcion |
|-------|-------------|
| `dcgempresa` | Codigo de empresa |
| `dcgejercicio` | Ejercicio fiscal |
| `dcgcodaeat` | Codigo AEAT. JOIN con `EQLIBROIYG.elicolaeat` |
| `dcgdescrip1` | Descripcion primaria de la columna |
| `dcgdescrip2` | Descripcion secundaria de la columna |

---

### 5. Modelos Fiscales y Retenciones

#### PREFIJOS (ctasp{year}) - Prefijos de cuentas por modelo fiscal

Define que prefijos de cuenta corresponden a cada modelo fiscal (110, 115, 123).

| Campo | Descripcion |
|-------|-------------|
| `prfempresa` | Codigo de empresa |
| `prfejercicio` | Ejercicio fiscal |
| `prfaccion` | Modelo fiscal: `'110'`, `'115'`, `'123'` |
| `prfprefijo1`..`prfprefijo10` | Hasta 10 prefijos de cuenta. Generan filtros `pcucuenta LIKE 'xx%'` |

#### PCLOCALES (ctasp{year}) - Locales asociados a cuentas

Determina si una cuenta/subcuenta tiene un local asociado (relevante para modelo 115 - alquileres).

| Campo | Descripcion |
|-------|-------------|
| `pclempresa` | Codigo de empresa |
| `pclejercicio` | Ejercicio fiscal |
| `pclcuenta` | Codigo de cuenta |
| `pclsubcuenta` | Codigo de subcuenta |

La existencia de un registro indica que la cuenta tiene local asociado (clave para modelo 115).

---

### 6. Inmovilizado y Amortizaciones

#### PCINMOV (easp) - Bienes de inversion / Fichas de activo inmovilizado

Acceso via `[easp].[dbo].[PCINMOV]`. Registro de activos fijos de la empresa.
Usada por: Bienes de Inversion (ListadoBienesInv), Fichas de Activo (ProgInvprlisinver), Listado Amortizaciones (ProgInvprlisbieninv).

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `pcielemento` | int | NO | Codigo del bien (PK con empresa) |
| `pciempresa` | int | NO | Codigo de empresa |
| `pciejercicio` | int | NO | Ejercicio fiscal |
| `pcicuenta` | varchar(4) | NO | Cuenta contable del activo |
| `pcisubcuenta` | varchar(12) | NO | Subcuenta contable del activo |
| `pciarticulo` | int | NO | Codigo de articulo |
| `pcitipoamort` | varchar(3) | NO | Metodo amortizacion: LIN, DCC, DCV, LIB, LIM, PLA, PRU |
| `pcicodigoamor` | int | NO | Codigo numerico de amortizacion |
| `pcinuevousado` | varchar(3) | NO | Nuevo/Usado (NUE, USA) |
| `pcidesc` | varchar(40) | SI | Descripcion del bien |
| `pciregistro` | varchar(8) | SI | Numero de registro |
| `pcictaamort` | varchar(4) | SI | Cuenta de amortizacion acumulada |
| `pcisubctaamort` | varchar(12) | SI | Subcuenta de amortizacion acumulada |
| `pcictadot` | varchar(4) | SI | Cuenta de dotacion a la amortizacion |
| `pcisubctadot` | varchar(12) | SI | Subcuenta de dotacion |
| `pcicoefapli` | float | SI | Coeficiente de amortizacion aplicado (%) |
| `pciperapli` | int | SI | Periodo de amortizacion aplicado (anos) |
| `pcifecalta` | datetime | SI | Fecha de alta/adquisicion |
| `pcifecbaja` | datetime | SI | Fecha de baja (NULL = activo) |
| `pcifecplan` | datetime | SI | Fecha del plan de amortizacion |
| `pciadquis` | float | SI | Valor de adquisicion (base amortizable) |
| `pcicoste` | float | SI | Coste original del bien |
| `pcinoamort` | float | SI | Importe no amortizable |
| `pcihoras` | float | SI | Numero de horas (para amortizacion por uso) |
| `pciunidades` | int | SI | Numero de unidades |
| `pcireserva` | float | SI | Importe reservado |
| `pciobser` | varchar(4000) | SI | Observaciones |
| `pcicodini` | int | SI | Codigo inicial |
| `pcifradoc` | varchar(60) | SI | Numero documento factura de compra |
| `pcifrafecha` | datetime | SI | Fecha factura de compra |
| `pcifratotal` | float | SI | Total factura (con IVA) |
| `pcifrabase` | float | SI | Base imponible factura |
| `pcifracuota` | float | SI | Cuota IVA factura |
| `pcifraporc` | float | SI | Porcentaje IVA factura |
| `pcinifprov` | varchar(15) | SI | NIF del proveedor |
| `pcinomprov` | varchar(200) | SI | Nombre del proveedor |
| `pcicausabaja` | varchar(200) | SI | Causa de la baja |
| `pciproyecto` | varchar(5) | SI | Codigo de proyecto |
| `pcideparta` | varchar(5) | SI | Codigo de departamento |
| `pciactividad` | int | SI | Codigo de actividad economica |
| `pcianyosreg` | int | SI | Anos de regimen |
| `pcidivisor` | int | SI | Divisor para calculo |
| `pcicoefdefi` | float | SI | Coeficiente definitivo |
| `pcilimiteinver` | float | SI | Limite de inversion |
| `pciincrplantil` | float | SI | Incremento de plantilla |
| `pcicoeffiscal` | float | SI | Coeficiente fiscal |
| `pcitipofiscal` | varchar(5) | SI | Tipo fiscal |
| `pcileavresid` | float | SI | Valor residual leasing |
| `pcileaporcint` | float | SI | Porcentaje intereses leasing |
| `pcileaespyme` | varchar(1) | SI | Flag espyme leasing |
| `pcictal524` | varchar(4) | SI | Cuenta leasing 524 |
| `pcisubctal524` | varchar(12) | SI | Subcuenta leasing 524 |
| `pcictal662` | varchar(4) | SI | Cuenta leasing 662 |
| `pcisubctal662` | varchar(12) | SI | Subcuenta leasing 662 |
| `pcictal626` | varchar(4) | SI | Cuenta leasing 626 |
| `pcisubctal626` | varchar(12) | SI | Subcuenta leasing 626 |
| `pcictal472` | varchar(4) | SI | Cuenta leasing 472 |
| `pcisubctal472` | varchar(12) | SI | Subcuenta leasing 472 |
| `pcictal572` | varchar(4) | SI | Cuenta leasing 572 |
| `pcisubctal572` | varchar(12) | SI | Subcuenta leasing 572 |
| `pcimporteventa` | float | SI | Importe de venta |
| `pcfechaventa` | datetime | SI | Fecha de venta |

**Tipos de libro** (filtros usados por Bienes de Inversion):
- **A**: `pcifecbaja IS NULL OR pcifecbaja >= fecha_desde`
- **C**: `YEAR(pcifecalta) = year`
- **N**: `pcifecbaja IS NULL OR pcifecbaja > fecha_hasta`
- **P**: `pcifecalta <= fecha_hasta`
- **T**: `pcifecbaja IS NOT NULL AND pcifecbaja <= fecha_hasta`

**Filtros Fichas de Activo** (usados por ProgInvprlisinver / endpoint POST /fichas-activo):
- Por cuentas: `pcicuenta >= :desde` (si <= 4 chars) o compuesto `(pcicuenta > :cta OR (pcicuenta = :cta AND pcisubcuenta >= :sub))` (si > 4 chars)
- Por elementos: `pcielemento >= :desde AND pcielemento <= :hasta`
- Por fechas adquisicion: `pcifecalta >= :desde AND pcifecalta <= :hasta`
- Bajas: `pcifecbaja IS NULL` (excluir bajas por defecto)
- Actividad: `pciactividad >= :desde AND pciactividad <= :hasta` o `pciactividad IS NOT NULL`

**Ordenacion Fichas de Activo:**
- Por cuentas (defecto): `ORDER BY pcicuenta, pcisubcuenta`
- Por fechas: `ORDER BY pcifecalta`
- Por elementos: `ORDER BY pcielemento`

**Filtros Listado Amortizaciones** (usados por ProgInvprlisbieninv / endpoint POST /amortizaciones-listado):
- Por cuentas: misma logica que Fichas de Activo (4 chars vs compuesto)
- Por fechas adquisicion: `pcifecalta >= :desde AND pcifecalta <= :hasta`
- Bajas: `pcifecbaja IS NULL` (excluir bajas por defecto)
- Actividad: misma logica que Fichas de Activo
- Subquery PCMORANUAL: `pcielemento IN (SELECT pcmelemento FROM PCMORANUAL WHERE pcmamorejer = :year AND pcmtipo = 'C')` (cuando tipo_listado='S' o fiscal)
- Ordenacion fija: `ORDER BY pcicuenta, pcisubcuenta, pciarticulo`

#### PCMORANUAL (easp) - Amortizaciones anuales

Acceso via `[easp].[dbo].[PCMORANUAL]`. Registra la amortizacion anual de cada bien.
Usada por: Listado Amortizaciones (ProgInvprlisbieninv), Bienes de Inversion (ListadoBienesInv).

| Campo | Tipo | Null | Descripcion |
|-------|------|------|-------------|
| `pcmelemento` | int | NO | Codigo del bien. FK a `PCINMOV.pcielemento` (PK con pcmamorejer + pcmtipo) |
| `pcmamorejer` | int | NO | Ejercicio de la amortizacion (PK) |
| `pcmtipo` | varchar(1) | NO | Tipo: `'C'` = contable, `'F'` = fiscal (PK) |
| `pcmcoefamort` | float | SI | Coeficiente de amortizacion aplicado (%) |
| `pcmamortanual` | float | SI | Amortizacion del periodo/ejercicio |
| `pcmamortacum` | float | SI | Amortizacion acumulada total |
| `pcmamortpdte` | float | SI | Amortizacion pendiente |
| `pcmcuotaapli` | float | SI | Cuota de amortizacion aplicada |
| `pcmultfecha` | datetime | SI | Ultima fecha de amortizacion |
| `pcmporcint` | float | SI | Porcentaje de intereses (leasing) |
| `pcmintereses` | float | SI | Importe de intereses (leasing) |

**Filtros Listado Amortizaciones** (usados por ProgInvprlisbieninv / endpoint POST /amortizaciones-listado):

Logica de acceso (replica `FuncionesJasper.initAmortizacion()` en Java):
```sql
SELECT * FROM PCMORANUAL
WHERE pcmelemento = :elemento AND pcmtipo = :tipo   -- 'C' o 'F'
  AND pcmamorejer <= :ejercicio                      -- tipo_listado 'T' (todos)
  -- o pcmamorejer = :ejercicio                      -- tipo_listado 'S' (solo cuota actual)
ORDER BY pcmamorejer DESC                            -- tomar el registro mas reciente
```

Regla especial para `pcmamortanual` con tipo_listado `'T'`: solo tiene valor si `pcmamorejer == ejercicio`, sino se devuelve `0` (Java lineas 384-389 FuncionesJasper.java).

**Subquery en PCINMOV** (filtra elementos que tienen amortizacion):
```sql
-- Se anade al WHERE de PCINMOV cuando tipo_listado='S' o amortizaciones_fiscales=True
AND pcielemento IN (
    SELECT pcmelemento FROM PCMORANUAL
    WHERE pcmamorejer = :year AND pcmtipo = 'C'  -- o 'F' si fiscal
)
```

**Tipos de correccion fiscal** (`pcitipofiscal` en PCINMOV, usado solo en modo fiscal):

| Valor | Descripcion |
|-------|-------------|
| `1` | Diferencias entre amortizacion contable y fiscal (art. 12.1 LIS) |
| `2` | Deduccion del 30% gastos amortiz. contable (art. 7 Ley 16/2012) |
| `3` | Amortizacion inmovilizado intangible y fondo de comercio (art. 12.2 LIS) |
| `4` | Amortizacion inmovilizado afecto a I+D (art. 12.3 b) LIS) |
| `5` | Libertad amortizacion gastos I+D (art. 12.3 c) LIS) |
| `6` | Libertad amortizacion inmovilizado material nuevo (art. 12.3 e) LIS) |
| `7` | Otros supuestos libertad amortizacion (art. 12.3 a) y d) y DA 16a LIS) |
| `8` | Libertad amortizacion con mantenimiento empleo (RDL 6/2010) |
| `9` | Libertad amortizacion sin mantenimiento empleo (RDL 13/2010) |
| `10` | ERD: libertad amortizacion (art. 102 LIS) |
| `11` | ERD: amortizacion acelerada (art. 103 LIS) |

**Diferencia dineraria** (modo fiscal): `amort_contable (tipo C) - amort_fiscal (tipo F)`

---

### 7. Maestros Compartidos (easp)

#### NIFES (easp) - Datos fiscales y direccion de terceros

Tabla central de terceros. Acceso via `[easp].[dbo].[nifes]`.

| Campo | Descripcion |
|-------|-------------|
| `danifcif` | NIF/CIF (PK). Enlaza con `PCUENTAS.pcunif`, `IVACABECERA.civnif` |
| `datnombre` | Nombre de pila |
| `datapell1` | Primer apellido |
| `datapell2` | Segundo apellido |
| `datsiglas` | Tipo de via (C/, Avda., Pza., etc.) |
| `datvia` | Nombre de la via |
| `datnum` | Numero |
| `datesc` | Escalera |
| `datpiso` | Piso |
| `datletra` | Puerta/letra |
| `dattel` | Telefono |
| `datprov` | Codigo de provincia. FK a `PROVINCIA.pvcodigo` |
| `datcpos` | Codigo postal |
| `datpobla` | Poblacion |
| `datemail` | Email |

**Construccion de direccion completa:** Concatenar `datsiglas + datvia + datnum + datesc + datpiso + datletra`
**Construccion de razon social:** Concatenar `datapell1 + datapell2 + datnombre`

#### PROVINCIA (easp) - Catalogo de provincias

| Campo | Descripcion |
|-------|-------------|
| `pvcodigo` | Codigo de provincia (PK) |
| `pvdesc` | Nombre de la provincia |

#### CDP (easp) - Dominios de empresas

| Campo | Descripcion |
|-------|-------------|
| `cdpcodi` | Codigo dominio (12 chars): chars 0-5 = grupo, chars 6-11 = empresa |
| `cdpnifcif` | NIF/CIF de la empresa. FK a `NIFES.danifcif` |
| `cdpckconta` | Flag contabilidad activa: `'S'`/`'N'` |

#### BDSCARGADAS (easp) - Bases de datos cargadas

Registra que ejercicios tiene cargados cada dominio.

| Campo | Descripcion |
|-------|-------------|
| `bddominio` | Codigo dominio. FK a `CDP.cdpcodi` |
| `bdejer` | Ejercicio fiscal cargado |

#### TRANSACCIONES (easp) - Catalogo de tipos de transaccion

Tabla global (sin filtro de empresa/ejercicio).

| Campo | Descripcion |
|-------|-------------|
| `tratipo` | Codigo tipo transaccion (PK). Ej: EIN, RIN, DIB, RAS, RRD, RAG |
| `tradesc` | Descripcion de la transaccion |
| `traemre` | Emision/recepcion: `'E'`=emitida, otro=recibida |
| `tratipoiva` | Tipo IVA de la transaccion. Valores `'DI'`, `'DIB'`, `'AD'`, `'ADB'`, `'RD'` indican doble registro |
| `traoper349` | Operacion modelo 349. `'I'` = intracomunitaria |

#### FORMACOBPAG (easp) - Formas de cobro/pago

| Campo | Descripcion |
|-------|-------------|
| `fcpforma` | Codigo forma de pago (PK). FK desde `COBROPAGO.cobcobpagfp` |
| `fcpdesc` | Descripcion de la forma de pago |

---

## Patrones de Consulta Comunes

### Obtener nombre/razon social de una empresa

La tabla `EMPRESA` (en `ctasp{year}`) **no contiene el nombre**. Hay que cruzar `empnif` con `easp.NIFES`:

```sql
SELECT
    emp.empcodigo,
    emp.empnif,
    LTRIM(RTRIM(
        ISNULL(RTRIM(nif.datapell1), '') + ' ' +
        ISNULL(RTRIM(nif.datapell2), '') + ' ' +
        ISNULL(RTRIM(nif.datnombre), '')
    )) AS razon_social
FROM EMPRESA emp
LEFT JOIN [easp].[dbo].[NIFES] nif ON nif.danifcif = emp.empnif
WHERE emp.empcodigo = :empresa
```

Para personas juridicas la razon social suele venir en `datapell1`; para personas fisicas se combinan apellidos y nombre.

### Calculo de saldos desde ASIENTOS

```sql
-- Saldo neto de una cuenta
SELECT
    asicuenta,
    SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE 0 END) AS total_debe,
    SUM(CASE WHEN asidebehaber = 'H' THEN asiimporte ELSE 0 END) AS total_haber,
    SUM(CASE WHEN asidebehaber = 'D' THEN asiimporte ELSE -asiimporte END) AS saldo_neto
FROM ASIENTOS
WHERE asiempresa = :empresa AND asiejercicio = :year
GROUP BY asicuenta
```

### Deteccion de periodos especiales

```sql
-- Apertura (mes logico 0)
WHERE asidiario = 31 AND asiasiento = 1 AND DAY(asifecha) = 1 AND MONTH(asifecha) = 1

-- Meses normales (1-12): excluir asientos de diario 31
WHERE MONTH(asifecha) BETWEEN :mes_desde AND :mes_hasta
  AND NOT (asidiario = 31 AND ...)

-- Cierre ejercicio (mes logico 13)
WHERE asidiario = 31 AND asiasiento = (SELECT MAX(asiasiento) FROM ASIENTOS WHERE asidiario = 31 ...) - 1

-- Cierre contabilidad (mes logico 14)
WHERE asidiario = 31 AND asiasiento = (SELECT MAX(asiasiento) FROM ASIENTOS WHERE asidiario = 31 ...)
```

### Inversion de civemirep

```sql
-- El usuario pide "Emitidas" (E) -> en BD se filtra por 'R'
-- El usuario pide "Recibidas" (R) -> en BD se filtra por 'S'
-- El usuario pide "Ambas" (A) -> sin filtro
CASE :tipo_factura
    WHEN 'E' THEN civemirep = 'R'
    WHEN 'R' THEN civemirep = 'S'
    WHEN 'A' THEN 1=1
END
```

### Saldo anterior + movimientos del periodo

Patron de 3 queries para balances:
1. **Saldo anterior**: SUM de ASIENTOS con meses [0, mes_desde - 1]
2. **Movimientos**: SUM de ASIENTOS con meses [mes_desde, mes_hasta]
3. **Saldo actual**: saldo_anterior + movimientos (o query directa meses [0, mes_hasta])

### Calculo proporcional RECC

```sql
-- Base e IVA proporcional al cobro/pago realizado
SUM(liv.livbase * (cob.cobimporte / NULLIF(civ.civimporte, 0))) AS base_recc,
SUM(liv.livimpiva * (cob.cobimporte / NULLIF(civ.civimporte, 0))) AS cuota_recc
```

### Consulta multi-ejercicio

Cuando las fechas cruzan el limite del ejercicio (ej: consultar diciembre del ano anterior):
1. Abrir conexion a `ctasp{year-1}` o `ctasp{year+1}`
2. Ejecutar la misma query con el ejercicio alternativo
3. Combinar resultados

### Matching tipo_ig (clasificacion AEAT)

Para el listado oficial de IVA, se determina el codigo AEAT de cada linea mediante 4 estrategias:
1. Buscar en EQLIBROIYG la cuenta 6xx/7xx del asiento vinculado
2. Si no hay match, buscar por direccion D/H del asiento
3. Si no hay match, buscar por importe exacto
4. Fallback: primer codigo encontrado para cualquier cuenta del asiento

### Determinacion de claves de modelo fiscal (IRPF)

Para cada factura con retencion:
1. Consultar PREFIJOS para obtener prefijos de cuenta del modelo (110/115/123)
2. Buscar en PCUENTAS las subcuentas que coinciden con esos prefijos y el NIF de la factura
3. Verificar existencia de local en PCLOCALES (determina si es modelo 115)
4. Consultar IVALINEAS para transaccion RAG/RRA (claves especificas H01/G01)
5. Prioridad: `civclave110` (BD) > clave calculada

---

## Notas Importantes

### Prefijo [API]
Varias descripciones se prefijan con `"[API] "` en las respuestas para identificar que los datos provienen de la API REST (marca de agua/watermark).

### Precision numerica
Todos los importes se manejan como `Decimal` para evitar errores de punto flotante.

### Queries parametrizadas
Todas las consultas usan parametros SQL (`:param`) para prevenir inyeccion SQL. Los nombres de tabla se validan via `SecureDatabaseContext.get_safe_table_name()`.
