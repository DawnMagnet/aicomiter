package ai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"dawnmagnet.top/m/aicomiter/internal/config"
)

func TestOpenAIClientCreation(t *testing.T) {
	client := NewOpenAIClient("sk-test", "gpt-4o-mini", "https://api.openai.com/v1", config.AIConfig{
		Temperature: 0.7,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	if client == nil {
		t.Error("NewOpenAIClient() returned nil")
	}

	if client.apiKey != "sk-test" {
		t.Errorf("Expected apiKey 'sk-test', got '%s'", client.apiKey)
	}

	if client.model != "gpt-4o-mini" {
		t.Errorf("Expected model 'gpt-4o-mini', got '%s'", client.model)
	}

	if client.temperature != 0.7 {
		t.Errorf("Expected temperature 0.7, got %.2f", client.temperature)
	}
}

func TestOpenAIClientDefaultBaseURL(t *testing.T) {
	client := NewOpenAIClient("sk-test", "gpt-4o-mini", "", config.AIConfig{
		Temperature: 0.7,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	if client.baseURL != "https://api.openai.com/v1" {
		t.Errorf("Expected default baseURL, got '%s'", client.baseURL)
	}
}

func TestOpenAIClientGenerateCommitMessageSuccess(t *testing.T) {
	// Create a mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request
		if r.Method != "POST" {
			t.Errorf("Expected POST request, got %s", r.Method)
		}

		if r.Header.Get("Authorization") == "" {
			t.Error("Missing Authorization header")
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"choices": [{
				"message": {
					"content": "feat: add new feature"
				}
			}]
		}`))
	}))
	defer server.Close()

	client := NewOpenAIClient("sk-test", "gpt-4o-mini", server.URL, config.AIConfig{
		Temperature: 0.7,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	ctx := context.Background()
	result, err := client.GenerateCommitMessage(ctx, "diff content", "en", 1)

	if err != nil {
		t.Fatalf("GenerateCommitMessage() error = %v", err)
	}

	if result != "feat: add new feature" {
		t.Errorf("Expected 'feat: add new feature', got '%s'", result)
	}
}

func TestOpenAIClientGenerateCommitMessageError(t *testing.T) {
	// Create a mock server that returns an error
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"error": {
				"message": "Invalid API key"
			}
		}`))
	}))
	defer server.Close()

	client := NewOpenAIClient("sk-invalid", "gpt-4o-mini", server.URL, config.AIConfig{
		Temperature: 0.7,
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

func TestOpenAIClientGenerateCommitMessageEmptyResponse(t *testing.T) {
	// Create a mock server that returns empty choices
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"choices": []
		}`))
	}))
	defer server.Close()

	client := NewOpenAIClient("sk-test", "gpt-4o-mini", server.URL, config.AIConfig{
		Temperature: 0.7,
		TopP:        1.0,
		MaxTokens:   500,
		Timeout:     30,
	})

	ctx := context.Background()
	_, err := client.GenerateCommitMessage(ctx, "diff", "en", 1)

	if err == nil {
		t.Error("GenerateCommitMessage() expected error for empty choices")
	}
}
