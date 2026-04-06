package main

import (
	"os"

	"dawnmagnet.top/m/aicomiter/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
