package cmd

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"
)

var (
	configFormat string
)

var showConfigCmd = &cobra.Command{
	Use:   "show-config",
	Short: "Show current configuration",
	Long:  `Display the current configuration being used by aicomiter.`,
	RunE:  runShowConfig,
}

func runShowConfig(cmd *cobra.Command, args []string) error {
	cfg := GetConfig()

	switch configFormat {
	case "json":
		jsonBytes, err := json.MarshalIndent(cfg, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal config: %w", err)
		}
		fmt.Println(string(jsonBytes))

	case "yaml", "text":
		fmt.Println("=== AI Configuration ===")
		fmt.Printf("Provider:    %s\n", cfg.AI.Provider)
		fmt.Printf("Model:       %s\n", cfg.GetDefaultModel())
		fmt.Printf("Base URL:    %s\n", cfg.GetDefaultBaseURL())
		fmt.Printf("Temperature: %.2f\n", cfg.AI.Temperature)
		fmt.Printf("Top-P:       %.2f\n", cfg.AI.TopP)
		fmt.Printf("Max Tokens:  %d\n", cfg.AI.MaxTokens)
		fmt.Printf("Timeout:     %d seconds\n", cfg.AI.Timeout)

		if cfg.AI.APIKey != "" {
			// Show masked API key
			apiKey := cfg.AI.APIKey
			if len(apiKey) > 10 {
				apiKey = apiKey[:6] + "***" + apiKey[len(apiKey)-4:]
			}
			fmt.Printf("API Key:     %s\n", apiKey)
		}

		fmt.Println("\n=== Generate Configuration ===")
		fmt.Printf("Language: %s\n", cfg.Generate.Language)
		fmt.Printf("Count:    %d\n", cfg.Generate.Count)

	default:
		return fmt.Errorf("unsupported format: %s", configFormat)
	}

	return nil
}

func init() {
	rootCmd.AddCommand(showConfigCmd)
	showConfigCmd.Flags().StringVar(&configFormat, "format", "text", "Output format: text, json, or yaml")
}
