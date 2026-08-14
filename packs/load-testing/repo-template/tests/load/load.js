// Prueba de carga — a demanda, NO bloqueante.
//
// Esta corrida sí mide capacidad: rampa de usuarios virtuales hasta el objetivo,
// sostiene, y baja. Su salida es evidencia del paquete de entrega, no una
// compuerta de fusión, por dos razones:
//
//   1. No es determinista. Los arranques en frío de funciones sin servidor y la
//      CPU variable de un ejecutor compartido mueven el p(95) entre corridas.
//   2. Genera costo real. En plataformas que cobran por invocación, una rampa en
//      cada push se factura.
//
// ADVERTENCIA: no ejecutes esto contra el entorno de producción de un cliente sin
// autorización por escrito. Genera tráfico facturable, puede disparar límites de
// tasa, y en varias plataformas contradice los términos de servicio. El objetivo
// correcto es un entorno de preparación o un despliegue de vista previa.

import http from 'k6/http';
import { check } from 'k6';
import { resolveTarget } from './lib/target.js';
import { assertRealApp } from './lib/guard.js';
import { supabaseSession, sessionHeaders } from './lib/session.js';
import { markCompleted, buildThresholds, TREND_STATS } from './lib/metrics.js';
import { buildReport } from './lib/summary.js';

const target = resolveTarget();
const PEAK_VUS = Number(__ENV.PERF_PEAK_VUS || 10);
const RAMP = __ENV.PERF_RAMP || '30s';
const HOLD = __ENV.PERF_HOLD || '1m';

export const options = {
  stages: [
    { duration: RAMP, target: PEAK_VUS },
    { duration: HOLD, target: PEAK_VUS },
    { duration: '10s', target: 0 },
  ],
  // Con una rampa el total de iteraciones no es predecible, así que la cuenta
  // esperada baja a 1: sigue atrapando un script completamente roto, pero ya no
  // puede verificar una cuenta exacta. El verificador (bin/perf-check) cubre el
  // resto contando los errores del registro.
  thresholds: buildThresholds({ expectedIterations: 1 }),
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
    });
  }
  markCompleted();
}

export function handleSummary(data) {
  const meta = { target: target.base, authMode: target.mode, profile: 'load' };
  return {
    'tests/load/results/load-summary.json': JSON.stringify(data, null, 2),
    'tests/load/results/load-report.md': buildReport(data, meta),
  };
}
