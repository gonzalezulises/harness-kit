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

## Contenido

```text
bin/sentry-check                       La compuerta. Fail-closed.
.github/workflows/observability.yml    Corre la compuerta tras un deploy exitoso
```

### Variables

Crea `.env.sentry.example` en el repositorio destino con este contenido (no se
incluye como archivo en el pack: los archivos `.env*` suelen estar bloqueados por
las reglas de permisos del agente, y así debe ser):

```bash
# El DSN identifica el proyecto que recibe los eventos. Es público por diseño:
# viaja en el bundle del navegador.
#   https://<publicKey>@o<orgId>.ingest.<region>.sentry.io/<projectId>
NEXT_PUBLIC_SENTRY_DSN=

# Necesarios para leer el evento de vuelta y confirmar que llegó.
# El token necesita scope project:read (y project:releases para source maps).
SENTRY_ORG=
SENTRY_PROJECT=
SENTRY_AUTH_TOKEN=

# 0 descarta todo en silencio: la compuerta lo bloquea a propósito.
SENTRY_SAMPLE_RATE=1

# La ingesta no es instantánea; por debajo de ~30 s tendrás falsos rojos.
SENTRY_CANARY_TIMEOUT=60
```

`SENTRY_AUTH_TOKEN` es un secreto real. El DSN no lo es —va en el bundle del
navegador—, pero el token sube source maps y lee tu organización: va al llavero
o a los secretos del repositorio, nunca al control de versiones.

## Uso

```bash
bin/sentry-check preflight        # estático; antes de desplegar
bin/sentry-check canary           # envía un evento y confirma que se almacenó
bin/sentry-check release v1.2.3   # confirma que el release tiene source maps
bin/sentry-check all v1.2.3       # los tres
```

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
bash packs/sentry/verify-pack.sh   # 21 modos de falla, todos deben bloquear
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
