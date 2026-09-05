# Semántica formal de paradas y recuperación

Estado: propuesta inactiva, versión 1.0.0. Datos: [stop-taxonomy.v1.yaml](policies/stop-taxonomy.v1.yaml). Schema: [stop-taxonomy.schema.json](schemas/stop-taxonomy.schema.json).

Se separan dos ejes: **veredicto de verificación** y **motivo/disposición operacional**. `AUTO_REMEDIABLE_*` nunca es un veredicto de éxito. Significa que existe una ruta candidata de recuperación; el gate permanece no satisfecho hasta que la nueva operación produce evidencia verificada.

| Veredicto | Interpretación | Salida del registry actual |
|---|---|---|
| PASS | La obligación aplicable se verificó | 0 |
| FAIL | Se verificó una contradicción | 1 |
| NOT_CONFIGURED | Contrato/configuración inválidos | 2 |
| TOOL_FAILURE | Herramienta o entorno no pudo operar | 3 |
| INCOMPLETE | Evidencia ausente, truncada o stale | 4 |
| POLICY | Violación de autoridad o integridad | 5 |
| UNKNOWN | Resultado sin interpretación soportada | Otra salida |
| NOT_EXECUTED | Gate requerido no ejecutado | Estado del runner |

El mapper actual no puede reutilizarse ciegamente para toda CLI: `verify-feature` usa 3 para budget agotado y 4 para bloqueo repetido; `verify-delivery-doc` comenta 3 como NOT_CONFIGURED. H01/H02 deben normalizar los contratos de salida o usar recibos estructurados validados. El stdout que dice «skipped» acompañado de 0 tampoco prueba una obligación; la aplicabilidad debe estar decidida por política previa, separada de PASS.

| Grupo | Tratamiento |
|---|---|
| HUMAN_DECISION | Suspender efectos fuera de grants existentes; emitir contexto, artefactos afectados y decisión mínima. No dejar que un approval genérico gane alcance |
| UNVERIFIED | Suspender claim actual. Una reparación de entorno puede continuar bajo capability aprobada; falta de autoridad, evidencia o budget no autoriza el trabajo por defecto |
| MECHANICAL_RECOVERY | Evaluar prueba + grant si aplica + budget + lease; ejecutar capability cerrada; verificar nueva evidencia; conservar incidente anterior |

Reglas de transición:

1. Un reason code no reemplaza el veredicto que lo originó.
2. `UNKNOWN` o prueba incompleta implica deny. No se rebautiza como mecánico para continuar.
3. El cambio compuesto hereda todas las restricciones; la más restrictiva decide si puede ejecutar.
4. Una reparación consume presupuesto operacional y deja recibo. No consume revisión semántica si no hubo una revisión semántica, pero tampoco genera intentos infinitos gratuitos.
5. Un budget agotado sólo cambia con una nueva autorización identificable; cambiar run_id o reiniciar el proceso no lo borra.
6. Un run terminal conserva su veredicto. La supersesión se expresa en linaje nuevo, nunca como sobrescritura retroactiva.
7. Una decisión humana aprobada incluye hash, owner verificable y scope; la continuidad requiere grant explícito separado. La baseline final nunca tiene autoapproval.

`BLOCKED_BY_UNEXPECTED_COUPLING` puede conservarse como traducción legacy para errores sin mapeo, con disposition `UNKNOWN`. No es la categoría habitual para ausencia de modelo, timeout, config incompatible o evidence stale cuando ya existe un código específico.
