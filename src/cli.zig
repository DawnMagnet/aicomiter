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

    const OptionTag = enum {
        api_key,
        provider,
        model,
        base_url,
        temperature,
        top_p,
        max_tokens,
        timeout,
        language,
        count,
        config,
        all,
        push,
        commit,
        format,
        show_config_sources,
    };

    const option_map = std.StaticStringMap(OptionTag).initComptime(.{
        .{ "--api-key", .api_key },
        .{ "--provider", .provider },
        .{ "--model", .model },
        .{ "--base-url", .base_url },
        .{ "--temperature", .temperature },
        .{ "--top-p", .top_p },
        .{ "--max-tokens", .max_tokens },
        .{ "--timeout", .timeout },
        .{ "-l", .language },
        .{ "--language", .language },
        .{ "-c", .count },
        .{ "--count", .count },
        .{ "--config", .config },
        .{ "-a", .all },
        .{ "--all", .all },
        .{ "-p", .push },
        .{ "--push", .push },
        .{ "-C", .commit },
        .{ "--commit", .commit },
        .{ "--format", .format },
        .{ "--show-config-sources", .show_config_sources },
    });

    pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !CLI {
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
            const tag = option_map.get(arg) orelse continue;

            switch (tag) {
                .api_key => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.api_key, allocator, value);
                },
                .provider => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.provider, allocator, value);
                },
                .model => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.model, allocator, value);
                },
                .base_url => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.base_url, allocator, value);
                },
                .temperature => if (nextArg(args, &i)) |value| {
                    cli.temperature = try std.fmt.parseFloat(f32, value);
                },
                .top_p => if (nextArg(args, &i)) |value| {
                    cli.top_p = try std.fmt.parseFloat(f32, value);
                },
                .max_tokens => if (nextArg(args, &i)) |value| {
                    cli.max_tokens = try std.fmt.parseInt(i32, value, 10);
                },
                .timeout => if (nextArg(args, &i)) |value| {
                    cli.timeout = try std.fmt.parseInt(i32, value, 10);
                },
                .language => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.language, allocator, value);
                },
                .count => if (nextArg(args, &i)) |value| {
                    cli.count = try std.fmt.parseInt(i32, value, 10);
                },
                .config => if (nextArg(args, &i)) |value| {
                    try setOptionalString(&cli.config, allocator, value);
                },
                .all => cli.all = true,
                .push => cli.push = true,
                .commit => cli.commit = true,
                .format => if (nextArg(args, &i)) |value| {
                    try setRequiredString(&cli.format, allocator, value);
                },
                .show_config_sources => if (nextArg(args, &i)) |value| {
                    cli.show_config_sources = !std.mem.eql(u8, value, "false");
                },
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

    fn nextArg(args: []const [:0]const u8, index: *usize) ?[]const u8 {
        if (index.* + 1 >= args.len) return null;
        index.* += 1;
        return args[index.*];
    }

    fn setOptionalString(target: *?[]const u8, allocator: std.mem.Allocator, value: []const u8) !void {
        if (target.*) |existing| allocator.free(existing);
        target.* = try allocator.dupe(u8, value);
    }

    fn setRequiredString(target: *[]const u8, allocator: std.mem.Allocator, value: []const u8) !void {
        allocator.free(target.*);
        target.* = try allocator.dupe(u8, value);
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
