package git

import (
	"os"
	"os/exec"
	"strings"
)

// GetStagedDiff returns the diff of staged changes
func GetStagedDiff() (string, error) {
	cmd := exec.Command("git", "diff", "--cached")
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(output)), nil
}

// GetUnstagedDiff returns the diff of unstaged changes
func GetUnstagedDiff() (string, error) {
	cmd := exec.Command("git", "diff")
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(output)), nil
}

// GetLastCommitMessage returns the last commit message
func GetLastCommitMessage() (string, error) {
	cmd := exec.Command("git", "log", "-1", "--pretty=%B")
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(output)), nil
}

// GetBranchName returns the current branch name
func GetBranchName() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(output)), nil
}
