const std = @import("std");

pub fn escapeJson(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try result.append('"');
    for (str) |char| {
        switch (char) {
            '"' => try result.appendSlice("\\\""),
            '\\' => try result.appendSlice("\\\\"),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            else => try result.append(char),
        }
    }
    try result.append('"');

    return result.toOwnedSlice();
}

pub fn trimLeft(str: []const u8, char: u8) []const u8 {
    var i: usize = 0;
    while (i < str.len and str[i] == char) : (i += 1) {}
    return str[i..];
}

pub fn trimRight(str: []const u8, char: u8) []const u8 {
    if (str.len == 0) return str;
    var i = str.len;
    while (i > 0 and str[i - 1] == char) : (i -= 1) {}
    return str[0..i];
}
