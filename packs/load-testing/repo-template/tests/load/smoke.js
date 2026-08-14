// Smoke de rendimiento — la compuerta bloqueante.
//
// Un solo usuario virtual y pocas iteraciones. No mide capacidad: prueba que las
// rutas críticas responden correctamente y que su latencia no se desplomó. Es
// determinista a propósito, porque es la corrida que puede bloquear una fusión, y
// una compuerta intermitente se termina ignorando.
//
// La prueba de capacidad real vive en load.js y NO bloquea.

import http from 'k6/http';
import { check } from 'k6';
import { resolveTarget } from './lib/target.js';
import { assertRealApp } from './lib/guard.js';
import { supabaseSession, sessionHeaders } from './lib/session.js';
import { markCompleted, buildThresholds, TREND_STATS } from './lib/metrics.js';
import { buildReport } from './lib/summary.js';

const target = resolveTarget();
const ITERATIONS = Number(__ENV.PERF_SMOKE_ITERATIONS || 5);

export const options = {
  vus: 1,
  iterations: ITERATIONS,
  // La cuenta esperada es exacta: una marca por iteración.
  thresholds: buildThresholds({ expectedIterations: ITERATIONS }),
  // Modo compacto: la salida completa entierra el bloque de umbrales en el log de CI.
  summaryMode: 'compact',
  summaryTrendStats: TREND_STATS,
};

// setup() corre una sola vez y es el único lugar donde se puede pedir la sesión:
// k6 prohíbe peticiones HTTP en el contexto de inicialización. Las cabeceras que
// devuelve son las que usa cada iteración.
export function setup() {
  let headers = target.headers;

  if (target.mode === 'supabase') {
    const session = supabaseSession();
    headers = Object.assign({}, headers, sessionHeaders(session));
  }

  // El guard corre CON la sesión puesta: sin ella, una ruta protegida
  // redirigiría al login y el guard lo reportaría como objetivo equivocado.
  assertRealApp(target, headers);

  return { headers: headers };
}

export default function (data) {
  for (const route of target.routes) {
    const res = http.request(route.method, `${target.base}${route.path}`, null, {
      headers: data.headers,
      tags: { route: route.path },
    });

    check(res, {
      [`${route.method} ${route.path} responde 200`]: (r) => r.status === 200,
      [`${route.method} ${route.path} tiene cuerpo`]: (r) => (r.body || '').length > 0,
    });
  }

  // Última línea de la iteración: si algo falló arriba, no se ejecuta y el
  // umbral de cuenta absoluta hace fallar el test.
  markCompleted();
}

export function handleSummary(data) {
  const meta = { target: target.base, authMode: target.mode, profile: 'smoke' };
  return {
    'tests/load/results/smoke-summary.json': JSON.stringify(data, null, 2),
    'tests/load/results/smoke-report.md': buildReport(data, meta),
  };
}
