const std = @import("std");

pub const Git = struct {
    allocator: std.mem.Allocator,
    io: std.Io,

    const max_diff_size = 1024 * 1024;

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Git {
        return .{
            .allocator = allocator,
            .io = io,
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
        const result = try std.process.run(self.allocator, self.io, .{
            .argv = argv,
            .stdout_limit = .limited(1024 * 1024),
            .stderr_limit = .limited(1024 * 1024),
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        switch (result.term) {
            .exited => |code| if (code != 0) {
                printCommandOutput(result);
                return failure;
            },
            else => {
                printCommandOutput(result);
                return failure;
            },
        }
    }

    fn runCaptureChecked(self: Git, argv: []const []const u8, max_bytes: usize, failure: anyerror) ![]const u8 {
        const result = try std.process.run(self.allocator, self.io, .{
            .argv = argv,
            .stdout_limit = .limited(max_bytes),
            .stderr_limit = .limited(1024 * 1024),
        });
        errdefer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        switch (result.term) {
            .exited => |code| if (code != 0) {
                printCommandOutput(result);
                return failure;
            },
            else => {
                printCommandOutput(result);
                return failure;
            },
        }

        return result.stdout;
    }

    fn printCommandOutput(result: std.process.RunResult) void {
        if (result.stdout.len > 0) std.debug.print("{s}", .{result.stdout});
        if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});
    }
};

test "Git - initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const git = Git.init(allocator, std.testing.io);
    defer git.deinit();

    // Validate structural initialization invariants.
    try testing.expect(@TypeOf(git.allocator) == std.mem.Allocator);
}
