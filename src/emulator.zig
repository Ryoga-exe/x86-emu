const std = @import("std");
const Allocator = std.mem.Allocator;
const Emulator = @This();
const Register = @import("register.zig").Register;

usingnamespace @import("instruction.zig");

// general registers
registers: [Register.len]u32,
// EFLAGS register
eflags: u32,
// byte string
memory: []u8,
// Program counter
eip: u32,

allocator: Allocator,

pub fn init(allocator: Allocator, size: usize, eip: u32, esp: u32) !Emulator {
    var emu = Emulator{
        .registers = [1]u32{0} ** Register.len,
        .eflags = 0,
        .memory = try allocator.alloc(u8, size),
        .eip = eip,
        .allocator = allocator,
    };
    emu.registers[@intFromEnum(Register.ESP)] = esp;
    return emu;
}

pub fn deinit(self: *Emulator) void {
    self.allocator.free(self.memory);
}

pub fn executeInstruction(self: *Emulator, code: u8) bool {
    switch (code) {
        0xB8...0xB8 + 7 => self.movR32Imm32(),
        0xE9 => self.nearJump(),
        0xEB => self.shortJump(),
        else => return false,
    }
    return true;
}

pub fn dumpRegisters(self: Emulator, writer: anytype) !void {
    for (0..Register.len) |i| {
        try writer.print("{s} = {x:0>8}\n", .{ Register.name[i], self.registers[i] });
    }
    try writer.print("EIP = {x:0>8}\n", .{self.eip});
}

// Get unsigned 8-bit value in relative position from program counter
pub fn getCode8(self: Emulator, index: usize) u8 {
    return self.memory[self.eip + index];
}

// Get signed 8-bit value in relative position from program counter
pub fn getSignCode8(self: Emulator, index: usize) i8 {
    return @bitCast(self.memory[self.eip + index]);
}

// Get unsigned 32-bit value in relative position from program counter
pub fn getCode32(self: Emulator, index: usize) u32 {
    var ret: u32 = 0;
    // get value from memory as little endian
    for (0..4) |i| {
        ret |= @as(u32, self.getCode8(index + i)) << @intCast(i * 8);
    }
    return ret;
}

// Get signed 32-bit value in relative position from program counter
pub fn getSignCode32(self: Emulator, index: usize) i32 {
    return @bitCast(self.getCode32(index));
}
