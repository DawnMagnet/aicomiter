package config

// ConfigSource represents where a configuration value comes from
type ConfigSource string

const (
	SourceDefault       ConfigSource = "default"
	SourceFile          ConfigSource = "file"
	SourceEnv           ConfigSource = "environment"
	SourceCommandLine   ConfigSource = "command-line"
)

// ConfigMetadata tracks the source of each configuration value
type ConfigMetadata struct {
	AI       AIMetadata       `yaml:"-"`
	Generate GenerateMetadata `yaml:"-"`
}

type AIMetadata struct {
	Provider    ConfigSource
	APIKey      ConfigSource
	BaseURL     ConfigSource
	Model       ConfigSource
	Temperature ConfigSource
	TopP        ConfigSource
	MaxTokens   ConfigSource
	Timeout     ConfigSource
}

type GenerateMetadata struct {
	Language ConfigSource
	Count    ConfigSource
}

// GetSourceDescription returns a human-readable description of config sources
func GetSourceDescription(c *Config, meta *ConfigMetadata) string {
	sources := make(map[ConfigSource][]string)

	// AI Config
	addSource(sources, meta.AI.Provider, "provider")
	addSource(sources, meta.AI.APIKey, "api-key")
	addSource(sources, meta.AI.BaseURL, "base-url")
	addSource(sources, meta.AI.Model, "model")
	addSource(sources, meta.AI.Temperature, "temperature")
	addSource(sources, meta.AI.TopP, "top-p")
	addSource(sources, meta.AI.MaxTokens, "max-tokens")
	addSource(sources, meta.AI.Timeout, "timeout")

	// Generate Config
	addSource(sources, meta.Generate.Language, "language")
	addSource(sources, meta.Generate.Count, "count")

	// Build description
	var desc string
	for _, source := range []ConfigSource{SourceCommandLine, SourceEnv, SourceFile, SourceDefault} {
		if items, ok := sources[source]; ok && len(items) > 0 {
			if desc != "" {
				desc += " | "
			}
			sourceLabel := getSourceLabel(source)
			desc += sourceLabel + ": " + joinItems(items)
		}
	}

	if desc == "" {
		desc = "default"
	}

	return desc
}

func addSource(sources map[ConfigSource][]string, source ConfigSource, item string) {
	if source != "" {
		sources[source] = append(sources[source], item)
	}
}

func getSourceLabel(source ConfigSource) string {
	switch source {
	case SourceCommandLine:
		return "CLI"
	case SourceEnv:
		return "Env"
	case SourceFile:
		return "File"
	case SourceDefault:
		return "Default"
	default:
		return "Unknown"
	}
}

func joinItems(items []string) string {
	if len(items) == 0 {
		return ""
	}
	if len(items) == 1 {
		return items[0]
	}
	result := items[0]
	for i := 1; i < len(items); i++ {
		result += ", " + items[i]
	}
	return result
}
