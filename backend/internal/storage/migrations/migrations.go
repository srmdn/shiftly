package migrations

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/hex"
	"fmt"
	"sort"
	"strings"
)

//go:embed sql/*.sql
var migrationFiles embed.FS

// Apply runs every unapplied migration in filename order. Applied migrations
// are immutable: changing a file after it runs produces a checksum error.
func Apply(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version TEXT PRIMARY KEY,
			checksum TEXT NOT NULL,
			applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
		)`); err != nil {
		return fmt.Errorf("create schema migrations table: %w", err)
	}

	entries, err := migrationFiles.ReadDir("sql")
	if err != nil {
		return fmt.Errorf("read embedded migrations: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		body, err := migrationFiles.ReadFile("sql/" + entry.Name())
		if err != nil {
			return fmt.Errorf("read migration %s: %w", entry.Name(), err)
		}
		if err := applyOne(ctx, db, entry.Name(), body); err != nil {
			return err
		}
	}

	return nil
}

func applyOne(ctx context.Context, db *sql.DB, version string, body []byte) error {
	sum := sha256.Sum256(body)
	checksum := hex.EncodeToString(sum[:])

	var recorded string
	err := db.QueryRowContext(ctx,
		"SELECT checksum FROM schema_migrations WHERE version = ?", version,
	).Scan(&recorded)
	switch {
	case err == nil:
		if recorded != checksum {
			return fmt.Errorf("migration %s checksum changed", version)
		}
		return nil
	case err != sql.ErrNoRows:
		return fmt.Errorf("inspect migration %s: %w", version, err)
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin migration %s: %w", version, err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, string(body)); err != nil {
		return fmt.Errorf("apply migration %s: %w", version, err)
	}
	if _, err := tx.ExecContext(ctx,
		"INSERT INTO schema_migrations(version, checksum) VALUES (?, ?)",
		version, checksum,
	); err != nil {
		return fmt.Errorf("record migration %s: %w", version, err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit migration %s: %w", version, err)
	}
	return nil
}
