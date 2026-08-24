package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	ListenAddress   string
	DatabasePath    string
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	timeout, err := durationSeconds("SHIFTLY_SHUTDOWN_TIMEOUT_SECONDS", 10)
	if err != nil {
		return Config{}, err
	}
	return Config{
		ListenAddress:   stringValue("SHIFTLY_LISTEN_ADDRESS", "127.0.0.1:8080"),
		DatabasePath:    stringValue("SHIFTLY_DATABASE_PATH", "var/shiftly.db"),
		ShutdownTimeout: timeout,
	}, nil
}

func stringValue(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func durationSeconds(name string, fallback int) (time.Duration, error) {
	raw := os.Getenv(name)
	if raw == "" {
		return time.Duration(fallback) * time.Second, nil
	}
	seconds, err := strconv.Atoi(raw)
	if err != nil || seconds <= 0 {
		return 0, fmt.Errorf("%s must be a positive integer", name)
	}
	return time.Duration(seconds) * time.Second, nil
}
