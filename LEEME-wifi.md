# Panel del PC (edición Wi-Fi)

Panel de control del PC que se abre en el navegador del celular por la red Wi-Fi de la casa.
No hay que instalar ninguna app en el celular ni activar nada en sus ajustes. Funciona en Windows 10 y 11.

## Instalación (una sola vez)

1. Descomprime el .zip en una carpeta fija (por ejemplo, en Documentos). No lo ejecutes desde dentro del .zip.
2. Doble clic en **`instalar.cmd`**. Revisa los requisitos y pregunta antes de instalar lo que falte
   (**Node.js 18 o superior**, con winget; si el PC no tiene winget, abre la página oficial).
   También crea `config.json`, la ventana del panel (`Panel del PC.exe`, que se compila en el propio PC con lo que trae
   Windows) y el icono **Panel Wi-Fi** en el menú Inicio.
   Si Windows avisa de que el archivo viene de internet, elige **Más información → Ejecutar de todas formas**.
3. La primera vez que abras el panel, Windows puede preguntar si permites que Node.js use la red:
   permítelo en **redes privadas**.

## Usar

1. Abre **Panel Wi-Fi** desde el menú Inicio. Se abre la ventana del panel con un **código QR**.
2. Con el celular conectado a la **misma red Wi-Fi** que el PC, escanea el QR con la cámara.
   Se abre el panel en el navegador (si se abre en uno que no sea Chrome, usa "Abrir en Chrome").
3. **La primera vez, el PC pide permiso:** aparece el aviso "Panel del PC: dispositivo nuevo" con la IP y el modelo
   del celular. Pulsa **Sí** y el panel se abre solo en el celular.
   Pulsa **No** si no lo reconoces: ese dispositivo no podrá volver a pedir acceso hasta que reinicies el panel.
4. En el celular, en Chrome: menú ⋮ > **Agregar a pantalla principal**. Desde ese icono se abre directo y a pantalla completa.

- La ventana también muestra los dispositivos autorizados, con un botón **Quitar** para cada uno, y la actividad:
  los botones que pulsas desde el celular y los dispositivos que piden entrar.
- **Cerrar la ventana no detiene el panel:** sigue funcionando y queda un icono junto al reloj. Para volver a la ventana,
  haz clic en ese icono o abre otra vez **Panel Wi-Fi**. Para detenerlo, pulsa **Detener el panel**.
- Si el celular dice "Sin conexión", revisa que el panel siga en marcha en el PC y que el celular esté en la misma red.
- Si el router cambia la IP del PC o del celular, el icono deja de funcionar: abre Panel Wi-Fi, vuelve a escanear el QR
  y aprueba el aviso. Para evitarlo, reserva esas IP en el router.
- La red del PC debe estar marcada como **Privada** en Windows (Configuración > Red e Internet > propiedades de la red).

### Pantalla completa

- El primer toque en el panel lo pone a pantalla completa y en horizontal. También puedes usar el botón ⛶ de la esquina del reloj.
- Mientras el panel está abierto, la pantalla del celular no se apaga.

## Páginas

Desliza a los lados para cambiar de página. Funciona mejor con el celular en horizontal.

1. **Inicio**: reloj, la canción que suena en el PC (con carátula, progreso y controles), volumen, y CPU, RAM, red y disco.
2. **Sistema**: indicadores circulares y los botones de atajos.
3. **Rendimiento**: historial de CPU, RAM y red de los últimos 3 minutos, y el uso de cada núcleo.
4. **Procesos**: los programas que más CPU y memoria usan, agrupados.
5. **Enfoque**: temporizador pomodoro, lista de tareas (se guarda en el PC, en `data/tareas.json`) y botones de acceso rápido.
6. **Calendario**: el mes actual, relojes del mundo y el clima.
7. **Discord**: compartir pantalla, silenciar el micrófono, ensordecer, modo streamer y abrir Discord.
   Los botones envían atajos globales que hay que configurar una vez en Discord
   (Ajustes de usuario → Atajos de teclado → Añadir un atajo):
   `Ctrl+Shift+F11` compartir pantalla, `Ctrl+Shift+F7` silencio, `Ctrl+Shift+F8` ensordecer, `Ctrl+Shift+F9` modo streamer.
8. **Comandos**: botones de comandos y la consola donde se ve su resultado.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

- `"relojes"`: lista de `{ "nombre": "...", "zona": "America/New_York" }` (zonas horarias IANA, máximo 6).
- `"pomodoro"`: minutos de `enfoque`, `descanso` y `largo`.
- `"clima"`: viene desactivado. Para activarlo pon `"activo": true` y tu `"ciudad"`, `"lat"` y `"lon"` (usa Open-Meteo, gratis).
- `"wifi"` → `"dispositivos"`: los celulares aprobados. Para quitarle el acceso a uno, borra su IP.

Cada grupo de botones tiene `"place"`: `"atajos"` (página Sistema, hasta 12), `"enfoque"` (página Enfoque, hasta 4),
`"discord"`, `"comandos"` o `"media"`. Cada botón admite `"label"`, `"icon"` y `"color"` (por ejemplo `"#2dd4bf"`).
Iconos: `play` `pause` `prev` `next` `vol` `mute` `music` `folder` `download` `briefcase` `globe` `calculator`
`scissors` `activity` `monitor` `flame` `wifi` `clock` `lock` `moon` `terminal` `book` `share` `mic` `headphones` `eye` `chat`.

| type      | campos                       | ejemplo                                                |
|-----------|------------------------------|--------------------------------------------------------|
| `open`    | `target`, `args` (opcional)  | programa, carpeta o URL: `"target": "notepad.exe"`     |
| `media`   | `key`, `repeat`              | `prev` `next` `playpause` `stop` `mute` `volup` `voldown` |
| `keys`    | `keys` (formato SendKeys)    | `"^c"` = Ctrl+C, `"%{TAB}"` = Alt+Tab, `"^+{ESC}"`     |
| `command` | `command`, `cwd`, `timeout`  | cualquier PowerShell; su salida se muestra en el celular |

Si añades `"confirm": true` a un botón, pedirá confirmación antes de ejecutarse.

## Verificar requisitos

Doble clic en **`verificar.cmd`** en cualquier momento: revisa los archivos del panel, Windows, PowerShell, .NET Framework,
Node.js, los componentes de Windows que usa el panel (atajos, volumen y música), el puerto 8787, la red local y el firewall.
Si falta algo obligatorio, lo dice y ofrece instalarlo; el panel tampoco arranca hasta resolverlo.

## Seguridad

- Solo entran el propio PC y los celulares que aprobaste (`wifi.dispositivos`). A cualquier otro equipo de la red se le
  corta la conexión sin responderle.
- Para pedir acceso hace falta el token que va dentro del QR (48 caracteres aleatorios, distinto en cada PC, guardado en `.token`).
  El QR se genera en el propio PC, sin internet. Si crees que alguien vio el QR, borra `.token`: se genera uno nuevo.
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
- La conexión no va cifrada: úsalo solo en redes de confianza (la de tu casa), no en redes públicas.
