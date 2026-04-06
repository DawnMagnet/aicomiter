package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"dawnmagnet.top/m/aicomiter/internal/config"
)

type AnthropicClient struct {
	apiKey      string
	model       string
	baseURL     string
	temperature float32
	topP        float32
	maxTokens   int
	timeout     int
	client      *http.Client
}

// NewAnthropicClient creates a new Anthropic client
func NewAnthropicClient(apiKey, model, baseURL string, aiCfg config.AIConfig) *AnthropicClient {
	if baseURL == "" {
		baseURL = "https://api.anthropic.com/v1"
	}
	if model == "" {
		model = "claude-3-5-sonnet-20241022"
	}

	return &AnthropicClient{
		apiKey:      apiKey,
		model:       model,
		baseURL:     baseURL,
		temperature: aiCfg.Temperature,
		topP:        aiCfg.TopP,
		maxTokens:   aiCfg.MaxTokens,
		timeout:     aiCfg.Timeout,
		client: &http.Client{
			Timeout: time.Duration(aiCfg.Timeout) * time.Second,
		},
	}
}

// Message request/response types for Anthropic API
type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type anthropicRequest struct {
	Model       string              `json:"model"`
	MaxTokens   int                 `json:"max_tokens"`
	Temperature float32             `json:"temperature"`
	TopP        float32             `json:"top_p"`
	System      string              `json:"system"`
	Messages    []anthropicMessage  `json:"messages"`
}

type anthropicResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

// GenerateCommitMessage generates a commit message using Anthropic API
func (c *AnthropicClient) GenerateCommitMessage(ctx context.Context, diff, language string, count int) (string, error) {
	prompt := buildPrompt(diff, language, count)

	reqBody := anthropicRequest{
		Model:       c.model,
		MaxTokens:   c.maxTokens,
		Temperature: c.temperature,
		TopP:        c.topP,
		System:      "You are a helpful assistant that generates clear and concise commit messages based on code changes. Follow conventional commits format.",
		Messages: []anthropicMessage{
			{
				Role:    "user",
				Content: prompt,
			},
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	url := c.baseURL + "/messages"
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := c.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var antResp anthropicResponse
	if err := json.Unmarshal(body, &antResp); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if antResp.Error != nil {
		return "", fmt.Errorf("anthropic API error: %s", antResp.Error.Message)
	}

	if len(antResp.Content) == 0 {
		return "", fmt.Errorf("no response from Anthropic")
	}

	message := strings.TrimSpace(antResp.Content[0].Text)
	// Remove markdown code block markers if present
	message = strings.TrimPrefix(message, "```")
	message = strings.TrimSuffix(message, "```")
	message = strings.TrimSpace(message)

	return message, nil
}
