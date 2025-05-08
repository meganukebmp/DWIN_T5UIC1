// ImHex pattern for DWIN ico files

import std.mem;

struct IconEntry {
    be u16 width;
    be u16 height;
    be u32 offset;
    padding[1];
    be u16 length;
    padding[5];
    std::mem::Bytes<length> data @ offset [[hex::visualize("image", this)]];
} [[hex::visualize("image", data)]];

IconEntry icons[256] @ 0x00 [[inline]];