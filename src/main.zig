const std = @import("std");
const Emulator = @import("emulator.zig");
const MemorySize = 1024 * 1024; // 1MB

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

        if (!emu.executeInstruction(code)) {
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
