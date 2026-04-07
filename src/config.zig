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
    config_file: ?[]const u8 = null,

    const Self = @This();

    pub fn load(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .allocator = allocator,
        };

        // Load from config file first
        if (std.process.getEnvVarOwned(allocator, "HOME")) |home_dir| {
            defer allocator.free(home_dir);
            const config_path = try std.fmt.allocPrint(allocator, "{s}/.aicomiter.yaml", .{home_dir});
            defer allocator.free(config_path);

            if (std.fs.openFileAbsolute(config_path, .{})) |file| {
                defer file.close();
                const content = try file.readToEndAlloc(allocator, 1024 * 100);
                defer allocator.free(content);

                try self.parseYaml(content);
            } else |_| {}
        } else |_| {}

        // Load from environment variables
        self.loadFromEnv(allocator);

        return self;
    }

    fn parseYaml(self: *Self, content: []const u8) !void {
        var lines = std.mem.splitSequence(u8, content, "\n");

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) continue;

            if (std.mem.startsWith(u8, trimmed, "provider:")) {
                const value = std.mem.trim(u8, trimmed[9..], " \t\"");
                self.ai.provider = value;
            } else if (std.mem.startsWith(u8, trimmed, "api_key:")) {
                const value = std.mem.trim(u8, trimmed[8..], " \t\"");
                self.ai.api_key = value;
            } else if (std.mem.startsWith(u8, trimmed, "base_url:")) {
                const value = std.mem.trim(u8, trimmed[9..], " \t\"");
                self.ai.base_url = value;
            } else if (std.mem.startsWith(u8, trimmed, "model:")) {
                const value = std.mem.trim(u8, trimmed[6..], " \t\"");
                self.ai.model = value;
            } else if (std.mem.startsWith(u8, trimmed, "temperature:")) {
                const value = std.mem.trim(u8, trimmed[12..], " \t");
                self.ai.temperature = try std.fmt.parseFloat(f32, value);
            } else if (std.mem.startsWith(u8, trimmed, "top_p:")) {
                const value = std.mem.trim(u8, trimmed[6..], " \t");
                self.ai.top_p = try std.fmt.parseFloat(f32, value);
            } else if (std.mem.startsWith(u8, trimmed, "max_tokens:")) {
                const value = std.mem.trim(u8, trimmed[11..], " \t");
                self.ai.max_tokens = try std.fmt.parseInt(i32, value, 10);
            } else if (std.mem.startsWith(u8, trimmed, "timeout:")) {
                const value = std.mem.trim(u8, trimmed[8..], " \t");
                self.ai.timeout = try std.fmt.parseInt(i32, value, 10);
            } else if (std.mem.startsWith(u8, trimmed, "language:")) {
                const value = std.mem.trim(u8, trimmed[9..], " \t\"");
                self.generate.language = value;
            } else if (std.mem.startsWith(u8, trimmed, "count:")) {
                const value = std.mem.trim(u8, trimmed[6..], " \t");
                self.generate.count = try std.fmt.parseInt(i32, value, 10);
            }
        }
    }

    fn loadFromEnv(self: *Self, allocator: std.mem.Allocator) void {
        if (std.process.getEnvVarOwned(allocator, "AICOMITER_AI_API_KEY")) |val| {
            defer allocator.free(val);
            self.ai.api_key = val;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "API_KEY")) |val| {
            defer allocator.free(val);
            self.ai.api_key = val;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "AICOMITER_AI_MODEL")) |val| {
            defer allocator.free(val);
            self.ai.model = val;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "MODEL")) |val| {
            defer allocator.free(val);
            self.ai.model = val;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "AICOMITER_GENERATE_LANGUAGE")) |val| {
            defer allocator.free(val);
            self.generate.language = val;
        } else |_| {}
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
        _ = self;
    }
};
