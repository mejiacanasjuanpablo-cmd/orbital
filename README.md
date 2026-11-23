# Panel del PC

Panel de control del PC que se abre en el navegador del celular. Incluye:

- música y volumen, y un mezclador con el volumen de cada aplicación y la salida de audio;
- CPU, RAM, red y disco, con su historial y los procesos que más consumen;
- pomodoro y lista de tareas;
- calendario, relojes del mundo y clima;
- controles de Discord;
- botones de atajos y de comandos.

Se conecta por la red Wi-Fi de la casa, escaneando un código QR, o por cable USB. No hay que instalar nada en el celular, y en el PC solo necesita Node.js y PowerShell, sin otras dependencias.

![Página de inicio del panel](docs/historia/portada.png)

## Usarlo

- **Guía completa (USB y Wi-Fi):** [LEEME.md](LEEME.md)
- **Guía de la edición solo Wi-Fi** (la que va en el .zip para compartir): [LEEME-wifi.md](LEEME-wifi.md)
- **En corto:** doble clic en `instalar.cmd`, que revisa los requisitos y crea la ventana del panel y los iconos. Luego abre **Panel Wi-Fi**, escanea el QR con el celular y acepta el aviso en el PC.

## Versiones

| Etiqueta | Fecha | Qué trae |
|---|---|---|
| `v1.0` | 20 nov 2026 | Versión inicial: unos cuantos botones (atajos, monitor y comandos) por cable USB |
| `v2.0` | 20 nov 2026 | UI mejorado: diseño oscuro con tarjetas, música, páginas deslizables, pantalla completa y modo app |
| `v3.0` | 20 nov 2026 | Más pantallas y widgets: Rendimiento, Procesos, Enfoque y Calendario con clima |
| `v4.0` | 21 nov 2026 | Wi-Fi, con el cable USB como puente para autorizar el celular |
| `v5.0` | 21 nov 2026 | Solo Wi-Fi: código QR y aprobación en el PC, sin modo desarrollador; .zip para compartir |
| `v6.0` | 21 nov 2026 | Ventana propia en el PC, sin consola: QR, dispositivos, actividad, cambio de modo e icono junto al reloj |

El recorrido por cada versión, con capturas y todos los cambios, está en **[HISTORIA.md](HISTORIA.md)**.

## Estructura

| Archivo | Para qué |
|---|---|
| `server.js` | Servidor HTTP en Node, sin dependencias |
| `public/` | La página del celular (`index.html`), la de espera de aprobación (`espera.html`) y el manifest de la app |
| `lib/media.ps1` | Música que suena en el PC, controles de música y volumen |
| `lib/mezclador.ps1` | Mezclador: volumen, silencio y nivel de sonido de cada aplicación, y salida de audio |
| `lib/keys.ps1` | Atajos de teclado (SendInput con scan codes) |
| `lib/qr.js` | Generador de códigos QR, hecho desde cero |
| `lib/aprobacion.js`, `lib/allow.js` | Aprobación de dispositivos nuevos y lista de dispositivos permitidos en modo Wi-Fi |
| `lib/requisitos.ps1` | Revisión de requisitos (la usan `verificar`, `instalar`, `iniciar` y la ventana) |
| `ventana.ps1` | La ventana del panel en el PC: QR, estado, dispositivos, actividad e icono junto al reloj |
| `lib/lanzador.cs` | `Panel del PC.exe`, que abre la ventana sin consola (lo compila `instalar` en cada PC) |
| `lib/arranque.ps1` | Arranque compartido por la ventana y el modo consola: token, red, cable USB y servidor |
| `iniciar.cmd`, `iniciar-wifi.cmd` | Abren la ventana del panel por USB o por Wi-Fi |
| `iniciar.ps1` | Modo consola, con los mensajes del servidor a la vista |
| `instalar.*`, `verificar.*`, `empaquetar.ps1` | Instalación, verificación de requisitos y .zip para compartir |

## Datos personales

`.token`, `config.json`, `data/` y `debug.log` son de cada PC y están en `.gitignore`, así que nunca se suben.
La configuración de ejemplo es `config.ejemplo.json`; la primera vez, el servidor crea `config.json` a partir de ella.
