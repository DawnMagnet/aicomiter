package config

import (
	"os"
	"path/filepath"
	"strconv"
	"sync"

	"gopkg.in/yaml.v2"
)

// configMetadataLock protects access to globalMetadata
var configMetadataLock sync.RWMutex

// globalMetadata stores the source information for the loaded config
var globalMetadata *ConfigMetadata

// LoadSimple loads configuration with priority: default -> config file -> environment variables -> command line flags (via ApplyFlags)
// Priority order: Command line flags > Environment variables > Config file > Default values
func LoadSimple(cfgFile string) (*Config, error) {
	cfg := DefaultConfig()
	meta := &ConfigMetadata{
		AI: AIMetadata{
			Provider:    SourceDefault,
			APIKey:      SourceDefault,
			BaseURL:     SourceDefault,
			Model:       SourceDefault,
			Temperature: SourceDefault,
			TopP:        SourceDefault,
			MaxTokens:   SourceDefault,
			Timeout:     SourceDefault,
		},
		Generate: GenerateMetadata{
			Language: SourceDefault,
			Count:    SourceDefault,
		},
	}

	// Step 1: Load from config file
	if cfgFile == "" {
		home, err := os.UserHomeDir()
		if err == nil {
			cfgFile = filepath.Join(home, ".aicomiter.yaml")
		}
	}

	if cfgFile != "" {
		data, err := os.ReadFile(cfgFile)
		if err == nil {
			var rawCfg Config
			if err := yaml.Unmarshal(data, &rawCfg); err == nil {
				// Merge loaded config with defaults
				if rawCfg.AI.Provider != "" {
					cfg.AI.Provider = rawCfg.AI.Provider
					meta.AI.Provider = SourceFile
				}
				if rawCfg.AI.APIKey != "" {
					cfg.AI.APIKey = rawCfg.AI.APIKey
					meta.AI.APIKey = SourceFile
				}
				if rawCfg.AI.BaseURL != "" {
					cfg.AI.BaseURL = rawCfg.AI.BaseURL
					meta.AI.BaseURL = SourceFile
				}
				if rawCfg.AI.Model != "" {
					cfg.AI.Model = rawCfg.AI.Model
					meta.AI.Model = SourceFile
				}
				if rawCfg.AI.Temperature != 0 {
					cfg.AI.Temperature = rawCfg.AI.Temperature
					meta.AI.Temperature = SourceFile
				}
				if rawCfg.AI.TopP != 0 {
					cfg.AI.TopP = rawCfg.AI.TopP
					meta.AI.TopP = SourceFile
				}
				if rawCfg.AI.MaxTokens != 0 {
					cfg.AI.MaxTokens = rawCfg.AI.MaxTokens
					meta.AI.MaxTokens = SourceFile
				}
				if rawCfg.AI.Timeout != 0 {
					cfg.AI.Timeout = rawCfg.AI.Timeout
					meta.AI.Timeout = SourceFile
				}
				if rawCfg.Generate.Language != "" {
					cfg.Generate.Language = rawCfg.Generate.Language
					meta.Generate.Language = SourceFile
				}
				if rawCfg.Generate.Count != 0 {
					cfg.Generate.Count = rawCfg.Generate.Count
					meta.Generate.Count = SourceFile
				}
			}
		}
	}

	// Step 2: Override with environment variables
	applyEnvironmentVariables(cfg, meta)

	// Store metadata globally for later access
	configMetadataLock.Lock()
	globalMetadata = meta
	configMetadataLock.Unlock()

	return cfg, nil
}

// applyEnvironmentVariables applies environment variable overrides
// Environment variables follow naming convention: AICOMITER_<SECTION>_<KEY>
func applyEnvironmentVariables(cfg *Config, meta *ConfigMetadata) {
	// AI Provider
	if apiKey := os.Getenv("AICOMITER_AI_API_KEY"); apiKey != "" {
		cfg.AI.APIKey = apiKey
		meta.AI.APIKey = SourceEnv
	} else if apiKey := os.Getenv("API_KEY"); apiKey != "" {
		// Backward compatibility
		cfg.AI.APIKey = apiKey
		meta.AI.APIKey = SourceEnv
	}

	if provider := os.Getenv("AICOMITER_AI_PROVIDER"); provider != "" {
		cfg.AI.Provider = provider
		meta.AI.Provider = SourceEnv
	} else if provider := os.Getenv("PROVIDER"); provider != "" {
		// Backward compatibility
		cfg.AI.Provider = provider
		meta.AI.Provider = SourceEnv
	}

	if model := os.Getenv("AICOMITER_AI_MODEL"); model != "" {
		cfg.AI.Model = model
		meta.AI.Model = SourceEnv
	} else if model := os.Getenv("MODEL"); model != "" {
		// Backward compatibility
		cfg.AI.Model = model
		meta.AI.Model = SourceEnv
	}

	if baseURL := os.Getenv("AICOMITER_AI_BASE_URL"); baseURL != "" {
		cfg.AI.BaseURL = baseURL
		meta.AI.BaseURL = SourceEnv
	}

	if temp := os.Getenv("AICOMITER_AI_TEMPERATURE"); temp != "" {
		if f, err := strconv.ParseFloat(temp, 32); err == nil {
			cfg.AI.Temperature = float32(f)
			meta.AI.Temperature = SourceEnv
		}
	}

	if topP := os.Getenv("AICOMITER_AI_TOP_P"); topP != "" {
		if f, err := strconv.ParseFloat(topP, 32); err == nil {
			cfg.AI.TopP = float32(f)
			meta.AI.TopP = SourceEnv
		}
	}

	if maxTokens := os.Getenv("AICOMITER_AI_MAX_TOKENS"); maxTokens != "" {
		if i, err := strconv.Atoi(maxTokens); err == nil {
			cfg.AI.MaxTokens = i
			meta.AI.MaxTokens = SourceEnv
		}
	}

	if timeout := os.Getenv("AICOMITER_AI_TIMEOUT"); timeout != "" {
		if i, err := strconv.Atoi(timeout); err == nil {
			cfg.AI.Timeout = i
			meta.AI.Timeout = SourceEnv
		}
	}

	// Generate
	if lang := os.Getenv("AICOMITER_GENERATE_LANGUAGE"); lang != "" {
		cfg.Generate.Language = lang
		meta.Generate.Language = SourceEnv
	}

	if count := os.Getenv("AICOMITER_GENERATE_COUNT"); count != "" {
		if i, err := strconv.Atoi(count); err == nil {
			cfg.Generate.Count = i
			meta.Generate.Count = SourceEnv
		}
	}
}

// GetConfigMetadata returns the metadata about config sources
func GetConfigMetadata() *ConfigMetadata {
	configMetadataLock.RLock()
	defer configMetadataLock.RUnlock()
	return globalMetadata
}
