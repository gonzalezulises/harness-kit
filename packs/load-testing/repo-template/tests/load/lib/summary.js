// Generación de evidencia a partir del resumen de fin de test.
//
// k6 tiene dos formatos de resumen: el heredado (por defecto) y el nuevo formato
// legible por máquina que se habilita con --new-machine-readable-summary. Los
// lectores de abajo aceptan ambos, porque un pack que sólo entiende uno se rompe
// silenciosamente al cambiar de versión o de flag: devuelve null, el reporte sale
// con guiones, y nadie nota que la evidencia quedó vacía.

// Extrae un valor de métrica sin asumir formato.
export function metricValue(data, metric, stat) {
  const m = data.metrics && data.metrics[metric];
  if (!m) return null;

  // Formato heredado: { values: { 'p(95)': 12.3, count: 5, rate: 0.5 } }
  if (m.values && m.values[stat] !== undefined) return m.values[stat];

  // Formato nuevo: las estadísticas cuelgan directo de la métrica.
  if (m[stat] !== undefined) return m[stat];

  // El resumen exportado por --summary-export aplana count/value.
  if (stat === 'count' && m.count !== undefined) return m.count;
  if (stat === 'value' && m.value !== undefined) return m.value;

  return null;
}

export function thresholdFailures(data) {
  const failures = [];
  const metrics = data.metrics || {};
  for (const [name, metric] of Object.entries(metrics)) {
    const th = metric.thresholds;
    if (!th) continue;
    for (const [expression, result] of Object.entries(th)) {
      // Heredado: { 'p(95)<500': { ok: false } }. Nuevo: booleano directo.
      const ok = typeof result === 'boolean' ? result : result && result.ok;
      if (ok === false) failures.push(`${name}: ${expression}`);
    }
  }
  return failures;
}

function fmt(value, unit = 'ms', digits = 1) {
  if (value === null || value === undefined) return '—';
  return `${Number(value).toFixed(digits)} ${unit}`;
}

// Reporte legible destinado al paquete de entrega. Markdown y no HTML a
// propósito: se versiona, se revisa en un diff, y se pega en un informe.
export function buildReport(data, meta) {
  const failures = thresholdFailures(data);
  const passed = failures.length === 0;

  const lines = [
    `# Evidencia de rendimiento — ${meta.profile}`,
    '',
    `- **Objetivo:** \`${meta.target}\``,
    `- **Modo de autenticación:** \`${meta.authMode}\``,
    `- **Perfil:** \`${meta.profile}\``,
    `- **Resultado:** ${passed ? 'APROBADO' : 'NO APROBADO'}`,
    '',
    '## Umbrales',
    '',
  ];

  if (passed) {
    lines.push('Todos los umbrales declarados se cumplieron.', '');
  } else {
    lines.push('Umbrales incumplidos:', '');
    for (const f of failures) lines.push(`- \`${f}\``);
    lines.push('');
  }

  const reqs = metricValue(data, 'http_reqs', 'count');
  const iterations = metricValue(data, 'perf_completed', 'count');
  const failRate = metricValue(data, 'http_req_failed', 'rate');

  lines.push(
    '## Mediciones',
    '',
    '| Medición | Valor |',
    '|---|---|',
    `| Peticiones HTTP | ${reqs === null ? '—' : reqs} |`,
    `| Iteraciones completadas | ${iterations === null ? '—' : iterations} |`,
    `| Tasa de error | ${failRate === null ? '—' : (failRate * 100).toFixed(2) + ' %'} |`,
    `| Latencia p(50) | ${fmt(metricValue(data, 'http_req_duration', 'med'))} |`,
    `| Latencia p(95) | ${fmt(metricValue(data, 'http_req_duration', 'p(95)'))} |`,
    `| Latencia p(99) | ${fmt(metricValue(data, 'http_req_duration', 'p(99)'))} |`,
    `| Latencia máxima | ${fmt(metricValue(data, 'http_req_duration', 'max'))} |`,
    '',
    '## Alcance de esta evidencia',
    '',
    'Esta corrida midió las rutas declaradas en `PERF_ROUTES` contra el objetivo',
    'indicado arriba, y sólo después de que el guard confirmara que respondió la',
    'aplicación real. No cubre rutas no declaradas, ni caminos autenticados por',
    'usuario final, ni comportamiento bajo carga sostenida más allá del perfil',
    'ejecutado.',
    '',
  );

  return lines.join('\n');
}
