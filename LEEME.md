# Panel USB

Panel de control del PC que se abre en el Chrome del celular Android a través del cable USB.
No hay que instalar ninguna app en el celular y no se expone nada a la red Wi-Fi.

## Requisitos (una sola vez)

1. **adb** (herramientas oficiales de Google):
   `winget install Google.PlatformTools` y luego cierra y vuelve a abrir la terminal.
2. En el celular: **Ajustes > Acerca del teléfono**, toca 7 veces **Número de compilación**, y después
   **Opciones de desarrollador > Depuración USB**. Al conectar el cable, acepta "Permitir depuración USB".

## Usar

- Doble clic en `iniciar.cmd`, o en una terminal ejecuta `.\iniciar.ps1`.
- Para probarlo sin celular: `.\iniciar.ps1 -SoloPC`.
- Para detenerlo, pulsa Ctrl+C o cierra la ventana.
- Si desconectas el cable con el panel en marcha, al volver a conectarlo el panel se recupera solo en unos segundos.

### Por Wi-Fi (sin cable)

- Usa el icono **Panel Wi-Fi** (o `iniciar-wifi.cmd`, o `.\iniciar.ps1 -Wifi`). El celular tiene que estar en la misma red que el PC.
- La ventana muestra la dirección para abrir en el celular (`http://IP-del-PC:8787/#t=...`). Si el cable está conectado
  al arrancar, el script se la abre solo y luego puedes desconectarlo.
- Ábrela una vez así y después agrégala a la pantalla principal desde Chrome; el icono recordará el token.
- La red debe estar marcada como **Privada** en Windows. Si el router cambia la IP del PC, hay que volver a abrir la
  dirección nueva (se evita reservando la IP del PC en el router).
- En este modo el panel queda accesible desde tu red local, siempre con el token. Úsalo solo en redes de confianza
  (la de tu casa), no en redes públicas. El modo USB normal no expone nada a la red.

### Si no abre en el celular

- La ventana dice "Esperando al celular…": desbloquea el celular. Si aparece "Permitir depuración USB",
  marca **Permitir siempre desde este ordenador** y acepta. El script espera hasta 60 segundos.
- Al pulsar el icono con el panel ya abierto, solo se vuelve a abrir en el celular (no se arranca otro).

### Pantalla completa

- El primer toque en el panel lo pone a pantalla completa y en horizontal. También puedes usar el botón ⛶ de la esquina del reloj.
- Mientras el panel está abierto, la pantalla del celular no se apaga.
- Para salir de la pantalla completa, desliza desde arriba y pulsa Atrás, o toca el botón otra vez.

### Como app en la pantalla de inicio

En Chrome del celular: menú ⋮ > **Agregar a pantalla principal**. El icono abre el panel directamente a pantalla completa.
Solo funciona mientras `iniciar.cmd` está en marcha en el PC con el cable conectado.

El token de acceso se guarda en `.token`. Si lo borras se genera uno nuevo y tendrás que volver a abrir el panel desde el script.

## Páginas

Desliza a los lados (o usa las flechas del teclado) para cambiar de página. Funciona mejor con el celular en horizontal.

1. **Inicio**: reloj, la canción que suena en el PC (con carátula, progreso y controles), volumen, y CPU, RAM, red y disco con gráficas.
2. **Sistema**: indicadores circulares y los botones de atajos.
3. **Rendimiento**: historial de CPU, RAM y red de los últimos 3 minutos, y el uso de cada núcleo.
4. **Procesos**: los programas que más CPU y memoria usan, agrupados (por ejemplo, todas las ventanas de Chrome juntas).
   Los servicios protegidos de Windows no se pueden medir sin permisos de administrador.
5. **Enfoque**: temporizador pomodoro (enfoque, descanso y descanso largo, con vibración y sonido al terminar) y lista de tareas.
   Las tareas se guardan en el PC, en `data/tareas.json`.
6. **Calendario**: el mes actual, relojes del mundo y el clima.
7. **Discord**: compartir pantalla, silenciar el micrófono, ensordecer, modo streamer y abrir Discord. Indica si Discord está abierto en el PC.
   Los botones envían atajos globales, que hay que configurar una vez en Discord
   (Ajustes de usuario → Atajos de teclado → Añadir un atajo):
   `Ctrl+Shift+F11` compartir pantalla, `Ctrl+Shift+F7` silencio, `Ctrl+Shift+F8` ensordecer, `Ctrl+Shift+F9` modo streamer.
   Compartir pantalla solo funciona estando en un canal de voz, y transmite la ventana o el juego que esté al frente en el PC.
   Puedes cambiar los atajos en `config.json` (grupo `"discord"`, campo `"keys"` en formato SendKeys).
8. **Comandos**: botones de comandos y la consola donde se ve su resultado.

### Ajustes de estas páginas en `config.json`

- `"relojes"`: lista de `{ "nombre": "...", "zona": "America/New_York" }` (zonas horarias IANA, máximo 6).
- `"pomodoro"`: minutos de `enfoque`, `descanso` y `largo`.
- `"clima"`: viene desactivado. Para activarlo pon `"activo": true`, `"ciudad"`, `"lat"` y `"lon"`.
  El servidor consulta Open-Meteo (gratis, sin cuenta) cada 15 minutos y le envía esas coordenadas redondeadas.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

Cada grupo tiene `"place"`: `"atajos"` (página Sistema, hasta 12 botones), `"enfoque"` (página Enfoque, debajo de las tareas, hasta 4),
`"discord"`, `"comandos"` o `"media"`.
Los botones `prev`, `playpause` y `next` del grupo `media` son los que usa la tarjeta de música.

Cada botón admite `"icon"` y `"color"` (por ejemplo `"#2dd4bf"`). Iconos disponibles:
`play` `pause` `prev` `next` `vol` `mute` `music` `folder` `download` `briefcase` `globe` `calculator`
`scissors` `activity` `monitor` `flame` `wifi` `clock` `lock` `moon` `terminal`.

| type      | campos                       | ejemplo                                                |
|-----------|------------------------------|--------------------------------------------------------|
| `open`    | `target`, `args` (opcional)  | programa, carpeta o URL: `"target": "notepad.exe"`     |
| `media`   | `key`, `repeat`              | `prev` `next` `playpause` `stop` `mute` `volup` `voldown` |
| `keys`    | `keys` (formato SendKeys)    | `"^c"` = Ctrl+C, `"%{TAB}"` = Alt+Tab, `"^+{ESC}"`     |
| `command` | `command`, `cwd`, `timeout`  | cualquier PowerShell; su salida se muestra en el celular |

Si añades `"confirm": true` a un botón, pedirá confirmación antes de ejecutarse.

## Seguridad

- En modo USB el servidor solo escucha en `127.0.0.1`; el celular llega a él únicamente por el túnel `adb reverse`.
  En modo Wi-Fi también escucha en la IP local del PC y solo acepta conexiones desde direcciones de red privada.
- Cada sesión usa un token aleatorio y rechaza peticiones con otro nombre de host (protección contra DNS rebinding).
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
