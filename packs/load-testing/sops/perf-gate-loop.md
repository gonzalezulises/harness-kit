# SOP — Bucle de la compuerta de rendimiento

Procedimiento para poner la compuerta a funcionar en un repositorio y mantenerla
creíble. El orden importa: cada paso deja evidencia que el siguiente necesita.

## 1. Construye el verificador antes de la prueba

Empieza por `bin/perf-check`, no por el script de k6. El verificador define qué
significa "aprobado", y esa definición debe existir antes de que haya un número
que interpretar. Si escribes primero la prueba, el criterio termina ajustándose
al resultado que ya obtuviste.

## 2. Prueba que la compuerta falla, antes de confiar en que pasa

Una compuerta que nunca viste fallar no es una compuerta. Antes de darla por
buena, provoca cada modo de falla y confirma que bloquea:

| Provocación | Resultado esperado |
|---|---|
| `PERF_TARGET` a un host que redirige al login | Aborta, código `108` |
| `PERF_APP_MARKER` con un texto que no existe en la página | Aborta con el motivo del marcador |
| `PERF_AUTH=iap` sin definir `PERF_APP_MARKER` | Aborta exigiendo el marcador |
| `PERF_P95_MS=1` contra cualquier objetivo real | Umbral incumplido, código `99` |
| Una llamada a una función inexistente dentro de la función por defecto | Bloquea, no aprueba |
| Borrar el resumen antes de la verificación | Bloquea por falta de evidencia |

La última fila prueba la parte que más se olvida: la compuerta debe rechazar una
corrida sin evidencia, no asumir que salió bien.

## 3. Establece la línea base sobre una corrida representativa

No apruebes como línea base la primera corrida que pase. Una línea base tomada de
una máquina fría, o de un despliegue recién creado, produce una referencia que no
representa el comportamiento normal y hará saltar la compuerta sin motivo.

Corre el smoke tres veces contra el mismo objetivo. Si el p(95) varía más que tu
`PERF_DRIFT_PCT`, el objetivo es demasiado inestable para una compuerta de
deriva: sube la tolerancia o mide contra un entorno más estable antes de fijar la
referencia.

## 4. Trata cada degradación aceptada como una decisión

Cuando la compuerta bloquee por deriva, hay exactamente dos respuestas
legítimas:

- **Arreglar la degradación.** La compuerta hizo su trabajo.
- **Aprobarla explícitamente** con `bin/perf-check <perfil> --update-baseline` y
  comitear la nueva línea base, explicando en el mensaje del commit POR QUÉ la
  degradación es aceptable.

Lo que no es legítimo: subir `PERF_DRIFT_PCT` para que deje de molestar. Eso
convierte la compuerta en decoración y el próximo cambio pasa sin revisión.

## 5. Archiva la evidencia cuando entregues

`tests/load/results/` es directorio de trabajo y no se versiona. Cuando entregues
una versión al cliente, copia el reporte a donde vivan los entregables del
proyecto. El reporte incluye una sección de alcance que dice explícitamente qué
no se midió — no la borres: es lo que evita que la evidencia se lea como una
garantía más amplia de la que es.

## 6. Revisa la compuerta cuando cambie la infraestructura

Un cambio de región, de plan, de runtime o de plataforma invalida la línea base.
Después de un cambio de infraestructura, vuelve al paso 3 en lugar de dejar que
la compuerta bloquee cada corrida hasta que alguien la desactive.

## Señales de que la compuerta perdió credibilidad

- Alguien añadió `continue-on-error` o `|| true` al paso de CI.
- La línea base se actualizó tres veces en una semana sin explicación.
- El equipo relanza el trabajo esperando que "esta vez pase".

Las tres significan lo mismo: la compuerta está midiendo algo demasiado
inestable, o su umbral está mal calibrado. Arréglalo en la compuerta, no en la
tolerancia del equipo.
