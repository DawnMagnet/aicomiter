package config

import (
	"fmt"
	"os"
	"path/filepath"
)

type AIConfig struct {
	Provider    string  `yaml:"provider"`
	APIKey      string  `yaml:"api_key"`
	BaseURL     string  `yaml:"base_url"`
	Model       string  `yaml:"model"`
	Temperature float32 `yaml:"temperature"`
	TopP        float32 `yaml:"top_p"`
	MaxTokens   int     `yaml:"max_tokens"`
	Timeout     int     `yaml:"timeout"` // seconds
}

type GenerateConfig struct {
	Language string `yaml:"language"`
	Count    int    `yaml:"count"`
}

type Config struct {
	AI       AIConfig       `yaml:"ai"`
	Generate GenerateConfig `yaml:"generate"`
}

// DefaultConfig returns the default configuration
func DefaultConfig() *Config {
	return &Config{
		AI: AIConfig{
			Provider:    "openai",
			Temperature: 0.7,
			TopP:        1.0,
			MaxTokens:   500,
			Timeout:     30,
		},
		Generate: GenerateConfig{
			Language: "en",
			Count:    1,
		},
	}
}

// Load loads configuration from file and environment
// This is a wrapper that delegates to LoadSimple
func Load(cfgFile string) (*Config, error) {
	return LoadSimple(cfgFile)
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.AI.APIKey == "" {
		return fmt.Errorf("API key is required (set via --api-key, AICOMITER_AI_API_KEY, or config file)")
	}

	if c.AI.Provider != "openai" && c.AI.Provider != "anthropic" {
		return fmt.Errorf("unsupported provider: %s (must be 'openai' or 'anthropic')", c.AI.Provider)
	}

	if c.AI.Temperature < 0 || c.AI.Temperature > 2 {
		return fmt.Errorf("temperature must be between 0 and 2, got %.2f", c.AI.Temperature)
	}

	if c.AI.TopP < 0 || c.AI.TopP > 1 {
		return fmt.Errorf("top_p must be between 0 and 1, got %.2f", c.AI.TopP)
	}

	if c.AI.MaxTokens < 1 {
		return fmt.Errorf("max_tokens must be positive, got %d", c.AI.MaxTokens)
	}

	if c.Generate.Count < 1 {
		return fmt.Errorf("count must be positive, got %d", c.Generate.Count)
	}

	return nil
}

// GetDefaultBaseURL returns the default base URL for the provider
func (c *Config) GetDefaultBaseURL() string {
	if c.AI.BaseURL != "" {
		return c.AI.BaseURL
	}

	switch c.AI.Provider {
	case "openai":
		return "https://api.openai.com/v1"
	case "anthropic":
		return "https://api.anthropic.com/v1"
	default:
		return ""
	}
}

// GetDefaultModel returns the default model for the provider
func (c *Config) GetDefaultModel() string {
	if c.AI.Model != "" {
		return c.AI.Model
	}

	switch c.AI.Provider {
	case "openai":
		return "gpt-4o-mini"
	case "anthropic":
		return "claude-3-5-sonnet-20241022"
	default:
		return ""
	}
}

// SaveExample saves an example config file
func SaveExample(path string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	if path == "" {
		path = filepath.Join(home, ".aicomiter.example.yaml")
	}

	example := `# aicomiter configuration file
# Copy this to ~/.aicomiter.yaml and fill in your API key

ai:
  # Provider: openai or anthropic
  provider: openai

  # API key for the provider
  api_key: sk-your-api-key-here

  # Base URL (optional, uses provider default if not set)
  # base_url: https://api.openai.com/v1

  # Model name (optional, uses provider default if not set)
  # model: gpt-4o-mini

  # Temperature: controls randomness (0-2, lower = more deterministic)
  temperature: 0.7

  # Top-P: nucleus sampling (0-1)
  top_p: 1.0

  # Max tokens for response
  max_tokens: 500

  # Request timeout in seconds
  timeout: 30

generate:
  # Language for commit message: en, zh, etc.
  language: en

  # Number of suggestions to generate
  count: 1
`

	return os.WriteFile(path, []byte(example), 0644)
}
