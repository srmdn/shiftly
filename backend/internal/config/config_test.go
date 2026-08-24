package config

import (
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("SHIFTLY_LISTEN_ADDRESS", "")
	t.Setenv("SHIFTLY_DATABASE_PATH", "")
	t.Setenv("SHIFTLY_SHUTDOWN_TIMEOUT_SECONDS", "")
	got, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if got.ListenAddress != "127.0.0.1:8080" {
		t.Fatalf("ListenAddress = %q", got.ListenAddress)
	}
	if got.DatabasePath != "var/shiftly.db" {
		t.Fatalf("DatabasePath = %q", got.DatabasePath)
	}
	if got.ShutdownTimeout != 10*time.Second {
		t.Fatalf("ShutdownTimeout = %s", got.ShutdownTimeout)
	}
}

func TestLoadOverrides(t *testing.T) {
	t.Setenv("SHIFTLY_LISTEN_ADDRESS", ":9000")
	t.Setenv("SHIFTLY_DATABASE_PATH", "/tmp/shiftly-test.db")
	t.Setenv("SHIFTLY_SHUTDOWN_TIMEOUT_SECONDS", "3")
	got, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if got.ListenAddress != ":9000" || got.DatabasePath != "/tmp/shiftly-test.db" {
		t.Fatalf("unexpected config: %+v", got)
	}
	if got.ShutdownTimeout != 3*time.Second {
		t.Fatalf("ShutdownTimeout = %s", got.ShutdownTimeout)
	}
}

func TestLoadRejectsInvalidTimeout(t *testing.T) {
	t.Setenv("SHIFTLY_SHUTDOWN_TIMEOUT_SECONDS", "never")
	if _, err := Load(); err == nil {
		t.Fatal("invalid timeout was accepted")
	}
}
