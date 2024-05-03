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

const RegisterName = [_][]const u8{ "EAX", "ECX", "EDX", "EBX", "ESP", "EBP", "ESI", "EDI" };

const Emulator = struct {
    const Self = @This();
    const InstructionFn = ?*const fn (*Self) void;

    // general registers
    registers: [@intFromEnum(Register.size)]u32,
    // EFLAGS register
    eflags: u32,
    // byte string
    memory: []u8,
    // Program counter
    eip: u32,

    instructions: [256]InstructionFn,

    allocator: Allocator,

    pub fn init(allocator: Allocator, size: usize, eip: u32, esp: u32) !Self {
        var self = Self{
            .registers = [1]u32{0} ** @intFromEnum(Register.size),
            .eflags = 0,
            .memory = try allocator.alloc(u8, size),
            .eip = eip,
            .instructions = [1]InstructionFn{null} ** 256,
            .allocator = allocator,
        };
        self.registers[@intFromEnum(Register.esp)] = esp;
        self.initInstructions();
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.memory);
    }
    fn initInstructions(self: *Self) void {
        for (0..8) |i| {
            self.instructions[0xB8 + i] = movR32Imm32;
        }
        self.instructions[0xE9] = nearJump;
        self.instructions[0xEB] = shortJump;
    }
    pub fn movR32Imm32(self: *Self) void {
        const reg = self.getCode8(0) - 0xB8;
        const value = self.getCode32(1);
        self.registers[reg] = value;
        self.eip += 5;
    }
    pub fn shortJump(self: *Self) void {
        const diff = self.getSignCode8(1);
        const res: i32 = @intCast(self.eip);

        self.eip = @bitCast(res + diff + 2);
    }
    pub fn nearJump(self: *Self) void {
        const diff = self.getSignCode32(1);
        const res: i32 = @intCast(self.eip);

        self.eip = @bitCast(res + diff + 5);
    }
    pub fn getCode8(self: Self, index: usize) u8 {
        return self.memory[self.eip + index];
    }
    pub fn getSignCode8(self: Self, index: usize) i8 {
        return @bitCast(self.memory[self.eip + index]);
    }
    pub fn getCode32(self: Self, index: usize) u32 {
        var ret: u32 = 0;
        // get value from memory as little endian
        for (0..4) |i| {
            ret |= @as(u32, self.getCode8(index + i)) << @intCast(i * 8);
        }
        return ret;
    }
    pub fn getSignCode32(self: Self, index: usize) i32 {
        return @bitCast(self.getCode32(index));
    }
    pub fn dumpRegisters(self: Self, writer: anytype) !void {
        for (0..@intFromEnum(Register.size)) |i| {
            try writer.print("{s} = {x:0>8}\n", .{ RegisterName[i], self.registers[i] });
        }
        try writer.print("EIP = {x:0>8}\n", .{self.eip});
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

    // EIP = 0x7C00, ESP = 0x7C00
    var emu = try Emulator.init(allocator, MemorySize, 0x7c00, 0x7c00);

    var file = std.fs.cwd().openFile(args[1], .{}) catch {
        std.debug.print("no such file: {s}\n", .{args[1]});
        std.os.exit(1);
    };
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();
    _ = try reader.readAtLeast(emu.memory[0x7c00..], 0x200);

    while (emu.eip < MemorySize) {
        const code = emu.getCode8(0);

        try stdout.print("EIP = {X}, Code = {X:0>2}\n", .{ emu.eip, code });
        try bw.flush();

        if (emu.instructions[code]) |instruction| {
            // execute an instruction
            instruction(&emu);
        } else {
            try stdout.print("\n\nNot Implemented: {x}\n", .{code});
            try bw.flush();
            break;
        }

        if (emu.eip == 0x00) {
            try stdout.print("\n\nend of program\n\n", .{});
            try bw.flush();
            break;
        }
    }
    try emu.dumpRegisters(stdout);
    try bw.flush();
}
