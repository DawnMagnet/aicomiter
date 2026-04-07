const std = @import("std");

pub const Git = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Git {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Git) void {
        _ = self;
    }

    pub fn getStagedDiff(self: Git) ![]const u8 {
        var child = std.process.Child.init(&.{ "git", "diff", "--cached" }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        defer _ = child.wait() catch {};

        const stdout = child.stdout orelse return error.NoStdout;
        const diff = try stdout.readToEndAlloc(self.allocator, 1024 * 1024);

        return diff;
    }

    pub fn stageAll(self: Git) !void {
        var child = std.process.Child.init(&.{ "git", "add", "-A" }, self.allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();

        switch (term) {
            .Exited => |code| {
                if (code != 0) return error.GitStageFailed;
            },
            else => return error.GitStageFailed,
        }
    }

    pub fn commit(self: Git, message: []const u8) !void {
        const argv = &.{ "git", "commit", "-m", message };
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();

        switch (term) {
            .Exited => |code| {
                if (code != 0) return error.GitCommitFailed;
            },
            else => return error.GitCommitFailed,
        }
    }

    pub fn push(self: Git) !void {
        var child = std.process.Child.init(&.{ "git", "push" }, self.allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();

        switch (term) {
            .Exited => |code| {
                if (code != 0) return error.GitPushFailed;
            },
            else => return error.GitPushFailed,
        }
    }
};

test "Git - initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const git = Git.init(allocator);
    defer git.deinit();

    // Just verifying struct is formed properly.
    try testing.expect(@TypeOf(git.allocator) == std.mem.Allocator);
}
