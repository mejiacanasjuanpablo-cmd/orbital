# Panel del PC

Panel de control del PC que se abre en el navegador del celular por la red Wi-Fi de la casa.
No hay que instalar ninguna app en el celular ni activar nada en sus ajustes. Funciona en Windows 10 y 11, en español o en inglés.

## Instalación (una sola vez)

1. Descomprime `Panel-del-PC.zip` en una carpeta fija (por ejemplo, en Documentos). No lo ejecutes desde dentro del .zip.
2. Doble clic en **`instalar.cmd`**. Revisa los requisitos y pregunta antes de instalar lo que falte
   (**Node.js 18 o superior**, con winget; si el PC no tiene winget, abre la página oficial) y antes de dar permiso a
   Node.js en el firewall de Windows.
   También crea `config.json`, la ventana del panel (`Panel del PC.exe`, que se compila en el propio PC con lo que trae
   Windows) y el icono **Panel del PC** en el menú Inicio.
   Si Windows avisa de que el archivo viene de internet, elige **Más información → Ejecutar de todas formas**.
3. La primera vez que abras el panel, Windows puede preguntar si permites que Node.js use la red:
   permítelo en **redes privadas**. Si se cancela o nadie responde, la ventana del panel lo avisa y lo arregla con
   **Permitir el acceso** (ver [Si no abre en el celular](#si-no-abre-en-el-celular)).

Si mueves la carpeta a otro sitio, vuelve a ejecutar `instalar.cmd` para que el icono apunte a la nueva ubicación.

**Si vienes de una versión anterior** (con los iconos **Panel USB** y **Panel Wi-Fi**): vuelve a ejecutar `instalar.cmd`.
Los cambia por el icono **Panel del PC**. Mientras tanto, los dos iconos viejos siguen funcionando y abren el panel por Wi-Fi.

### Verificar requisitos

Doble clic en **`verificar.cmd`** en cualquier momento. Revisa y muestra con `[OK]`, `[FALTA]`, `[AVISO]` o `[INFO]`:

| Qué revisa | ¿Obligatorio? |
|---|---|
| Archivos del panel completos | Sí |
| Windows 10/11, PowerShell 5.1 y .NET Framework 4.5+ | Sí |
| Node.js 18 o superior (ofrece instalarlo o actualizarlo) | Sí |
| Componentes de Windows que usa el panel: atajos de teclado, volumen, música y mezclador | Sí (volumen, música y mezclador, opcionales) |
| Puerto 8787 libre (o ya en uso por el panel) | Sí |
| El PC conectado a una red local, marcada como Privada | Sí (que sea Privada, recomendado) |
| Permiso de Node.js en el firewall de Windows (ofrece darlo o desbloquearlo) | Para que entre el celular (Windows lo pide la primera vez) |
| Discord instalado | Opcional |

Si falta algo obligatorio, el panel tampoco arranca: lo avisa y te manda a `verificar.cmd`.

## Usar

Abre **Panel del PC** desde el menú Inicio (o doble clic en `iniciar.cmd`). Se abre la **ventana del panel** en el PC,
sin consola. Muestra:
- si el panel está en marcha;
- el **código QR** para conectar el celular y la dirección, con un botón para copiarla;
- los dispositivos autorizados, con un botón **Quitar** para cada uno;
- la actividad: los botones que pulsas desde el celular y los dispositivos que piden entrar.

Arriba a la derecha eliges el **idioma** (**Español** o **English**) y, con **Selección de widgets**, qué páginas se ven en
el celular y en qué orden (ver [Páginas](#páginas)).

- **Cerrar la ventana no detiene el panel:** sigue funcionando y queda un icono junto al reloj. Para volver a la ventana,
  haz clic en ese icono o abre otra vez el panel desde el menú Inicio (no se arranca otro).
- **Para detenerlo,** pulsa **Detener el panel**, en la ventana o en el menú del icono junto al reloj.
- **Para probarlo sin celular:** **Abrir en este PC** en la ventana.
- **Para ver los mensajes del servidor en una consola** (por ejemplo, para diagnosticar), usa el modo consola:
  `.\iniciar.ps1` (o `.\iniciar.ps1 -SoloPC`, que lo abre solo en el navegador del PC), y Ctrl+C para detenerlo.

### Conectar el celular

1. Con el celular en la **misma red Wi-Fi** que el PC, escanea con la cámara el código QR de la ventana.
   Se abre el panel en el navegador (si se abre en uno que no sea Chrome, usa "Abrir en Chrome").
2. **La primera vez, el PC pide permiso:** aparece el aviso "Panel del PC: dispositivo nuevo" con la IP y el modelo
   del celular. Pulsa **Sí** y el panel se abre solo en el celular.
   Pulsa **No** si no lo reconoces: ese dispositivo no podrá volver a pedir acceso hasta que reinicies el panel.
3. En el celular, en Chrome: menú ⋮ > **Agregar a pantalla principal**. Desde ese icono se abre directo y a pantalla completa.

- Para pedir acceso hace falta el token que va dentro del QR: un equipo de la red que no lo tenga no puede ni abrir el aviso.
- Los dispositivos aprobados se guardan en `config.json` → `"wifi": { "dispositivos": ["192.168.1.50"] }`. Para quitar uno,
  pulsa **Quitar** en la ventana (o borra su IP del archivo; se aplica al instante). A cualquier otro equipo se le corta
  la conexión sin responderle.
- Si el router cambia la IP del PC o del celular, el icono del celular deja de funcionar: vuelve a escanear el QR
  y aprueba el aviso. Para evitarlo, reserva esas IP en el router.
- La red debe estar marcada como **Privada** en Windows (Configuración > Red e Internet > propiedades de la red).
  Úsalo solo en redes de confianza (la de tu casa), no en redes públicas: la conexión no va cifrada.

### Si no abre en el celular

- El celular dice "Buscando el PC…" o "Sin conexión": revisa que el panel siga en marcha en el PC (la ventana o el icono
  junto al reloj) y que el celular esté en la misma red Wi-Fi.
- La ventana avisa de que la red está marcada como **Pública**: cámbiala a Privada con el botón del aviso.
- La ventana avisa de que el **firewall de Windows** no deja entrar al celular (arriba dice «En marcha, pero el celular no
  puede entrar»): pulsa **Permitir el acceso** y acepta el aviso de administrador de Windows. Pasa cuando, la primera
  vez, alguien canceló la pregunta de Windows o nadie la respondió, o la cuenta no es de administrador (Windows pide
  entonces la contraseña de un administrador). Desde el propio PC no se nota, porque sus conexiones no pasan por el
  firewall: por eso el panel lo revisa aparte. Si avisa de que está activado «Bloquear todas las conexiones entrantes»,
  desactívalo con **Abrir el firewall**. `verificar.cmd` también lo revisa y ofrece arreglarlo.
- Si la ventana no avisa de nada y el celular sigue sin abrirlo: la red puede no dejar que los dispositivos se vean entre
  sí (redes de invitados, de oficina, de universidades o de cafés), puede haber una VPN en el PC o en el celular, o un
  antivirus con firewall propio (Norton, McAfee, Avast, Kaspersky, ESET…) que bloquee Node.js.
- La ventana dice que hay otra copia del panel abierta: es una ventana de consola de una versión anterior.
  Pulsa **Cerrarla y continuar**.
- Si tienes en el celular pestañas viejas del panel que empiezan por `localhost`, ciérralas: eran del modo por cable,
  que ya no existe.

### Pantalla completa

- El primer toque en el panel lo pone a pantalla completa y en horizontal. También puedes usar el botón ⛶ de la esquina del reloj.
- Mientras el panel está abierto, la pantalla del celular no se apaga.
- Para salir de la pantalla completa, desliza desde arriba y pulsa Atrás, o toca el botón otra vez.

El token de acceso se guarda en `.token`. Si lo borras se genera uno nuevo y tendrás que volver a escanear el código QR.

## Idioma

En la ventana del panel, arriba a la derecha: **Español** o **English**. Cambia a la vez la ventana, la página del
celular (al momento, sin recargar), la página de espera de los celulares nuevos y el aviso del PC para aprobarlos.
Se guarda en el PC, en `data/preferencias.json`; la primera vez se usa el idioma de Windows.

Los nombres de tus botones, relojes y comandos salen tal como los escribiste en `config.json`.

## Páginas

Desliza a los lados (o usa las flechas del teclado) para cambiar de página. Funciona mejor con el celular en horizontal.

**Elegir qué páginas ves y en qué orden:** en la ventana del panel, en el PC, pulsa **Selección de widgets**. Cada página
es una tarjeta con su vista previa, en el orden en que salen en el celular:
- el interruptor de la tarjeta la muestra u oculta (las ocultas se ven tenues, con «Oculta»);
- para cambiar el orden, arrastra la tarjeta sobre otra: ocupa su lugar. También puedes usar las flechas que aparecen
  al pasar el ratón por la tarjeta (o al llegar a ellas con Tab);
- la primera, marcada «Al conectar», es la que aparece al conectar el celular (si solo recargas la página, vuelves a la
  que estabas viendo).

**Editar los atajos de la página Sistema:** en la ventana del panel pulsa **Atajos**. Cada botón es una tarjeta con su
icono, su nombre y lo que hace; el celular ve cada cambio al momento, sin recargar.
- Pulsa una tarjeta para editarla, o **Agregar atajo** (hasta 12). En el editor eliges el nombre, el color, el icono y
  qué hace:
  - **Abrir**: un programa, una carpeta, un archivo o una página web (con **Examinar…** o escribiéndolo), con
    argumentos opcionales.
  - **Atajo de teclado**: haz clic en el recuadro y pulsa la combinación (con Ctrl, Shift y Alt; la tecla de Windows no
    se puede enviar). Le llega al programa que esté al frente en el PC.
  - **Comando**: un comando de PowerShell; lo que escriba se ve en la página Comandos.
  - **Preguntar en el celular antes de hacerlo**, para los que no quieres pulsar por error (por ejemplo, apagar).
- Para cambiar el orden, arrastra una tarjeta sobre otra. **Eliminar** (en el editor) lo quita, y **Restablecer** vuelve
  a los atajos de ejemplo.
- Se guardan en `config.json`, en el grupo `"atajos"`, un atajo por línea; también puedes editarlos ahí a mano.

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
7. **Calendario**: el mes actual con tu agenda, relojes del mundo y el clima.
   - **Agenda:** los días con algo agendado llevan un punto. Toca un día (por ejemplo, el de hoy) y se abre una ventana
     con lo que tienes ese día: lo de todo el día arriba y lo demás por hora, con su lugar. En el de hoy, lo que ya pasó
     se ve más tenue y la lista empieza en lo siguiente. Ver [Conectar tu calendario](#conectar-tu-calendario).
   - **Clima:** pulsa **Mostrar el clima de aquí** en su tarjeta. Usa la ubicación de Windows de este PC, que es
     aproximada (unos km), así que puede salir el municipio de al lado. Si Windows tiene la ubicación apagada, la tarjeta
     dice dónde activarla: Configuración > Privacidad y seguridad > Ubicación, también para las aplicaciones de escritorio.
     Desde el celular no se puede tomar la ubicación: el navegador solo la da en páginas seguras (https), y el panel va
     por http en la red de casa.
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
- `"clima"`: viene desactivado; el botón de la tarjeta del clima lo deja en `{ "activo": true, "ubicacion": "pc" }`.
  Para una ciudad fija en vez de la ubicación del PC: `{ "activo": true, "ciudad": "Medellín", "lat": 6.25, "lon": -75.56 }`.
  El servidor consulta Open-Meteo (gratis, sin cuenta) cada 15 minutos y le envía las coordenadas redondeadas a 2
  decimales (alrededor de 1 km). Con la ubicación del PC, también se las envía a OpenStreetMap, para el nombre de la
  ciudad, y pregunta la ubicación a Windows como mucho cada 3 horas.
- `"calendario"`: `{ "ics": "…" }`, el enlace privado del calendario. Lo guarda el panel al conectarlo desde la página
  Calendario; para quitarlo, **Cambiar enlace → Desconectar**.

### Conectar tu calendario

La agenda se lee desde el enlace privado de tu calendario en formato iCal: solo lectura, sin iniciar sesión.

1. En el PC, abre Google Calendar en el navegador → ⚙ **Configuración** → en la columna izquierda, tu calendario →
   **Integrar el calendario** → copia la **Dirección secreta en formato iCal** (termina en `.ics`).
2. En la ventana del panel pulsa **Abrir en este PC**, ve a la página Calendario y toca cualquier día.
3. Pega el enlace y pulsa **Conectar**. El panel lo prueba antes de guardarlo.

También sirven Outlook.com (Configuración → Calendario → Calendarios compartidos → Publicar un calendario → enlace ICS) e
iCloud (calendario público, enlace `webcal://`). La agenda se actualiza cada 10 minutos, y al abrir un día si pasaron
más de 2. Google puede tardar un rato en reflejar lo que acabas de agendar en ese enlace.

El enlace se guarda solo en `config.json`, en este PC: no va al celular, ni a git, ni al `.zip`, ni al ejecutable para
compartir. **Quien lo tenga puede ver tu calendario.** Si alguna vez lo compartes por error, en Google Calendar pulsa
**Restablecer** junto a la dirección secreta y vuelve a conectar el nuevo.

## Personalizar: `config.json`

Los cambios se aplican sin reiniciar; basta con recargar la página en el celular.

Cada grupo tiene `"place"`: `"atajos"` (página Sistema, hasta 12 botones), `"enfoque"` (página Enfoque, debajo de las tareas, hasta 4),
`"discord"`, `"comandos"` o `"media"`.
Los botones `prev`, `playpause` y `next` del grupo `media` son los que usa la tarjeta de música. Controlan el reproductor
que esté sonando (Spotify, Opera, Chrome… cualquiera que aparezca en los controles de música de Windows), sin importar
qué ventana esté al frente.

Cada botón admite `"label"`, `"icon"` y `"color"` (por ejemplo `"#2dd4bf"`). Iconos disponibles:
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

Hay dos formas. Ninguna incluye nunca tu `.token`, tu `config.json` ni la carpeta `data` (tus tareas, el orden de tus
páginas y el idioma).

**Un solo programa (lo más fácil para probarlo en otros PC).** En la carpeta del panel ejecuta
`.\herramientas\portatil.ps1`. Crea `Panel del PC.exe` en el Escritorio (unos 35 MB): lleva dentro todo el panel y Node.js,
así que en el otro PC no hay que instalar nada.
- Quien lo reciba solo le hace doble clic. Como el programa no está firmado, Windows puede avisar: **Más información →
  Ejecutar de todas formas**.
- La primera vez tarda unos segundos: deja el panel en `%LOCALAPPDATA%\Panel del PC` y el icono **Panel del PC** en el
  menú Inicio (si ya había uno, no lo toca). Después se abre directo, también desde ese icono.
- Si le llega un `Panel del PC.exe` más nuevo, al abrirlo actualiza el programa y conserva su `config.json`, su token y sus
  datos. Si el panel está abierto, primero pide cerrarlo con **Detener el panel**.
- La primera vez Windows pregunta si permite que Node.js use la red: permítelo en **redes privadas**. Si se cancela o
  nadie responde, la ventana lo avisa y lo arregla con **Permitir el acceso**.
- Para quitarlo: borra la carpeta `%LOCALAPPDATA%\Panel del PC` y el icono del menú Inicio.

**El .zip.** En la carpeta del panel ejecuta `.\empaquetar.ps1`. Crea `Panel-del-PC.zip` junto a la carpeta, con solo los
archivos del programa (sin Node.js). Quien lo reciba empieza por la sección **Instalación**.

## Seguridad

- El servidor escucha en `127.0.0.1` (para abrirlo en el propio PC) y en la IP local del PC. Solo entran el propio PC y
  los celulares que aprobaste (`wifi.dispositivos`); a cualquier otro equipo de la red se le corta la conexión sin responderle.
- Para pedir acceso hace falta el token que va dentro del QR (48 caracteres aleatorios, distinto en cada PC, guardado en `.token`).
  El QR se genera en el propio PC, sin internet. Si crees que alguien vio el QR, borra `.token`: se genera uno nuevo.
- Todas las peticiones necesitan ese token, y se rechazan las que llegan con otro nombre de host (protección contra DNS rebinding).
- El celular solo puede ejecutar los botones definidos en `config.json`, nunca comandos arbitrarios.
- La conexión no va cifrada: úsalo solo en redes de confianza (la de tu casa), no en redes públicas.
