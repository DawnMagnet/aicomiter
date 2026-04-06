package ai

import (
	"context"
	"fmt"
	"strings"

	"dawnmagnet.top/m/aicomiter/internal/config"
)

// Client is the interface for AI providers
type Client interface {
	GenerateCommitMessage(ctx context.Context, diff, language string, count int) (string, error)
}

// NewClient creates a new AI client based on the configuration
func NewClient(cfg *config.Config) (Client, error) {
	provider := strings.ToLower(cfg.AI.Provider)
	baseURL := cfg.GetDefaultBaseURL()
	model := cfg.GetDefaultModel()

	switch provider {
	case "openai":
		return NewOpenAIClient(cfg.AI.APIKey, model, baseURL, cfg.AI), nil
	case "anthropic":
		return NewAnthropicClient(cfg.AI.APIKey, model, baseURL, cfg.AI), nil
	default:
		return nil, fmt.Errorf("unsupported provider: %s", provider)
	}
}
