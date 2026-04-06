package ai

import (
	"fmt"
	"strings"
)

func buildPrompt(diff, language string, count int) string {
	var langInstruction string

	switch strings.ToLower(language) {
	case "zh", "chinese":
		langInstruction = "请用中文生成提交信息。"
	case "en", "english":
		langInstruction = "Please generate the commit message in English."
	default:
		langInstruction = fmt.Sprintf("Please generate the commit message in %s.", language)
	}

	countInstruction := ""
	if count > 1 {
		countInstruction = fmt.Sprintf("Generate %d commit message suggestions, each on a separate line.\n", count)
	}

	diffBlock := fmt.Sprintf("```diff\n%s\n```", diff)

	return fmt.Sprintf(`%s
Analyze the following git diff and generate a clear, concise commit message.
%s
Follow the conventional commits format (type(scope): description).
Keep the description under 72 characters when possible.
Focus on the "why" and "what" of the changes, not the "how".

Git Diff:
%s

Commit Message:`, langInstruction, countInstruction, diffBlock)
}
