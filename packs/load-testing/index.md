# Pack de Rendimiento (k6)

Este pack añade una compuerta de rendimiento a cualquier repositorio: un smoke
determinista que puede bloquear una fusión, una prueba de carga a demanda que
produce evidencia para el paquete de entrega, y una línea base que detecta
degradación entre versiones.

Usa este pack cuando entregues software a un cliente y necesites poder afirmar
—con evidencia y no con confianza— que la aplicación responde.

## El problema que resuelve

Medir el rendimiento es fácil. Medir el rendimiento *de la aplicación correcta*
es donde falla el 90 % de los primeros intentos, y falla en verde:

| Situación | Qué mide k6 sin protección | Qué reporta |
|---|---|---|
| Preview de Vercel con Deployment Protection | La pantalla de autenticación de Vercel | Latencias excelentes |
| Cloud Run detrás de IAP sin token | La redirección a `accounts.google.com` | Latencias excelentes |
| Token de IAP con audience equivocado | Un `401` servido en milisegundos | Latencias excelentes |
| El script de prueba tiene un error de runtime | Nada | **Éxito, código de salida 0** |

Las cuatro filas producen reportes verdes sobre aplicaciones que nunca se
ejecutaron. Ese es el modo de falla que este pack existe para cerrar.

## Hallazgos medidos (k6 v2.1.0, agosto 2026)

Estos comportamientos se verificaron ejecutando k6, no leyendo su documentación:

| Caso | Código de salida |
|---|---|
| Todos los umbrales cumplidos | `0` |
| Un umbral incumplido | `99` |
| `exec.test.abort()` | `108` |
| **Error de runtime en la función por defecto** | **`0`** |

La última fila es la importante: un script roto sale con éxito. Además:

- Un umbral `checks: ['rate==1.0']` **no** detecta el script roto: una métrica sin
  muestras se evalúa como aprobada.
- El contador de iteraciones tampoco: reporta las iteraciones como completadas
  aunque todas hayan fallado.
- Lo que sí lo detecta es un contador propio con umbral de cuenta **absoluta**
  (`count>=N`). Si el script se rompe, el contador queda en cero y el umbral
  falla. Es la razón de existir de `perf_completed` en `lib/metrics.js`.

También cambió la interfaz: `--no-summary` ya no existe en k6 v2; su reemplazo es
`--summary-mode disabled`. Un gate copiado de un tutorial anterior a v2 falla al
arrancar.

## Diseño de inicio incluido

```text
tests/load/
├── lib/
│   ├── abort.js      Aborta con motivo (módulo propio: rompe un ciclo de importación)
│   ├── target.js     Resuelve objetivo y credenciales; aborta si faltan
│   ├── session.js    Sesión de usuario final (Supabase) y su cookie
│   ├── guard.js      Prueba que respondió la aplicación real, no un login
│   ├── metrics.js    Umbrales y el detector de scripts rotos
│   └── summary.js    Evidencia en Markdown desde el resumen de k6
├── smoke.js          1 usuario virtual, determinista. Bloqueante.
├── load.js           Rampa de usuarios virtuales. Evidencia, no compuerta.
├── baseline.json     Línea base aprobada (la crea perf-check)
└── results/          Resúmenes y reportes generados (ignóralo en git)

bin/perf-discover         Sondea la app corriendo y dice QUÉ se puede medir
bin/perf-init.sh          Instalador: archivos, variables y regla de rama
bin/perf-check            El verificador. Fail-closed.
bin/perf-resolve-target   Encuentra la vista previa de un commit, o nada
.github/workflows/perf.yml
.env.perf.example
```

## Los dos niveles, y por qué están separados

**Smoke — bloqueante.** Un usuario virtual, iteraciones fijas. No mide capacidad:
prueba que las rutas críticas responden y que la latencia no se desplomó. Es
determinista, y por eso puede bloquear una fusión.

**Carga — a demanda, nunca bloqueante.** Rampa de usuarios virtuales. No es
determinista: los arranques en frío de funciones sin servidor y la CPU compartida
de un ejecutor mueven el p(95) entre corridas. Meterla en la ruta de fusión
produce falsas alarmas, y una compuerta que da falsas alarmas se desactiva en dos
semanas. Su salida es evidencia de entrega.

## Primero averigua qué se puede medir

Antes de configurar nada, levanta la aplicación y sondéala:

```sh
bin/perf-discover http://127.0.0.1:3000
```

Clasifica cada ruta en cuatro grupos y propone la configuración:

| Grupo | Qué significa |
|---|---|
| MEDIBLES | Sirven contenido real. Son las que valen. |
| REQUIEREN SESIÓN | Redirigen al login: sin autenticarse, medirlas mide redirecciones. |
| ARMAZÓN DE CLIENTE | Responden 200 pero su texto visible es un cargador. Medirlas da un p(95) excelente sobre una página vacía. |
| ERRORES | 401, 404, 500. |

Este paso no es opcional en la práctica. Al aplicarlo a un proyecto real
(Next.js con Supabase, 36 rutas) el resultado fue: 27 rutas exigían sesión, una
servía un armazón cuyo texto visible completo era `"Comparador de Precios —
Casabat Cargando…"`, y sólo dos eran medibles sin autenticarse. Configurar la
compuerta a ojo habría medido el armazón y reportado un verde sin significado.

El marcador que propone se auto-verifica: sólo sugiere una frase que existe
literalmente en el cuerpo servido por la ruta del guard. Un marcador inventado
haría abortar la compuerta en su primera corrida.

## Cómo adoptarlo

Instala k6 una vez (`brew install k6`) y luego, desde la raíz del repositorio
destino:

```sh
# Simula: muestra cada acción sin cambiar nada
bash ~/GitHub/harness-kit/packs/load-testing/repo-template/bin/perf-init.sh \
  --dry-run --account <tu-cuenta> --marker '<texto que sólo exista en tu app>'

# Aplica
bash ~/GitHub/harness-kit/packs/load-testing/repo-template/bin/perf-init.sh \
  --account <tu-cuenta> --marker '<texto que sólo exista en tu app>'
```

El instalador copia los archivos, actualiza `.gitignore`, detecta el stack y las
rutas (en Next.js App Router las deduce de `app/**/page.tsx`), define las
variables del repositorio y registra el check `smoke` como requerido. Es
idempotente y no sobrescribe sin `--force`.

`--account` importa cuando tienes varias cuentas de GitHub autenticadas: **la
cuenta que responde a la API no siempre es la que `gh auth status` marca como
activa**. Configurar el repositorio equivocado en silencio es peor que no
configurar nada, así que el instalador declara con qué cuenta opera y verifica que
tenga permiso de administración antes de intentar nada.

Después de instalar, establece la referencia local:

```sh
PERF_TARGET=http://127.0.0.1:3000 bin/perf-check smoke
PERF_TARGET=http://127.0.0.1:3000 bin/perf-check smoke --update-baseline
```

`tests/load/baseline.json` se comitea; `tests/load/results/` y `.env.perf` no.

## Por qué el disparador es pull_request y no deployment_status

Un check que sólo corre cuando existe un despliegue **no se puede exigir**. Si se
marca como requerido, cualquier pull request que no genere vista previa —un cambio
de documentación, de configuración, del propio workflow— queda bloqueado para
siempre esperando un check que nunca va a reportar, y la única salida es
desactivar la regla.

Con `pull_request` el trabajo corre siempre. `bin/perf-resolve-target` busca la
vista previa del commit y, si no aparece, el trabajo lo dice y aprueba: no medir
no es lo mismo que medir mal. Eso es lo que lo hace seguro de exigir.

## Medir rutas detrás del login de la aplicación

`guard.js` cubre autenticación de *plataforma* (IAP, protección de despliegue).
Cuando lo que exige sesión es la *aplicación*, se usa `PERF_AUTH=supabase`:

```sh
PERF_AUTH=supabase
PERF_SUPABASE_URL=https://<ref>.supabase.co
PERF_SUPABASE_ANON_KEY=<clave anónima, es pública por diseño>
PERF_USER_EMAIL=usuario-de-prueba@…
PERF_USER_PASSWORD=…        # en .env.perf o en secretos de CI, NUNCA en el repo
```

El pack inicia sesión contra `/auth/v1/token?grant_type=password`, construye la
cookie que espera `@supabase/ssr` y la envía en cada petición. Tres detalles que
se leyeron del paquete instalado y no de la documentación, porque asumirlos
rompe la sesión en silencio:

1. La cookie se llama `sb-<project-ref>-auth-token`.
2. Su valor es `"base64-"` + el JSON de la sesión en base64**url**.
3. `stringToBase64URL` **no** emite relleno `=`. En k6 eso es
   `b64encode(s, 'rawurl')`; con `'url'` se añade relleno y el servidor descarta
   la cookie como corrupta.

Usa siempre un usuario de PRUEBA con datos de prueba. Nunca uno real del
cliente: la prueba de carga genera cientos de peticiones autenticadas como ese
usuario.

Como la autenticación es una petición HTTP y k6 las prohíbe en el contexto de
inicialización, la sesión se obtiene en `setup()`. El guard corre después, ya
con la sesión puesta.

## Límite de plataforma: dónde puede bloquear de verdad

Exigir un check requiere conjuntos de reglas, y GitHub no los ofrece en
repositorios privados de cuentas Free. Verificado creando y borrando reglas reales
(agosto 2026):

| Repositorio | ¿Puede bloquear la fusión? |
|---|---|
| Público, cuenta personal | Sí |
| **Privado, cuenta personal (Free)** | **No** — `403 Upgrade to GitHub Pro` |
| De una organización con plan de pago | Sí |

En un repositorio privado de cuenta Free la compuerta **queda instalada y
corriendo**: el check aparece en cada pull request y su evidencia se publica como
artefacto. Lo único que no puede hacer es impedir la fusión. Para que bloquee:
mover el repositorio a una organización con plan, activar GitHub Pro, o hacerlo
público. El instalador detecta el caso y lo dice en lugar de fingir que quedó
configurado.

## Integración con el resto del harness

**Con `make check`** (repositorios que usan este kit): añade `bin/perf-check smoke`
como capa de runtime de la feature correspondiente. Requiere que la aplicación
esté levantada, así que va después de los pasos estáticos.

**Con `.factory/quality`** (repositorios gobernados por la Fábrica de Software):
añádelo como comando requerido. El contrato de la Fábrica exige que el
descubrimiento vacío cuente como falla, y `perf-check` ya lo hace: si no hay
resumen, o el resumen no reporta iteraciones completadas, sale distinto de cero.

**Con la línea base de deriva:** `baseline.json` se comitea. Una degradación por
encima de `PERF_DRIFT_PCT` bloquea, y aprobarla es un acto explícito
(`--update-baseline`) que queda en el historial de git. Así una degradación
aceptada es una decisión registrada y no un olvido.

## Advertencia sobre objetivos de producción

No ejecutes el perfil de carga contra el entorno de producción de un cliente sin
autorización por escrito. Genera tráfico facturable, puede disparar límites de
tasa y en varias plataformas contradice los términos de servicio. El objetivo
correcto es un entorno de preparación o un despliegue de vista previa.

## Lo que este pack NO hace

- No mide rendimiento percibido en el navegador (Core Web Vitals, LCP, CLS). k6
  mide el lado del servidor; para el lado del cliente hacen falta otras
  herramientas.
- No prueba caminos autenticados por usuario final. El guard verifica
  autenticación de *plataforma*; una sesión de usuario dentro de la aplicación es
  un problema distinto.
- No sustituye monitoreo en producción. Una compuerta mide antes de entregar;
  saber qué pasa después necesita observabilidad.
