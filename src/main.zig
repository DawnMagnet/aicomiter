const std = @import("std");

const Config = @import("config.zig").Config;
const CLI = @import("cli.zig").CLI;
const Git = @import("git.zig").Git;
const AI = @import("ai.zig").AI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    var cli = try CLI.parse(allocator);
    defer cli.deinit(allocator);

    // Handle commands
    if (std.mem.eql(u8, cli.command, "init")) {
        try handleInit(allocator);
    } else if (std.mem.eql(u8, cli.command, "generate") or std.mem.eql(u8, cli.command, "gen")) {
        try handleGenerate(allocator, cli);
    } else if (std.mem.eql(u8, cli.command, "show-config")) {
        try handleShowConfig(allocator, cli);
    } else {
        try printHelp();
    }
}

fn handleInit(allocator: std.mem.Allocator) !void {
    const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
        std.debug.print("Error: Could not get HOME directory: {}\n", .{err});
        return;
    };
    defer allocator.free(home_dir);

    const config_path = try std.fmt.allocPrint(allocator, "{s}/.aicomiter.yaml", .{home_dir});
    defer allocator.free(config_path);

    // Check if config already exists
    if (std.fs.openFileAbsolute(config_path, .{})) |file| {
        file.close();
        std.debug.print("ℹ️  Config already exists at: {s}\n", .{config_path});
        return;
    } else |_| {}

    const config_content =
        \\# aicomiter configuration file
        \\# ~/.aicomiter.yaml
        \\
        \\ai:
        \\  provider: openai              # openai or anthropic
        \\  api_key: ""                   # Your API key
        \\  base_url: ""                  # Optional: custom API endpoint
        \\  model: ""                     # Optional: model name
        \\  temperature: 0.7              # 0-2, lower = more deterministic
        \\  top_p: 1.0                    # 0-1, nucleus sampling
        \\  max_tokens: 500               # Max response length
        \\  timeout: 30                   # Request timeout in seconds
        \\
        \\generate:
        \\  language: en                  # en, zh, etc
        \\  count: 1                      # Number of suggestions
    ;

    var file = try std.fs.createFileAbsolute(config_path, .{});
    defer file.close();

    try file.writeAll(config_content);
    std.debug.print("✅ Config file created at: {s}\n", .{config_path});
    std.debug.print("📝 Please edit it and add your API key\n", .{});
}

fn handleGenerate(allocator: std.mem.Allocator, cli: CLI) !void {
    // Load config
    var config = try Config.load(allocator);
    defer config.deinit();

    // Override with CLI flags
    config.applyCliOverrides(cli);

    // Show config sources if requested
    if (cli.show_config_sources) {
        std.debug.print("📋 Config sources: ", .{});
        try config.printSources();
        std.debug.print("\n", .{});
    }

    // Stage all if requested
    if (cli.all) {
        std.debug.print("📝 Staging all changes...\n", .{});
        var git = Git.init(allocator);
        defer git.deinit();
        try git.stageAll();
    }

    // Get git diff
    var git = Git.init(allocator);
    defer git.deinit();

    const diff = git.getStagedDiff() catch |err| {
        std.debug.print("Error: failed to get staged diff: {}\n", .{err});
        return;
    };
    defer allocator.free(diff);

    if (diff.len == 0) {
        std.debug.print("No staged changes found.\n", .{});
        return;
    }

    // Validate config
    if (config.ai.api_key.len == 0) {
        std.debug.print("Error: API key is required. Set it in config file or use --api-key\n", .{});
        return;
    }

    // Generate commit message
    var ai = try AI.init(allocator, config);
    defer ai.deinit();

    const commit_message = ai.generateCommitMessage(diff, config.generate.language, config.generate.count) catch |err| {
        std.debug.print("Error: failed to generate commit message: {}\n", .{err});
        return;
    };
    defer allocator.free(commit_message);

    std.debug.print("{s}\n", .{commit_message});

    // Create commit if requested or if push is requested
    if (cli.commit or cli.push) {
        std.debug.print("💾 Creating commit...\n", .{});
        try git.commit(commit_message);
        std.debug.print("✅ Commit created\n", .{});

        if (cli.push) {
            std.debug.print("📤 Pushing changes...\n", .{});
            try git.push();
            std.debug.print("✅ Changes pushed successfully\n", .{});
        }
    }
}

fn handleShowConfig(allocator: std.mem.Allocator, cli: CLI) !void {
    var config = try Config.load(allocator);
    defer config.deinit();

    config.applyCliOverrides(cli);

    if (std.mem.eql(u8, cli.format, "json")) {
        try config.printJson(allocator);
    } else {
        try config.print();
    }
}

fn printHelp() !void {
    const help_text =
        \\aicomiter - Generate git commit messages using AI
        \\
        \\USAGE:
        \\    aicomiter <COMMAND> [OPTIONS]
        \\
        \\COMMANDS:
        \\    init          Initialize configuration file
        \\    generate|gen  Generate commit message from staged changes
        \\    show-config   Show current configuration
        \\    help          Show this help message
        \\
        \\OPTIONS:
        \\    --api-key STRING         API key for the AI provider
        \\    --provider STRING        AI provider: openai or anthropic
        \\    --model STRING           Model name
        \\    --base-url STRING        Base URL for API endpoint
        \\    --temperature FLOAT      Temperature (0-2)
        \\    --top-p FLOAT            Top-P (0-1)
        \\    --max-tokens INT         Max tokens in response
        \\    --timeout INT            Request timeout in seconds
        \\    -l, --language STRING    Language for commit message
        \\    -c, --count INT          Number of suggestions
        \\    -a, --all                Stage all changes before generating
        \\    -p, --push               Push changes after commit
        \\    -C, --commit             Auto-commit with generated message
        \\    --config STRING          Config file path
        \\    --format STRING          Output format (text/json)
        \\    --show-config-sources    Show config sources
        \\
        \\EXAMPLES:
        \\    aicomiter init
        \\    aicomiter generate
        \\    aicomiter gen --language zh --count 3
        \\    aicomiter gen --all --push
        \\    aicomiter show-config --format json
        \\
    ;
    std.debug.print("{s}\n", .{help_text});
}

pub const std_options: std.Options = .{
    .log_level = .info,
};
