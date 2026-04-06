package cmd

import (
	"fmt"
	"os"

	"dawnmagnet.top/m/aicomiter/internal/config"
	"github.com/spf13/cobra"
)

var (
	cfgFile           string
	apiKey            string
	provider          string
	model             string
	baseURL           string
	temperature       float32
	topP              float32
	maxTokens         int
	timeout           int
	flagLanguage      string
	flagCount         int
	showConfigSources bool
)

var rootCmd = &cobra.Command{
	Use:   "aicomiter",
	Short: "Generate commit messages using AI",
	Long: `aicomiter is a CLI tool that generates meaningful commit messages
based on your git staged changes using AI providers like OpenAI or Anthropic.`,
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.aicomiter.yaml)")

	// AI Provider Flags
	rootCmd.PersistentFlags().StringVar(&apiKey, "api-key", "", "API key for the AI provider")
	rootCmd.PersistentFlags().StringVar(&provider, "provider", "", "AI provider: openai or anthropic")
	rootCmd.PersistentFlags().StringVar(&model, "model", "", "Model name")
	rootCmd.PersistentFlags().StringVar(&baseURL, "base-url", "", "Base URL for the API endpoint")

	// Model Parameters
	rootCmd.PersistentFlags().Float32Var(&temperature, "temperature", -1, "Temperature (0-2, controls randomness)")
	rootCmd.PersistentFlags().Float32Var(&topP, "top-p", -1, "Top-P (0-1, nucleus sampling)")
	rootCmd.PersistentFlags().IntVar(&maxTokens, "max-tokens", -1, "Maximum tokens in response")
	rootCmd.PersistentFlags().IntVar(&timeout, "timeout", -1, "Request timeout in seconds")

	// Generate Flags
	rootCmd.PersistentFlags().StringVarP(&flagLanguage, "language", "l", "", "Language for commit message")
	rootCmd.PersistentFlags().IntVarP(&flagCount, "count", "c", -1, "Number of suggestions")

	// Debug Flags
	rootCmd.PersistentFlags().BoolVar(&showConfigSources, "show-config-sources", true, "Show which configuration source is used for each setting")
}

func initConfig() {
	// Load configuration with priority: default -> config file -> environment variables
	cfg, err := config.LoadSimple(cfgFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Get metadata to track which sources are used
	meta := config.GetConfigMetadata()
	if meta == nil {
		meta = &config.ConfigMetadata{}
	}

	// Override with command line flags (highest priority)
	// Only override if the flag was explicitly set (not default value)
	if apiKey != "" {
		cfg.AI.APIKey = apiKey
		meta.AI.APIKey = config.SourceCommandLine
	}
	if provider != "" {
		cfg.AI.Provider = provider
		meta.AI.Provider = config.SourceCommandLine
	}
	if model != "" {
		cfg.AI.Model = model
		meta.AI.Model = config.SourceCommandLine
	}
	if baseURL != "" {
		cfg.AI.BaseURL = baseURL
		meta.AI.BaseURL = config.SourceCommandLine
	}
	// For numeric flags, -1 or 0 means "not set"
	if temperature >= 0 {
		cfg.AI.Temperature = temperature
		meta.AI.Temperature = config.SourceCommandLine
	}
	if topP >= 0 {
		cfg.AI.TopP = topP
		meta.AI.TopP = config.SourceCommandLine
	}
	if maxTokens > 0 {
		cfg.AI.MaxTokens = maxTokens
		meta.AI.MaxTokens = config.SourceCommandLine
	}
	if timeout > 0 {
		cfg.AI.Timeout = timeout
		meta.AI.Timeout = config.SourceCommandLine
	}
	if flagLanguage != "" {
		cfg.Generate.Language = flagLanguage
		meta.Generate.Language = config.SourceCommandLine
	}
	if flagCount > 0 {
		cfg.Generate.Count = flagCount
		meta.Generate.Count = config.SourceCommandLine
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Store config and metadata in context for commands to access
	globalConfig = cfg
	globalConfigMetadata = meta
}

var globalConfig *config.Config
var globalConfigMetadata *config.ConfigMetadata

// GetConfig returns the global configuration
func GetConfig() *config.Config {
	return globalConfig
}

// GetConfigMetadata returns the metadata about config sources
func GetConfigMetadata() *config.ConfigMetadata {
	return globalConfigMetadata
}
