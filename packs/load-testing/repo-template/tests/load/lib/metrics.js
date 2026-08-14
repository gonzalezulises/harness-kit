// Métricas y umbrales.
//
// Hallazgo que define este archivo (medido contra k6 v2.1.0): un error de runtime
// dentro de la función por defecto NO hace fallar el test. k6 sale con código 0,
// reporta las iteraciones como completadas, y un umbral `checks: ['rate==1.0']`
// tampoco lo detecta, porque un umbral de tasa sobre una métrica sin muestras se
// evalúa como aprobado.
//
// Lo que sí lo detecta es un contador propio con un umbral de cuenta ABSOLUTA:
// si el script se rompe, el contador nunca se incrementa, la cuenta queda en 0 y
// el umbral falla (exit 99). Ese es el único motivo por el que existe
// `perf_completed`: no es telemetría, es el detector de scripts rotos.
//
//   sin contador  : script roto -> exit 0   (falso verde)
//   con contador  : script roto -> exit 99  (falla correctamente)

import { Counter } from 'k6/metrics';

// Se incrementa una vez al FINAL de cada iteración. Colocarlo al final es
// deliberado: si algo truena antes, no se incrementa.
export const completed = new Counter('perf_completed');

export function markCompleted() {
  completed.add(1);
}

// k6 sólo calcula avg/min/med/max/p(90)/p(95) por defecto. Sin declarar p(99)
// aquí, el reporte de evidencia lo muestra vacío.
export const TREND_STATS = ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'];

// Umbrales configurables. Los valores por defecto son deliberadamente laxos:
// un umbral apretado sobre infraestructura compartida produce fallas
// intermitentes, y una compuerta que da falsas alarmas se termina ignorando.
export function buildThresholds({ expectedIterations, p95 = null }) {
  const p95Limit = Number(__ENV.PERF_P95_MS || p95 || 1500);
  const errorRate = Number(__ENV.PERF_ERROR_RATE || 0.01);

  return {
    // El detector de scripts rotos. Cuenta absoluta, no tasa.
    perf_completed: [`count>=${expectedIterations}`],

    // Errores HTTP. abortOnFail corta la corrida en vez de gastar minutos
    // midiendo un servicio que ya está caído.
    http_req_failed: [{ threshold: `rate<${errorRate}`, abortOnFail: true }],

    // Latencia. p(95) y no promedio: el promedio esconde la cola.
    http_req_duration: [`p(95)<${p95Limit}`],

    // Las respuestas del guard no deben contaminar la medición de la aplicación.
    'http_req_duration{guard:true}': [`p(95)<${p95Limit * 4}`],
  };
}
