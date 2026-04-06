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

type OpenAIClient struct {
	apiKey      string
	model       string
	baseURL     string
	temperature float32
	topP        float32
	maxTokens   int
	timeout     int
	client      *http.Client
}

// NewOpenAIClient creates a new OpenAI client
func NewOpenAIClient(apiKey, model, baseURL string, aiCfg config.AIConfig) *OpenAIClient {
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	if model == "" {
		model = "gpt-4o-mini"
	}

	return &OpenAIClient{
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

// Message types for OpenAI API
type openaiMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openaiRequest struct {
	Model       string          `json:"model"`
	Messages    []openaiMessage `json:"messages"`
	Temperature float32         `json:"temperature"`
	TopP        float32         `json:"top_p"`
	MaxTokens   int             `json:"max_tokens"`
}

type openaiResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

// GenerateCommitMessage generates a commit message using OpenAI
func (c *OpenAIClient) GenerateCommitMessage(ctx context.Context, diff, language string, count int) (string, error) {
	prompt := buildPrompt(diff, language, count)

	reqBody := openaiRequest{
		Model: c.model,
		Messages: []openaiMessage{
			{
				Role:    "system",
				Content: "You are a helpful assistant that generates clear and concise commit messages based on code changes. Follow conventional commits format.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
		Temperature: c.temperature,
		TopP:        c.topP,
		MaxTokens:   c.maxTokens,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	url := c.baseURL + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var oaiResp openaiResponse
	if err := json.Unmarshal(body, &oaiResp); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if oaiResp.Error != nil {
		return "", fmt.Errorf("openai API error: %s", oaiResp.Error.Message)
	}

	if len(oaiResp.Choices) == 0 {
		return "", fmt.Errorf("no response from OpenAI")
	}

	message := strings.TrimSpace(oaiResp.Choices[0].Message.Content)
	// Remove markdown code block markers if present
	message = strings.TrimPrefix(message, "```")
	message = strings.TrimSuffix(message, "```")
	message = strings.TrimSpace(message)

	return message, nil
}
