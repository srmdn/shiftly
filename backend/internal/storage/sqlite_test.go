package storage

import (
	"context"
	"path/filepath"
	"testing"
)

func TestOpenConfiguresAndMigratesDatabase(t *testing.T) {
	db, err := Open(context.Background(), filepath.Join(t.TempDir(), "nested", "shiftly.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	var foreignKeys int
	if err := db.QueryRow("PRAGMA foreign_keys").Scan(&foreignKeys); err != nil {
		t.Fatal(err)
	}
	if foreignKeys != 1 {
		t.Fatalf("foreign_keys = %d, want 1", foreignKeys)
	}
	var applied int
	if err := db.QueryRow("SELECT count(*) FROM schema_migrations").Scan(&applied); err != nil {
		t.Fatal(err)
	}
	if applied != 1 {
		t.Fatalf("migrations = %d, want 1", applied)
	}
}
