const Elf = @This();

const std = @import("std");

const Allocator = std.mem.Allocator;
const Context = @import("../Context.zig");

pub const base_tag: Context.Tag = .elf;

base: Context,

header: std.elf.Elf64_Ehdr,
debug_info_sect: ?std.elf.Elf64_Shdr = null,
debug_string_sect: ?std.elf.Elf64_Shdr = null,
debug_abbrev_sect: ?std.elf.Elf64_Shdr = null,
debug_frame: ?std.elf.Elf64_Shdr = null,
eh_frame: ?std.elf.Elf64_Shdr = null,

pub fn isElfFile(data: []const u8) bool {
    // TODO: 32bit ELF files
    const header = @as(*const std.elf.Elf64_Ehdr, @ptrCast(@alignCast(data.ptr))).*;
    return std.mem.eql(u8, "\x7fELF", header.e_ident[0..4]);
}

pub fn deinit(elf: *Elf, gpa: Allocator) void {
    _ = elf;
    _ = gpa;
}

pub fn parse(gpa: Allocator, data: []const u8) !*Elf {
    const elf = try gpa.create(Elf);
    errdefer gpa.destroy(elf);

    elf.* = .{
        .base = .{
            .tag = .elf,
            .data = data,
        },
        .header = undefined,
    };
    elf.header = @as(*const std.elf.Elf64_Ehdr, @ptrCast(@alignCast(data.ptr))).*;

    const shdrs = elf.getShdrs();
    for (shdrs) |shdr| switch (shdr.sh_type) {
        std.elf.SHT_PROGBITS => {
            const sh_name = elf.getShString(@as(u32, @intCast(shdr.sh_name)));
            if (std.mem.eql(u8, sh_name, ".debug_info")) {
                elf.debug_info_sect = shdr;
            }
            if (std.mem.eql(u8, sh_name, ".debug_abbrev")) {
                elf.debug_abbrev_sect = shdr;
            }
            if (std.mem.eql(u8, sh_name, ".debug_str")) {
                elf.debug_string_sect = shdr;
            }
            if (std.mem.eql(u8, sh_name, ".debug_frame")) {
                elf.debug_frame = shdr;
            }
            if (std.mem.eql(u8, sh_name, ".eh_frame")) {
                elf.eh_frame = shdr;
            }
        },
        else => {},
    };

    return elf;
}

pub fn getDebugInfoData(elf: *const Elf) ?[]const u8 {
    const shdr = elf.debug_info_sect orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getDebugStringData(elf: *const Elf) ?[]const u8 {
    const shdr = elf.debug_string_sect orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getDebugAbbrevData(elf: *const Elf) ?[]const u8 {
    const shdr = elf.debug_abbrev_sect orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getDebugFrameData(elf: *const Elf) ?[]const u8 {
    const shdr = elf.debug_frame orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getEhFrameData(elf: *const Elf) ?[]const u8 {
    const shdr = elf.eh_frame orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getShdrByName(elf: *const Elf, name: []const u8) ?std.elf.Elf64_Shdr {
    const shdrs = elf.getShdrs();
    for (shdrs) |shdr| {
        const shdr_name = elf.getShString(shdr.sh_name);
        if (std.mem.eql(u8, shdr_name, name)) return shdr;
    }
    return null;
}

fn getShdrs(elf: *const Elf) []const std.elf.Elf64_Shdr {
    const shdrs = @as(
        [*]const std.elf.Elf64_Shdr,
        @ptrCast(@alignCast(elf.base.data.ptr + elf.header.e_shoff)),
    )[0..elf.header.e_shnum];
    return shdrs;
}

fn getShdrData(elf: *const Elf, shdr: std.elf.Elf64_Shdr) []const u8 {
    return elf.base.data[shdr.sh_offset..][0..shdr.sh_size];
}

fn getShString(elf: *const Elf, off: u32) []const u8 {
    const shdr = elf.getShdrs()[elf.header.e_shstrndx];
    const shstrtab = elf.getShdrData(shdr);
    std.debug.assert(off < shstrtab.len);
    return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(shstrtab.ptr + off)), 0);
}

pub fn getArch(elf: *const Elf) ?std.Target.Cpu.Arch {
    return switch (elf.header.e_machine) {
        .AVR => .avr,
        .MSP430 => .msp430,
        .ARC => .arc,
        .ARM => .arm,
        .@"68K" => .m68k,
        .MIPS => .mips,
        .MIPS_RS3_LE => .mipsel,
        .PPC => .powerpc,
        .SPARC => .sparc,
        .@"386" => .x86,
        .XCORE => .xcore,
        .CSR_KALIMBA => .kalimba,
        .LANAI => .lanai,
        .AARCH64 => .aarch64,
        .PPC64 => .powerpc64,
        .RISCV => .riscv64,
        .X86_64 => .x86_64,
        .BPF => .bpfel,
        .SPARCV9 => .sparc64,
        .S390 => .s390x,
        .SPU_2 => .spu_2,
        // FIXME:
        // No support for .loongarch32 yet so it is safe to assume we are on .loongarch64.
        //
        // However, when e_machine is .LOONGARCH, we should check
        // ei_class's value to decide the CPU architecture.
        // - ELFCLASS32 => .loongarch32
        // - ELFCLASS64 => .loongarch64
        .LOONGARCH => .loongarch64,
        // there's many cases we don't (yet) handle, or will never have a
        // zig target cpu arch equivalent (such as null).
        else => null,
    };
}
