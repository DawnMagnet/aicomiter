const std = @import("std");

pub const Git = struct {
    allocator: std.mem.Allocator,

    const max_diff_size = 1024 * 1024;

    pub fn init(allocator: std.mem.Allocator) Git {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Git) void {
        _ = self;
    }

    pub fn getStagedDiff(self: Git) ![]const u8 {
        return try self.runCaptureChecked(&.{ "git", "diff", "--cached" }, max_diff_size, error.GitDiffFailed);
    }

    pub fn stageAll(self: Git) !void {
        try self.runChecked(&.{ "git", "add", "-A" }, error.GitStageFailed);
    }

    pub fn commit(self: Git, message: []const u8) !void {
        try self.runChecked(&.{ "git", "commit", "-m", message }, error.GitCommitFailed);
    }

    pub fn push(self: Git) !void {
        try self.runChecked(&.{ "git", "push" }, error.GitPushFailed);
    }

    fn runChecked(self: Git, argv: []const []const u8, failure: anyerror) !void {
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();

        switch (term) {
            .Exited => |code| if (code != 0) return failure,
            else => return failure,
        }
    }

    fn runCaptureChecked(self: Git, argv: []const []const u8, max_bytes: usize, failure: anyerror) ![]const u8 {
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        const stdout = child.stdout orelse return error.NoStdout;
        const output = try stdout.readToEndAlloc(self.allocator, max_bytes);

        const term = try child.wait();
        switch (term) {
            .Exited => |code| if (code != 0) {
                self.allocator.free(output);
                return failure;
            },
            else => {
                self.allocator.free(output);
                return failure;
            },
        }

        return output;
    }
};

test "Git - initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const git = Git.init(allocator);
    defer git.deinit();

    // Validate structural initialization invariants.
    try testing.expect(@TypeOf(git.allocator) == std.mem.Allocator);
}
