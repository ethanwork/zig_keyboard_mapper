const std = @import("std");

// Windows API function signatures
extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int, hMod: ?*usize, dwThreadId: u32) ?*usize;
extern "user32" fn CallNextHookEx(hhk: ?*usize, nCode: c_int, wParam: usize, lParam: ?*KBDLLHOOKSTRUCT) callconv(.C) c_int;
extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?*usize, wMsgFilterMin: u32, wMsgFilterMax: u32) c_int;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) c_int;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) c_int;

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
        std.debug.print("Key Pressed: {}\n", .{lParam.?.vkCode});
    }
    return CallNextHookEx(hook_handle, nCode, wParam, lParam);
}

// Ensure the function pointer is explicitly cast
const keyboardHookPtr: *const fn (c_int, usize, ?*KBDLLHOOKSTRUCT) callconv(.C) c_int = keyboardHookCallback;

pub fn main() !void {
    // Set the keyboard hook
    const WH_KEYBOARD_LL = 13;
    const hInstance: ?*usize = null; // No module handle needed for global hooks

    hook_handle = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookPtr, hInstance, 0);
    if (hook_handle == null) {
        std.debug.print("Failed to set keyboard hook\n", .{});
        return;
    }

    std.debug.print("Keyboard hook installed. Press any key...\n", .{});

    // Windows message loop to keep the hook running
    var msg: MSG = undefined;
    while (GetMessageW(&msg, null, 0, 0) > 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}
