const std = @import("std");

pub const Rom = struct {
    data: std.AutoHashMap(u16, u16),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Rom {
        return .{
            .data = std.AutoHashMap(u16, u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Rom) void {
        self.data.deinit();
    }

    pub fn loadFromFile(self: *Rom, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        // Read entire file into memory
        const contents = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(contents);

        // Parse line by line
        var iter = std.mem.splitScalar(u8, contents, '\n');
        while (iter.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, &std.ascii.whitespace);

            // Skip comments and empty lines
            if (line.len == 0 or line[0] == '#') continue;

            // Parse address:value format
            if (std.mem.indexOfScalar(u8, line, ':')) |colon_pos| {
                const addr_str = line[0..colon_pos];
                const val_str = line[colon_pos + 1 ..];
                const addr = std.fmt.parseInt(u16, addr_str, 16) catch continue;
                const val = std.fmt.parseInt(u16, val_str, 16) catch continue;
                try self.data.put(addr, val);
            }
        }
    }

    pub fn read(self: *const Rom, address: u16) u16 {
        return self.data.get(address) orelse 0;
    }

    pub fn size(self: *const Rom) usize {
        return self.data.count();
    }
};

test "rom basic functionality" {
    const allocator = std.testing.allocator;
    var rom = Rom.init(allocator);
    defer rom.deinit();

    try std.testing.expectEqual(@as(usize, 0), rom.size());
    try std.testing.expectEqual(@as(u16, 0), rom.read(0x1000));
}
