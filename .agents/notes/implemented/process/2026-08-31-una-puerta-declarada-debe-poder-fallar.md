# Una puerta declarada tiene que poder fallar

El instalador fabricaba puertas que no verificaban nada. `bin/harness-init.sh` resolvía así el
comando de e2e cuando no encontraba uno en el proyecto destino:

```
[[ -n "$E2E_CMD" ]] || E2E_CMD="echo 'TODO: set the end-to-end command'"
```

Ese target sale 0. Y `AGENTS.md` declara la capa 3 obligatoria para todo cambio que cruce una
frontera de componente. El resultado es la peor combinación posible: un contrato que exige una
verificación, y una verificación que no puede fallar. Se detectó en tres repos instalados
(climalab, pcf-evaluator, portal-expediente-kyc), donde la capa obligatoria llevaba meses en
verde sin abrir un navegador.

Lo revelador es que la línea de al lado ya estaba bien: `VERIFY_CMD` termina en `; false` desde
siempre. No era una decisión de diseño, era un olvido de una línea, y el kit no tenía forma de
notarlo.

**La decisión.** Tres cambios que se sostienen entre sí. (1) El default de `E2E_CMD` termina en
`; false`, igual que `VERIFY_CMD`: una puerta sin implementar bloquea hasta que alguien la
implemente. (2) `scripts/verify-makefile-gates.sh` falla si cualquier target anuncia un TODO y
aún así sale 0, o si no ejecuta nada; queda registrado en `make gates` (quick y full), así que
corre en cada repo instalado sin que nadie se acuerde. (3) La suite comprueba que todo script
del template que `run-gates.sh` registra llegue efectivamente al repo destino.

El (3) importa más de lo que parece. `run-gates.sh` hace SKIP —no FAIL— cuando falta el script
de un gate, y eso es deliberado: `verify-version-sync.sh` es del kit y no debe correr en un repo
instalado. Pero ese mismo SKIP convierte cualquier olvido del instalador en un gate que no corre
nunca y no se queja. La lista de `render` en `harness-init.sh` es explícita, así que el olvido
es cuestión de tiempo. Ahora se detecta al instalar.

**Alternativas rechazadas.** Convertir el SKIP en FAIL: parecía lo coherente con el resto del kit,
que es fail-closed en todo, pero rompe el único mecanismo que permite compartir `run-gates.sh`
entre el kit y sus instalaciones, y habría dejado en rojo a todo repo nuevo por un gate que ahí
no aplica. Escribir el verificador como test del stack (vitest, cargo test): el kit instala en
repos Node, Rust y Go, así que un verificador propio del kit tiene que ser bash.

**Lo que se cedió.** `make e2e` recién instalado ahora falla, y eso se ve en el primer `make gates`
de un repo nuevo. Es intencional: es la diferencia entre una tarea pendiente visible y una
verificación fantasma. Quien no quiera la capa 3 todavía, borra el target; no lo deja mintiendo.

**Un efecto de borde que conviene recordar.** `required-quality.yml` copia
`scripts/verify-claims.sh` desde la base protegida encima del del head durante su paso de
claims: es la propiedad que impide que una PR debilite al juez que la evalúa. Pero la suite del
repo corre DENTRO de ese paso, así que cualquier prueba que inspeccione ese archivo está mirando
la versión de la base, no la del commit. Costó dos corridas en rojo con todo verde en local —
aquí el falso positivo fue la comparación de drift entre `scripts/` y `templates/full/scripts/`.
`CLAIMS_BASE_FILE` la exporta exactamente ese paso, así que sirve de marca: cuando está presente,
el contenido se lee de `git show HEAD:...`; fuera, manda el árbol de trabajo, que es lo que hace
falta para escribir la prueba en rojo antes que el arreglo.

**Condición de revisión.** Si aparece un target legítimo cuyo trabajo es solo imprimir, se declara
en `HARNESS_INFORMATIONAL_TARGETS` con su razón — es la salida documentada, y `help` ya la usa.
