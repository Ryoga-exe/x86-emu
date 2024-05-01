const std = @import("std");
const MemorySize = 1024 * 1024; // 1MB
const Allocator = std.mem.Allocator;

const Register = enum {
    eax,
    ecx,
    edx,
    ebx,
    esp,
    ebp,
    esi,
    edi,
    size,
};

const Emulator = struct {
    const Self = @This();

    registers: [@intFromEnum(Register.size)]u32,
    eflags: u32,
    memory: []u8,
    eip: u32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, size: usize, eip: u32, esp: u32) !Self {
        var self = Self{
            .registers = [1]u32{0} ** @intFromEnum(Register.size),
            .eflags = 0,
            .memory = try allocator.alloc(u8, size),
            .eip = eip,
            .allocator = allocator,
        };
        self.registers[@intFromEnum(Register.esp)] = esp;
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.memory);
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = std.process.argsAlloc(allocator) catch {
        std.debug.print("out of memory\n", .{});
        std.os.exit(1);
    };
    defer std.process.argsFree(allocator, args);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    if (args.len < 2) {
        try stdout.print("usage: x86-emu filename\n", .{});
        try bw.flush();
        std.os.exit(1);
    }

    var emu = try Emulator.init(allocator, MemorySize, 0x0000, 0x7c00);

    var file = std.fs.cwd().openFile(args[1], .{}) catch {
        std.debug.print("no such file: {s}\n", .{args[1]});
        std.os.exit(1);
    };
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();
    _ = try reader.readAll(emu.memory);
}
