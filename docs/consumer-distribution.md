# Distribución de `autonomy-runtime.v1`

Este perfil instala el runtime QO fijado por un SHA Git y su cierre exacto de `yaml`/`zod` dentro de `.harness/distribution/`. Es una instalación técnica: deja `adoptionStatus: NOT_ADOPTED`, no crea autoridad, baseline ni aceptación humana, y no cambia el estado a `ACTIVE`. Un tag local sólo produce `TAGGED_SOURCE`; no prueba una publicación externa.

## Bundle reproducible e inventario

El builder lee runtime, manager, bootstrap, schema y regla de vendoring desde el mismo commit exacto. Los archivos npm se suministran localmente y se verifican contra el SHA512 de `package-lock.json`; no ejecuta `npm` ni usa red. El digest excluye fechas y rutas locales, por lo que el mismo commit y archives copiados a otra ubicación producen el mismo `bundleDigest`.

```bash
python3 bin/harness-consumer.py bundle \
  --source-repo "$SOURCE_REPO" --source-sha "$SOURCE_SHA" \
  --source-identity gonzalezulises/harness-kit \
  --package-archives "$ARCHIVES_JSON" --output "$BUNDLE" \
  --profile autonomy-runtime.v1
python3 bin/harness-consumer.py inventory --bundle "$BUNDLE" > "$INVENTORY_JSON"
```

`source-identity` es una declaración portable del productor, no una verificación remota de owner, tag o publicación. El manifest la marca `DECLARED_NOT_REMOTE_VERIFIED` y registra por separado el root commit del linaje observado y el SHA exacto. `inventory` es la lista exhaustiva y verificable: devuelve cada archivo con path, SHA256, modo, origen y modo de origen, además de versión, integrity SHA512 y tamaño de cada archive de dependencia.

Los archivos estables administrados son `bootstrap.mjs`, `harness-consumer.py`, `consumer-installation.v1.json` y `.gitignore`. El inventario del bundle enumera los módulos de producción `.mjs`, contratos `contracts-*.md`, schemas, `package.json`, `package-lock.json` y las dependencias exactas `yaml`/`zod` que existen en el SHA seleccionado. Esto incluye los módulos de producto y recuperación cuando ese commit los contiene; una lista histórica de módulos no sustituye al inventario. Los tests del productor no forman parte del runtime instalado. La excepción `.gitignore` vive dentro del namespace administrado para permitir versionar el cierre offline en un consumidor con `node_modules/` ignorado.

## Plan, aplicación y verificación

Guarde el plan fuera del checkout consumidor y entregue su digest exacto por un canal de aprobación separado. `plan` y `upgrade-plan` son de sólo lectura. El plan declara `lockPath` como la ruta absoluta del directorio Git efectivo y la incluye en `allowedWrites`; en un worktree enlazado puede estar fuera del checkout. Apply la revalida antes y después de tomar el lock y no escribe contenido en ese archivo.

```bash
python3 bin/harness-consumer.py plan \
  --target "$CONSUMER" --bundle "$BUNDLE" --profile autonomy-runtime.v1 \
  --config-schema autonomy-config.v1 --state-schema autonomy-state.v1 \
  > "$INSTALL_PLAN"
python3 bin/harness-consumer.py apply \
  --target "$CONSUMER" --bundle "$BUNDLE" --plan "$INSTALL_PLAN" \
  --approve-plan "$PLAN_DIGEST"

python3 "$PROTECTED_HARNESS_ROOT/bin/harness-consumer.py" verify \
  --target "$CONSUMER" \
  --expected-installation-digest "$EXPECTED_INSTALLATION_DIGEST" \
  --expected-plan-digest "$EXPECTED_PLAN_DIGEST"
```

`PROTECTED_HARNESS_ROOT` debe ser un checkout o artifact read-only controlado fuera del candidato y fijado por la política de la base. Sin los dos digests externos, `verify` sólo informa integridad local; no certifica adopción. Para CI con autoridad use el checker externo protegido y ambos valores desde una fuente protegida. El manager instalado en el candidato sirve para operación local, pero no puede certificar su propia adopción.

```bash
python3 "$CONSUMER/.harness/distribution/harness-consumer.py" upgrade-plan \
  --target "$CONSUMER" --bundle "$NEXT_BUNDLE" --profile autonomy-runtime.v1 \
  --config-schema autonomy-config.v1 --state-schema autonomy-state.v1 \
  > "$UPGRADE_PLAN"
python3 "$CONSUMER/.harness/distribution/harness-consumer.py" upgrade \
  --target "$CONSUMER" --bundle "$NEXT_BUNDLE" --plan "$UPGRADE_PLAN" \
  --approve-plan "$UPGRADE_PLAN_DIGEST"

python3 "$CONSUMER/.harness/distribution/harness-consumer.py" rollback \
  --target "$CONSUMER" --to "$OLDER_BUNDLE_DIGEST" \
  --profile autonomy-runtime.v1 --config-schema autonomy-config.v1 \
  --state-schema autonomy-state.v1 > "$ROLLBACK_PLAN"
python3 "$CONSUMER/.harness/distribution/harness-consumer.py" rollback \
  --target "$CONSUMER" --plan "$ROLLBACK_PLAN" \
  --approve-plan "$ROLLBACK_PLAN_DIGEST"
```

Los cambios de major, bootstrap o schema sin migración compatible devuelven `MIGRATION_REQUIRED`. No hay hooks arbitrarios de migración.

## Propiedad del consumidor

Salvo el `lockPath` Git exacto declarado por cada plan, todo path fuera de `.harness/distribution/` sigue siendo propiedad del consumidor. Esto incluye producto, comandos, workflows, root `AGENTS.md`, `Makefile`, package/lock, políticas, autoridad, objetivos, allowlists, frozen regions, adapters y gates. El lock debe ser un archivo regular privado, sin symlink ni hardlink, y sólo aporta ownership de proceso mediante `flock`. No se presupone ni enumera el contenido de Casabat.

El instalador preserva explícitamente `.harness/autonomy-v2.json`, `.harness/FIXTURE_ONLY-state/`, `.harness/autonomy/`, `.harness/oracles/`, `.harness/receipts/`, `feature_list.json`, `PROGRESS.md`, `DECISIONS.md`, journals, runs y markers. También conserva cualquier `scripts/quality-orchestrator/` existente: el nuevo bootstrap es paralelo y explícito. Rollback conmuta a una generación verificada y mantiene configuración, journal y evidencia más nuevos.

La prueba E2E crea un consumidor Git, instala, versiona sólo `.harness/distribution`, clona de nuevo, retira source y bundle, usa cache npm vacío y ejecuta `bootstrap.mjs identify` con el QO real y los paquetes `yaml`/`zod` vendorizados. La autoridad usada allí es efímera y marcada `EPHEMERAL_NOT_ADOPTED`; demuestra operación offline, no aceptación del consumidor.
