import assert from "node:assert/strict";
import { Given, When, Then, World } from "@cucumber/cucumber";

// Los steps comparan un valor esperado contra uno observado del producto.
// Un step que no compara nada pasa siempre y no prueba nada: por eso el
// validador exige que cada escenario ejecute y termine en PASSED.

Given("un carrito con {int} unidades de {float}", function (qty, price) {
  this.items = [{ qty, price }];
});

Given("se agrega {int} unidad de {float}", function (qty, price) {
  this.items.push({ qty, price });
});

When("se calcula el total", function () {
  this.total = this.items.reduce((sum, i) => sum + i.price * i.qty, 0);
});

Then("el total es {float}", function (expected) {
  assert.equal(this.total, expected);
});
