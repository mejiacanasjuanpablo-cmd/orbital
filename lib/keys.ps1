# Envía atajos de teclado como pulsaciones "físicas" (SendInput con scan code).
# WScript.Shell.SendKeys manda las teclas sin scan code y algunas apps (Discord cuando está al frente) las ignoran.
# Acepta el formato simple de SendKeys: modificadores ^ (Ctrl) + (Shift) % (Alt) seguidos de una tecla,
# por ejemplo "^+{F7}", "%{TAB}", "^c". Si el texto es más complejo, se usa SendKeys como antes.
Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public static class PanelKeys {
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }

    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);
    [DllImport("user32.dll")] static extern short VkKeyScan(char ch);

    const uint KEYUP = 0x0002, EXTENDED = 0x0001;
    static readonly HashSet<ushort> Ext = new HashSet<ushort> { 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x5B };
    static readonly Dictionary<string, ushort> Names = new Dictionary<string, ushort>(StringComparer.OrdinalIgnoreCase) {
        {"ESC",0x1B},{"ESCAPE",0x1B},{"TAB",0x09},{"ENTER",0x0D},{"BACKSPACE",0x08},{"BS",0x08},{"DEL",0x2E},{"DELETE",0x2E},
        {"INS",0x2D},{"INSERT",0x2D},{"HOME",0x24},{"END",0x23},{"PGUP",0x21},{"PGDN",0x22},{"UP",0x26},{"DOWN",0x28},
        {"LEFT",0x25},{"RIGHT",0x27},{"SPACE",0x20},{"PRTSC",0x2C},{"BREAK",0x13}
    };

    static INPUT Key(ushort vk, bool up) {
        var i = new INPUT { type = 1 };
        i.u.ki.wVk = vk;
        i.u.ki.wScan = (ushort)MapVirtualKey(vk, 0);
        i.u.ki.dwFlags = (up ? KEYUP : 0) | (Ext.Contains(vk) ? EXTENDED : 0);
        return i;
    }

    static void Send(params INPUT[] keys) { SendInput((uint)keys.Length, keys, Marshal.SizeOf(typeof(INPUT))); }

    // Devuelve false si el texto no es un atajo simple (entonces se usa SendKeys).
    public static bool TrySend(string s) {
        var mods = new List<ushort>();
        int p = 0;
        while (p < s.Length && "^+%".IndexOf(s[p]) >= 0) {
            mods.Add(s[p] == '^' ? (ushort)0x11 : s[p] == '+' ? (ushort)0x10 : (ushort)0x12);
            p++;
        }
        string rest = s.Substring(p);
        ushort vk;
        if (rest.Length > 2 && rest[0] == '{' && rest[rest.Length - 1] == '}') {
            string name = rest.Substring(1, rest.Length - 2);
            int f;
            if (name.Length > 1 && (name[0] == 'F' || name[0] == 'f') && int.TryParse(name.Substring(1), out f) && f >= 1 && f <= 24) vk = (ushort)(0x70 + f - 1);
            else if (!Names.TryGetValue(name, out vk)) return false;
        } else if (rest.Length == 1) {
            short r = VkKeyScan(rest[0]);
            if (r == -1) return false;
            vk = (ushort)(r & 0xFF);
            if ((r & 0x100) != 0 && !mods.Contains(0x10)) mods.Add(0x10);
        } else return false;

        foreach (var m in mods) { Send(Key(m, false)); Thread.Sleep(15); }
        Send(Key(vk, false)); Thread.Sleep(40);
        Send(Key(vk, true)); Thread.Sleep(15);
        for (int k = mods.Count - 1; k >= 0; k--) { Send(Key(mods[k], true)); Thread.Sleep(10); }
        return true;
    }
}
'@

function Send-PanelKeys([string]$Keys) {
    if (-not [PanelKeys]::TrySend($Keys)) {
        (New-Object -ComObject WScript.Shell).SendKeys($Keys)
    }
}
