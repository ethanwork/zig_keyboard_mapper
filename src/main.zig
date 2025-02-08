const std = @import("std");

// Windows API function signatures

const win = struct {
    const WM_KEYDOWN = 0x0100;
    const WM_KEYUP = 0x0101;
    const WM_SYSKEYDOWN = 0x0104;
    const WM_SYSKEYUP = 0x0105;

    pub extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int, hMod: ?*usize, dwThreadId: u32) ?*usize;
    pub extern "user32" fn UnhookWindowsHookEx(hhk: ?*usize) callconv(.C) bool;
    pub extern "user32" fn CallNextHookEx(hhk: ?*usize, nCode: c_int, wParam: usize, lParam: ?*KBDLLHOOKSTRUCT) callconv(.C) c_int;
    pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?*usize, wMsgFilterMin: u32, wMsgFilterMax: u32) c_int;
    pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) c_int;
    pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) c_int;
    pub extern "user32" fn GetKeyboardState(lpKeyState: [*]u8) callconv(.C) bool;
    pub extern "user32" fn ToUnicode(vkCode: u32, scanCode: u32, lpKeyState: [*]const u8, pwszBuff: [*]u16, cchBuff: i32, wFlags: u32) callconv(.Stdcall) i32;
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

// Global variable to hold hook handle
var hook_handle: ?*usize = null;

// Define keyboard hook callback as a function pointer
fn keyboardHookCallback(nCode: c_int, wParam: usize, lParam: ?*KBDLLHOOKSTRUCT) callconv(.C) c_int {
    if (nCode >= 0 and lParam != null) {
        var eventType: []const u8 = "Unknown event";

        switch (wParam) {
            win.WM_KEYDOWN => eventType = "WM_KEYDOWN",
            win.WM_KEYUP => eventType = "WM_KEYUP",
            win.WM_SYSKEYDOWN => eventType = "WM_SYSKEYDOWN",
            win.WM_SYSKEYUP => eventType = "WM_SYSKEYUP",
            else => {},
        }

        std.debug.print("Key Event: {s}, vkCode: {}\n", .{ eventType, lParam.?.vkCode });
    }
    return win.CallNextHookEx(hook_handle, nCode, wParam, lParam);
}

// Ensure the function pointer is explicitly cast
const keyboardHookPtr: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int = keyboardHookCallback;

pub fn main() !void {
    // Set the keyboard hook
    const WH_KEYBOARD_LL = 13;
    const hInstance: ?*usize = null; // No module handle needed for global hooks

    hook_handle = win.SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookPtr, hInstance, 0);
    defer _ = win.UnhookWindowsHookEx(hook_handle);

    if (hook_handle == null) {
        std.debug.print("Failed to set keyboard hook\n", .{});
        return;
    }

    std.debug.print("Keyboard hook installed. Press any key...\n", .{});

    // Windows message loop to keep the hook running
    var msg: MSG = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
    }
}
