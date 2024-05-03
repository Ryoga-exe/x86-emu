const Emulator = @import("emulator.zig");

pub fn movR32Imm32(self: *Emulator) void {
    const reg = self.getCode8(0) - 0xB8;
    const value = self.getCode32(1);
    self.registers[reg] = value;
    self.eip += 5;
}

pub fn shortJump(self: *Emulator) void {
    const diff = self.getSignCode8(1);
    const res: i32 = @intCast(self.eip);

    self.eip = @bitCast(res + diff + 2);
}

pub fn nearJump(self: *Emulator) void {
    const diff = self.getSignCode32(1);
    const res: i32 = @intCast(self.eip);

    self.eip = @bitCast(res + diff + 5);
}
