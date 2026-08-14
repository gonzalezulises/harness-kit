# Especificación ejecutable: esto es el criterio de aceptación, no documentación.
# El tag @SCN- da identidad al escenario para poder trazar su evidencia.
Feature: Total del carrito
  Como cliente quiero que el total refleje precio por cantidad
  para no pagar de menos ni de más.

  @SCN-001
  Scenario: Suma precio por cantidad
    Given un carrito con 2 unidades de 10.00
    And se agrega 1 unidad de 5.00
    When se calcula el total
    Then el total es 25.00
