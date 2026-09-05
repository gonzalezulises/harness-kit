# Contratos propuestos

Los schemas usan JSON Schema Draft 2020-12 y no requieren un servicio remoto. Los `$id` URN son identificadores locales. Los cuatro YAML sólo validan como `PROPOSED_NON_AUTHORITATIVE` y `activation: false`: cambiar esos campos no activa nada y deja de validar como propuesta.

| Documento | Schema |
|---|---|
| `autonomy-policy.v1.yaml` | `autonomy-policy.schema.json` |
| `mechanical-change-policy.v1.yaml` | `mechanical-change-policy.schema.json` |
| `release-execution-policy.v1.yaml` | `release-execution-policy.schema.json` |
| `stop-taxonomy.v1.yaml` | `stop-taxonomy.schema.json` |

`records.schema.json` define `$defs` reutilizables para authority_binding, triple identidad, prueba, human gate, continuation grant, release objective y stop record. Al validar un registro debe seleccionarse su `$defs` concreto: el documento raíz es un contenedor, no un validador genérico de registros.

Los enums, proof kinds, arrays obligatorios y campos adicionales cerrados evitan ambigüedad estructural. Los invariantes de seguridad del diseño v1 están fijados; cambiarlos exige una versión del schema y decisión normativa, no una edición silenciosa. Un perfil puede reducir capabilities, pero no eliminar pruebas mínimas para ampliar autonomía.

**Límite:** validación de schema no demuestra que un hash exista, que una firma sea auténtica, que un authority_binding de rol derived pueda actuar como normative, que no haya revocaciones o que un proof describa una ejecución real. Eso lo verifica el runtime de H03–H08 con inputs y recibos confiables. No se aceptan booleans del agente en sustitución de esas comprobaciones.

Los schemas se validaron sintácticamente y los YAML contra ellos. También se comprobaron negativas de activación, clases/capabilities desconocidas, falta de pruebas, pérdida de condiciones de producción y autoaprobación. Estas comprobaciones son QA de contratos propuestos, no PASS del motor que aún no existe.
