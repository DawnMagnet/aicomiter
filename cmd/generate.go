package cmd

import (
	"context"
	"fmt"
	"os/exec"

	"dawnmagnet.top/m/aicomiter/internal/ai"
	"dawnmagnet.top/m/aicomiter/internal/config"
	"dawnmagnet.top/m/aicomiter/internal/git"
	"github.com/spf13/cobra"
)

var (
	stageAll bool
	autoCommit bool
	pushAfter bool
)

var generateCmd = &cobra.Command{
	Use:     "generate",
	Aliases: []string{"gen"},
	Short:   "Generate commit message from staged changes",
	Long: `Generate a meaningful commit message based on your staged git changes
using the configured AI provider.`,
	RunE: runGenerate,
}

func runGenerate(cmd *cobra.Command, args []string) error {
	cfg := GetConfig()
	meta := GetConfigMetadata()

	// Show config sources if requested
	if showConfigSources && meta != nil {
		sourcesDesc := config.GetSourceDescription(cfg, meta)
		fmt.Printf("📋 Config sources: %s\n", sourcesDesc)
	}

	// Stage all changes if --all flag is set
	if stageAll {
		fmt.Println("📝 Staging all changes...")
		gitCmd := exec.Command("git", "add", "-A")
		if err := gitCmd.Run(); err != nil {
			return fmt.Errorf("failed to stage all changes: %w", err)
		}
	}

	// Get the diff
	diff, err := git.GetStagedDiff()
	if err != nil {
		return fmt.Errorf("failed to get staged diff: %w", err)
	}

	if diff == "" {
		fmt.Println("No staged changes found.")
		return nil
	}

	// Create AI client
	client, err := ai.NewClient(cfg)
	if err != nil {
		return fmt.Errorf("failed to create AI client: %w", err)
	}

	// Generate commit message
	ctx := context.Background()
	message, err := client.GenerateCommitMessage(ctx, diff, cfg.Generate.Language, cfg.Generate.Count)
	if err != nil {
		return fmt.Errorf("failed to generate commit message: %w", err)
	}

	fmt.Println(message)

	// Create commit if --commit flag is set or if --push flag is set
	if autoCommit || pushAfter {
		fmt.Println("💾 Creating commit...")
		commitCmd := exec.Command("git", "commit", "-m", message)
		if err := commitCmd.Run(); err != nil {
			return fmt.Errorf("failed to create commit: %w", err)
		}
		fmt.Println("✅ Commit created")

		// Push if --push flag is set
		if pushAfter {
			fmt.Println("📤 Pushing changes...")
			pushCmd := exec.Command("git", "push")
			if err := pushCmd.Run(); err != nil {
				return fmt.Errorf("failed to push changes: %w", err)
			}
			fmt.Println("✅ Changes pushed successfully")
		}
	}

	return nil
}

func init() {
	rootCmd.AddCommand(generateCmd)

	// Git operation flags
	generateCmd.Flags().BoolVarP(&stageAll, "all", "a", false, "Stage all unstaged changes before generating commit message")
	generateCmd.Flags().BoolVarP(&autoCommit, "commit", "C", false, "Automatically create commit with generated message")
	generateCmd.Flags().BoolVarP(&pushAfter, "push", "p", false, "Automatically push changes after commit (implies --commit)")
}
