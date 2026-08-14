// Aborto del test con un motivo legible.
//
// Vive en su propio módulo para romper un ciclo de importación: `target.js`
// necesita abortar, `session.js` necesita abortar, y `target.js` necesita a
// `session.js`. Con la función aquí, ninguno de los dos se importa al otro.
//
// Abortar produce el código de salida 108, distinto del 99 de un umbral
// incumplido. Esa diferencia importa: 99 significa "se midió y no cumplió",
// 108 significa "no se midió nada". Confundirlos convierte un problema de
// configuración en un falso informe de rendimiento.

import exec from 'k6/execution';

export function abortWithReason(reason) {
  exec.test.abort(reason);
}
