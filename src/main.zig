const std = @import("std");
const cpu_mod = @import("cpu.zig");
const Hp16cCpu = cpu_mod.Hp16cCpu;
const Base = cpu_mod.Base;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var calculator = Hp16cCpu.init(allocator);
    defer calculator.deinit();

    // Setup buffered I/O
    var stdout_buf: [4096]u8 = undefined;
    var stdout_w = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_w.interface;

    var stderr_buf: [256]u8 = undefined;
    var stderr_w = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_w.interface;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_r = std.fs.File.stdin().readerStreaming(&stdin_buf);
    const stdin = &stdin_r.interface;

    // Load ROM data
    calculator.loadRom("16c.obj") catch {
        try stderr.writeAll("Warning: Could not load ROM file.\n");
        try stderr.writeAll("Continuing without ROM data...\n");
        try stderr.flush();
    };

    try stdout.writeAll("HP-16C RPN Calculator Emulator\n");
    try stdout.writeAll("==============================\n");
    try stdout.writeAll("Type HELP for detailed command information, or QUIT to exit.\n");
    try stdout.writeAll("\n");

    var running = true;
    while (running) {
        try displayCalculator(&calculator, stdout);

        try stdout.writeAll("> ");
        try stdout.flush();

        const input_raw = (try stdin.takeDelimiter('\n')) orelse break;
        const input = std.mem.trim(u8, input_raw, &std.ascii.whitespace);
        if (input.len == 0) continue;

        var upper_buf: [1024]u8 = undefined;
        const upper = toUpper(input, &upper_buf);

        if (std.mem.eql(u8, upper, "QUIT") or std.mem.eql(u8, upper, "Q")) {
            running = false;
        } else if (std.mem.eql(u8, upper, "HELP") or std.mem.eql(u8, upper, "H") or std.mem.eql(u8, upper, "?")) {
            try showHelp(stdout);
            continue;
        } else if (std.mem.eql(u8, upper, "CLR") or std.mem.eql(u8, upper, "CLEAR")) {
            calculator.x = 0;
            calculator.y = 0;
            calculator.z = 0;
            calculator.t = 0;
        } else if (std.mem.eql(u8, upper, "ENTER")) {
            calculator.push(calculator.x);
        } else if (std.mem.eql(u8, upper, "DROP")) {
            calculator.dropStack();
        } else if (std.mem.eql(u8, upper, "SWAP")) {
            calculator.swapXy();
        } else if (std.mem.eql(u8, upper, "RV")) {
            calculator.rollDown();
        } else if (std.mem.eql(u8, upper, "R^")) {
            calculator.rollUp();
        } else if (std.mem.eql(u8, upper, "+")) {
            calculator.add();
        } else if (std.mem.eql(u8, upper, "-")) {
            calculator.subtract();
        } else if (std.mem.eql(u8, upper, "*")) {
            calculator.multiply();
        } else if (std.mem.eql(u8, upper, "/")) {
            calculator.divide();
        } else if (std.mem.eql(u8, upper, "&")) {
            calculator.bitwiseAnd();
        } else if (std.mem.eql(u8, upper, "|")) {
            calculator.bitwiseOr();
        } else if (std.mem.eql(u8, upper, "^")) {
            calculator.bitwiseXor();
        } else if (std.mem.eql(u8, upper, "~")) {
            calculator.bitwiseNot();
        } else if (std.mem.eql(u8, upper, "BIN")) {
            calculator.setBase(.bin);
        } else if (std.mem.eql(u8, upper, "OCT")) {
            calculator.setBase(.oct);
        } else if (std.mem.eql(u8, upper, "DEC")) {
            calculator.setBase(.dec);
        } else if (std.mem.eql(u8, upper, "HEX")) {
            calculator.setBase(.hex);
        } else if (stripPrefix(upper, "STO ")) |reg_str| {
            if (std.fmt.parseInt(usize, reg_str, 10)) |reg| {
                calculator.store(reg);
            } else |_| {
                try stdout.writeAll("Invalid register number\n");
            }
        } else if (stripPrefix(upper, "RCL ")) |reg_str| {
            if (std.fmt.parseInt(usize, reg_str, 10)) |reg| {
                calculator.recall(reg);
            } else |_| {
                try stdout.writeAll("Invalid register number\n");
            }
        } else if (stripPrefix(upper, "WS ")) |size_str| {
            if (std.fmt.parseInt(u8, size_str, 10)) |size_val| {
                calculator.setWordSize(size_val);
            } else |_| {
                try stdout.writeAll("Invalid word size (1-128)\n");
            }
        } else if (stripPrefix(upper, "SL ")) |pos_str| {
            if (std.fmt.parseInt(u8, pos_str, 10)) |positions| {
                calculator.shiftLeft(positions);
            } else |_| {
                try stdout.writeAll("Invalid shift count\n");
            }
        } else if (stripPrefix(upper, "SR ")) |pos_str| {
            if (std.fmt.parseInt(u8, pos_str, 10)) |positions| {
                calculator.shiftRight(positions);
            } else |_| {
                try stdout.writeAll("Invalid shift count\n");
            }
        } else {
            // Try to parse as number in current base
            const radix = calculator.base.radix();
            if (std.fmt.parseInt(u128, upper, radix)) |value| {
                calculator.push(value);
            } else |_| {
                try stdout.print("Unknown command or invalid number: {s}\n", .{upper});
            }
        }
    }

    try stdout.writeAll("Goodbye!\n");
    try stdout.flush();
}

fn toUpper(input: []const u8, buf: []u8) []const u8 {
    const len = @min(input.len, buf.len);
    for (0..len) |i| {
        buf[i] = std.ascii.toUpper(input[i]);
    }
    return buf[0..len];
}

fn stripPrefix(input: []const u8, prefix: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, input, prefix)) {
        return input[prefix.len..];
    }
    return null;
}

fn displayCalculator(calc: *const Hp16cCpu, w: anytype) !void {
    try w.writeAll("\x1b[2J\x1b[H\n");

    var stack_bufs: [4][256]u8 = undefined;
    const stack = calc.getStackDisplay(&stack_bufs);

    const title = "HP-16C Calculator";

    var status_buf: [64]u8 = undefined;
    const status_line = std.fmt.bufPrint(&status_buf, "Base: {d:2}  Word Size: {d:3}", .{ calc.base.radix(), calc.word_size }) catch "???";

    var flags_buf: [64]u8 = undefined;
    const flags_line = std.fmt.bufPrint(&flags_buf, "Carry: {s}  Overflow: {s}", .{
        if (calc.carry) "1" else "0",
        if (calc.overflow) "1" else "0",
    }) catch "???";

    // Find the maximum width needed
    var max_width = title.len;
    if (status_line.len > max_width) max_width = status_line.len;
    if (flags_line.len > max_width) max_width = flags_line.len;
    for (stack) |line| {
        if (line.len > max_width) max_width = line.len;
    }

    // Ensure minimum width and add padding for borders
    if (max_width < 29) max_width = 29;
    const display_width = max_width + 2; // +2 for left and right padding

    // Print borders and content
    try printBorder(w, display_width, .top);
    try printPadded(w, title, display_width);
    try printBorder(w, display_width, .mid);
    try printPadded(w, status_line, display_width);
    try printPadded(w, flags_line, display_width);
    try printBorder(w, display_width, .mid);

    for (stack) |line| {
        try printPadded(w, line, display_width);
    }

    try printBorder(w, display_width, .bottom);
}

const BorderKind = enum { top, mid, bottom };

fn printBorder(w: anytype, width: usize, kind: BorderKind) !void {
    const corners = switch (kind) {
        .top => .{ "\xe2\x94\x8c", "\xe2\x94\x90" },
        .mid => .{ "\xe2\x94\x9c", "\xe2\x94\xa4" },
        .bottom => .{ "\xe2\x94\x94", "\xe2\x94\x98" },
    };

    try w.writeAll(corners[0]);
    for (0..width) |_| {
        try w.writeAll("\xe2\x94\x80");
    }
    try w.writeAll(corners[1]);
    try w.writeAll("\n");
}

fn printPadded(w: anytype, text: []const u8, width: usize) !void {
    try w.writeAll("\xe2\x94\x82 ");
    try w.writeAll(text);
    const pad = width - 2 - text.len;
    for (0..pad) |_| {
        try w.writeAll(" ");
    }
    try w.writeAll(" \xe2\x94\x82\n");
}

fn showHelp(w: anytype) !void {
    try w.writeAll(
        \\
        \\===================================================================
        \\                      HP-16C CALCULATOR HELP
        \\===================================================================
        \\
        \\BASIC USAGE:
        \\  Enter numbers in the current base and press ENTER to push to stack
        \\  Operations consume stack values (RPN - Reverse Polish Notation)
        \\  Example: To calculate 10 + 5: type '10', 'ENTER', '5', '+'
        \\
        \\NUMBER ENTRY:
        \\  [number]   Enter number in current base   FF (hex), 255 (dec)
        \\  ENTER      Push X to stack (duplicate)    10 ENTER -> stack: [10,10]
        \\
        \\ARITHMETIC OPERATIONS:
        \\  +          Add Y + X                      10 ENTER 5 + -> 15
        \\  -          Subtract Y - X                 10 ENTER 3 - -> 7
        \\  *          Multiply Y * X                 6 ENTER 7 * -> 42
        \\  /          Divide Y / X                   20 ENTER 4 / -> 5
        \\
        \\BITWISE OPERATIONS:
        \\  &          Bitwise AND of Y & X           F0 ENTER 0F & -> 0
        \\  |          Bitwise OR of Y | X            F0 ENTER 0F | -> FF
        \\  ^          Bitwise XOR of Y ^ X           FF ENTER AA ^ -> 55
        \\  ~          Bitwise NOT of X               FF ~ -> 0 (in 8-bit mode)
        \\
        \\STACK MANIPULATION:
        \\  DROP       Remove X, lift stack up        [4,3,2,1] DROP -> [3,2,1,1]
        \\  SWAP       Exchange X and Y               [4,3,2,1] SWAP -> [3,4,2,1]
        \\  RV         Roll stack down                [4,3,2,1] RV -> [3,2,1,4]
        \\  R^         Roll stack up                  [4,3,2,1] R^ -> [1,4,3,2]
        \\
        \\NUMBER BASE CONVERSION:
        \\  HEX        Switch to hexadecimal          255 HEX -> displays as FF
        \\  DEC        Switch to decimal              FF DEC -> displays as 255
        \\  OCT        Switch to octal                255 OCT -> displays as 377
        \\  BIN        Switch to binary               255 BIN -> displays as 11111111
        \\
        \\WORD SIZE CONTROL:
        \\  WS [n]     Set word size (1-128 bits)     WS 8 -> 8-bit arithmetic
        \\
        \\SHIFT OPERATIONS:
        \\  SL [n]     Shift left n positions         5 SL 1 -> A (5<<1 = 10)
        \\  SR [n]     Shift right n positions        A SR 1 -> 5 (10>>1 = 5)
        \\
        \\MEMORY OPERATIONS:
        \\  STO [n]    Store X in register n (0-15)   42 STO 5 -> saves 42 to R5
        \\  RCL [n]    Recall register n to stack     RCL 5 -> pushes R5 to stack
        \\
        \\UTILITY COMMANDS:
        \\  CLR        Clear all stack registers      CLR -> all registers = 0
        \\  HELP       Show this help (also H, ?)     HELP -> shows this screen
        \\  QUIT       Exit calculator (also Q)       QUIT -> exits program
        \\
        \\DISPLAY:
        \\  T, Z, Y, X: The four-level RPN stack
        \\  Base: Current number base (2, 8, 10, or 16)
        \\  Word Size: Current bit width (1-128)
        \\  Carry: Set when arithmetic operation carries/borrows
        \\  Overflow: Set when result exceeds word size
        \\
        \\===================================================================
        \\
    );
}

test "toUpper" {
    var buf: [64]u8 = undefined;
    const result = toUpper("hello", &buf);
    try std.testing.expectEqualStrings("HELLO", result);
}

test "stripPrefix" {
    try std.testing.expectEqualStrings("5", stripPrefix("STO 5", "STO ").?);
    try std.testing.expectEqualStrings("10", stripPrefix("WS 10", "WS ").?);
    try std.testing.expect(stripPrefix("NOMATCH", "STO ") == null);
}
