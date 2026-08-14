#!/usr/bin/env bash
# perf-init.sh — instala y activa la compuerta de rendimiento en este repositorio.
#
# Hace tres cosas que de otro modo se hacen a mano y se olvidan:
#
#   1. Copia los archivos de la compuerta y actualiza .gitignore.
#   2. Configura las variables del repositorio a partir del stack detectado.
#   3. Registra el check "smoke" como REQUERIDO en la rama por defecto, que es el
#      único paso que convierte el workflow en una compuerta real. Un workflow sin
#      ese registro se pone rojo y deja fusionar igual.
#
# Ejecútalo desde la raíz del repositorio destino:
#   bash bin/perf-init.sh --dry-run     # muestra todo, no cambia nada
#   bash bin/perf-init.sh
#
# Compatible con bash 3.2 (macOS).

set -uo pipefail

DRY_RUN=0
FORCE=0
SKIP_CI=0
MARKER=""
ROUTES=""
PACK_SRC=""
ACCOUNT=""

usage() {
  cat <<'USAGE'
Uso: bash bin/perf-init.sh [opciones]

  --dry-run          Muestra cada acción sin ejecutar ninguna.
  --force            Sobrescribe archivos existentes de la compuerta.
  --no-ci            Sólo instala archivos; no toca variables ni reglas de rama.
  --marker TEXTO     Texto que sólo existe en tu aplicación (PERF_APP_MARKER).
  --routes LISTA     Rutas a medir, separadas por coma. Si se omite, se detectan.
  --from RUTA        Directorio repo-template del pack. Por defecto se autodetecta.
  --account CUENTA   Cuenta de GitHub a usar para configurar CI. Úsalo si tienes
                     varias autenticadas: la cuenta que responde a la API no
                     siempre es la que 'gh auth status' marca como activa. No
                     cambia tu cuenta activa; sólo afecta a esta ejecución.
  -h, --help         Esta ayuda.

Requiere: bash, git. Para configurar CI además: gh autenticado con permiso de
administración sobre el repositorio.

Límite de plataforma conocido: exigir un check requiere conjuntos de reglas, y
GitHub no los ofrece en repositorios PRIVADOS de cuentas Free (responde 403
"Upgrade to GitHub Pro"). En repositorios públicos, y en repositorios de una
organización con plan de pago, sí funcionan. Este script lo detecta y lo dice.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --no-ci) SKIP_CI=1 ;;
    --marker) MARKER="${2:-}"; shift ;;
    --routes) ROUTES="${2:-}"; shift ;;
    --from) PACK_SRC="${2:-}"; shift ;;
    --account) ACCOUNT="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "perf-init: opción desconocida '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

step()  { echo "${BOLD}$1${RESET}"; }
ok()    { echo "  ${GREEN}hecho${RESET}   $1"; }
note()  { echo "  ${YELLOW}nota${RESET}    $1"; }
warn()  { echo "  ${YELLOW}aviso${RESET}   $1"; }
bad()   { echo "  ${RED}falla${RESET}   $1"; }
plan()  { echo "  ${YELLOW}haría${RESET}   $1"; }
die()   { echo "${RED}perf-init: $1${RESET}" >&2; exit 1; }

# Ejecuta o describe, según el modo.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    plan "$*"
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# 1. Contexto del repositorio
# ---------------------------------------------------------------------------

step "1. Repositorio"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "esto no es un repositorio git."
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || die "no se pudo entrar a $ROOT"
ok "raíz: $ROOT"

SLUG=""
REMOTE_URL="$(git remote get-url origin 2>/dev/null)"
if [ -n "$REMOTE_URL" ]; then
  # Acepta https://github.com/owner/repo(.git) y git@github.com:owner/repo(.git)
  SLUG="$(printf '%s' "$REMOTE_URL" \
    | sed -e 's#^https://[^/]*/##' -e 's#^git@[^:]*:##' -e 's#\.git$##')"
  ok "remoto: $SLUG"
else
  note "sin remoto 'origin': se instalarán los archivos, pero no se puede configurar CI."
  SKIP_CI=1
fi

DEFAULT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH="main"

# ---------------------------------------------------------------------------
# 2. Origen del pack
# ---------------------------------------------------------------------------

step "2. Origen del pack"

if [ -z "$PACK_SRC" ]; then
  # Si este script ya vive dentro del repo destino, el pack es su propio directorio
  # padre; si se ejecuta desde el kit, es el repo-template del pack.
  SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
  for candidate in \
    "$SELF_DIR/.." \
    "$HOME/GitHub/harness-kit/packs/load-testing/repo-template"; do
    if [ -f "$candidate/tests/load/smoke.js" ]; then
      PACK_SRC="$(cd "$candidate" && pwd)"
      break
    fi
  done
fi

[ -n "$PACK_SRC" ] || die "no se encontró el repo-template del pack. Indícalo con --from RUTA."
[ -f "$PACK_SRC/tests/load/smoke.js" ] || die "$PACK_SRC no contiene tests/load/smoke.js"
ok "pack: $PACK_SRC"

# ---------------------------------------------------------------------------
# 3. Detección del stack
# ---------------------------------------------------------------------------

step "3. Stack detectado"

STACK="desconocido"
if [ -f package.json ]; then
  if grep -q '"next"' package.json 2>/dev/null; then
    STACK="next.js"
  else
    STACK="node"
  fi
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  STACK="python"
fi
ok "stack: $STACK"

# Rutas: en Next.js con App Router, cada page.tsx es una ruta servible.
#
# Se usa sed -E porque `\?` no es un cuantificador en el sed de macOS (BSD): con
# BRE la extensión no se recortaba y las rutas salían como "/ahorro/page.tsx".
# Se excluyen las rutas con segmentos dinámicos ([id]): medirlas exige un valor
# real que este script no puede inventar.
if [ -z "$ROUTES" ] && [ -d app ]; then
  ROUTES="$(find app -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.js' \) 2>/dev/null \
    | grep -v '\[' \
    | sed -E -e 's#^app##' -e 's#/page\.(tsx|jsx|js)$##' -e 's#^$#/#' \
    | sort -u | head -5 | tr '\n' ',' | sed -e 's/,$//')"
fi
[ -n "$ROUTES" ] || ROUTES="/"
ok "rutas a medir: $ROUTES"

if [ -z "$MARKER" ]; then
  # No se inventa un marcador: uno que no exista en el HTML haría que el guard
  # aborte en cada corrida, y el usuario perseguiría un fallo inexistente.
  warn "sin PERF_APP_MARKER. La compuerta funciona en objetivos sin autenticación,"
  warn "pero para un preview de Vercel o Cloud Run tras IAP es obligatorio:"
  warn "vuelve a ejecutar con --marker '<texto que sólo exista en tu app>'."
fi

# ---------------------------------------------------------------------------
# 4. Instalación de archivos
# ---------------------------------------------------------------------------

step "4. Archivos"

copy_item() {
  local rel="$1" src="$PACK_SRC/$1" dest="$ROOT/$1"
  [ -e "$src" ] || { bad "no existe en el pack: $rel"; return 1; }
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    note "ya existe, se conserva: $rel  (usa --force para sobrescribir)"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    plan "copiar $rel"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  ok "copiado: $rel"
}

copy_item "tests/load"
copy_item "bin/perf-check"
copy_item "bin/perf-resolve-target"
copy_item ".github/workflows/perf.yml"
copy_item ".env.perf.example"

if [ "$DRY_RUN" -eq 0 ]; then
  chmod +x "$ROOT/bin/perf-check" "$ROOT/bin/perf-resolve-target" 2>/dev/null
fi

# .gitignore: results/ es directorio de trabajo, .env.perf lleva credenciales.
# baseline.json NO se ignora: es la referencia aprobada y su historial es el
# registro de las degradaciones que el equipo aceptó.
step "5. .gitignore"
for entry in ".env.perf" "tests/load/results/"; do
  if [ -f .gitignore ] && grep -qxF "$entry" .gitignore; then
    note "ya presente: $entry"
  elif [ "$DRY_RUN" -eq 1 ]; then
    plan "añadir a .gitignore: $entry"
  else
    printf '%s\n' "$entry" >> .gitignore
    ok "añadido: $entry"
  fi
done

# ---------------------------------------------------------------------------
# 6. Configuración de CI
# ---------------------------------------------------------------------------

if [ "$SKIP_CI" -eq 1 ]; then
  step "6. CI"
  note "omitido (--no-ci o sin remoto)."
else
  step "6. Cuenta de GitHub"

  if ! command -v gh >/dev/null 2>&1; then
    warn "gh no está instalado: no se pueden configurar variables ni la regla de rama."
    SKIP_CI=1
  else
    # Selección explícita de cuenta. No se toca la cuenta activa del sistema:
    # se exporta el token sólo para este proceso.
    if [ -n "$ACCOUNT" ]; then
      TOKEN="$(gh auth token --user "$ACCOUNT" 2>/dev/null)"
      if [ -n "$TOKEN" ]; then
        export GH_TOKEN="$TOKEN"
        ok "usando la cuenta solicitada: $ACCOUNT"
      else
        warn "no hay token para la cuenta '$ACCOUNT'. Autentícala con: gh auth login"
      fi
    fi

    # Con varias cuentas autenticadas, la que responde a la API no es
    # necesariamente la que 'gh auth status' marca como activa. Se consulta a la
    # API para saber quién opera de verdad, porque configurar el repositorio
    # equivocado en silencio es peor que no configurar nada.
    API_USER="$(gh api user --jq .login 2>/dev/null)"
    if [ -z "$API_USER" ]; then
      warn "gh no está autenticado: no se puede configurar CI."
      SKIP_CI=1
    else
      ok "la API responde como: $API_USER"
      OWNER="${SLUG%%/*}"
      if [ "$API_USER" != "$OWNER" ]; then
        note "el repositorio pertenece a '$OWNER' y operas como '$API_USER'."
        note "si falta permiso, cambia de cuenta: gh auth switch --user <cuenta>"
      fi

      IS_ADMIN="$(gh api "repos/$SLUG" --jq '.permissions.admin' 2>/dev/null)"
      if [ "$IS_ADMIN" = "true" ]; then
        ok "permiso de administración sobre $SLUG"
      else
        warn "sin permiso de administración sobre $SLUG (admin=${IS_ADMIN:-desconocido})."
        warn "los archivos quedan instalados, pero el check NO se registrará como requerido."
        warn "cámbiate a la cuenta con admin (gh auth switch --user <cuenta>) y vuelve a ejecutar."
      fi
    fi
  fi
fi

if [ "$SKIP_CI" -eq 0 ]; then
  step "7. Variables del repositorio"
  set_var() {
    local name="$1" value="$2"
    [ -n "$value" ] || { note "sin valor, se omite: $name"; return 0; }
    if [ "$DRY_RUN" -eq 1 ]; then
      plan "gh variable set $name --repo $SLUG --body '$value'"
    elif gh variable set "$name" --repo "$SLUG" --body "$value" >/dev/null 2>&1; then
      ok "$name = $value"
    else
      warn "no se pudo definir $name (¿permisos?)"
    fi
  }
  set_var PERF_ROUTES "$ROUTES"
  set_var PERF_APP_MARKER "$MARKER"

  step "8. Registrar el check como requerido"
  if [ "$IS_ADMIN" = "true" ]; then
    BRANCH_DEFAULT="$(gh api "repos/$SLUG" --jq '.default_branch' 2>/dev/null)"
    [ -n "$BRANCH_DEFAULT" ] || BRANCH_DEFAULT="$DEFAULT_BRANCH"

    # Sólo un id numérico cuenta como "ya existe". Sin esta comprobación, una
    # respuesta de error (por ejemplo el 403 de plan) se guardaba en EXISTING y el
    # script informaba que la regla ya estaba puesta — ocultando justo el problema
    # que debía reportar.
    EXISTING="$(gh api "repos/$SLUG/rulesets" --jq '.[] | select(.name=="perf-gate") | .id' 2>/dev/null | head -1)"
    case "$EXISTING" in
      ''|*[!0-9]*) EXISTING="" ;;
    esac
    if [ -n "$EXISTING" ]; then
      note "ya existe el conjunto de reglas 'perf-gate' (id $EXISTING); se conserva."
    else
      PAYLOAD="$(cat <<JSON
{
  "name": "perf-gate",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "smoke" } ]
      }
    }
  ]
}
JSON
)"
      if [ "$DRY_RUN" -eq 1 ]; then
        plan "crear conjunto de reglas 'perf-gate' en $SLUG (rama $BRANCH_DEFAULT) exigiendo el check 'smoke'"
        printf '%s\n' "$PAYLOAD" | sed 's/^/          | /'
      else
        RULESET_RESP="$(printf '%s' "$PAYLOAD" | gh api "repos/$SLUG/rulesets" --input - 2>&1)"
        if printf '%s' "$RULESET_RESP" | grep -q '"id"'; then
          ok "check 'smoke' exigido en la rama $BRANCH_DEFAULT — la compuerta ya bloquea"
        elif printf '%s' "$RULESET_RESP" | grep -qi 'Upgrade to GitHub Pro'; then
          IS_PRIVATE="$(gh api "repos/$SLUG" --jq '.private' 2>/dev/null)"
          warn "GitHub no permite conjuntos de reglas en este repositorio (privado=${IS_PRIVATE})."
          warn "Respondió: Upgrade to GitHub Pro or make this repository public."
          warn ""
          warn "La compuerta queda instalada y CORRIENDO: verás el check en cada pull"
          warn "request y su resultado en la pestaña Actions. Lo que NO puede hacer todavía"
          warn "es impedir la fusión. Para que bloquee, elige una de estas tres:"
          warn "  1. Mover el repositorio a una organización con plan de pago."
          warn "  2. Activar GitHub Pro en esta cuenta."
          warn "  3. Hacer público el repositorio (rara vez aceptable en trabajo de cliente)."
        else
          warn "no se pudo crear el conjunto de reglas. Respuesta de la API:"
          printf '%s\n' "$RULESET_RESP" | head -3 | sed 's/^/          /'
          warn "Alternativa manual: Settings > Rules > New ruleset > Require status checks > 'smoke'"
        fi
      fi
    fi
  else
    note "omitido: requiere permiso de administración."
  fi
fi

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

echo
step "Siguiente paso"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  Esto fue una simulación: no se cambió nada. Quita --dry-run para aplicarlo."
else
  echo "  1. Levanta la aplicación y establece la referencia local:"
  echo "       PERF_TARGET=http://127.0.0.1:3000 bin/perf-check smoke"
  echo "       PERF_TARGET=http://127.0.0.1:3000 bin/perf-check smoke --update-baseline"
  echo "  2. Comitea tests/load/baseline.json junto a los archivos instalados."
  if [ -z "$MARKER" ]; then
    echo "  3. Define PERF_APP_MARKER antes de medir un objetivo autenticado."
  fi
fi
