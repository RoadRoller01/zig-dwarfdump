const Context = @This();

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

const Allocator = mem.Allocator;

pub const Elf = @import("Context/Elf.zig");
pub const MachO = @import("Context/MachO.zig");
pub const Wasm = @import("Context/Wasm.zig");

tag: Tag,
data: []const u8,

pub const Tag = enum {
    elf,
    macho,
    wasm,
};

pub fn cast(base: *Context, comptime T: type) ?*T {
    if (base.tag != T.base_tag)
        return null;

    return @fieldParentPtr(T, "base", base);
}

pub fn constCast(base: *const Context, comptime T: type) ?*const T {
    if (base.tag != T.base_tag)
        return null;

    return @fieldParentPtr(T, "base", base);
}

pub fn deinit(base: *Context, gpa: Allocator) void {
    gpa.free(base.data);
}

pub fn destroy(base: *Context, gpa: Allocator) void {
    base.deinit(gpa);
    switch (base.tag) {
        .elf => {
            const parent = @fieldParentPtr(Elf, "base", base);
            parent.deinit(gpa);
            gpa.destroy(parent);
        },
        .macho => {
            const parent = @fieldParentPtr(MachO, "base", base);
            parent.deinit(gpa);
            gpa.destroy(parent);
        },
        .wasm => {
            const parent = @fieldParentPtr(Wasm, "base", base);
            parent.deinit(gpa);
            gpa.destroy(parent);
        },
    }
}

pub fn parse(gpa: Allocator, data: []const u8) !*Context {
    if (Elf.isElfFile(data)) {
        return &(try Elf.parse(gpa, data)).base;
    }
    if (MachO.isMachOFile(data)) {
        return &(try MachO.parse(gpa, data)).base;
    }
    if (Wasm.isWasmFile(data)) {
        return &(try Wasm.parse(gpa, data)).base;
    }
    return error.UnknownFileFormat;
}

pub fn getDebugInfoData(base: *const Context) ?[]const u8 {
    return switch (base.tag) {
        .elf => @fieldParentPtr(Elf, "base", base).getDebugInfoData(),
        .macho => @fieldParentPtr(MachO, "base", base).getDebugInfoData(),
        .wasm => @fieldParentPtr(Wasm, "base", base).getDebugInfoData(),
    };
}

pub fn getDebugStringData(base: *const Context) ?[]const u8 {
    return switch (base.tag) {
        .elf => @fieldParentPtr(Elf, "base", base).getDebugStringData(),
        .macho => @fieldParentPtr(MachO, "base", base).getDebugStringData(),
        .wasm => @fieldParentPtr(Wasm, "base", base).getDebugStringData(),
    };
}

pub fn getDebugAbbrevData(base: *const Context) ?[]const u8 {
    return switch (base.tag) {
        .elf => @fieldParentPtr(Elf, "base", base).getDebugAbbrevData(),
        .macho => @fieldParentPtr(MachO, "base", base).getDebugAbbrevData(),
        .wasm => @fieldParentPtr(Wasm, "base", base).getDebugAbbrevData(),
    };
}

pub fn getArch(base: *const Context) ?std.Target.Cpu.Arch {
    return switch (base.tag) {
        .elf => @fieldParentPtr(Elf, "base", base).getArch(),
        .macho => @fieldParentPtr(MachO, "base", base).getArch(),
        .wasm => .wasm32,
    };
}
pub fn getDwarfString(base: *const Context, off: u64) []const u8 {
    const debug_str = base.getDebugStringData().?;
    assert(off < debug_str.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(debug_str.ptr + off)), 0);
}
