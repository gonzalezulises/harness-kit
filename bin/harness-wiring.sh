#!/usr/bin/env bash
# harness-wiring.sh — is this repo wired to everything it needs, as the right account?
#
# Usage:
#   bin/harness-wiring.sh [--target DIR] [--quick] [--json]
#   bin/harness-wiring.sh --fleet OWNER [--root DIR]
#
# harness-status answers "does anything stop a bad merge?". This answers the question
# that cost real time on 2026-10-23: Dependabot off in 235 repos, four sites that did not
# deploy themselves, a Supabase project with open signup over `USING true` policies, a
# Vercel CLI user that could not see the repo it was asked to connect. None of that lives
# in the repo, so no gate in the repo can catch it. Every check here asks the live system
# and names the object it asked about.
#
# Read-only. It never fixes anything: each failing line names what to run instead.
#
# Account profiles (identifiers only, never secrets) live outside the kit, in
#   ${HARNESS_PROFILES_DIR:-~/.config/harness-kit/profiles}/<github-owner>.profile
# See profiles/example.profile.
#
# States:
#   WIRED      every check passed
#   PARTIAL    nothing failed, but something could not be verified (login wall, no access)
#   NOT_WIRED  at least one integration is missing or points at the wrong object
#
# Exit codes: 0 for WIRED or PARTIAL, 1 for NOT_WIRED, 64 for a usage error.

set -uo pipefail

TARGET="."; QUICK=0; JSON=0; FLEET=""; ROOT="$HOME/GitHub"
PROFILES_DIR="${HARNESS_PROFILES_DIR:-$HOME/.config/harness-kit/profiles}"
CACHE_DIR="${HARNESS_WIRING_CACHE:-$HOME/.cache/harness-wiring}"
# Overridable so the contract test can answer for Supabase without the network.
SUPABASE_API="${HARNESS_SUPABASE_API:-https://api.supabase.com}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --quick)  QUICK=1; shift ;;
    --json)   JSON=1; shift ;;
    --fleet)  FLEET="${2:-}"; shift 2 ;;
    --root)   ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]] || [[ $JSON -eq 1 ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

slug_of() {
  git -C "$1" remote get-url origin 2>/dev/null \
    | sed -e 's#^git@[^:]*:##' -e 's#^https\{0,1\}://[^/]*/##' -e 's#\.git$##'
}

# ── Fleet mode: one line per local clone owned by OWNER ──────────────────────
if [[ -n "$FLEET" ]]; then
  printf '%-48s %-10s %s\n' "repo" "estado" "fallos"
  for dir in "$ROOT"/*/; do
    dir="${dir%/}"
    [[ -d "$dir/.git" ]] || continue
    s="$(slug_of "$dir")"
    [[ "${s%%/*}" == "$FLEET" ]] || continue
    out="$(NO_COLOR=1 bash "$0" --target "$dir" --json 2>/dev/null)"
    python3 - "$s" "$out" <<'PY'
import json, sys
slug, raw = sys.argv[1], sys.argv[2]
try:
    d = json.loads(raw)
except Exception:
    print(f"{slug:48} {'ERROR':10} salida ilegible"); sys.exit(0)
fails = [c["item"] for c in d["checks"] if c["status"] == "fail"]
print(f"{slug:48} {d['state']:10} {'; '.join(fails)}")
PY
  done
  exit 0
fi

TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "harness-wiring: no such directory" >&2; exit 64; }
SLUG="$(slug_of "$TARGET")"
OWNER="${SLUG%%/*}"; REPO="${SLUG#*/}"

# ── Results ──────────────────────────────────────────────────────────────────
RESULTS="$(mktemp)"; trap 'rm -f "$RESULTS"' EXIT
# rec <ok|fail|warn|na> <block> <item> <evidence> [fix]
rec() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" >> "$RESULTS"; }

# ── 1. Identity ──────────────────────────────────────────────────────────────
if [[ -z "$SLUG" ]]; then
  rec fail identidad "remoto" "el repo no tiene origin" "crea el repo en GitHub y añade el remoto"
else
  PROFILE="$PROFILES_DIR/$OWNER.profile"
  GIT_EMAIL=""; GH_USER="$OWNER"; GCP_PROJECT=""
  SUPABASE_KEYCHAIN_ITEMS="SUPABASE_ACCESS_TOKEN,Supabase CLI"
  if [[ -f "$PROFILE" ]]; then
    # shellcheck disable=SC1090
    . "$PROFILE"
    rec ok identidad "perfil" "$PROFILE"
  else
    rec warn identidad "perfil" "no hay perfil para $OWNER en $PROFILES_DIR" "copia profiles/example.profile a $PROFILE"
  fi

  email="$(git -C "$TARGET" config user.email 2>/dev/null || true)"
  if [[ -n "$GIT_EMAIL" && "$email" != "$GIT_EMAIL" ]]; then
    rec fail identidad "email de git" "$email (el perfil pide $GIT_EMAIL)" "revisa la regla includeIf de ~/.gitconfig"
  elif [[ -n "$email" ]]; then
    rec ok identidad "email de git" "$email"
  fi

  GH_TOKEN_VAL="$(gh auth token --user "$GH_USER" 2>/dev/null || true)"
  if [[ -z "$GH_TOKEN_VAL" ]]; then
    rec fail identidad "cuenta de GitHub" "gh no tiene token para $GH_USER" "gh auth login con la cuenta $GH_USER"
  else
    export GH_TOKEN="$GH_TOKEN_VAL"
    REPO_JSON="$(gh api "repos/$SLUG" 2>/dev/null || true)"
    if [[ -z "$REPO_JSON" ]]; then
      rec fail identidad "acceso al repo" "$GH_USER no ve $SLUG (404)" "usa el token de la cuenta dueña"
    else
      admin="$(printf '%s' "$REPO_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["permissions"].get("admin"))')"
      rec ok identidad "acceso al repo" "$GH_USER ve $SLUG (admin=$admin)"
    fi
  fi
fi

finish_report() {
  local state="WIRED"
  grep -q $'^warn\t' "$RESULTS" && state="PARTIAL"
  grep -q $'^fail\t' "$RESULTS" && state="NOT_WIRED"
  [[ "${ARCHIVED:-0}" -eq 1 ]] && state="ARCHIVED"
  if [[ $JSON -eq 1 ]]; then
    python3 - "$SLUG" "$state" "$RESULTS" <<'PY'
import json, sys
slug, state, path = sys.argv[1:4]
keys = ("status", "block", "item", "evidence", "fix")
checks = [dict(zip(keys, l.rstrip("\n").split("\t"))) for l in open(path) if l.strip()]
print(json.dumps({"repo": slug, "state": state, "checks": checks}, ensure_ascii=False))
PY
  else
    case "$state" in
      WIRED)     printf '%s\n' "${GREEN}${BOLD}WIRED${RESET} — $SLUG está conectado a todo lo que declara." ;;
      PARTIAL)   printf '%s\n' "${YELLOW}${BOLD}PARTIAL${RESET} — nada falla, pero hay integraciones sin verificar." ;;
      NOT_WIRED) printf '%s\n' "${RED}${BOLD}NOT_WIRED${RESET} — falta al menos una integración." ;;
      ARCHIVED)  printf '%s\n' "${BOLD}ARCHIVED${RESET} — $SLUG está archivado: no se revisa." ;;
    esac
    local last=""
    while IFS=$'\t' read -r st block item ev fix; do
      [[ "$block" != "$last" ]] && { printf '\n%s\n' "${BOLD}${block}${RESET}"; last="$block"; }
      case "$st" in
        ok)   mark="${GREEN}ok${RESET}  " ;;
        fail) mark="${RED}FAIL${RESET}" ;;
        warn) mark="${YELLOW}??${RESET}  " ;;
        *)    mark="--  " ;;
      esac
      printf '  %s %s — %s\n' "$mark" "$item" "$ev"
      [[ -n "$fix" && "$st" != "ok" ]] && printf '       → %s\n' "$fix"
    done < "$RESULTS"
  fi
  if [[ -n "$SLUG" && $QUICK -eq 0 ]]; then
    mkdir -p "$CACHE_DIR" 2>/dev/null && cp "$RESULTS" "$CACHE_DIR/${SLUG//\//__}.tsv" 2>/dev/null
  fi
  [[ "$state" == "NOT_WIRED" ]] && exit 1
  exit 0
}

# ── Quick mode: identity now, the rest from the last full run (< 24 h) ────────
if [[ $QUICK -eq 1 ]]; then
  cache="$CACHE_DIR/${SLUG//\//__}.tsv"
  if [[ -n "$SLUG" && -f "$cache" ]] && [[ -n "$(find "$cache" -mmin -1440 2>/dev/null)" ]]; then
    grep -v $'\tidentidad\t' "$cache" >> "$RESULTS"
  else
    rec warn caché "última corrida completa" "no hay una de menos de 24 h" "corre harness-wiring.sh sin --quick"
  fi
  finish_report
fi
[[ -z "$SLUG" || -z "${GH_TOKEN:-}" || -z "${REPO_JSON:-}" ]] && finish_report

DEFAULT_BRANCH="$(printf '%s' "$REPO_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["default_branch"])')"
if [[ "$(printf '%s' "$REPO_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("archived"))')" == "True" ]]; then
  ARCHIVED=1; rec na github "repo" "archivado: fuera de alcance"; finish_report
fi
HEAD_SHA="$(gh api "repos/$SLUG/commits/$DEFAULT_BRANCH" --jq .sha 2>/dev/null || true)"
# File checks read the remote default branch, not the working tree: a stale clone would
# report a defect that main no longer has (seen on mallol-bim-control, 2026-10-23).
git -C "$TARGET" fetch -q origin "$DEFAULT_BRANCH" 2>/dev/null
REF="origin/$DEFAULT_BRANCH"
git -C "$TARGET" rev-parse -q --verify "$REF" >/dev/null 2>&1 || REF="HEAD"
TREE="$(git -C "$TARGET" ls-tree -r --name-only "$REF" 2>/dev/null)"
tracked() {
  python3 - "$TREE" "$@" <<'PY'
import fnmatch, sys
tree, pats = sys.argv[1].splitlines(), sys.argv[2:]
print("\n".join(f for f in tree if any(fnmatch.fnmatchcase(f, p) and (p.count("/") == f.count("/")) for p in pats)))
PY
}
catf() { git -C "$TARGET" show "$REF:$1" 2>/dev/null; }

# ── 2. GitHub ────────────────────────────────────────────────────────────────
if gh api "repos/$SLUG/vulnerability-alerts" >/dev/null 2>&1; then
  rec ok github "alertas de Dependabot" "activas en $SLUG"
else
  rec fail github "alertas de Dependabot" "apagadas en $SLUG" "gh api -X PUT repos/$SLUG/vulnerability-alerts"
fi
if [[ "$(gh api "repos/$SLUG/automated-security-fixes" --jq .enabled 2>/dev/null)" == "true" ]]; then
  rec ok github "actualizaciones de seguridad" "Dependabot abre PRs de seguridad en $SLUG"
else
  rec warn github "actualizaciones de seguridad" "apagadas en $SLUG" "gh api -X PUT repos/$SLUG/automated-security-fixes"
fi
rules="$(gh api "repos/$SLUG/rules/branches/$DEFAULT_BRANCH" --jq '[.[].type]|join(",")' 2>/dev/null || true)"
HAS_REQ=0
if [[ "$rules" == *required_status_checks* ]] || \
   gh api "repos/$SLUG/branches/$DEFAULT_BRANCH/protection/required_status_checks" >/dev/null 2>&1; then
  HAS_REQ=1
fi

# ── 3. Quality ───────────────────────────────────────────────────────────────
wf_count="$(tracked '.github/workflows/*.yml' '.github/workflows/*.yaml' | wc -l | tr -d ' ')"
if [[ "$wf_count" -gt 0 ]]; then
  rec ok calidad "CI" "$wf_count workflow(s) en .github/workflows"
else
  rec fail calidad "CI" "no hay ningún workflow: nada corre en cada PR" "bin/harness-activate.sh --target $TARGET"
fi
while IFS= read -r pj; do
  [[ -n "$pj" ]] || continue
  lint="$(catf "$pj" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("scripts",{}).get("lint",""))' 2>/dev/null)"
  if [[ "$lint" == "next lint"* ]]; then
    rec fail calidad "lint ($pj)" "usa «next lint», que Next 16 eliminó: no revisa nada" "eslint.config.mjs + \"lint\": \"eslint .\""
  fi
done < <(tracked 'package.json' '*/package.json' | grep -v node_modules)
if [[ -n "$(tracked 'sonar-project.properties' '.github/workflows/*sonar*')" ]]; then
  rec ok calidad "análisis de calidad" "SonarCloud declarado (el análisis no se verifica aquí)"
else
  rec warn calidad "análisis de calidad" "sin SonarCloud declarado"
fi

# ── 4. Deploy: does a merge to the default branch reach production on its own? ─
DEPLOY=0; PROD_URL=""; VERCEL_ENV_NAMES=""; RUN_ENV_NAMES=""; SEEN_PIDS=" "
while IFS= read -r vp; do
  [[ -n "$vp" ]] || continue
  DEPLOY=1
  pid="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["projectId"])' "$TARGET/$vp" 2>/dev/null)"
  # The same project is often linked twice (root and frontend/): report it once.
  [[ "$SEEN_PIDS" == *" $pid "* ]] && continue
  SEEN_PIDS="$SEEN_PIDS$pid "
  org="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["orgId"])' "$TARGET/$vp" 2>/dev/null)"
  pj="$(vercel api "/v9/projects/$pid?teamId=$org" 2>/dev/null | python3 -c 'import sys;r=sys.stdin.read();print(r[r.index("{"):] if "{" in r else "")' 2>/dev/null)"
  if [[ -z "$pj" ]] || printf '%s' "$pj" | grep -q '"error"'; then
    rec warn despliegue "Vercel ($pid)" "la CLI de Vercel no ve el proyecto en $org" "vercel login con la cuenta del team"
    continue
  fi
  read -r link_repo prod_sha prod_url < <(printf '%s' "$pj" | python3 -c '
import json, sys
p = json.load(sys.stdin); l = p.get("link") or {}; t = (p.get("targets") or {}).get("production") or {}
alias = [a.get("domain") for a in (p.get("alias") or []) if a.get("domain")]
print((l.get("org","") + "/" + l.get("repo","")) if l.get("repo") else "-", (t.get("meta") or {}).get("githubCommitSha","-") or "-", ("https://" + alias[0]) if alias else "-")')
  [[ "$prod_url" != "-" ]] && PROD_URL="$prod_url"
  if [[ "$link_repo" == "$SLUG" ]]; then
    rec ok despliegue "Vercel ($pid)" "conectado a $SLUG: cada push a $DEFAULT_BRANCH despliega"
  else
    rec fail despliegue "Vercel ($pid)" "sin Git conectado ($link_repo): un merge no publica nada" "conecta Git desde la sesión de Vercel cuyo GitHub ve $SLUG"
  fi
  if [[ "$prod_sha" == "$HEAD_SHA" ]]; then
    rec ok despliegue "producción al día" "Vercel sirve ${HEAD_SHA:0:7}, el HEAD de $DEFAULT_BRANCH"
  else
    rec warn despliegue "producción al día" "Vercel sirve ${prod_sha:0:7}; $DEFAULT_BRANCH está en ${HEAD_SHA:0:7}"
  fi
  VERCEL_ENV_NAMES="$(vercel api "/v9/projects/$pid/env?teamId=$org" 2>/dev/null | python3 -c '
import json, sys
r = sys.stdin.read(); d = json.loads(r[r.index("{"):]) if "{" in r else {}
print(" ".join(sorted({e["key"] for e in d.get("envs", []) if "production" in (e.get("target") or [])})))' 2>/dev/null)"
# .vercel/ is gitignored by default, so look on disk: the root and one level down (web/, app/).
done < <(cd "$TARGET" && find . -maxdepth 3 -path ./node_modules -prune -o \
           -path '*/.vercel/project.json' -print 2>/dev/null | sed 's#^\./##' | sort -u)

ACTIONS_DEPLOY=""
for wf in $(tracked '.github/workflows/*.yml' '.github/workflows/*.yaml'); do
  catf "$wf" | grep -qE 'gcloud run deploy|gcloud builds submit|deploy-cloudrun|vercel deploy|vercel --prod|wrangler deploy|fly deploy' \
    && ACTIONS_DEPLOY="$ACTIONS_DEPLOY ${wf#.github/workflows/}"
done
if [[ -n "$ACTIONS_DEPLOY" ]]; then
  DEPLOY=1
  rec ok despliegue "GitHub Actions" "despliega desde${ACTIONS_DEPLOY}"
fi

if [[ -n "$(tracked 'cloudbuild.yaml' '*/cloudbuild.yaml')" ]]; then
  DEPLOY=1
  if [[ -z "$GCP_PROJECT" ]]; then
    rec warn despliegue "Cloud Build" "el perfil de $OWNER no declara GCP_PROJECT"
  else
    trig="$(gcloud builds triggers list --project "$GCP_PROJECT" --format='value(name,github.name)' 2>/dev/null | awk -F'\t' -v r="$REPO" '$2==r{print $1}' | head -1)"
    if [[ -n "$trig" ]]; then
      rec ok despliegue "Cloud Build" "trigger $trig en $GCP_PROJECT"
      st="$(gcloud builds list --project "$GCP_PROJECT" --limit=20 --filter="substitutions.COMMIT_SHA=$HEAD_SHA" --format='value(status)' 2>/dev/null | head -1)"
      case "$st" in
        SUCCESS) rec ok despliegue "último build" "${HEAD_SHA:0:7} desplegó (SUCCESS)" ;;
        "")      rec warn despliegue "último build" "no hay build para ${HEAD_SHA:0:7} (¿el cambio no tocó las rutas del trigger?)" ;;
        *)       rec fail despliegue "último build" "${HEAD_SHA:0:7} terminó en $st" "gcloud builds list --project $GCP_PROJECT --region us-central1" ;;
      esac
    elif [[ -n "$ACTIONS_DEPLOY" ]]; then
      rec warn despliegue "Cloud Build" "cloudbuild.yaml sin trigger; el despliegue va por GitHub Actions"
    else
      rec fail despliegue "Cloud Build" "hay cloudbuild.yaml pero ningún trigger para $REPO en $GCP_PROJECT" "gcloud builds triggers create github …"
    fi
    svc="$(for f in $(tracked 'cloudbuild.yaml' '*/cloudbuild.yaml'); do catf "$f"; done | grep -oE '_SERVICE: *[A-Za-z0-9-]+' | head -1 | awk '{print $2}')"
    if [[ -n "$svc" ]]; then
      RUN_ENV_NAMES="$(gcloud run services describe "$svc" --region us-central1 --project "$GCP_PROJECT" --format='value(spec.template.spec.containers[0].env[].name)' 2>/dev/null | tr ';' ' ')"
      run_url="$(gcloud run services describe "$svc" --region us-central1 --project "$GCP_PROJECT" --format='value(status.url)' 2>/dev/null)"
      [[ -n "$run_url" ]] && PROD_URL="$run_url"
    fi
  fi
fi
[[ $DEPLOY -eq 0 ]] && rec warn despliegue "plataforma" "ni Vercel, ni Cloud Build, ni un workflow que despliegue: no detecto producción"

# D10: the merge gate belongs where there is production. Without one, its absence is a note.
if [[ $HAS_REQ -eq 1 ]]; then
  rec ok github "check requerido" "$DEFAULT_BRANCH no acepta merges sin checks"
elif [[ $DEPLOY -eq 1 ]]; then
  rec fail github "check requerido" "$SLUG despliega a producción y nada impide fusionar en $DEFAULT_BRANCH sin CI" "bin/harness-activate.sh --target $TARGET  (o bin/harness-protect.sh $SLUG)"
else
  rec warn github "check requerido" "sin producción detectada: D10 no exige la compuerta aquí"
fi

# ── 5. Supabase: open signup over `USING true` is invisible to the Advisor ─────
refs="$(git -C "$TARGET" grep -hoE '[a-z]{20}\.supabase\.co' "$REF" -- . ':!*.lock' ':!*lock.json' 2>/dev/null | sed -e 's/^[^:]*://' -e 's/\.supabase\.co//' | sort -u)"
[[ -f "$TARGET/supabase/.temp/project-ref" ]] && refs="$(printf '%s\n%s' "$refs" "$(cat "$TARGET/supabase/.temp/project-ref")" | grep -v '^$' | sort -u)"
for ref in $refs; do
  sbt=""
  IFS=',' read -r -a items <<< "$SUPABASE_KEYCHAIN_ITEMS"
  for item in "${items[@]}"; do
    t="$(security find-generic-password -s "$item" -w 2>/dev/null || true)"
    [[ -n "$t" ]] || continue
    code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $t" "$SUPABASE_API/v1/projects/$ref")"
    [[ "$code" == "200" ]] && { sbt="$t"; break; }
  done
  if [[ -z "$sbt" ]]; then
    rec warn supabase "$ref" "ningún token del Keychain ve este proyecto (¿es de otra organización o ya no existe?)"
    continue
  fi
  verdict="$(SBT="$sbt" API="$SUPABASE_API" python3 - "$ref" <<'PY'
import json, os, sys, urllib.request
ref, tok, api = sys.argv[1], os.environ["SBT"], os.environ["API"]
def call(path, body=None):
    req = urllib.request.Request(f"{api}{path}", method="POST" if body else "GET",
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json", "User-Agent": "curl/8.4.0"})
    with urllib.request.urlopen(req) as r: return json.loads(r.read() or b"null")
auth = call(f"/v1/projects/{ref}/config/auth")
n = call(f"/v1/projects/{ref}/database/query", {"query":
    "select count(*) as n from pg_policies where schemaname='public' and roles @> array['authenticated']::name[] "
    "and (coalesce(qual,'') in ('true','(true)') or coalesce(with_check,'') in ('true','(true)'))"})[0]["n"]
print(auth.get("disable_signup"), auth.get("password_hibp_enabled"), n)
PY
)"
  read -r closed hibp n <<< "$verdict"
  if [[ -z "$verdict" ]]; then
    rec warn supabase "$ref" "no se pudo leer la config de Auth"
  elif [[ "$closed" != "True" && "${n:-0}" -gt 0 ]]; then
    rec fail supabase "$ref registro" "registro abierto y $n políticas «true» para authenticated: cualquiera se registra y lee" "PATCH config/auth {\"disable_signup\": true} o lista blanca (skill supabase-rls-fix)"
  else
    rec ok supabase "$ref registro" "disable_signup=$closed, políticas true para authenticated: $n"
  fi
  [[ "$hibp" == "True" ]] && rec ok supabase "$ref contraseñas filtradas" "protección activa" \
                          || rec warn supabase "$ref contraseñas filtradas" "protección apagada" "PATCH config/auth {\"password_hibp_enabled\": true}"
  envs="$VERCEL_ENV_NAMES $RUN_ENV_NAMES"
  if [[ -n "${envs// /}" ]]; then
    [[ "$envs" == *SUPABASE* || "$envs" == *DATABASE_URL* ]] \
      && rec ok conexiones "app → Supabase" "el entorno de producción declara variables de Supabase" \
      || rec fail conexiones "app → Supabase" "el repo usa $ref pero producción no tiene variables de Supabase"
  fi
done

# ── 6. Sentry ────────────────────────────────────────────────────────────────
if for f in $(tracked 'package.json' '*/package.json'); do catf "$f"; done | grep -q '"@sentry/'; then
  envs="$VERCEL_ENV_NAMES $RUN_ENV_NAMES"
  if [[ -z "${envs// /}" ]]; then
    rec warn sentry "DSN en producción" "SDK instalado; no pude leer el entorno de producción"
  elif [[ "$envs" == *SENTRY_DSN* ]]; then
    rec ok sentry "DSN en producción" "SDK instalado y SENTRY_DSN declarado (que el evento llegue lo prueba packs/sentry)"
  else
    rec fail sentry "DSN en producción" "SDK instalado pero producción no declara SENTRY_DSN: no reporta nada" "añade el DSN al entorno de producción"
  fi
else
  rec warn sentry "SDK" "sin @sentry en package.json: los errores de producción no llegan a nadie" "packs/sentry"
fi

# ── 7. Smoke: production answers, or says honestly that it cannot be seen ─────
if [[ -n "$PROD_URL" ]]; then
  read -r code redirect < <(curl -s -o /dev/null -m 15 -w '%{http_code} %{redirect_url}' "$PROD_URL" 2>/dev/null; echo)
  case "$code" in
    2??) rec ok conexiones "producción responde" "$PROD_URL → $code" ;;
    30?) if [[ "$redirect" == *accounts.google.com* || "$redirect" == *vercel.com/login* || "$redirect" == *sso* ]]; then
           rec warn conexiones "producción responde" "$PROD_URL pide login ($code): el render no se verifica sin sesión"
         else rec ok conexiones "producción responde" "$PROD_URL → $code"; fi ;;
    401|403) rec warn conexiones "producción responde" "$PROD_URL → $code (protegido: sin verificar)" ;;
    *) rec fail conexiones "producción responde" "$PROD_URL → ${code:-sin respuesta}" ;;
  esac
fi

finish_report
