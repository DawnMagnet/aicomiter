const std = @import("std");
const Config = @import("config.zig").Config;

pub const AI = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,

    const system_prompt = "You are an expert developer. Generate a concise, conventional git commit message based on the diff. Do not explain, just return the commit message.";

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !AI {
        return .{
            .allocator = allocator,
            .io = io,
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

        const base_url = normalizeBaseUrl(self.config.ai.base_url, "https://api.openai.com/v1");

        const url = try std.fmt.allocPrint(self.allocator, "{s}/chat/completions", .{base_url});
        defer self.allocator.free(url);

        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.config.ai.api_key});
        defer self.allocator.free(auth_header);

        const user_prompt = try buildUserPrompt(self.allocator, language, diff);
        defer self.allocator.free(user_prompt);

        var payload_aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer payload_aw.deinit();

        var w: std.json.Stringify = .{ .writer = &payload_aw.writer, .options = .{} };
        try w.write(.{
            .model = model,
            .messages = &[_]struct { role: []const u8, content: []const u8 }{
                .{
                    .role = "system",
                    .content = system_prompt,
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

        const headers = [_]std.http.Header{
            .{ .name = "Authorization", .value = auth_header },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const response_body = try self.fetchJson(url, headers[0..], payload_aw.writer.buffered());
        defer self.allocator.free(response_body);

        return try parseOpenAIResponse(self.allocator, response_body);
    }

    fn generateAnthropic(self: *AI, diff: []const u8, language: []const u8, count: i32) ![]const u8 {
        const model = if (self.config.ai.model.len > 0)
            self.config.ai.model
        else
            "claude-3-5-sonnet-20241022";

        _ = count; // Anthropic API does not support n (multiple generations) the same way

        const base_url = normalizeBaseUrl(self.config.ai.base_url, "https://api.anthropic.com/v1");

        const url = try std.fmt.allocPrint(self.allocator, "{s}/messages", .{base_url});
        defer self.allocator.free(url);

        const user_prompt = try buildUserPrompt(self.allocator, language, diff);
        defer self.allocator.free(user_prompt);

        var payload_aw: std.Io.Writer.Allocating = .init(self.allocator);
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
            .system = system_prompt,
            .temperature = self.config.ai.temperature,
            .top_p = self.config.ai.top_p,
            .max_tokens = self.config.ai.max_tokens,
        });

        const headers = [_]std.http.Header{
            .{ .name = "x-api-key", .value = self.config.ai.api_key },
            .{ .name = "anthropic-version", .value = "2023-06-01" },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const response_body = try self.fetchJson(url, headers[0..], payload_aw.writer.buffered());
        defer self.allocator.free(response_body);

        return try parseAnthropicResponse(self.allocator, response_body);
    }

    fn normalizeBaseUrl(config_base_url: []const u8, default_base_url: []const u8) []const u8 {
        var base_url = if (config_base_url.len > 0) config_base_url else default_base_url;
        if (std.mem.endsWith(u8, base_url, "/")) {
            base_url = base_url[0 .. base_url.len - 1];
        }
        return base_url;
    }

    fn buildUserPrompt(allocator: std.mem.Allocator, language: []const u8, diff: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator, "Language: {s}\nDiff:\n{s}", .{ language, diff });
    }

    fn fetchJson(self: *AI, url: []const u8, headers: []const std.http.Header, payload: []const u8) ![]const u8 {
        var client: std.http.Client = .{ .allocator = self.allocator, .io = self.io };
        defer client.deinit();

        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();

        const res = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = payload,
            .extra_headers = headers,
            .response_writer = &aw.writer,
        });

        if (res.status != .ok) {
            std.debug.print("API Error ({}): {s}\n", .{ res.status, aw.writer.buffered() });
            return error.ApiRequestFailed;
        }

        return try self.allocator.dupe(u8, aw.writer.buffered());
    }

    fn parseOpenAIResponse(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
        defer parsed.deinit();

        const root = parsed.value;
        const msg = root.object.get("choices").?.array.items[0].object.get("message").?.object.get("content").?.string;
        return try allocator.dupe(u8, msg);
    }

    fn parseAnthropicResponse(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
        defer parsed.deinit();

        const root = parsed.value;
        const msg = root.object.get("content").?.array.items[0].object.get("text").?.string;
        return try allocator.dupe(u8, msg);
    }
};

test "AI - generateCommitMessage (HTTP)" {
    return error.SkipZigTest;
}
