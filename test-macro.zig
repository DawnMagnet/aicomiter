const std = @import("std");

pub const AIConfig = struct {
    provider: []const u8 = "openai",
    temperature: f32 = 0.7,
    max_tokens: i32 = 500,
};

pub const GenerateConfig = struct {
    language: []const u8 = "en",
    count: i32 = 1,
};

pub const Config = struct {
    ai: AIConfig = .{},
    generate: GenerateConfig = .{},

    fn parseYaml(self: *@This(), content: []const u8) !void {
        var lines = std.mem.splitSequence(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) continue;

            inline for (std.meta.fields(AIConfig)) |field| {
                const prefix = field.name ++ ":";
                if (std.mem.startsWith(u8, trimmed, prefix)) {
                    const val = std.mem.trim(u8, trimmed[prefix.len..], " \t\"");
                    if (field.type == []const u8) {
                        @field(self.ai, field.name) = val;
                    } else if (field.type == f32) {
                        @field(self.ai, field.name) = try std.fmt.parseFloat(f32, val);
                    } else if (field.type == i32) {
                        @field(self.ai, field.name) = try std.fmt.parseInt(i32, val, 10);
                    }
                }
            }

            inline for (std.meta.fields(GenerateConfig)) |field| {
                const prefix = field.name ++ ":";
                if (std.mem.startsWith(u8, trimmed, prefix)) {
                    const val = std.mem.trim(u8, trimmed[prefix.len..], " \t\"");
                    if (field.type == []const u8) {
                        @field(self.generate, field.name) = val;
                    } else if (field.type == f32) {
                        @field(self.generate, field.name) = try std.fmt.parseFloat(f32, val);
                    } else if (field.type == i32) {
                        @field(self.generate, field.name) = try std.fmt.parseInt(i32, val, 10);
                    }
                }
            }
        }
    }
};

pub fn main() !void {
    var config = Config{};
    try config.parseYaml("provider: anthropic\ntemperature: 0.9\ncount: 5");
    std.debug.print("{s} {d} {d}\n", .{config.ai.provider.ptr, config.ai.temperature, config.generate.count});
}
