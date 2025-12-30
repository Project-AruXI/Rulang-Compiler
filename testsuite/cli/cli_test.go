package cliTests

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"
)

const (
	PROJ_ROOT = "../../"
	OUTBIN = "out/"
	COMPILER = "arxc"
	COMPILER_PATH = "../../out/arxc"
	RED 		= "\033[31m"
	GREEN   = "\033[32m"
	YELLOW  = "\033[33m"
	RESET   = "\033[0m"
)

func runCommandAndCheckOutput(cmd string, expectedOutput string) error {
	// Run command
	outputBytes, err := exec.Command("sh", "-c", cmd).CombinedOutput()
	if err != nil {
		return err
	}
	output := string(outputBytes)

	// Check output
	if !strings.Contains(output, expectedOutput) {
		return fmt.Errorf("expected output not found. Got: %s", output)
	}
	return nil
}

func TestHelpCommand(t *testing.T) {
	cmd := fmt.Sprintf("%s --help", COMPILER_PATH)
	t.Logf("%sRunning command `%s`%s", YELLOW, cmd, RESET)

	err := runCommandAndCheckOutput(cmd, "Usage: arxc [options] <source_file>")
	if err != nil {
		t.Fatalf("%sHelp command failed: %v%s", RED, err, RESET)
	}
}

func TestVersionCommand(t *testing.T) {
	cmd := fmt.Sprintf("%s --version", COMPILER_PATH)
	t.Logf("%sRunning command `%s`%s", YELLOW, cmd, RESET)

	err := runCommandAndCheckOutput(cmd, "0.1.0")
	if err != nil {
		t.Fatalf("Version command failed: %v", err)
	}
}