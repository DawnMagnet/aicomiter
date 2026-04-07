const std = @import("std");

pub const CLI = struct {
    command: []const u8,
    api_key: ?[]const u8 = null,
    provider: ?[]const u8 = null,
    model: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    max_tokens: ?i32 = null,
    timeout: ?i32 = null,
    language: ?[]const u8 = null,
    count: ?i32 = null,
    config: ?[]const u8 = null,
    all: bool = false,
    push: bool = false,
    commit: bool = false,
    format: []const u8,
    show_config_sources: bool = true,

    pub fn parse(allocator: std.mem.Allocator) !CLI {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        var command: []const u8 = "help";
        const format: []const u8 = "text";

        if (args.len < 2) {
            return CLI{
                .command = try allocator.dupe(u8, command),
                .format = try allocator.dupe(u8, format),
            };
        }

        var i: usize = 1;
        if (args.len > 1 and !std.mem.startsWith(u8, args[1], "-")) {
            command = args[1];
            i = 2;
        }

        var cli = CLI{
            .command = try allocator.dupe(u8, command),
            .format = try allocator.dupe(u8, format),
        };

        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--api-key")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.api_key = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--provider")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.provider = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--model")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.model = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--base-url")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.base_url = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--temperature")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.temperature = try std.fmt.parseFloat(f32, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--top-p")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.top_p = try std.fmt.parseFloat(f32, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--max-tokens")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.max_tokens = try std.fmt.parseInt(i32, args[i], 10);
                }
            } else if (std.mem.eql(u8, arg, "--timeout")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.timeout = try std.fmt.parseInt(i32, args[i], 10);
                }
            } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--language")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.language = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--count")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.count = try std.fmt.parseInt(i32, args[i], 10);
                }
            } else if (std.mem.eql(u8, arg, "--config")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.config = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--all")) {
                cli.all = true;
            } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--push")) {
                cli.push = true;
            } else if (std.mem.eql(u8, arg, "-C") or std.mem.eql(u8, arg, "--commit")) {
                cli.commit = true;
            } else if (std.mem.eql(u8, arg, "--format")) {
                if (i + 1 < args.len) {
                    i += 1;
                    allocator.free(cli.format);
                    cli.format = try allocator.dupe(u8, args[i]);
                }
            } else if (std.mem.eql(u8, arg, "--show-config-sources")) {
                if (i + 1 < args.len) {
                    i += 1;
                    cli.show_config_sources = !std.mem.eql(u8, args[i], "false");
                }
            }
        }

        return cli;
    }

    pub fn deinit(self: *CLI, allocator: std.mem.Allocator) void {
        allocator.free(self.command);
        if (self.api_key) |api_key| allocator.free(api_key);
        if (self.provider) |provider| allocator.free(provider);
        if (self.model) |model| allocator.free(model);
        if (self.base_url) |base_url| allocator.free(base_url);
        if (self.language) |language| allocator.free(language);
        if (self.config) |config| allocator.free(config);
        allocator.free(self.format);
    }
};

test "CLI - default instantiation" {
    const cli = CLI{
        .command = "help",
        .format = "text",
    };
    try std.testing.expectEqualStrings("help", cli.command);
    try std.testing.expectEqualStrings("text", cli.format);
    try std.testing.expect(cli.api_key == null);
    try std.testing.expect(cli.temperature == null);
}
