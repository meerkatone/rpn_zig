const std = @import("std");
const Rom = @import("rom.zig").Rom;

pub const Base = enum(u8) {
    bin = 2,
    oct = 8,
    dec = 10,
    hex = 16,

    pub fn radix(self: Base) u8 {
        return @intFromEnum(self);
    }
};

pub const Hp16cCpu = struct {
    x: u128 = 0,
    y: u128 = 0,
    z: u128 = 0,
    t: u128 = 0,

    rom: Rom,

    word_size: u8 = 16,

    base: Base = .hex,

    carry: bool = false,
    overflow: bool = false,

    memory: [16]u128 = [_]u128{0} ** 16,

    pub fn init(allocator: std.mem.Allocator) Hp16cCpu {
        return .{
            .rom = Rom.init(allocator),
        };
    }

    pub fn deinit(self: *Hp16cCpu) void {
        self.rom.deinit();
    }

    pub fn loadRom(self: *Hp16cCpu, filename: []const u8) !void {
        try self.rom.loadFromFile(filename);
    }

    // RPN Stack operations
    pub fn push(self: *Hp16cCpu, value: u128) void {
        self.t = self.z;
        self.z = self.y;
        self.y = self.x;
        self.x = self.maskValue(value);
    }

    pub fn pop(self: *Hp16cCpu) u128 {
        const result = self.x;
        self.x = self.y;
        self.y = self.z;
        self.z = self.t;
        return result;
    }

    pub fn dropStack(self: *Hp16cCpu) void {
        self.x = self.y;
        self.y = self.z;
        self.z = self.t;
    }

    pub fn swapXy(self: *Hp16cCpu) void {
        std.mem.swap(u128, &self.x, &self.y);
    }

    pub fn rollDown(self: *Hp16cCpu) void {
        const temp = self.x;
        self.x = self.y;
        self.y = self.z;
        self.z = self.t;
        self.t = temp;
    }

    pub fn rollUp(self: *Hp16cCpu) void {
        const temp = self.t;
        self.t = self.z;
        self.z = self.y;
        self.y = self.x;
        self.x = temp;
    }

    // Apply word size mask
    fn maskValue(self: *const Hp16cCpu, value: u128) u128 {
        if (self.word_size == 128) {
            return value;
        } else if (self.word_size == 64) {
            return value & @as(u128, std.math.maxInt(u64));
        } else {
            return value & ((@as(u128, 1) << @intCast(self.word_size)) - 1);
        }
    }

    pub fn add(self: *Hp16cCpu) void {
        const result = self.x +% self.y;
        self.carry = result < self.x or result < self.y;
        self.dropStack();
        self.x = self.maskValue(result);
    }

    pub fn subtract(self: *Hp16cCpu) void {
        const result = self.y -% self.x;
        self.carry = self.y < self.x;
        self.dropStack();
        self.x = self.maskValue(result);
    }

    pub fn multiply(self: *Hp16cCpu) void {
        const result = @mulWithOverflow(self.x, self.y);
        self.carry = result[1] != 0;
        self.dropStack();
        self.x = self.maskValue(result[0]);
    }

    pub fn divide(self: *Hp16cCpu) void {
        if (self.x != 0) {
            const result = self.y / self.x;
            self.dropStack();
            self.x = self.maskValue(result);
            self.carry = false;
        } else {
            self.overflow = true;
        }
    }

    pub fn bitwiseAnd(self: *Hp16cCpu) void {
        const result = self.x & self.y;
        self.dropStack();
        self.x = result;
    }

    pub fn bitwiseOr(self: *Hp16cCpu) void {
        const result = self.x | self.y;
        self.dropStack();
        self.x = result;
    }

    pub fn bitwiseXor(self: *Hp16cCpu) void {
        const result = self.x ^ self.y;
        self.dropStack();
        self.x = result;
    }

    pub fn bitwiseNot(self: *Hp16cCpu) void {
        self.x = self.maskValue(~self.x);
    }

    pub fn shiftLeft(self: *Hp16cCpu, positions: u8) void {
        const shift: u7 = @intCast(positions);
        const result = self.x << shift;
        const carry_shift: u7 = @intCast(self.word_size - positions);
        self.carry = (self.x >> carry_shift) != 0;
        self.x = self.maskValue(result);
    }

    pub fn shiftRight(self: *Hp16cCpu, positions: u8) void {
        const shift: u7 = @intCast(positions);
        self.carry = (self.x & ((@as(u128, 1) << shift) - 1)) != 0;
        self.x >>= shift;
    }

    // Memory operations
    pub fn store(self: *Hp16cCpu, register: usize) void {
        if (register < 16) {
            self.memory[register] = self.x;
        }
    }

    pub fn recall(self: *Hp16cCpu, register: usize) void {
        if (register < 16) {
            self.push(self.memory[register]);
        }
    }

    pub fn setBase(self: *Hp16cCpu, base: Base) void {
        self.base = base;
    }

    pub fn setWordSize(self: *Hp16cCpu, size_val: u8) void {
        if (size_val >= 1 and size_val <= 128) {
            self.word_size = size_val;
            self.x = self.maskValue(self.x);
            self.y = self.maskValue(self.y);
            self.z = self.maskValue(self.z);
            self.t = self.maskValue(self.t);
        }
    }

    // Display formatting
    pub fn formatDisplay(self: *const Hp16cCpu, buf: []u8) []const u8 {
        return formatU128(self.x, self.base, buf);
    }

    pub fn getStackDisplay(self: *const Hp16cCpu, out: *[4][256]u8) [4][]const u8 {
        var results: [4][]const u8 = undefined;
        const regs = [4]struct { label: []const u8, val: u128 }{
            .{ .label = "T", .val = self.t },
            .{ .label = "Z", .val = self.z },
            .{ .label = "Y", .val = self.y },
            .{ .label = "X", .val = self.x },
        };
        for (regs, 0..) |reg, i| {
            var num_buf: [256]u8 = undefined;
            const num_str = formatU128(reg.val, self.base, &num_buf);
            const result = std.fmt.bufPrint(&out[i], "{s}: {s}", .{ reg.label, num_str }) catch "???";
            results[i] = result;
        }
        return results;
    }
};

fn formatU128(value: u128, base: Base, buf: []u8) []const u8 {
    return switch (base) {
        .bin => std.fmt.bufPrint(buf, "{b}", .{value}) catch "???",
        .oct => std.fmt.bufPrint(buf, "{o}", .{value}) catch "???",
        .dec => std.fmt.bufPrint(buf, "{d}", .{value}) catch "???",
        .hex => std.fmt.bufPrint(buf, "{X}", .{value}) catch "???",
    };
}

// Tests
test "rpn stack push pop" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    calc.push(42);
    try std.testing.expectEqual(@as(u128, 42), calc.x);
    try std.testing.expectEqual(@as(u128, 0), calc.y);

    calc.push(100);
    try std.testing.expectEqual(@as(u128, 100), calc.x);
    try std.testing.expectEqual(@as(u128, 42), calc.y);

    const popped = calc.pop();
    try std.testing.expectEqual(@as(u128, 100), popped);
    try std.testing.expectEqual(@as(u128, 42), calc.x);
}

test "basic arithmetic" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    // Test addition: 10 + 5 = 15
    calc.push(10);
    calc.push(5);
    calc.add();
    try std.testing.expectEqual(@as(u128, 15), calc.x);

    // Test subtraction: 15 - 3 = 12
    calc.push(3);
    calc.subtract();
    try std.testing.expectEqual(@as(u128, 12), calc.x);

    // Test multiplication: 12 * 2 = 24
    calc.push(2);
    calc.multiply();
    try std.testing.expectEqual(@as(u128, 24), calc.x);

    // Test division: 24 / 4 = 6
    calc.push(4);
    calc.divide();
    try std.testing.expectEqual(@as(u128, 6), calc.x);
}

test "bitwise operations" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    // Test AND: 0xF0 & 0x0F = 0x00
    calc.push(0xF0);
    calc.push(0x0F);
    calc.bitwiseAnd();
    try std.testing.expectEqual(@as(u128, 0x00), calc.x);

    // Test OR: 0xF0 | 0x0F = 0xFF
    calc.push(0xF0);
    calc.push(0x0F);
    calc.bitwiseOr();
    try std.testing.expectEqual(@as(u128, 0xFF), calc.x);

    // Test XOR: 0xFF ^ 0xAA = 0x55
    calc.push(0xFF);
    calc.push(0xAA);
    calc.bitwiseXor();
    try std.testing.expectEqual(@as(u128, 0x55), calc.x);
}

test "stack operations" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    calc.push(1);
    calc.push(2);
    calc.push(3);
    calc.push(4);

    try std.testing.expectEqual(@as(u128, 4), calc.x);
    try std.testing.expectEqual(@as(u128, 3), calc.y);
    try std.testing.expectEqual(@as(u128, 2), calc.z);
    try std.testing.expectEqual(@as(u128, 1), calc.t);

    calc.swapXy();
    try std.testing.expectEqual(@as(u128, 3), calc.x);
    try std.testing.expectEqual(@as(u128, 4), calc.y);

    calc.rollDown();
    try std.testing.expectEqual(@as(u128, 4), calc.x);
    try std.testing.expectEqual(@as(u128, 2), calc.y);
    try std.testing.expectEqual(@as(u128, 1), calc.z);
    try std.testing.expectEqual(@as(u128, 3), calc.t);
}

test "word size masking" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    calc.setWordSize(8);
    calc.push(0x1FF); // 511, should be masked to 8 bits
    try std.testing.expectEqual(@as(u128, 0xFF), calc.x);

    calc.setWordSize(4);
    calc.push(0x20); // 32, should be masked to 4 bits
    try std.testing.expectEqual(@as(u128, 0x0), calc.x);
}

test "memory operations" {
    const allocator = std.testing.allocator;
    var calc = Hp16cCpu.init(allocator);
    defer calc.deinit();

    calc.push(0xDEAD);
    calc.store(5);
    try std.testing.expectEqual(@as(u128, 0xDEAD), calc.memory[5]);

    calc.x = 0;
    calc.recall(5);
    try std.testing.expectEqual(@as(u128, 0xDEAD), calc.x);
}
