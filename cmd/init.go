package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"dawnmagnet.top/m/aicomiter/internal/config"
	"github.com/spf13/cobra"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize configuration file",
	Long: `Initialize a configuration file at ~/.aicomiter.yaml with default values.
You can then edit it to add your API key and customize settings.`,
	RunE: runInit,
}

func runInit(cmd *cobra.Command, args []string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	cfgPath := filepath.Join(home, ".aicomiter.yaml")

	// Check if file already exists
	if _, err := os.Stat(cfgPath); err == nil {
		fmt.Printf("Configuration file already exists at %s\n", cfgPath)
		return nil
	}

	// Save example config
	if err := config.SaveExample(cfgPath); err != nil {
		return fmt.Errorf("failed to create configuration file: %w", err)
	}

	fmt.Printf("Configuration file created at: %s\n", cfgPath)
	fmt.Printf("Please edit the file and add your API key.\n")
	fmt.Printf("\nEdit with:\n")
	fmt.Printf("  vim %s\n", cfgPath)
	fmt.Printf("  nano %s\n", cfgPath)

	return nil
}

func init() {
	rootCmd.AddCommand(initCmd)
}
