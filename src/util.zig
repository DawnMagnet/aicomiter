const std = @import("std");

pub fn escapeJson(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    try result.append(allocator, '"');
    for (str) |char| {
        switch (char) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, char),
        }
    }
    try result.append(allocator, '"');

    return result.toOwnedSlice(allocator);
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

test "util - escapeJson" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const input = "testing \"quotes\" and \\ slashes\nand new\tlines";
    const expected = "\"testing \\\"quotes\\\" and \\\\ slashes\\nand new\\tlines\"";
    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "util - trimLeft & trimRight" {
    const testing = std.testing;

    try testing.expectEqualStrings("hello", trimLeft("   hello", ' '));
    try testing.expectEqualStrings("   hello", trimLeft("   hello", 'a'));

    try testing.expectEqualStrings("world", trimRight("world   ", ' '));
}
