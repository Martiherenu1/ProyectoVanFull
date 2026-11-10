// Este helper local no carga Maps hasta recibir configuración Web completa.
(() => {
  let carga;
  let claveInicial;
  window.vanfullMapsPreparar = (clave, mapIdWeb) => {
    if (typeof clave !== 'string' || !clave.trim() ||
        typeof mapIdWeb !== 'string' || !mapIdWeb.trim()) {
      return Promise.resolve(false);
    }
    // Una clave diferente requiere recargar la página, no otro script.
    if (carga) return clave === claveInicial ? carga : Promise.resolve(false);
    claveInicial = clave;
    carga = new Promise((resolve) => {
      const script = document.createElement('script');
      window.vanfullMapsPreparado = () => resolve(Boolean(
        window.google?.maps?.Map &&
        window.google?.maps?.marker?.AdvancedMarkerElement));
      window.gm_authFailure = () => resolve(false);
      script.async = true;
      const url = new URL('https://maps.googleapis.com/maps/api/js');
      url.searchParams.set('key', clave);
      url.searchParams.set('callback', 'vanfullMapsPreparado');
      url.searchParams.set('libraries', 'marker');
      url.searchParams.set('loading', 'async');
      url.searchParams.set('v', 'quarterly');
      script.src = url.toString();
      script.onerror = () => resolve(false);
      document.head.append(script);
    });
    return carga;
  };
})();
