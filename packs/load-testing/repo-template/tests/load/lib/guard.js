// El guard: prueba que el objetivo es la aplicación real ANTES de medir nada.
//
// Sin esta verificación, apuntar k6 a un recurso protegido (preview de Vercel con
// Deployment Protection, servicio de Cloud Run detrás de IAP) produce el peor
// resultado posible: la plataforma responde su pantalla de autenticación en
// pocos milisegundos, todos los umbrales pasan en verde, y el reporte afirma un
// rendimiento excelente sobre una aplicación que nunca se ejecutó.
//
// El guard corre en setup(), una sola vez, y aborta el test completo (exit 108)
// si no puede demostrar que respondió la aplicación.

import http from 'k6/http';
import { isAuthHost } from './target.js';
import { abortWithReason } from './abort.js';

export function assertRealApp(target, headers) {
  const url = `${target.base}${target.guardPath}`;
  const requestHeaders = headers || target.headers;

  // Un objetivo autenticado sin marcador es indistinguible de su pantalla de
  // login: ambos devuelven 200 y HTML. Exigir el marcador es lo que convierte
  // este guard en una prueba y no en una suposición.
  if (target.mode !== 'none' && !target.appMarker) {
    abortWithReason(
      `PERF_AUTH=${target.mode} exige PERF_APP_MARKER. Sin un texto que sólo ` +
        'exista en tu aplicación, no se puede distinguir la app de la pantalla ' +
        'de autenticación de la plataforma: ambas responden 200 con HTML.'
    );
  }

  // redirects: 0 expone la redirección cruda. Con el seguimiento automático de
  // k6, un 302 al login se ve como un 200 exitoso en otro host.
  const res = http.get(url, {
    headers: requestHeaders,
    redirects: 0,
    tags: { guard: 'true' },
  });

  if (res.status >= 300 && res.status < 400) {
    const location = res.headers['Location'] || res.headers['location'] || '';
    if (isAuthHost(location)) {
      abortWithReason(
        `El objetivo redirigió a una pantalla de autenticación (${res.status} -> ${location}). ` +
          credentialHint(target)
      );
    }
    abortWithReason(
      `El objetivo respondió ${res.status} -> ${location}. Apunta PERF_GUARD_PATH ` +
        'a la ruta final de la aplicación en lugar de una que redirige.'
    );
  }

  if (res.status === 401 || res.status === 403) {
    abortWithReason(
      `El objetivo rechazó la credencial (${res.status}). ` + credentialHint(target)
    );
  }

  if (res.status !== 200) {
    abortWithReason(
      `El guard esperaba 200 en ${url} y recibió ${res.status}. ` +
        'La aplicación no está sirviendo su ruta canónica.'
    );
  }

  if (target.appMarker && !(res.body || '').includes(target.appMarker)) {
    abortWithReason(
      `${url} respondió 200 pero su cuerpo no contiene PERF_APP_MARKER ` +
        `("${target.appMarker}"). Algo respondió, pero no fue tu aplicación: ` +
        'lo más probable es una pantalla de autenticación o una página de error ' +
        'de la plataforma.'
    );
  }

  return { verifiedAt: url, status: res.status };
}

function credentialHint(target) {
  switch (target.mode) {
    case 'iap':
      return (
        'Regenera el ID token con `gcloud auth print-identity-token ' +
        '--audiences=<IAP_OAUTH_CLIENT_ID>`. El audience debe ser el client ID de ' +
        'OAuth de IAP, no la URL del servicio; un audience equivocado produce 401 ' +
        'aunque el token sea válido. El token expira en ~1 hora.'
      );
    case 'vercel-bypass':
      return (
        'Verifica VERCEL_AUTOMATION_BYPASS_SECRET contra Vercel > Project > ' +
        'Settings > Deployment Protection > Protection Bypass for Automation.'
      );
    case 'bearer':
      return 'Verifica PERF_BEARER: puede estar vencido o no tener los permisos de la ruta.';
    default:
      return (
        'PERF_AUTH=none, pero el objetivo exige autenticación. Configura el modo ' +
        'que corresponde a esta plataforma.'
      );
  }
}
