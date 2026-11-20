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

Consejo: en Chrome del celular, menú ⋮ > **Agregar a pantalla principal** para tenerlo como icono.
Cada vez que arrancas el panel se genera un token nuevo, así que ábrelo siempre desde el script.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

| type      | campos                       | ejemplo                                                |
|-----------|------------------------------|--------------------------------------------------------|
| `open`    | `target`, `args` (opcional)  | programa, carpeta o URL: `"target": "notepad.exe"`     |
| `media`   | `key`, `repeat`              | `prev` `next` `playpause` `stop` `mute` `volup` `voldown` |
| `keys`    | `keys` (formato SendKeys)    | `"^c"` = Ctrl+C, `"%{TAB}"` = Alt+Tab, `"^+{ESC}"`     |
| `command` | `command`, `cwd`, `timeout`  | cualquier PowerShell; su salida se muestra en el celular |

Si añades `"confirm": true` a un botón, pedirá confirmación antes de ejecutarse.
Los grupos cuyos botones son todos de tipo `command` aparecen en la pestaña **Comandos**, y el resto en **Atajos**.

## Seguridad

- El servidor solo escucha en `127.0.0.1`. El celular llega a él únicamente por el túnel `adb reverse`.
- Cada sesión usa un token aleatorio y rechaza peticiones con otro nombre de host (protección contra DNS rebinding).
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
