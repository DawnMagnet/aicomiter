package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadSimpleFromFile(t *testing.T) {
	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "config.yaml")

	// Create a test config file
	content := `ai:
  provider: openai
  api_key: sk-test-key
  model: gpt-4o-mini
  temperature: 0.8
  top_p: 0.95
  max_tokens: 1000
  timeout: 60
generate:
  language: zh
  count: 3
`

	err := os.WriteFile(cfgPath, []byte(content), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config file: %v", err)
	}

	cfg, err := LoadSimple(cfgPath)
	if err != nil {
		t.Fatalf("LoadSimple() error = %v", err)
	}

	// Validate loaded config
	if cfg.AI.Provider != "openai" {
		t.Errorf("Expected provider 'openai', got '%s'", cfg.AI.Provider)
	}

	if cfg.AI.APIKey != "sk-test-key" {
		t.Errorf("Expected api_key 'sk-test-key', got '%s'", cfg.AI.APIKey)
	}

	if cfg.AI.Model != "gpt-4o-mini" {
		t.Errorf("Expected model 'gpt-4o-mini', got '%s'", cfg.AI.Model)
	}

	if cfg.AI.Temperature != 0.8 {
		t.Errorf("Expected temperature 0.8, got %.2f", cfg.AI.Temperature)
	}

	if cfg.AI.TopP != 0.95 {
		t.Errorf("Expected top_p 0.95, got %.2f", cfg.AI.TopP)
	}

	if cfg.AI.MaxTokens != 1000 {
		t.Errorf("Expected max_tokens 1000, got %d", cfg.AI.MaxTokens)
	}

	if cfg.AI.Timeout != 60 {
		t.Errorf("Expected timeout 60, got %d", cfg.AI.Timeout)
	}

	if cfg.Generate.Language != "zh" {
		t.Errorf("Expected language 'zh', got '%s'", cfg.Generate.Language)
	}

	if cfg.Generate.Count != 3 {
		t.Errorf("Expected count 3, got %d", cfg.Generate.Count)
	}
}

func TestLoadSimpleFromEnvVars(t *testing.T) {
	// Save original env vars
	originalAPIKey := os.Getenv("AICOMITER_AI_API_KEY")
	originalProvider := os.Getenv("AICOMITER_AI_PROVIDER")

	// Set env vars
	os.Setenv("AICOMITER_AI_API_KEY", "sk-env-key")
	os.Setenv("AICOMITER_AI_PROVIDER", "anthropic")

	defer func() {
		os.Setenv("AICOMITER_AI_API_KEY", originalAPIKey)
		os.Setenv("AICOMITER_AI_PROVIDER", originalProvider)
	}()

	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "nonexistent.yaml")

	cfg, err := LoadSimple(cfgPath)
	if err != nil {
		t.Fatalf("LoadSimple() error = %v", err)
	}

	if cfg.AI.APIKey != "sk-env-key" {
		t.Errorf("Expected api_key 'sk-env-key', got '%s'", cfg.AI.APIKey)
	}

	if cfg.AI.Provider != "anthropic" {
		t.Errorf("Expected provider 'anthropic', got '%s'", cfg.AI.Provider)
	}
}

func TestLoadSimpleFallbackEnvVars(t *testing.T) {
	// Save original env vars
	originalAPIKey := os.Getenv("API_KEY")

	// Set fallback env var
	os.Setenv("API_KEY", "sk-fallback-key")

	defer func() {
		os.Setenv("API_KEY", originalAPIKey)
	}()

	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "nonexistent.yaml")

	cfg, err := LoadSimple(cfgPath)
	if err != nil {
		t.Fatalf("LoadSimple() error = %v", err)
	}

	if cfg.AI.APIKey != "sk-fallback-key" {
		t.Errorf("Expected api_key 'sk-fallback-key', got '%s'", cfg.AI.APIKey)
	}
}

func TestLoadSimpleEnvVarOverrides(t *testing.T) {
	// Save original env vars
	originalTemp := os.Getenv("AICOMITER_AI_TEMPERATURE")
	originalTopP := os.Getenv("AICOMITER_AI_TOP_P")
	originalMaxTokens := os.Getenv("AICOMITER_AI_MAX_TOKENS")
	originalTimeout := os.Getenv("AICOMITER_AI_TIMEOUT")

	// Set env vars with numeric values
	os.Setenv("AICOMITER_AI_TEMPERATURE", "1.5")
	os.Setenv("AICOMITER_AI_TOP_P", "0.8")
	os.Setenv("AICOMITER_AI_MAX_TOKENS", "2000")
	os.Setenv("AICOMITER_AI_TIMEOUT", "120")

	defer func() {
		os.Setenv("AICOMITER_AI_TEMPERATURE", originalTemp)
		os.Setenv("AICOMITER_AI_TOP_P", originalTopP)
		os.Setenv("AICOMITER_AI_MAX_TOKENS", originalMaxTokens)
		os.Setenv("AICOMITER_AI_TIMEOUT", originalTimeout)
	}()

	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "nonexistent.yaml")

	cfg, err := LoadSimple(cfgPath)
	if err != nil {
		t.Fatalf("LoadSimple() error = %v", err)
	}

	if cfg.AI.Temperature != 1.5 {
		t.Errorf("Expected temperature 1.5, got %.2f", cfg.AI.Temperature)
	}

	if cfg.AI.TopP != 0.8 {
		t.Errorf("Expected top_p 0.8, got %.2f", cfg.AI.TopP)
	}

	if cfg.AI.MaxTokens != 2000 {
		t.Errorf("Expected max_tokens 2000, got %d", cfg.AI.MaxTokens)
	}

	if cfg.AI.Timeout != 120 {
		t.Errorf("Expected timeout 120, got %d", cfg.AI.Timeout)
	}
}

