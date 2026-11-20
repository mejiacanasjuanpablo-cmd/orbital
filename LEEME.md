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
3. **Comandos**: botones de comandos y la consola donde se ve su resultado.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

Cada grupo tiene `"place"`: `"atajos"` (página 2, hasta 12 botones), `"comandos"` (página 3) o `"media"`.
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

- El servidor solo escucha en `127.0.0.1`. El celular llega a él únicamente por el túnel `adb reverse`.
- Cada sesión usa un token aleatorio y rechaza peticiones con otro nombre de host (protección contra DNS rebinding).
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
