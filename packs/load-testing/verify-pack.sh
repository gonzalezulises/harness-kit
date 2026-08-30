#!/usr/bin/env bash
# Verificador del pack de rendimiento.
#
# Reproduce cada modo de falla contra servidores locales y comprueba que la
# compuerta bloquea. Existe porque "verifiqué que funciona" no es repetible:
# esto sí lo es, y corre en cualquier máquina con k6 y python3.
#
# Uso:  bash packs/load-testing/verify-pack.sh
# Sale 0 sólo si los diez casos se comportan como se espera.
#
# Compatible con bash 3.2: sin arreglos asociativos.

set -uo pipefail

PACK_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="${PACK_DIR}/repo-template"
WORK="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
  if [ -n "${SERVER_PIDS:-}" ]; then
    # El aviso "Terminated" del control de trabajos ensucia la salida del
    # verificador, así que se silencia junto con la espera.
    kill $SERVER_PIDS 2>/dev/null
    wait $SERVER_PIDS 2>/dev/null
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
# Failures repeat in the final summary: CI's claims runner only shows the tail
# of a failed layer, so a failure named only mid-run is a failure named never.
FALLAS=()
falla() { say "  FALLA $*"; FALLAS+=("$*"); }

# Comprueba que un caso produce el código de salida esperado y, opcionalmente,
# que su salida contiene un texto concreto.
expect() {
  local label="$1" want_code="$2" want_text="$3"
  shift 3
  local out code
  out=$(cd "$WORK/fixture" && env "$@" bin/perf-check "$PROFILE" 2>&1)
  code=$?

  local ok=1
  if [ "$want_code" = "zero" ]; then
    [ "$code" -eq 0 ] || ok=0
  else
    [ "$code" -ne 0 ] || ok=0
  fi
  if [ -n "$want_text" ] && ! printf '%s' "$out" | grep -q "$want_text"; then
    ok=0
  fi

  if [ "$ok" -eq 1 ]; then
    say "  ok   $label"
    PASS=$((PASS + 1))
  else
    falla "$label"
    say "       código=$code (esperado: $want_code)"
    [ -n "$want_text" ] && say "       se esperaba encontrar: $want_text"
    printf '%s\n' "$out" | sed 's/^/       | /'
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Requisitos
# ---------------------------------------------------------------------------

if ! command -v k6 >/dev/null 2>&1; then
  say "verify-pack: k6 no está instalado; no se puede verificar el pack."
  say "             Instálalo con 'brew install k6'."
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { say "verify-pack: falta python3"; exit 1; }

say "verify-pack: k6 $(k6 version | head -1)"
say ""

# ---------------------------------------------------------------------------
# Capa estática
# ---------------------------------------------------------------------------

say "1. sintaxis"
if bash -n "${TEMPLATE}/bin/perf-check"; then
  say "  ok   bin/perf-check es bash válido"
  PASS=$((PASS + 1))
else
  falla "bin/perf-check tiene un error de sintaxis"
  FAIL=$((FAIL + 1))
fi

# El verificador no debe contener NINGÚN escape de código de salida, ni siquiera
# uno inofensivo: un lector no puede distinguirlos, y la credibilidad de la
# compuerta depende de que no haya ambigüedad en este archivo.
# Se excluyen los comentarios: el archivo advierte por escrito contra `|| true`,
# y esa advertencia no debe contar como una infracción.
if grep -vE '^[[:space:]]*#' "${TEMPLATE}/bin/perf-check" \
   | grep -qE '\|\|[[:space:]]*true|\|\|[[:space:]]*:|continue-on-error'; then
  falla "bin/perf-check contiene un escape que anula el código de salida"
  FAIL=$((FAIL + 1))
else
  say "  ok   bin/perf-check no anula códigos de salida"
  PASS=$((PASS + 1))
fi

if command -v node >/dev/null 2>&1; then
  js_ok=1
  for f in "${TEMPLATE}"/tests/load/*.js "${TEMPLATE}"/tests/load/lib/*.js; do
    # k6 scripts are ESM; --input-type=module keeps the parse mode explicit so
    # the check does not depend on the Node version's module auto-detection.
    node --input-type=module --check < "$f" 2>/dev/null || { falla "sintaxis JS en $f"; js_ok=0; }
  done
  if [ "$js_ok" -eq 1 ]; then
    say "  ok   los scripts de k6 son JS válido"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
fi

# ---------------------------------------------------------------------------
# Entorno de prueba
# ---------------------------------------------------------------------------

mkdir -p "$WORK/fixture"
cp -R "${TEMPLATE}/tests" "$WORK/fixture/"
cp -R "${TEMPLATE}/bin" "$WORK/fixture/"
chmod +x "$WORK/fixture/bin/perf-check"

cat > "$WORK/server.py" <<'PY'
import sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
MODE, PORT = sys.argv[1], int(sys.argv[2])
MARKER = "PACK-VERIFY-APP"
APP = f'<!doctype html><html><body><div data-app="{MARKER}">ok</div></body></html>'
LOGIN = '<!doctype html><html><body><h1>Sign in to continue</h1></body></html>'
# Armazón que hidrata en el cliente: su texto visible completo es un cargador.
SHELL = '<!doctype html><html><head><title>Panel</title></head><body><div id="app">Cargando…</div></body></html>'
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def _s(self, status, body, extra=None):
        p = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(p)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(p)
    def do_GET(self):
        if MODE == "healthy": self._s(200, APP)
        elif MODE == "redirect-login":
            self._s(302, "", {"Location": "https://accounts.google.com/ServiceLogin"})
        elif MODE == "login-200": self._s(200, LOGIN)
        elif MODE == "shell": self._s(200, SHELL)
        elif MODE == "slow":
            time.sleep(0.35); self._s(200, APP)
        elif MODE == "unauthorized": self._s(401, "no")
        else: self._s(500, "?")
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

SERVER_PIDS=""
start_server() {
  python3 "$WORK/server.py" "$1" "$2" >/dev/null 2>&1 &
  SERVER_PIDS="$SERVER_PIDS $!"
}
start_server healthy 18801
start_server redirect-login 18802
start_server login-200 18803
start_server slow 18804
start_server unauthorized 18805
start_server shell 18806
sleep 2

MARKER=PACK-VERIFY-APP
PROFILE=smoke

say ""
say "2. la compuerta aprueba cuando debe"
expect "app sana con marcador aprueba" zero "APROBADO" \
  PERF_TARGET=http://127.0.0.1:18801 PERF_APP_MARKER=$MARKER PERF_P95_MS=2000

say ""
say "3. la compuerta bloquea el falso verde"
expect "redirección a pantalla de autenticación" nonzero "pantalla de autenticación" \
  PERF_TARGET=http://127.0.0.1:18802 PERF_AUTH=iap PERF_IAP_TOKEN=x PERF_APP_MARKER=$MARKER
expect "200 sin el marcador de la aplicación" nonzero "PERF_APP_MARKER" \
  PERF_TARGET=http://127.0.0.1:18803 PERF_AUTH=iap PERF_IAP_TOKEN=x PERF_APP_MARKER=$MARKER
expect "objetivo autenticado sin marcador declarado" nonzero "exige PERF_APP_MARKER" \
  PERF_TARGET=http://127.0.0.1:18803 PERF_AUTH=iap PERF_IAP_TOKEN=x
expect "credencial rechazada con 401" nonzero "rechazó la credencial" \
  PERF_TARGET=http://127.0.0.1:18805 PERF_AUTH=bearer PERF_BEARER=x PERF_APP_MARKER=$MARKER
expect "credencial ausente para el modo declarado" nonzero "PERF_IAP_TOKEN" \
  PERF_TARGET=http://127.0.0.1:18801 PERF_AUTH=iap PERF_APP_MARKER=$MARKER
expect "PERF_TARGET sin definir" nonzero "PERF_TARGET" \
  PERF_APP_MARKER=$MARKER

say ""
say "4. la compuerta bloquea por umbral y por deriva"
expect "umbral de latencia incumplido" nonzero "umbral" \
  PERF_TARGET=http://127.0.0.1:18804 PERF_APP_MARKER=$MARKER PERF_P95_MS=50

# Línea base tomada del servidor rápido, medida contra el lento: con el umbral
# holgado, sólo la deriva puede bloquear.
( cd "$WORK/fixture" && env PERF_TARGET=http://127.0.0.1:18801 \
    PERF_APP_MARKER=$MARKER PERF_P95_MS=2000 bin/perf-check smoke --update-baseline ) >/dev/null 2>&1
expect "degradación frente a la línea base" nonzero "se degradó" \
  PERF_TARGET=http://127.0.0.1:18804 PERF_APP_MARKER=$MARKER PERF_P95_MS=2000
rm -f "$WORK/fixture/tests/load/baseline.json"

say ""
say "5. la compuerta bloquea un script roto"
# Éste es el caso central: k6 por sí solo sale con 0 ante un error de runtime.
cp "$WORK/fixture/tests/load/smoke.js" "$WORK/smoke.orig"
python3 - "$WORK/fixture/tests/load/smoke.js" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("  markCompleted();", "  funcionInexistente();\n  markCompleted();")
open(p, 'w').write(s)
PY
expect "error de runtime en el script no aprueba" nonzero "" \
  PERF_TARGET=http://127.0.0.1:18801 PERF_APP_MARKER=$MARKER PERF_P95_MS=2000
cp "$WORK/smoke.orig" "$WORK/fixture/tests/load/smoke.js"

say ""
say "6. la compuerta bloquea sin evidencia"
# Un resumen ausente debe bloquear en lugar de asumir éxito. Se prueba con un
# smoke.js sin handleSummary: la corrida es válida y sus umbrales pasan, pero no
# deja evidencia. El perfil sigue siendo "smoke" porque perf-check sólo acepta
# perfiles conocidos, y esa lista blanca es parte del diseño.
cat > "$WORK/fixture/tests/load/smoke.js" <<'JS'
import http from 'k6/http';
import { resolveTarget } from './lib/target.js';
import { assertRealApp } from './lib/guard.js';
import { markCompleted, buildThresholds } from './lib/metrics.js';
const target = resolveTarget();
export const options = { vus: 1, iterations: 1, thresholds: buildThresholds({ expectedIterations: 1 }) };
export function setup() { return assertRealApp(target); }
export default function () {
  http.get(target.base, { headers: target.headers });
  markCompleted();
}
JS
expect "corrida sin resumen no aprueba" nonzero "evidencia" \
  PERF_TARGET=http://127.0.0.1:18801 PERF_APP_MARKER=$MARKER PERF_P95_MS=2000
cp "$WORK/smoke.orig" "$WORK/fixture/tests/load/smoke.js"

# ---------------------------------------------------------------------------
# Instalador y resolución del objetivo
# ---------------------------------------------------------------------------

check() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    say "  ok   $label"
    PASS=$((PASS + 1))
  else
    falla "$label"
    say "       condición: $condition"
    FAIL=$((FAIL + 1))
  fi
}

say ""
say "7. el instalador instala y no pisa"

TARGET_REPO="$WORK/target"
mkdir -p "$TARGET_REPO"
( cd "$TARGET_REPO" && git init --quiet && git config user.email t@t && git config user.name t ) >/dev/null 2>&1

# Simulación: debe describir sin cambiar nada.
( cd "$TARGET_REPO" && bash "${TEMPLATE}/bin/perf-init.sh" --dry-run --no-ci \
    --from "$TEMPLATE" ) >"$WORK/init-dry.log" 2>&1
check "--dry-run no crea archivos" "[ ! -e '$TARGET_REPO/tests/load/smoke.js' ]"
check "--dry-run describe lo que haría" "grep -q 'haría' '$WORK/init-dry.log'"

# Instalación real.
( cd "$TARGET_REPO" && bash "${TEMPLATE}/bin/perf-init.sh" --no-ci \
    --from "$TEMPLATE" ) >"$WORK/init-real.log" 2>&1
check "instala los escenarios de k6" "[ -f '$TARGET_REPO/tests/load/smoke.js' ]"
check "instala el verificador ejecutable" "[ -x '$TARGET_REPO/bin/perf-check' ]"
check "instala el resolvedor de objetivo" "[ -f '$TARGET_REPO/bin/perf-resolve-target' ]"
check "instala el flujo de CI" "[ -f '$TARGET_REPO/.github/workflows/perf.yml' ]"
check "ignora .env.perf" "grep -qxF '.env.perf' '$TARGET_REPO/.gitignore'"
check "ignora el directorio de resultados" "grep -qxF 'tests/load/results/' '$TARGET_REPO/.gitignore'"

# La línea base NO debe ignorarse: su historial es el registro de las
# degradaciones aceptadas.
check "no ignora la línea base" "! grep -q 'baseline.json' '$TARGET_REPO/.gitignore'"

# Idempotencia: una segunda corrida no debe duplicar entradas ni pisar cambios.
printf '// marca local\n' >> "$TARGET_REPO/tests/load/smoke.js"
( cd "$TARGET_REPO" && bash "${TEMPLATE}/bin/perf-init.sh" --no-ci \
    --from "$TEMPLATE" ) >"$WORK/init-again.log" 2>&1
IGNORE_COUNT=$(grep -cxF '.env.perf' "$TARGET_REPO/.gitignore")
check "segunda corrida no duplica .gitignore" "[ '$IGNORE_COUNT' -eq 1 ]"
check "segunda corrida no pisa sin --force" "grep -q 'marca local' '$TARGET_REPO/tests/load/smoke.js'"

# Un repositorio sin remoto no puede configurar CI, y debe decirlo en lugar de
# intentarlo y fallar a medias.
check "sin remoto, informa que omite CI" "grep -qi 'sin remoto' '$WORK/init-real.log'"

# Detección de rutas en Next.js App Router. El sed de macOS no admite `\?` como
# cuantificador, y con BRE las rutas salían como "/ahorro/page.tsx".
ROUTE_REPO="$WORK/routes"
mkdir -p "$ROUTE_REPO/app/ahorro" "$ROUTE_REPO/app/calidad/auditoria" "$ROUTE_REPO/app/item/[id]"
( cd "$ROUTE_REPO" && git init --quiet && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '{"dependencies":{"next":"16"}}\n' > "$ROUTE_REPO/package.json"
for p in app/page.tsx app/ahorro/page.tsx app/calidad/auditoria/page.tsx 'app/item/[id]/page.tsx'; do
  touch "$ROUTE_REPO/$p"
done
( cd "$ROUTE_REPO" && bash "${TEMPLATE}/bin/perf-init.sh" --dry-run --no-ci \
    --from "$TEMPLATE" ) >"$WORK/routes.log" 2>&1
check "detecta el stack Next.js" "grep -q 'stack: next.js' '$WORK/routes.log'"
check "las rutas no conservan page.tsx" "! grep -q 'page.tsx' '$WORK/routes.log'"
check "detecta una ruta anidada limpia" "grep -q '/calidad/auditoria' '$WORK/routes.log'"
check "excluye rutas con segmento dinámico" "! grep -q '\[id\]' '$WORK/routes.log'"

# Una respuesta de error de la API no debe interpretarse como "la regla ya existe".
check "sólo un id numérico cuenta como regla existente" \
  "grep -q 'case \"\$EXISTING\" in' '${TEMPLATE}/bin/perf-init.sh'"
check "el límite de plan se reporta de forma específica" \
  "grep -q 'Upgrade to GitHub Pro' '${TEMPLATE}/bin/perf-init.sh'"

# No poder exigir el check es el caso NORMAL en un repositorio privado de una
# cuenta Free. La instalación debe completarse y salir 0: si abortara, el modo
# "corre y publica evidencia, pero no bloquea" sería inusable.
bash "${TEMPLATE}/bin/perf-init.sh" --dry-run --no-ci --from "$TEMPLATE" \
  >/dev/null 2>&1 <<<""
INIT_CODE=$?
check "el instalador sale 0 cuando no configura CI" "[ '$INIT_CODE' -eq 0 ]"
check "no usa set -e (un fallo de gh no debe matar la instalación)" \
  "! grep -qE '^set -[a-z]*e' '${TEMPLATE}/bin/perf-init.sh'"
# shellcheck disable=SC2034  # se expande dentro del string que check() evalúa
PLAN_BRANCH="$(grep -A9 'Upgrade to GitHub Pro' '${TEMPLATE}/bin/perf-init.sh' 2>/dev/null || \
  grep -A9 'Upgrade to GitHub Pro' "${TEMPLATE}/bin/perf-init.sh")"
check "la rama del límite de plan no aborta" \
  "! printf '%s' \"\$PLAN_BRANCH\" | grep -qE '^[[:space:]]*(exit|die)'"

say ""
say "8. el resolvedor distingue 'sin despliegue' de 'error'"

# Sin argumentos: es un error de uso, no un 'no hay despliegue'.
# El código se captura en una variable: dentro de check() ya se habría perdido.
bash "${TEMPLATE}/bin/perf-resolve-target" >/dev/null 2>&1
RESOLVE_NOSHA=$?
check "sin sha devuelve error de uso (2)" "[ '$RESOLVE_NOSHA' -eq 2 ]"

bash "${TEMPLATE}/bin/perf-resolve-target" abc123 >/dev/null 2>&1
RESOLVE_NOREPO=$?
check "sin repositorio devuelve error de uso (2)" "[ '$RESOLVE_NOREPO' -eq 2 ]"

# Un commit sin despliegue debe imprimir nada y salir 0: la compuerta necesita
# poder distinguir "nada que medir" de "falló la consulta".
if command -v gh >/dev/null 2>&1 && gh api user --jq .login >/dev/null 2>&1; then
  RESOLVE_OUT="$(bash "${TEMPLATE}/bin/perf-resolve-target" \
    0000000000000000000000000000000000000000 "$(gh api user --jq .login)/inexistente-$$" 1 1 2>/dev/null)"
  RESOLVE_CODE=$?
  check "commit sin despliegue: salida vacía" "[ -z '$RESOLVE_OUT' ]"
  check "commit sin despliegue: no es un error de rendimiento" "[ '$RESOLVE_CODE' -ne 1 ]"
else
  say "  nota gh no disponible o sin autenticación; casos de red omitidos"
fi

say ""
say "9. el flujo de CI no puede bloquear un pull request para siempre"

WF="${TEMPLATE}/.github/workflows/perf.yml"
# Un check exigible tiene que reportar SIEMPRE. Si el disparador fuese sólo
# deployment_status, un pull request sin despliegue nunca recibiría el check y
# quedaría imposible de fusionar.
check "el flujo se dispara con pull_request" "grep -q '^  pull_request:' '$WF'"
check "no depende de deployment_status" "! grep -q 'deployment_status:' '$WF'"
check "hay una rama explícita para 'sin despliegue'" "grep -q \"steps.target.outputs.url == ''\" '$WF'"
check "el paso de medición sólo corre con objetivo" "grep -q \"steps.target.outputs.url != ''\" '$WF'"
# Se excluyen los comentarios: el archivo advierte por escrito contra
# continue-on-error, y esa advertencia no es una infracción.
grep -vE '^[[:space:]]*#' "$WF" > "$WORK/wf-nocomments.yml"
check "no hay continue-on-error en el flujo" "! grep -q 'continue-on-error' '$WORK/wf-nocomments.yml'"

if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml" 2>/dev/null; then
    python3 -c "
import yaml, sys
d = yaml.safe_load(open('$WF'))
on = d.get(True) or d.get('on')
assert 'pull_request' in on, 'falta el disparador pull_request'
assert 'deployment_status' not in on, 'deployment_status haría el check no exigible'
assert set(d['jobs']) == {'smoke', 'load'}, d['jobs'].keys()
" 2>/dev/null
    check "el YAML es válido y declara los dos trabajos" "[ \$? -eq 0 ]"
  fi
fi


say ""
say "10. la sesión de usuario final (Supabase)"

# Sin las variables, debe abortar y no medir. Se comprueba el mensaje porque el
# valor de este modo está en decir QUÉ falta.
bash -c "cd '$WORK/fixture' && PERF_TARGET=http://127.0.0.1:18801 PERF_AUTH=supabase \
  PERF_APP_MARKER=$MARKER bin/perf-check smoke" >"$WORK/supa.log" 2>&1
SUPA_CODE=$?
check "sin credenciales no mide" "[ '$SUPA_CODE' -ne 0 ]"
check "nombra cada variable que falta" \
  "grep -q 'PERF_SUPABASE_URL' '$WORK/supa.log' && grep -q 'PERF_USER_PASSWORD' '$WORK/supa.log'"

# Formato de la cookie. El servidor hace base64url-decode y JSON.parse, así que
# eso es exactamente lo que se comprueba aquí.
cat > "$WORK/cookie.js" <<'JS'
import encoding from 'k6/encoding';
export const options = { vus: 1, iterations: 1 };
export default function () {
  const s = { access_token: 'tok-áéí-ñ', refresh_token: 'r', expires_at: 1, user: { id: 'u' } };
  console.log('CV=base64-' + encoding.b64encode(JSON.stringify(s), 'rawurl'));
}
JS
k6 run --quiet --summary-mode disabled "$WORK/cookie.js" 2>&1 \
  | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.search(r'msg=\"CV=(.*?)\" source=console', line)
    if m:
        print(m.group(1)); break
" > "$WORK/cookie.txt"

python3 - "$WORK/cookie.txt" <<'PY2'
import base64, json, sys
value = open(sys.argv[1], encoding='utf-8').read().strip()
PREFIX = 'base64-'
assert value.startswith(PREFIX), 'falta el prefijo base64-'
payload = value[len(PREFIX):]
assert '=' not in payload, 'no debe llevar relleno'
assert '+' not in payload and '/' not in payload, 'debe ser alfabeto url-safe'
# El decodificador del servidor tolera la ausencia de relleno; aquí se repone
# para usar la biblioteca estándar.
decoded = base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)).decode('utf-8')
session = json.loads(decoded)
assert session['access_token'] == 'tok-áéí-ñ', 'UTF-8 multibyte corrupto'
assert session['user']['id'] == 'u'
PY2
check "la cookie es base64url sin relleno y se decodifica a JSON" "[ \$? -eq 0 ]"

# El marcador típico lleva espacios; el ejemplo debe advertirlo, porque `source`
# de un valor sin comillas parte la línea y ejecuta la segunda palabra.
check "el ejemplo advierte sobre entrecomillar valores con espacios" \
  "grep -qi 'entrecomilla' '${TEMPLATE}/.env.perf.example'"
check "el ejemplo documenta el modo supabase" \
  "grep -q 'PERF_SUPABASE_URL' '${TEMPLATE}/.env.perf.example'"

say ""
say "11. el sondeo distingue lo medible de lo que no lo es"

DISC="$WORK/discover.log"
bash "${TEMPLATE}/bin/perf-discover" http://127.0.0.1:18801 "/" >"$DISC" 2>&1
check "clasifica una página con contenido como medible" \
  "sed -n '/MEDIBLES/,/REQUIEREN/p' '$DISC' | grep -qE '^  /[[:space:]]+200'"
check "una página mínima NO se confunde con un armazón" \
  "! sed -n '/ARMAZÓN/,/CONFIGURACIÓN/p' '$DISC' | grep -qE '^  /[[:space:]]+200'"

bash "${TEMPLATE}/bin/perf-discover" http://127.0.0.1:18806 "/" >"$WORK/disc-shell.log" 2>&1
check "detecta un armazón que hidrata en el cliente" \
  "grep -q 'ARMAZÓN DE CLIENTE' '$WORK/disc-shell.log' && sed -n '/ARMAZÓN/,/CONFIGURACIÓN/p' '$WORK/disc-shell.log' | grep -q 'Cargando'"
check "no propone medir el armazón" \
  "! sed -n '/CONFIGURACIÓN SUGERIDA/,\$p' '$WORK/disc-shell.log' | grep -q 'PERF_ROUTES=/$'"

bash "${TEMPLATE}/bin/perf-discover" http://127.0.0.1:18802 "/" >"$WORK/disc-redir.log" 2>&1
check "detecta que una ruta exige sesión" \
  "grep -q 'REQUIEREN SESIÓN' '$WORK/disc-redir.log' && grep -q 'login' '$WORK/disc-redir.log'"
check "avisa cuántas rutas exigen sesión" \
  "grep -qE 'de [0-9]+ rutas' '$WORK/disc-redir.log'"

# El marcador propuesto debe existir en el cuerpo real: proponer uno inexistente
# haría abortar la compuerta en su primera corrida.
MARKER_LINE="$(grep 'PERF_APP_MARKER=' "$DISC" | head -1)"
if printf '%s' "$MARKER_LINE" | grep -q "PERF_APP_MARKER='"; then
  # shellcheck disable=SC2034  # se expande dentro del string que check() evalúa
  PROPOSED="$(printf '%s' "$MARKER_LINE" | sed -E "s/.*PERF_APP_MARKER='([^']*)'.*/\1/")"
  curl -s --max-time 8 http://127.0.0.1:18801/ > "$WORK/probe-body.html"
  check "el marcador propuesto existe en el cuerpo servido" \
    "grep -qF \"\$PROPOSED\" '$WORK/probe-body.html'"
fi

bash "${TEMPLATE}/bin/perf-discover" >/dev/null 2>&1
DISC_NOARG=$?
check "sin url devuelve error de uso (2)" "[ '$DISC_NOARG' -eq 2 ]"

say ""
say "────────────────────────────────────────"
say "$PASS correctos, $FAIL fallidos"
if [ "$FAIL" -ne 0 ]; then
  for f in "${FALLAS[@]}"; do say "  FALLA $f"; done
  exit 1
fi
say "verify-pack: el pack se comporta como se documenta."
