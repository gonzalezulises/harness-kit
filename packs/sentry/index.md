# Pack de Observabilidad (Sentry)

Este pack añade una compuerta de observabilidad a cualquier repositorio: prueba
que los errores **llegan** a Sentry, que el evento se **almacena** de verdad, y
que el release tiene source maps para que la traza apunte a una línea de código
en vez de a la columna 4913 de un bundle minificado.

Usa este pack cuando despliegues algo que un cliente vaya a usar y necesites
enterarte de que se rompió antes de que te escriba el cliente.

## El problema que resuelve

Instalar un SDK no es observabilidad. El fallo que este pack existe para cerrar
es que **un Sentry que nunca recibió un evento es indistinguible de uno que
funciona**, hasta la noche en que lo necesitas:

| Situación | Qué hace la aplicación | Qué reporta el build |
|---|---|---|
| `SENTRY_DSN` vacío o ausente | Corre normal; `Sentry.init()` no-opea | **Verde** |
| DSN copiado de la documentación | Corre normal; los eventos van a un proyecto ajeno | **Verde** |
| `sampleRate: 0` | Corre normal; descarta todo antes de salir del proceso | **Verde** |
| Cuota agotada o filtro de entrada | La ingesta responde `200` y luego tira el evento | **Verde** |
| Sin `onRequestError` en Next.js | Los errores de servidor nunca se capturan | **Verde** |
| Release sin source maps | El evento llega, pero la traza es ilegible | **Verde** |

Las seis filas dejan el despliegue en verde y el proyecto vacío. Ninguna falla
hace ruido. Es el mismo modo de falla que `packs/load-testing/` cierra para k6 y
`packs/gherkin/` para Cucumber: **verde sobre nada**.

## La única comprobación que prueba algo: la canary

Todo lo demás es inferencia. `sentry-check canary` envía un evento con un
marcador único y después **le pregunta a la API si quedó almacenado**. Si no
puede confirmarlo, sale con código 2 (`UNCONFIRMED`) y bloquea.

Es deliberado que aceptar no sea suficiente. La ingesta de Sentry responde `200`
y descarta el evento después si la cuota está agotada, si un filtro de entrada lo
descarta o si el rate limit se disparó. Una compuerta que se conforma con el
`200` reporta verde exactamente en el escenario que más importa.

## La regla que gobierna las comprobaciones opinadas

Una capacidad se puede apagar, pero **hay que apagarla en voz alta**. El tracing
en cero pasa sólo con `SENTRY_TRACING_ACKNOWLEDGED=true`; el envío de PII sólo
con `SENTRY_PII_ACKNOWLEDGED=true`. Un default que desactiva medio producto en
silencio es exactamente cómo se degrada la observabilidad: nadie decidió
apagarlo, simplemente nunca se encendió.

## Contenido

```text
bin/sentry-check                       La compuerta. Fail-closed.
bin/sentry-heartbeat                   Envuelve un cron para que Sentry note si deja de correr
bin/sentry-to-issues                   Abre un issue de GitHub por cada issue sin resolver
instrumentation.ts                     register() + onRequestError (errores de servidor)
instrumentation-client.ts              Navegador: replay, tracing de navegación
sentry.server.config.ts                Runtime Node
sentry.edge.config.ts                  Runtime edge (middleware) — no hereda del server
.github/workflows/observability.yml    Corre la compuerta tras un deploy exitoso
```

### Variables

El pack **no** incluye un `.env.sentry.example`: las reglas de permisos de un
agente bien configurado bloquean la escritura de archivos `.env*`, y así debe
ser. Créalo a mano en el repositorio destino con este contenido:

```bash
# Identidad del proyecto. El DSN es público por diseño: viaja en el bundle.
#   https://<publicKey>@o<orgId>.ingest.<region>.sentry.io/<projectId>
NEXT_PUBLIC_SENTRY_DSN=

# Para leer los eventos de vuelta. Scopes: project:read, project:releases, org:read.
SENTRY_ORG=
SENTRY_PROJECT=
SENTRY_AUTH_TOKEN=

# Separa preview de producción, o en dos semanas apagas las alertas.
SENTRY_ENVIRONMENT=production

# 0 descarta todo en silencio: la compuerta lo bloquea a propósito.
SENTRY_SAMPLE_RATE=1

# Sin trazas, un error no te dice qué consulta lo causó.
SENTRY_TRACES_SAMPLE_RATE=0.2

# Las sesiones CON error son las únicas que alguien mira: déjalo en 1.
SENTRY_REPLAYS_SESSION_SAMPLE_RATE=0.1
SENTRY_REPLAYS_ON_ERROR_SAMPLE_RATE=1

# sendDefaultPii envía cabeceras, cookies e IPs. Con datos de cliente, es una fuga.
SENTRY_SEND_DEFAULT_PII=false
SENTRY_PII_ACKNOWLEDGED=false

# El monitor que vigila tu trabajo programado.
SENTRY_MONITOR_SLUG=

# Umbrales de las compuertas.
SENTRY_CANARY_TIMEOUT=60
SENTRY_MIN_CRASH_FREE_RATE=99
```

`SENTRY_AUTH_TOKEN` es un secreto real. El DSN no lo es —va en el bundle del
navegador—, pero el token sube source maps y lee tu organización: va al llavero
o a los secretos del repositorio, nunca al control de versiones.

## Uso

```bash
bin/sentry-check preflight            # estático; antes de desplegar
bin/sentry-check canary               # envía un evento y confirma que se almacenó
bin/sentry-check release v1.2.3       # source maps + commits asociados
bin/sentry-check health v1.2.3        # tasa de sesiones sin fallo del release
bin/sentry-check cron nightly-backup  # el trabajo programado sigue reportando
bin/sentry-check triage               # issues sin resolver, como candidatos de backlog
bin/sentry-check all v1.2.3           # preflight + canary + release + health

bin/sentry-heartbeat nightly-backup -- pg_dump ...   # envuelve un cron

bin/sentry-to-issues            # dry run: imprime el plan, no crea nada
bin/sentry-to-issues --apply    # abre los issues de GitHub que falten
```

### El puente al backlog

`triage` te dice qué está roto; `sentry-to-issues` hace que eso llegue a donde el
próximo clock-in lo va a leer. Abre un issue de GitHub por cada issue sin
resolver de Sentry, y de ahí entra a `feature_list.json` como cualquier otra
feature — con lo que la señal de producción deja de morir en un correo.

Dos propiedades lo hacen seguro de programar:

- **Las escrituras son opt-in.** Sin `--apply` no crea nada e imprime el plan.
  Crear issues es un efecto sobre una superficie compartida, y una herramienta
  que lo hace por defecto se ejecuta una vez por accidente y después nadie
  vuelve a confiar en ella.
- **Es idempotente por `shortId`.** Un issue ya registrado se salta, buscando en
  abiertos *y* cerrados: un defecto que ya cerraste no reaparece como nuevo en la
  siguiente corrida. Sin esto, ponerlo en un cron produce cien duplicados del
  mismo error.

### Lo que cada comprobación cierra

| Comando | El fallo silencioso que impide |
|---|---|
| `preflight` | DSN vacío o de ejemplo, muestreo en 0, tracing apagado sin querer, PII saliendo sin que nadie lo decidiera, `onRequestError` ausente, entorno sin separar |
| `canary` | Un pipeline que acepta con `200` y descarta después: cuota, filtro de entrada, rate limit |
| `release` | Trazas minificadas ilegibles, y releases sin commits: sin ellos Sentry nunca nombra el cambio que rompió algo |
| `health` | Un despliegue que degradó la estabilidad y nadie miró el número |
| `cron` | **Un trabajo programado que dejó de correr.** No produce errores: produce silencio, y el silencio no dispara alertas |
| `triage` | Una cola de issues que nadie lee — equivalente a no monitorear |

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Todas las comprobaciones pedidas pasaron |
| `1` | Una comprobación falló: hay una mala configuración |
| `2` | `UNCONFIRMED` — no se pudo probar que los eventos llegan |
| `3` | Respuesta ilegible, o falta una entrada obligatoria |
| `64` | Error de uso |
| `69` | Falta una dependencia en el `PATH` |

El `2` está separado del `1` a propósito: «falló una comprobación» y «no pude
comprobar nada» son diagnósticos distintos, y confundirlos es cómo una compuerta
termina reportando verde sobre nada. Ambos bloquean.

## Instrumentación de Next.js

El pack comprueba la instrumentación, no la instala. Lo mínimo para que los
errores de servidor lleguen a Sentry (App Router, `@sentry/nextjs`):

```typescript
// instrumentation.ts
import * as Sentry from "@sentry/nextjs";

export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./sentry.server.config");
  }
  if (process.env.NEXT_RUNTIME === "edge") {
    await import("./sentry.edge.config");
  }
}

// Sin esta línea, los errores de servidor nunca se capturan. El preflight la exige.
export const onRequestError = Sentry.captureRequestError;
```

Más `instrumentation-client.ts` para el navegador y `sentry.server.config.ts` /
`sentry.edge.config.ts` con el `Sentry.init({ dsn })` correspondiente.

## Verificar el pack

```bash
bash packs/sentry/verify-pack.sh   # 55 modos de falla, todos deben bloquear
```

Las respuestas se sintetizan en vez de pedirse a la red, así que el pack se
verifica en cualquier máquina con `bash`: sin cuenta de Sentry, sin token, sin
red. `SENTRY_STUB_DIR` es la costura de prueba que lo permite; un fixture ausente
significa «la llamada falló», que es justo lo que la compuerta debe sobrevivir
cuando Sentry no responde.

La ruta viva la ejerce `bin/sentry-check` en cuanto el proyecto tiene un DSN real.

## Por qué está en el kit

Cierra la parte del ciclo que terminaba en «merge a main». Con este pack, una
alerta de producción se convierte en issue, el issue entra a `feature_list.json`
y el siguiente clock-in lo recoge: la señal de producción vuelve al backlog en
vez de morir en un correo. En el catálogo de DORA son dos capacidades —
*monitoring and observability* y *proactive failure notification* — y son la
condición para poder medir las cuatro métricas de entrega.
