package git

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func setupGitRepo(t *testing.T) string {
	tmpDir := t.TempDir()

	// Initialize git repo
	cmd := exec.Command("git", "init")
	cmd.Dir = tmpDir
	if err := cmd.Run(); err != nil {
		t.Skipf("Git not available: %v", err)
	}

	// Configure git
	cmds := [][]string{
		{"git", "config", "user.email", "test@example.com"},
		{"git", "config", "user.name", "Test User"},
	}

	for _, cmdArgs := range cmds {
		cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
		cmd.Dir = tmpDir
		if err := cmd.Run(); err != nil {
			t.Fatalf("Failed to configure git: %v", err)
		}
	}

	return tmpDir
}

func TestGetStagedDiff(t *testing.T) {
	tmpDir := setupGitRepo(t)
	originalCwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current directory: %v", err)
	}
	defer os.Chdir(originalCwd)

	os.Chdir(tmpDir)

	// Create and commit initial file
	file := filepath.Join(tmpDir, "test.txt")
	os.WriteFile(file, []byte("initial content\n"), 0644)

	cmd := exec.Command("git", "add", "test.txt")
	cmd.Dir = tmpDir
	cmd.Run()

	cmd = exec.Command("git", "commit", "-m", "Initial commit")
	cmd.Dir = tmpDir
	cmd.Run()

	// Modify file and stage changes
	os.WriteFile(file, []byte("initial content\nmodified line\n"), 0644)

	cmd = exec.Command("git", "add", "test.txt")
	cmd.Dir = tmpDir
	if err := cmd.Run(); err != nil {
		t.Fatalf("Failed to stage changes: %v", err)
	}

	// Get staged diff
	diff, err := GetStagedDiff()
	if err != nil {
		t.Fatalf("GetStagedDiff() error = %v", err)
	}

	if len(diff) == 0 {
		t.Error("GetStagedDiff() returned empty diff, expected non-empty")
	}

	if !strings.Contains(diff, "modified line") {
		t.Errorf("GetStagedDiff() diff doesn't contain expected changes")
	}
}

func TestGetUnstagedDiff(t *testing.T) {
	tmpDir := setupGitRepo(t)
	originalCwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current directory: %v", err)
	}
	defer os.Chdir(originalCwd)

	os.Chdir(tmpDir)

	// Create and commit initial file
	file := filepath.Join(tmpDir, "test.txt")
	os.WriteFile(file, []byte("initial content\n"), 0644)

	cmd := exec.Command("git", "add", "test.txt")
	cmd.Dir = tmpDir
	cmd.Run()

	cmd = exec.Command("git", "commit", "-m", "Initial commit")
	cmd.Dir = tmpDir
	cmd.Run()

	// Modify file without staging
	os.WriteFile(file, []byte("initial content\nunstaged changes\n"), 0644)

	// Get unstaged diff
	diff, err := GetUnstagedDiff()
	if err != nil {
		t.Fatalf("GetUnstagedDiff() error = %v", err)
	}

	if len(diff) == 0 {
		t.Error("GetUnstagedDiff() returned empty diff, expected non-empty")
	}

	if !strings.Contains(diff, "unstaged changes") {
		t.Errorf("GetUnstagedDiff() diff doesn't contain expected changes")
	}
}

func TestGetLastCommitMessage(t *testing.T) {
	tmpDir := setupGitRepo(t)
	originalCwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current directory: %v", err)
	}
	defer os.Chdir(originalCwd)

	os.Chdir(tmpDir)

	// Create and commit a file
	file := filepath.Join(tmpDir, "test.txt")
	os.WriteFile(file, []byte("test content\n"), 0644)

	cmd := exec.Command("git", "add", "test.txt")
	cmd.Dir = tmpDir
	cmd.Run()

	cmd = exec.Command("git", "commit", "-m", "Test commit message")
	cmd.Dir = tmpDir
	if err := cmd.Run(); err != nil {
		t.Fatalf("Failed to create commit: %v", err)
	}

	// Get last commit message
	msg, err := GetLastCommitMessage()
	if err != nil {
		t.Fatalf("GetLastCommitMessage() error = %v", err)
	}

	if msg != "Test commit message" {
		t.Errorf("GetLastCommitMessage() = %q, want %q", msg, "Test commit message")
	}
}

func TestGetBranchName(t *testing.T) {
	tmpDir := setupGitRepo(t)
	originalCwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current directory: %v", err)
	}
	defer os.Chdir(originalCwd)

	os.Chdir(tmpDir)

	// Create an initial commit so we have HEAD
	file := filepath.Join(tmpDir, "test.txt")
	os.WriteFile(file, []byte("test\n"), 0644)

	cmd := exec.Command("git", "add", "test.txt")
	cmd.Dir = tmpDir
	cmd.Run()

	cmd = exec.Command("git", "commit", "-m", "Initial commit")
	cmd.Dir = tmpDir
	if err := cmd.Run(); err != nil {
		t.Skipf("Failed to create initial commit: %v", err)
	}

	// Get current branch name
	branch, err := GetBranchName()
	if err != nil {
		t.Fatalf("GetBranchName() error = %v", err)
	}

	// On fresh repo, should be master or main
	if branch != "master" && branch != "main" {
		t.Errorf("GetBranchName() = %q, want 'master' or 'main'", branch)
	}
}

func TestEmptyDiff(t *testing.T) {
	tmpDir := setupGitRepo(t)
	originalCwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current directory: %v", err)
	}
	defer os.Chdir(originalCwd)

	os.Chdir(tmpDir)

	// Get diff on empty repo (no changes)
	diff, err := GetStagedDiff()
	if err != nil {
		t.Fatalf("GetStagedDiff() error = %v", err)
	}

	if diff != "" {
		t.Errorf("GetStagedDiff() on empty repo should return empty string, got %q", diff)
	}
}
