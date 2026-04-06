package ai

import (
	"strings"
	"testing"
)

func TestBuildPrompt(t *testing.T) {
	tests := []struct {
		name     string
		diff     string
		language string
		count    int
		contains []string
	}{
		{
			name:     "english single prompt",
			diff:     "diff --git a/test.go b/test.go\n+new line",
			language: "en",
			count:    1,
			contains: []string{
				"English",
				"git diff",
				"Commit Message:",
				"new line",
				"conventional commits",
			},
		},
		{
			name:     "chinese single prompt",
			diff:     "diff --git a/test.go b/test.go",
			language: "zh",
			count:    1,
			contains: []string{
				"中文",
				"git diff",
				"conventional commits",
			},
		},
		{
			name:     "multiple suggestions",
			diff:     "diff --git a/test.go b/test.go",
			language: "en",
			count:    3,
			contains: []string{
				"3",
				"suggestions",
				"separate line",
				"Commit Message:",
			},
		},
		{
			name:     "other language",
			language: "ja",
			count:    1,
			contains: []string{
				"Commit Message:",
				"git diff",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := buildPrompt(tt.diff, tt.language, tt.count)

			// Check that result is not empty
			if result == "" {
				t.Error("buildPrompt() returned empty string")
			}

			// Check for expected strings
			for _, expected := range tt.contains {
				if !strings.Contains(result, expected) {
					t.Errorf("buildPrompt() result doesn't contain %q", expected)
				}
			}

			// If count > 1, should include count in prompt
			if tt.count > 1 {
				if !strings.Contains(result, "Generate") {
					t.Errorf("buildPrompt() with count=%d should mention 'Generate'", tt.count)
				}
			}

			// Check that the diff is included
			if tt.diff != "" && !strings.Contains(result, tt.diff) {
				t.Error("buildPrompt() doesn't include the diff content")
			}
		})
	}
}

func TestBuildPromptLanguages(t *testing.T) {
	languages := []struct {
		lang     string
		expected string
	}{
		{"en", "English"},
		{"english", "English"},
		{"zh", "Chinese"},
		{"chinese", "Chinese"},
		{"fr", "French"},
		{"es", "Spanish"},
	}

	for _, lang := range languages {
		t.Run(lang.lang, func(t *testing.T) {
			result := buildPrompt("test diff", lang.lang, 1)

			if lang.lang == "en" || lang.lang == "english" {
				if !strings.Contains(result, "English") {
					t.Errorf("buildPrompt() for lang=%s should contain 'English'", lang.lang)
				}
			}

			// Just verify that result is not empty for any language
			if result == "" {
				t.Errorf("buildPrompt() for lang=%s returned empty result", lang.lang)
			}
		})
	}
}

func TestBuildPromptWithLargeDiff(t *testing.T) {
	// Create a large diff
	diff := ""
	for i := 0; i < 100; i++ {
		diff += "diff --git a/file" + string(rune(i)) + ".go\n"
		diff += "+added line " + string(rune(i)) + "\n"
	}

	result := buildPrompt(diff, "en", 1)

	if result == "" {
		t.Error("buildPrompt() returned empty for large diff")
	}

	if !strings.Contains(result, "Commit Message:") {
		t.Error("buildPrompt() missing 'Commit Message:' in result")
	}
}

func TestBuildPromptCount(t *testing.T) {
	tests := []struct {
		count    int
		contains bool
	}{
		{1, false}, // Single suggestion shouldn't mention count
		{2, true},  // Multiple should mention
		{5, true},  // Multiple should mention
		{10, true}, // Multiple should mention
	}

	for _, tt := range tests {
		t.Run("count="+string(rune(tt.count)), func(t *testing.T) {
			result := buildPrompt("test", "en", tt.count)

			hasCountMention := strings.Contains(result, "suggestions") || strings.Contains(result, "Generate")

			if tt.contains && !hasCountMention {
				t.Errorf("buildPrompt() with count=%d should mention suggestions", tt.count)
			}
		})
	}
}

func TestBuildPromptFormat(t *testing.T) {
	result := buildPrompt("test diff", "en", 1)

	// Check structure
	requiredSections := []string{
		"Git Diff:",
		"Commit Message:",
		"conventional commits",
	}

	for _, section := range requiredSections {
		if !strings.Contains(result, section) {
			t.Errorf("buildPrompt() missing required section: %s", section)
		}
	}

	// Check that diff is in proper code block
	if !strings.Contains(result, "```diff") {
		t.Error("buildPrompt() should use markdown code block for diff")
	}
}
