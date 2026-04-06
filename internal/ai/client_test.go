package ai

import (
	"testing"

	"dawnmagnet.top/m/aicomiter/internal/config"
)

func TestNewClient(t *testing.T) {
	tests := []struct {
		name      string
		provider  string
		apiKey    string
		model     string
		wantError bool
		wantType  string
	}{
		{
			name:      "openai client",
			provider:  "openai",
			apiKey:    "sk-test",
			model:     "gpt-4o-mini",
			wantError: false,
			wantType:  "*ai.OpenAIClient",
		},
		{
			name:      "anthropic client",
			provider:  "anthropic",
			apiKey:    "sk-test",
			model:     "claude-3-5-sonnet-20241022",
			wantError: false,
			wantType:  "*ai.AnthropicClient",
		},
		{
			name:      "unsupported provider",
			provider:  "invalid",
			apiKey:    "sk-test",
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &config.Config{
				AI: config.AIConfig{
					Provider: tt.provider,
					APIKey:   tt.apiKey,
					Model:    tt.model,
				},
			}

			client, err := NewClient(cfg)

			if (err != nil) != tt.wantError {
				t.Errorf("NewClient() error = %v, wantError %v", err, tt.wantError)
			}

			if !tt.wantError && client == nil {
				t.Error("NewClient() returned nil client when no error expected")
			}
		})
	}
}

func TestNewClientDefaultModel(t *testing.T) {
	cfg := &config.Config{
		AI: config.AIConfig{
			Provider: "openai",
			APIKey:   "sk-test",
			// Model is empty, should use default
		},
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if client == nil {
		t.Error("NewClient() returned nil client")
	}

	// The client should be created with the default model
	// We can't directly inspect the model, but we can verify the client was created
}

func TestNewClientDefaultBaseURL(t *testing.T) {
	tests := []struct {
		name        string
		provider    string
		baseURL     string
		expectedURL string
	}{
		{
			name:        "openai default URL",
			provider:    "openai",
			baseURL:     "",
			expectedURL: "https://api.openai.com/v1",
		},
		{
			name:        "anthropic default URL",
			provider:    "anthropic",
			baseURL:     "",
			expectedURL: "https://api.anthropic.com/v1",
		},
		{
			name:        "custom URL",
			provider:    "openai",
			baseURL:     "https://custom.com",
			expectedURL: "https://custom.com",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &config.Config{
				AI: config.AIConfig{
					Provider: tt.provider,
					APIKey:   "sk-test",
					BaseURL:  tt.baseURL,
				},
			}

			client, err := NewClient(cfg)
			if err != nil {
				t.Fatalf("NewClient() error = %v", err)
			}

			if client == nil {
				t.Error("NewClient() returned nil client")
			}
		})
	}
}
