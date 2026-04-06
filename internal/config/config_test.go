package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()

	if cfg.AI.Provider != "openai" {
		t.Errorf("Expected provider to be 'openai', got '%s'", cfg.AI.Provider)
	}

	if cfg.AI.Temperature != 0.7 {
		t.Errorf("Expected temperature to be 0.7, got %.2f", cfg.AI.Temperature)
	}

	if cfg.AI.TopP != 1.0 {
		t.Errorf("Expected top_p to be 1.0, got %.2f", cfg.AI.TopP)
	}

	if cfg.AI.MaxTokens != 500 {
		t.Errorf("Expected max_tokens to be 500, got %d", cfg.AI.MaxTokens)
	}

	if cfg.AI.Timeout != 30 {
		t.Errorf("Expected timeout to be 30, got %d", cfg.AI.Timeout)
	}

	if cfg.Generate.Language != "en" {
		t.Errorf("Expected language to be 'en', got '%s'", cfg.Generate.Language)
	}

	if cfg.Generate.Count != 1 {
		t.Errorf("Expected count to be 1, got %d", cfg.Generate.Count)
	}
}

func TestValidate(t *testing.T) {
	tests := []struct {
		name    string
		cfg     *Config
		wantErr bool
		errMsg  string
	}{
		{
			name:    "valid config with API key",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", Temperature: 0.7, TopP: 1.0, MaxTokens: 500}, Generate: GenerateConfig{Count: 1}},
			wantErr: false,
		},
		{
			name:    "missing API key",
			cfg:     &Config{AI: AIConfig{Provider: "openai"}},
			wantErr: true,
			errMsg:  "API key is required",
		},
		{
			name:    "invalid provider",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "invalid"}},
			wantErr: true,
			errMsg:  "unsupported provider",
		},
		{
			name:    "temperature too low",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", Temperature: -0.5}},
			wantErr: true,
			errMsg:  "temperature must be between 0 and 2",
		},
		{
			name:    "temperature too high",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", Temperature: 2.5}},
			wantErr: true,
			errMsg:  "temperature must be between 0 and 2",
		},
		{
			name:    "top_p too low",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", TopP: -0.1}},
			wantErr: true,
			errMsg:  "top_p must be between 0 and 1",
		},
		{
			name:    "top_p too high",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", TopP: 1.5}},
			wantErr: true,
			errMsg:  "top_p must be between 0 and 1",
		},
		{
			name:    "max_tokens invalid",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", MaxTokens: 0}},
			wantErr: true,
			errMsg:  "max_tokens must be positive",
		},
		{
			name:    "count invalid",
			cfg:     &Config{AI: AIConfig{APIKey: "sk-test", Provider: "openai", MaxTokens: 500}, Generate: GenerateConfig{Count: 0}},
			wantErr: true,
			errMsg:  "count must be positive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr && err != nil && tt.errMsg != "" {
				if !contains(err.Error(), tt.errMsg) {
					t.Errorf("Validate() error message = %v, want containing %v", err.Error(), tt.errMsg)
				}
			}
		})
	}
}

func TestGetDefaultBaseURL(t *testing.T) {
	tests := []struct {
		name     string
		provider string
		baseURL  string
		expected string
	}{
		{
			name:     "openai default",
			provider: "openai",
			baseURL:  "",
			expected: "https://api.openai.com/v1",
		},
		{
			name:     "anthropic default",
			provider: "anthropic",
			baseURL:  "",
			expected: "https://api.anthropic.com/v1",
		},
		{
			name:     "custom base url",
			provider: "openai",
			baseURL:  "https://custom.com/v1",
			expected: "https://custom.com/v1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				AI: AIConfig{
					Provider: tt.provider,
					BaseURL:  tt.baseURL,
				},
			}
			result := cfg.GetDefaultBaseURL()
			if result != tt.expected {
				t.Errorf("GetDefaultBaseURL() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestGetDefaultModel(t *testing.T) {
	tests := []struct {
		name     string
		provider string
		model    string
		expected string
	}{
		{
			name:     "openai default",
			provider: "openai",
			model:    "",
			expected: "gpt-4o-mini",
		},
		{
			name:     "anthropic default",
			provider: "anthropic",
			model:    "",
			expected: "claude-3-5-sonnet-20241022",
		},
		{
			name:     "custom model",
			provider: "openai",
			model:    "gpt-4-turbo",
			expected: "gpt-4-turbo",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				AI: AIConfig{
					Provider: tt.provider,
					Model:    tt.model,
				},
			}
			result := cfg.GetDefaultModel()
			if result != tt.expected {
				t.Errorf("GetDefaultModel() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestSaveExample(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "config.yaml")

	err := SaveExample(path)
	if err != nil {
		t.Errorf("SaveExample() error = %v", err)
	}

	// Check if file was created
	if _, err := os.Stat(path); os.IsNotExist(err) {
		t.Errorf("SaveExample() did not create file at %s", path)
	}

	// Check if file has content
	content, err := os.ReadFile(path)
	if err != nil {
		t.Errorf("Failed to read saved example file: %v", err)
	}

	if len(content) == 0 {
		t.Error("SaveExample() created empty file")
	}

	// Check for required content
	requiredStrings := []string{"provider", "api_key", "temperature", "max_tokens"}
	for _, s := range requiredStrings {
		if !contains(string(content), s) {
			t.Errorf("SaveExample() file missing required string: %s", s)
		}
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 || (len(s) > 0 && len(substr) > 0 && s[0:len(substr)] == substr) || (len(s) > len(substr) && findSubstring(s, substr)))
}

func findSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
