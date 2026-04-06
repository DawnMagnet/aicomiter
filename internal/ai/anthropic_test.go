package ai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"dawnmagnet.top/m/aicomiter/internal/config"
)

func TestAnthropicClientCreation(t *testing.T) {
	client := NewAnthropicClient("sk-ant-test", "claude-3-5-sonnet-20241022", "https://api.anthropic.com/v1", config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	if client == nil {
		t.Error("NewAnthropicClient() returned nil")
	}

	if client.apiKey != "sk-ant-test" {
		t.Errorf("Expected apiKey 'sk-ant-test', got '%s'", client.apiKey)
	}

	if client.model != "claude-3-5-sonnet-20241022" {
		t.Errorf("Expected model 'claude-3-5-sonnet-20241022', got '%s'", client.model)
	}

	if client.temperature != 1.0 {
		t.Errorf("Expected temperature 1.0, got %.2f", client.temperature)
	}
}

func TestAnthropicClientDefaultBaseURL(t *testing.T) {
	client := NewAnthropicClient("sk-ant-test", "claude-3-5-sonnet-20241022", "", config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	if client.baseURL != "https://api.anthropic.com/v1" {
		t.Errorf("Expected default baseURL, got '%s'", client.baseURL)
	}
}

func TestAnthropicClientGenerateCommitMessageSuccess(t *testing.T) {
	// Create a mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request
		if r.Method != "POST" {
			t.Errorf("Expected POST request, got %s", r.Method)
		}

		if r.Header.Get("x-api-key") == "" {
			t.Error("Missing x-api-key header")
		}

		if r.Header.Get("anthropic-version") == "" {
			t.Error("Missing anthropic-version header")
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"content": [{
				"type": "text",
				"text": "fix: resolve bug in authentication"
			}]
		}`))
	}))
	defer server.Close()

	client := NewAnthropicClient("sk-ant-test", "claude-3-5-sonnet-20241022", server.URL, config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	ctx := context.Background()
	result, err := client.GenerateCommitMessage(ctx, "diff content", "en", 1)

	if err != nil {
		t.Fatalf("GenerateCommitMessage() error = %v", err)
	}

	if result != "fix: resolve bug in authentication" {
		t.Errorf("Expected 'fix: resolve bug in authentication', got '%s'", result)
	}
}

func TestAnthropicClientGenerateCommitMessageError(t *testing.T) {
	// Create a mock server that returns an error
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"error": {
				"type": "authentication_error",
				"message": "Invalid API key"
			}
		}`))
	}))
	defer server.Close()

	client := NewAnthropicClient("sk-ant-invalid", "claude-3-5-sonnet-20241022", server.URL, config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	ctx := context.Background()
	_, err := client.GenerateCommitMessage(ctx, "diff", "en", 1)

	if err == nil {
		t.Error("GenerateCommitMessage() expected error for invalid API key")
	}
}

func TestAnthropicClientGenerateCommitMessageEmptyContent(t *testing.T) {
	// Create a mock server that returns empty content
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"content": []
		}`))
	}))
	defer server.Close()

	client := NewAnthropicClient("sk-ant-test", "claude-3-5-sonnet-20241022", server.URL, config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	ctx := context.Background()
	_, err := client.GenerateCommitMessage(ctx, "diff", "en", 1)

	if err == nil {
		t.Error("GenerateCommitMessage() expected error for empty content")
	}
}

func TestAnthropicClientDefaultModel(t *testing.T) {
	client := NewAnthropicClient("sk-ant-test", "", "", config.AIConfig{
		Temperature: 1.0,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	if client.model != "claude-3-5-sonnet-20241022" {
		t.Errorf("Expected default model 'claude-3-5-sonnet-20241022', got '%s'", client.model)
	}
}
