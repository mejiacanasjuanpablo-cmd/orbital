# Panel USB

Panel de control del PC que se abre en el Chrome de un celular Android, por cable USB o por la red Wi-Fi de la casa.
No hay que instalar ninguna app en el celular. Funciona en Windows 10 y 11.

## Instalación (una sola vez)

1. Descomprime `Panel-USB.zip` en una carpeta fija (por ejemplo, en Documentos). No lo ejecutes desde dentro del .zip.
2. Doble clic en **`instalar.cmd`**. Revisa los requisitos y pregunta antes de instalar lo que falte:
   - **Node.js 18 o superior** (obligatorio). Se instala con winget; si el PC no tiene winget, abre la página oficial.
   - **adb**, las herramientas oficiales de Google (solo para el modo con cable). Se descarga de dl.google.com
     y solo se instala si la firma digital es de Google.
   También crea `config.json`, la ventana del panel (`Panel del PC.exe`, que se compila en el propio PC con lo que trae
   Windows) y los iconos **Panel USB** y **Panel Wi-Fi** en el menú Inicio.
   Si Windows avisa de que el archivo viene de internet, elige **Más información → Ejecutar de todas formas**.
3. **Solo para el modo con cable (USB):** en el celular, **Ajustes > Acerca del teléfono**, toca 7 veces **Número de compilación**,
   y después **Opciones de desarrollador > Depuración USB**. Al conectar el cable, marca **Permitir siempre desde este ordenador**
   y acepta. **Para el modo Wi-Fi no hace falta tocar nada del celular.**

Si mueves la carpeta a otro sitio, vuelve a ejecutar `instalar.cmd` para que los iconos apunten a la nueva ubicación.

### Verificar requisitos

Doble clic en **`verificar.cmd`** en cualquier momento. Revisa y muestra con `[OK]`, `[FALTA]`, `[AVISO]` o `[INFO]`:

| Qué revisa | ¿Obligatorio? |
|---|---|
| Archivos del panel completos | Sí |
| Windows 10/11, PowerShell 5.1 y .NET Framework 4.5+ | Sí |
| Node.js 18 o superior (ofrece instalarlo o actualizarlo) | Sí |
| Componentes de Windows que usa el panel: atajos de teclado, volumen y música | Sí (volumen y música, opcionales) |
| Puerto 8787 libre (o ya en uso por el panel) | Sí |
| adb, para el modo USB (ofrece instalarlo) | Solo para USB |
| Red local marcada como Privada y permiso de Node.js en el firewall | Solo para Wi-Fi |
| Celular conectado por cable, autorizado y con Chrome | Opcional |
| Discord instalado | Opcional |

Si falta algo obligatorio, el panel tampoco arranca: lo avisa y te manda a `verificar.cmd`.

## Usar

Los iconos abren la **ventana del panel** en el PC, sin consola. Muestra:
- si el panel está en marcha;
- en modo Wi-Fi, el código QR y los dispositivos autorizados, con un botón **Quitar** para cada uno;
- en modo cable, si el celular está conectado;
- la actividad: los botones que pulsas desde el celular y los dispositivos que piden entrar.

Arriba a la derecha puedes cambiar entre **Wi-Fi** y **Cable USB** sin cerrar nada, y con **Páginas del celular**
eliges qué páginas se ven en el celular y en qué orden (ver [Páginas](#páginas)).

- **Cerrar la ventana no detiene el panel:** sigue funcionando y queda un icono junto al reloj. Para volver a la ventana,
  haz clic en ese icono o abre otra vez el panel desde el menú Inicio.
- **Para detenerlo,** pulsa **Detener el panel**, en la ventana o en el menú del icono junto al reloj.
- **Para ver los mensajes del servidor en una consola** (por ejemplo, para diagnosticar), usa el modo consola de antes:
  `.\iniciar.ps1` o `.\iniciar.ps1 -Wifi`, y Ctrl+C para detenerlo.

### Por cable (Panel USB)

- Abre **Panel USB** desde el menú Inicio (o doble clic en `iniciar.cmd`). El panel se abre solo en el celular.
- Para probarlo sin celular: **Abrir en este PC** en la ventana, o `.\iniciar.ps1 -SoloPC`.
- Si desconectas el cable con el panel en marcha, al volver a conectarlo el panel se recupera solo en unos segundos.
- En este modo no se expone nada a la red: el celular llega al PC solo por el cable.

### Por Wi-Fi (Panel Wi-Fi)

- Abre **Panel Wi-Fi** desde el menú Inicio (o doble clic en `iniciar-wifi.cmd`). El celular tiene que estar en la misma red que el PC.
- **La ventana muestra un código QR.** Escanéalo con la cámara del celular: se abre el panel (si se abre en otro navegador,
  usa "Abrir en Chrome"). No hace falta el cable ni el modo desarrollador.
- **La primera vez, el PC pide permiso:** aparece el aviso "Panel del PC: dispositivo nuevo" con la IP y el modelo del celular.
  Pulsa **Sí** y el panel se abre solo en el celular. Pulsa **No** si no lo reconoces: ese dispositivo no podrá volver a pedir
  acceso hasta que reinicies el panel. Después, en Chrome: ⋮ > **Agregar a pantalla principal**.
- Para pedir acceso hace falta el token que va dentro del QR: un equipo de la red que no lo tenga no puede ni abrir el aviso.
- Los dispositivos aprobados se guardan en `config.json` → `"wifi": { "dispositivos": ["192.168.1.50"] }`. Para quitar uno,
  pulsa **Quitar** en la ventana (o borra su IP del archivo; se aplica al instante). A cualquier otro equipo se le corta
  la conexión sin responderle.
- Si cambia la IP del celular, vuelve a escanear el QR y apruébalo otra vez; para que no cambie, resérvala en el router.
- Si el celular está conectado por cable al abrir Panel Wi-Fi, se autoriza solo y se le abre el panel (sin QR ni aviso).
- Si el router cambia la IP del PC, el icono del celular deja de funcionar: abre Panel Wi-Fi y usa la dirección nueva que muestra.
- La red debe estar marcada como **Privada** en Windows. Úsalo solo en redes de confianza (la de tu casa), no en redes públicas:
  la conexión no va cifrada.
- Cierra en Chrome las pestañas viejas del panel que empiezan por `localhost`: son del modo USB y en modo Wi-Fi no se conectan.

### Si no abre en el celular

- La ventana dice "Esperando al celular" o "Acepta el aviso en el celular": desbloquea el celular. Si aparece
  "Permitir depuración USB", marca **Permitir siempre desde este ordenador** y acepta. La ventana espera lo que haga falta
  y abre el panel en cuanto el celular responde.
- Al pulsar el icono con el panel ya abierto, solo se muestra la ventana y se vuelve a abrir en el celular (no se arranca otro).
- El panel dice "Sin conexión": revisa que el panel siga en marcha en el PC (la ventana o el icono junto al reloj).
- La ventana dice que hay otra copia del panel abierta: es una ventana de consola de una versión anterior.
  Pulsa **Cerrarla y continuar**.

### Pantalla completa

- El primer toque en el panel lo pone a pantalla completa y en horizontal. También puedes usar el botón ⛶ de la esquina del reloj.
- Mientras el panel está abierto, la pantalla del celular no se apaga.
- Para salir de la pantalla completa, desliza desde arriba y pulsa Atrás, o toca el botón otra vez.

### Como app en la pantalla de inicio

En Chrome del celular: menú ⋮ > **Agregar a pantalla principal**. El icono abre el panel directamente a pantalla completa.
Hazlo desde el modo que vayas a usar (USB o Wi-Fi): cada uno tiene su propia dirección. Solo funciona mientras el panel
está en marcha en el PC.

El token de acceso se guarda en `.token`. Si lo borras se genera uno nuevo y tendrás que volver a abrir el panel desde el script.

## Páginas

Desliza a los lados (o usa las flechas del teclado) para cambiar de página. Funciona mejor con el celular en horizontal.

**Elegir qué páginas ves y en qué orden:** en la ventana del panel, en el PC, pulsa **Páginas del celular**. Cada página
es una tarjeta con su vista previa, en el orden en que salen en el celular:
- el interruptor de la tarjeta la muestra u oculta (las ocultas se ven tenues, con «Oculta»);
- para cambiar el orden, arrastra la tarjeta sobre otra: ocupa su lugar. También puedes usar las flechas que aparecen
  al pasar el ratón por la tarjeta (o al llegar a ellas con Tab);
- la primera, marcada «Al conectar», es la que aparece al conectar el celular (si solo recargas la página, vuelves a la
  que estabas viendo).

Cada cambio llega al celular al momento, sin recargar, y se guarda en el PC, en `data/paginas.json`. **Restablecer**
vuelve al orden de abajo, con todas las páginas.

1. **Inicio**: reloj, la canción que suena en el PC (con carátula, progreso y controles), volumen, y CPU, RAM, red y disco con gráficas.
2. **Mezclador**: el volumen de cada aplicación que usa el sonido del PC, como el mezclador de Windows: una columna por
   aplicación, con su icono, un control para subir o bajar, el botón de silencio y un medidor que se mueve con el sonido.
   La primera columna es el volumen general. Arriba se ve la salida de audio (por ejemplo, los altavoces): tócala para
   elegir otra, como los audífonos o el monitor, igual que en el icono del volumen de Windows. Las llamadas se cambian
   también, salvo que en Windows las tengas a propósito en otra salida.
3. **Sistema**: indicadores circulares y los botones de atajos.
4. **Rendimiento**: historial de CPU, RAM y red de los últimos 3 minutos, y el uso de cada núcleo.
5. **Procesos**: los programas que más CPU y memoria usan, agrupados (por ejemplo, todas las ventanas de Chrome juntas).
   Los servicios protegidos de Windows no se pueden medir sin permisos de administrador.
6. **Enfoque**: temporizador pomodoro (enfoque, descanso y descanso largo, con vibración y sonido al terminar), lista de tareas
   y botones de acceso rápido. Las tareas se guardan en el PC, en `data/tareas.json`.
7. **Calendario**: el mes actual, relojes del mundo y el clima.
8. **Discord**: compartir pantalla, silenciar el micrófono, ensordecer, modo streamer y abrir Discord. Indica si Discord está abierto en el PC.
   Los botones envían atajos globales, que hay que configurar una vez en Discord
   (Ajustes de usuario → Atajos de teclado → Añadir un atajo):
   `Ctrl+Shift+F11` compartir pantalla, `Ctrl+Shift+F7` silencio, `Ctrl+Shift+F8` ensordecer, `Ctrl+Shift+F9` modo streamer.
   Compartir pantalla solo funciona estando en un canal de voz, y transmite la ventana o el juego que esté al frente en el PC.
   Puedes cambiar los atajos en `config.json` (grupo `"discord"`, campo `"keys"` en formato SendKeys).
9. **Comandos**: botones de comandos y la consola donde se ve su resultado.

### Ajustes de estas páginas en `config.json`

- `"relojes"`: lista de `{ "nombre": "...", "zona": "America/New_York" }` (zonas horarias IANA, máximo 6).
- `"pomodoro"`: minutos de `enfoque`, `descanso` y `largo`.
- `"clima"`: viene desactivado. Para activarlo pon `"activo": true` y tu `"ciudad"`, `"lat"` y `"lon"`.
  El servidor consulta Open-Meteo (gratis, sin cuenta) cada 15 minutos y le envía esas coordenadas redondeadas.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

Cada grupo tiene `"place"`: `"atajos"` (página Sistema, hasta 12 botones), `"enfoque"` (página Enfoque, debajo de las tareas, hasta 4),
`"discord"`, `"comandos"` o `"media"`.
Los botones `prev`, `playpause` y `next` del grupo `media` son los que usa la tarjeta de música. Controlan el reproductor
que esté sonando (Spotify, Opera, Chrome… cualquiera que aparezca en los controles de música de Windows), sin importar
qué ventana esté al frente.

Cada botón admite `"icon"` y `"color"` (por ejemplo `"#2dd4bf"`). Iconos disponibles:
`play` `pause` `prev` `next` `vol` `mute` `music` `folder` `download` `briefcase` `globe` `calculator`
`scissors` `activity` `monitor` `flame` `wifi` `clock` `lock` `moon` `terminal` `book` `share` `mic` `headphones` `eye` `chat`.

| type      | campos                       | ejemplo                                                |
|-----------|------------------------------|--------------------------------------------------------|
| `open`    | `target`, `args` (opcional)  | programa, carpeta o URL: `"target": "notepad.exe"`     |
| `media`   | `key`, `repeat`              | `prev` `next` `playpause` `stop` `mute` `volup` `voldown` |
| `keys`    | `keys` (formato SendKeys)    | `"^c"` = Ctrl+C, `"%{TAB}"` = Alt+Tab, `"^+{ESC}"`     |
| `command` | `command`, `cwd`, `timeout`  | cualquier PowerShell; su salida se muestra en el celular |

Si añades `"confirm": true` a un botón, pedirá confirmación antes de ejecutarse.

## Compartir el panel

En la carpeta del panel ejecuta `.\empaquetar.ps1`. Crea `Panel-USB.zip` junto a la carpeta, con solo los archivos del programa:
nunca incluye tu `.token`, tu `config.json`, tus tareas ni el orden de tus páginas. Quien lo reciba empieza por la sección **Instalación**.

## Seguridad

- En modo USB el servidor solo escucha en `127.0.0.1`; el celular llega a él únicamente por el túnel `adb reverse`.
  En modo Wi-Fi también escucha en la IP local del PC y solo acepta los dispositivos de `wifi.dispositivos`.
- Todas las peticiones necesitan el token de `.token` (48 caracteres aleatorios, distinto en cada PC), y se rechazan
  las que llegan con otro nombre de host (protección contra DNS rebinding).
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
