const std = @import("std");
const Config = @import("config.zig").Config;

pub const AI = struct {
    allocator: std.mem.Allocator,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, config: Config) !AI {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(_: *AI) void {}

    pub fn generateCommitMessage(self: *AI, diff: []const u8, language: []const u8, count: i32) ![]const u8 {
        if (std.mem.eql(u8, self.config.ai.provider, "openai")) {
            return try self.generateOpenAI(diff, language, count);
        } else if (std.mem.eql(u8, self.config.ai.provider, "anthropic")) {
            return try self.generateAnthropic(diff, language, count);
        }
        return error.UnknownProvider;
    }

    fn generateOpenAI(self: *AI, diff: []const u8, language: []const u8, count: i32) ![]const u8 {
        const model = if (self.config.ai.model.len > 0)
            self.config.ai.model
        else
            "gpt-4o-mini";

        var client: std.http.Client = .{ .allocator = self.allocator };
        defer client.deinit();

        var aw: std.io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();

        var base_url = if (self.config.ai.base_url.len > 0) self.config.ai.base_url else "https://api.openai.com/v1";
        if (std.mem.endsWith(u8, base_url, "/")) {
            base_url = base_url[0 .. base_url.len - 1];
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/chat/completions", .{base_url});
        defer self.allocator.free(url);

        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.config.ai.api_key});
        defer self.allocator.free(auth_header);

        const user_prompt = try std.fmt.allocPrint(self.allocator, "Language: {s}\nDiff:\n{s}", .{ language, diff });
        defer self.allocator.free(user_prompt);

        var payload_aw: std.io.Writer.Allocating = .init(self.allocator);
        defer payload_aw.deinit();

        var w: std.json.Stringify = .{ .writer = &payload_aw.writer, .options = .{} };
        try w.write(.{
            .model = model,
            .messages = &[_]struct { role: []const u8, content: []const u8 }{
                .{
                    .role = "system",
                    .content = "You are an expert developer. Generate a concise, conventional git commit message based on the diff. Do not explain, just return the commit message.",
                },
                .{
                    .role = "user",
                    .content = user_prompt,
                },
            },
            .temperature = self.config.ai.temperature,
            .top_p = self.config.ai.top_p,
            .max_tokens = self.config.ai.max_tokens,
            .n = count,
        });

        const res = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = payload_aw.writer.buffered(),
            .extra_headers = &.{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .response_writer = &aw.writer,
        });

        if (res.status != .ok) {
            std.debug.print("API Error ({}): {s}\n", .{ res.status, aw.writer.buffered() });
            return error.ApiRequestFailed;
        }

        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, aw.writer.buffered(), .{});
        defer parsed.deinit();

        const root = parsed.value;
        const msg = root.object.get("choices").?.array.items[0].object.get("message").?.object.get("content").?.string;
        return try self.allocator.dupe(u8, msg);
    }

    fn generateAnthropic(self: *AI, diff: []const u8, language: []const u8, count: i32) ![]const u8 {
        const model = if (self.config.ai.model.len > 0)
            self.config.ai.model
        else
            "claude-3-5-sonnet-20241022";

        _ = count; // Anthropic API does not support n (multiple generations) the same way

        var client: std.http.Client = .{ .allocator = self.allocator };
        defer client.deinit();

        var aw: std.io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();

        var base_url = if (self.config.ai.base_url.len > 0) self.config.ai.base_url else "https://api.anthropic.com/v1";
        if (std.mem.endsWith(u8, base_url, "/")) {
            base_url = base_url[0 .. base_url.len - 1];
        }

        const url = try std.fmt.allocPrint(self.allocator, "{s}/messages", .{base_url});
        defer self.allocator.free(url);

        const api_key = try std.fmt.allocPrint(self.allocator, "{s}", .{self.config.ai.api_key});
        defer self.allocator.free(api_key);

        const user_prompt = try std.fmt.allocPrint(self.allocator, "Language: {s}\nDiff:\n{s}", .{ language, diff });
        defer self.allocator.free(user_prompt);

        var payload_aw: std.io.Writer.Allocating = .init(self.allocator);
        defer payload_aw.deinit();

        var w: std.json.Stringify = .{ .writer = &payload_aw.writer, .options = .{} };
        try w.write(.{
            .model = model,
            .messages = &[_]struct { role: []const u8, content: []const u8 }{
                .{
                    .role = "user",
                    .content = user_prompt,
                },
            },
            .system = "You are an expert developer. Generate a concise, conventional git commit message based on the diff. Do not explain, just return the commit message.",
            .temperature = self.config.ai.temperature,
            .top_p = self.config.ai.top_p,
            .max_tokens = self.config.ai.max_tokens,
        });

        const res = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = payload_aw.writer.buffered(),
            .extra_headers = &.{
                .{ .name = "x-api-key", .value = api_key },
                .{ .name = "anthropic-version", .value = "2023-06-01" },
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .response_writer = &aw.writer,
        });

        if (res.status != .ok) {
            std.debug.print("API Error ({}): {s}\n", .{ res.status, aw.writer.buffered() });
            return error.ApiRequestFailed;
        }

        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, aw.writer.buffered(), .{});
        defer parsed.deinit();

        const root = parsed.value;
        const msg = root.object.get("content").?.array.items[0].object.get("text").?.string;
        return try self.allocator.dupe(u8, msg);
    }
};

test "AI - generateCommitMessage (HTTP)" {
    return error.SkipZigTest;
}
