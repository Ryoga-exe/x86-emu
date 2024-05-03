pub const Register = enum {
    EAX,
    ECX,
    EDX,
    EBX,
    ESP,
    EBP,
    ESI,
    EDI,

    pub const len = @import("std").meta.fields(@This()).len;
    pub const name = @import("std").meta.fieldNames(@This());
};
