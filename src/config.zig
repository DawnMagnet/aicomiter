const std = @import("std");
const CLI = @import("cli.zig").CLI;

pub const AIConfig = struct {
    provider: []const u8 = "openai",
    api_key: []const u8 = "",
    base_url: []const u8 = "",
    model: []const u8 = "",
    temperature: f32 = 0.7,
    top_p: f32 = 1.0,
    max_tokens: i32 = 500,
    timeout: i32 = 30,
};

pub const GenerateConfig = struct {
    language: []const u8 = "en",
    count: i32 = 1,
};

pub const Config = struct {
    ai: AIConfig = .{},
    generate: GenerateConfig = .{},
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    config_file: ?[]const u8 = null,

    const Self = @This();

    const ai_fields = std.meta.fields(AIConfig);
    const generate_fields = std.meta.fields(GenerateConfig);

    pub fn load(allocator: std.mem.Allocator) !Self {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var self = Self{
            .allocator = allocator,
            .arena = arena,
        };
        const aa = arena.allocator();

        // Load persistent baseline first to establish deterministic defaults.
        if (std.process.getEnvVarOwned(aa, "HOME")) |home_dir| {
            const config_path = try std.fmt.allocPrint(aa, "{s}/.aicomiter.yaml", .{home_dir});

            if (std.fs.openFileAbsolute(config_path, .{})) |file| {
                defer file.close();
                self.config_file = config_path;
                const content = try file.readToEndAlloc(aa, 1024 * 100);
                try self.parseYaml(content);
            } else |_| {}
        } else |_| {}

        // Apply environment-layer overrides as deployment-time controls.
        self.loadFromEnv(aa);

        return self;
    }

    fn parseYaml(self: *Self, content: []const u8) !void {
        var lines = std.mem.splitSequence(u8, content, "\n");

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) continue;

            if (try applyFieldToStruct(AIConfig, &self.ai, ai_fields, trimmed)) continue;
            _ = try applyFieldToStruct(GenerateConfig, &self.generate, generate_fields, trimmed);
        }
    }

    fn loadFromEnv(self: *Self, aa: std.mem.Allocator) void {
        applyFirstEnvValue(aa, &self.ai.api_key, &.{ "AICOMITER_AI_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "API_KEY" });
        applyFirstEnvValue(aa, &self.ai.base_url, &.{ "AICOMITER_AI_BASE_URL", "OPENAI_API_BASE", "API_BASE_URL" });
        applyFirstEnvValue(aa, &self.ai.provider, &.{"AICOMITER_AI_PROVIDER"});
        applyFirstEnvValue(aa, &self.ai.model, &.{ "AICOMITER_AI_MODEL", "MODEL" });
        applyFirstEnvValue(aa, &self.generate.language, &.{"AICOMITER_GENERATE_LANGUAGE"});
    }

    pub fn applyCliOverrides(self: *Self, cli: CLI) void {
        if (cli.api_key) |val| self.ai.api_key = val;
        if (cli.provider) |val| self.ai.provider = val;
        if (cli.model) |val| self.ai.model = val;
        if (cli.base_url) |val| self.ai.base_url = val;
        if (cli.temperature) |val| self.ai.temperature = val;
        if (cli.top_p) |val| self.ai.top_p = val;
        if (cli.max_tokens) |val| self.ai.max_tokens = val;
        if (cli.timeout) |val| self.ai.timeout = val;
        if (cli.language) |val| self.generate.language = val;
        if (cli.count) |val| self.generate.count = val;
    }

    pub fn print(self: Self) !void {
        std.debug.print("Configuration:\n", .{});
        std.debug.print("  AI Provider: {s}\n", .{self.ai.provider});
        std.debug.print("  API Key: [hidden]\n", .{});
        if (self.ai.base_url.len > 0) {
            std.debug.print("  Base URL: {s}\n", .{self.ai.base_url});
        }
        if (self.ai.model.len > 0) {
            std.debug.print("  Model: {s}\n", .{self.ai.model});
        }
        std.debug.print("  Temperature: {d}\n", .{self.ai.temperature});
        std.debug.print("  Top P: {d}\n", .{self.ai.top_p});
        std.debug.print("  Max Tokens: {d}\n", .{self.ai.max_tokens});
        std.debug.print("  Timeout: {d}s\n", .{self.ai.timeout});
        std.debug.print("  Language: {s}\n", .{self.generate.language});
        std.debug.print("  Count: {d}\n", .{self.generate.count});
    }

    pub fn printJson(self: Self, allocator: std.mem.Allocator) !void {
        const json = try std.fmt.allocPrint(allocator,
            \\{{
            \\  "ai": {{
            \\    "provider": "{s}",
            \\    "api_key": "***hidden***",
            \\    "base_url": "{s}",
            \\    "model": "{s}",
            \\    "temperature": {d},
            \\    "top_p": {d},
            \\    "max_tokens": {d},
            \\    "timeout": {d}
            \\  }},
            \\  "generate": {{
            \\    "language": "{s}",
            \\    "count": {d}
            \\  }}
            \\}}
        , .{ self.ai.provider, self.ai.base_url, self.ai.model, self.ai.temperature, self.ai.top_p, self.ai.max_tokens, self.ai.timeout, self.generate.language, self.generate.count });
        defer allocator.free(json);
        std.debug.print("{s}\n", .{json});
    }

    pub fn printSources(self: Self) !void {
        if (self.config_file) |file| {
            std.debug.print("config file ({s})", .{file});
        } else {
            std.debug.print("defaults", .{});
        }
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.allocator.destroy(self.arena);
    }

    fn applyFirstEnvValue(aa: std.mem.Allocator, target: *[]const u8, names: []const []const u8) void {
        for (names) |name| {
            if (std.process.getEnvVarOwned(aa, name)) |value| {
                target.* = value;
                return;
            } else |_| {}
        }
    }

    fn applyFieldToStruct(
        comptime T: type,
        target: *T,
        comptime fields: []const std.builtin.Type.StructField,
        line: []const u8,
    ) !bool {
        inline for (fields) |field| {
            const prefix = field.name ++ ":";
            if (std.mem.startsWith(u8, line, prefix)) {
                const raw = std.mem.trim(u8, line[prefix.len..], " \t\"");
                @field(target, field.name) = try parseScalar(field.type, raw);
                return true;
            }
        }

        return false;
    }

    fn parseScalar(comptime T: type, raw: []const u8) !T {
        if (T == []const u8) return raw;
        if (T == f32) return try std.fmt.parseFloat(f32, raw);
        if (T == i32) return try std.fmt.parseInt(i32, raw, 10);
        @compileError("Unsupported scalar type in config parser");
    }
};

test "config - applyCliOverrides" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);

    var config = Config{
        .allocator = allocator,
        .arena = arena,
    };
    defer config.deinit();

    const cli = CLI{
        .command = "gen",
        .format = "text",
        .api_key = "test_key",
        .provider = "anthropic",
        .temperature = 0.5,
        .count = 5,
        .all = true,
    };

    config.applyCliOverrides(cli);

    try testing.expectEqualStrings("test_key", config.ai.api_key);
    try testing.expectEqualStrings("anthropic", config.ai.provider);
    try testing.expectEqual(0.5, config.ai.temperature);
    try testing.expectEqual(5, config.generate.count);
}
