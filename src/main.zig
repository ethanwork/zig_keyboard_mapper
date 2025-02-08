const std = @import("std");
const unicode = std.unicode;

// Windows API function signatures
const win = struct {
    const WM_KEYDOWN = 0x0100;
    const WM_KEYUP = 0x0101;
    const WM_SYSKEYDOWN = 0x0104;
    const WM_SYSKEYUP = 0x0105;

    // Virtual key codes
    const VK_SHIFT = 0x10;
    const VK_CONTROL = 0x11;
    const VK_MENU = 0x12; // Alt key
    const VK_CAPITAL = 0x14; // Caps Lock

    pub extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int, hMod: ?*usize, dwThreadId: u32) ?*usize;
    pub extern "user32" fn UnhookWindowsHookEx(hhk: ?*usize) callconv(.C) bool;
    pub extern "user32" fn CallNextHookEx(hhk: ?*usize, nCode: c_int, wParam: usize, lParam: ?*KBDLLHOOKSTRUCT) callconv(.C) c_int;
    pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?*usize, wMsgFilterMin: u32, wMsgFilterMax: u32) c_int;
    pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) c_int;
    pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) c_int;
    pub extern "user32" fn GetAsyncKeyState(vKey: c_int) callconv(.C) u16;
    pub extern "user32" fn ToUnicode(vkCode: u32, scanCode: u32, lpKeyState: [*]const u8, pwszBuff: [*]u16, cchBuff: i32, wFlags: u32) callconv(.C) i32;
    pub extern "user32" fn keybd_event(bVk: u8, bScan: u8, dwFlags: u32, dwExtraInfo: usize) callconv(.C) void;
};

// Windows Structs
const MSG = extern struct {
    hwnd: ?*usize,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: POINT,
};

const POINT = extern struct {
    x: i32,
    y: i32,
};

const KBDLLHOOKSTRUCT = extern struct {
    vkCode: u32,
    scanCode: u32,
    flags: u32,
    time: u32,
    dwExtraInfo: usize,
};

// Global variables
var hook_handle: ?*usize = null;
var a_pressed: bool = false;
var o_pressed: bool = false;
var chord_triggered: bool = false;
var a_press_time: u32 = 0;

fn keyboardHookCallback(nCode: c_int, wParam: usize, lParam: ?*KBDLLHOOKSTRUCT) callconv(.C) c_int {
    if (nCode >= 0 and lParam != null) {
        const hook_struct = lParam.?;
        const vkCode = hook_struct.vkCode;
        const event_time = hook_struct.time;
        const is_key_down = (wParam == win.WM_KEYDOWN or wParam == win.WM_SYSKEYDOWN);
        const is_key_up = (wParam == win.WM_KEYUP or wParam == win.WM_SYSKEYUP);

        // Handle 'a' key down
        if (is_key_down and vkCode == 0x41) { // VK_A
            a_pressed = true;
            a_press_time = event_time;
            return 1; // Suppress 'A' key down
        }

        // Handle 'o' key down
        if (is_key_down and vkCode == 0x4F) { // VK_O
            if (a_pressed and (event_time - a_press_time) <= 100) {
                chord_triggered = true;
                o_pressed = true;
                win.keybd_event(0x59, 0, 0, 0); // Simulate 'Y' key down
                return 1; // Suppress 'O' key down
            }
        }

        // Handle 'a' key up
        if (is_key_up and vkCode == 0x41) { // VK_A
            if (a_pressed) {
                a_pressed = false;
                if (chord_triggered) {
                    if (!o_pressed) {
                        win.keybd_event(0x59, 0, 0x0002, 0); // Simulate 'Y' key up
                        chord_triggered = false;
                    }
                } else {
                    // Send 'A' down followed by up
                    win.keybd_event(0x41, 0, 0, 0); // 'A' down
                    win.keybd_event(0x41, 0, 0x0002, 0); // 'A' up
                }
                return 1; // Suppress original 'A' key up
            }
        }

        // Handle 'o' key up
        if (is_key_up and vkCode == 0x4F) { // VK_O
            if (chord_triggered and o_pressed) {
                o_pressed = false;
                if (!a_pressed) {
                    win.keybd_event(0x59, 0, 0x0002, 0); // Simulate 'Y' key up
                    chord_triggered = false;
                }
                return 1; // Suppress original 'O' key up
            }
        }

        // Original 'W' to 'A' replacement logic
        if (vkCode == 87) { // VK_W
            if (is_key_down) {
                win.keybd_event(65, 0, 0, 0); // 'A' down
                return 1;
            }
            if (is_key_up) {
                win.keybd_event(65, 0, 0x0002, 0); // 'A' up
                return 1;
            }
        }

        // Debug print logic (original)
        var eventType: []const u8 = "Unknown event";
        switch (wParam) {
            win.WM_KEYDOWN => eventType = "WM_KEYDOWN",
            win.WM_KEYUP => eventType = "WM_KEYUP",
            win.WM_SYSKEYDOWN => eventType = "WM_SYSKEYDOWN",
            win.WM_SYSKEYUP => eventType = "WM_SYSKEYUP",
            else => {},
        }

        std.debug.print("Key Event: {s}, vkCode: {}", .{ eventType, vkCode });

        if (is_key_down) {
            var keyState: [256]u8 = undefined;
            @memset(&keyState, 0);

            if (win.GetAsyncKeyState(win.VK_SHIFT) & 0x8000 != 0) keyState[win.VK_SHIFT] = 0x80;
            if (win.GetAsyncKeyState(win.VK_CONTROL) & 0x8000 != 0) keyState[win.VK_CONTROL] = 0x80;
            if (win.GetAsyncKeyState(win.VK_MENU) & 0x8000 != 0) keyState[win.VK_MENU] = 0x80;
            if (win.GetAsyncKeyState(win.VK_CAPITAL) & 0x0001 != 0) keyState[win.VK_CAPITAL] = 0x01;

            var buffer: [8]u16 = undefined;
            const result = win.ToUnicode(
                vkCode,
                hook_struct.scanCode,
                @ptrCast(&keyState),
                buffer[0..].ptr,
                @intCast(buffer.len),
                0,
            );

            if (result > 0) {
                const utf16_slice = buffer[0..@intCast(result)];
                var utf8_buffer: [4]u8 = undefined;
                if (unicode.utf16LeToUtf8(&utf8_buffer, utf16_slice)) |utf8_len| {
                    std.debug.print(", Character: '{s}'\n", .{utf8_buffer[0..utf8_len]});
                } else |_| {
                    std.debug.print(", Character: (invalid)\n", .{});
                }
            } else if (result == 0) {
                std.debug.print(", Character: (none)\n", .{});
            } else {
                std.debug.print(", Dead key\n", .{});
            }
        } else {
            std.debug.print("\n", .{});
        }
    }
    return win.CallNextHookEx(hook_handle, nCode, wParam, lParam);
}

const keyboardHookPtr: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int = keyboardHookCallback;

pub fn main() !void {
    const WH_KEYBOARD_LL = 13;
    hook_handle = win.SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookPtr, null, 0);
    defer _ = win.UnhookWindowsHookEx(hook_handle);

    if (hook_handle == null) {
        std.debug.print("Failed to set keyboard hook\n", .{});
        return;
    }

    var msg: MSG = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
    }
}
