package migrations_test

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"

	"github.com/srmdn/shiftly/backend/internal/storage/migrations"
	_ "modernc.org/sqlite"
)

const now = "2026-08-24T00:00:00Z"

func openTestDB(t *testing.T) *sql.DB {
	t.Helper()
	path := filepath.Join(t.TempDir(), "shiftly.db")
	db, err := sql.Open("sqlite", "file:"+path+"?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)")
	if err != nil {
		t.Fatal(err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { db.Close() })
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestApplyIsIdempotent(t *testing.T) {
	db := openTestDB(t)
	if err := migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}

	var count int
	if err := db.QueryRow("SELECT count(*) FROM schema_migrations").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("got %d applied migrations, want 1", count)
	}
}

func TestDatabasePragmas(t *testing.T) {
	db := openTestDB(t)
	var foreignKeys int
	if err := db.QueryRow("PRAGMA foreign_keys").Scan(&foreignKeys); err != nil {
		t.Fatal(err)
	}
	if foreignKeys != 1 {
		t.Fatalf("foreign_keys = %d, want 1", foreignKeys)
	}
	var journalMode string
	if err := db.QueryRow("PRAGMA journal_mode").Scan(&journalMode); err != nil {
		t.Fatal(err)
	}
	if journalMode != "wal" {
		t.Fatalf("journal_mode = %q, want wal", journalMode)
	}
}

func TestTenantAndIntervalConstraints(t *testing.T) {
	db := openTestDB(t)
	seed(t, db)

	if _, err := db.Exec(`INSERT INTO schedule_members(schedule_id, member_id)
		VALUES ('manual', 'other-member')`); err == nil {
		t.Fatal("cross-team schedule member was accepted")
	}

	insertManual := `INSERT INTO manual_assignments(
		id, schedule_id, member_id, starts_at, ends_at,
		created_by_member_id, created_at, updated_at
	) VALUES (?, 'manual', 'owner', ?, ?, 'owner', ?, ?)`
	if _, err := db.Exec(insertManual, "a1", "2026-08-24T00:00:00Z",
		"2026-08-25T00:00:00Z", now, now); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(insertManual, "a2", "2026-08-25T00:00:00Z",
		"2026-08-26T00:00:00Z", now, now); err != nil {
		t.Fatalf("adjacent half-open assignment was rejected: %v", err)
	}
	if _, err := db.Exec(insertManual, "a3", "2026-08-24T12:00:00Z",
		"2026-08-25T12:00:00Z", now, now); err == nil {
		t.Fatal("overlapping manual assignment was accepted")
	}
}

func TestRotationRuleAndReplacementOverlap(t *testing.T) {
	db := openTestDB(t)
	seed(t, db)

	insertRule := `INSERT INTO rotation_rules(
		id, schedule_id, effective_from, effective_until, anchor_local_date,
		anchor_member_id, cadence_value, cadence_unit, handover_kind,
		handover_time, created_by_member_id, created_at
	) VALUES (?, 'rotation', ?, ?, '2026-08-24', 'owner', 1, 'days',
		'clock', '08:00', 'owner', ?)`
	if _, err := db.Exec(insertRule, "r1", "2026-08-24T01:00:00Z",
		"2026-08-26T01:00:00Z", now); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(insertRule, "r2", "2026-08-26T01:00:00Z",
		nil, now); err != nil {
		t.Fatalf("adjacent rotation rule was rejected: %v", err)
	}
	if _, err := db.Exec(insertRule, "r3", "2026-08-25T01:00:00Z",
		"2026-08-27T01:00:00Z", now); err == nil {
		t.Fatal("overlapping rotation rule was accepted")
	}

	insertReplacement := `INSERT INTO replacements(
		id, schedule_id, unavailable_member_id, replacement_member_id,
		starts_at, ends_at, status, created_by_member_id, created_at
	) VALUES (?, 'rotation', 'owner', 'second', ?, ?, 'active', 'owner', ?)`
	if _, err := db.Exec(insertReplacement, "x1", "2026-08-24T01:00:00Z",
		"2026-08-25T01:00:00Z", now); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(insertReplacement, "x2", "2026-08-24T12:00:00Z",
		"2026-08-25T12:00:00Z", now); err == nil {
		t.Fatal("conflicting active replacement was accepted")
	}
}

func seed(t *testing.T, db *sql.DB) {
	t.Helper()
	statements := []string{
		`INSERT INTO users(id, google_subject, email, display_name, created_at, updated_at)
		 VALUES ('user', 'google-user', 'owner@example.com', 'Owner', '` + now + `', '` + now + `')`,
		`INSERT INTO teams(id, name, slug, default_timezone, created_by_user_id, created_at, updated_at)
		 VALUES ('team', 'Team', 'team', 'Asia/Jakarta', 'user', '` + now + `', '` + now + `')`,
		`INSERT INTO teams(id, name, slug, default_timezone, created_by_user_id, created_at, updated_at)
		 VALUES ('other-team', 'Other', 'other', 'Asia/Jakarta', 'user', '` + now + `', '` + now + `')`,
		`INSERT INTO members(id, team_id, user_id, display_name, color, role, status, created_at, updated_at)
		 VALUES ('owner', 'team', 'user', 'Owner', 'blue', 'owner', 'active', '` + now + `', '` + now + `')`,
		`INSERT INTO members(id, team_id, display_name, color, role, status, created_at, updated_at)
		 VALUES ('second', 'team', 'Second', 'green', 'member', 'active', '` + now + `', '` + now + `')`,
		`INSERT INTO members(id, team_id, display_name, color, role, status, created_at, updated_at)
		 VALUES ('other-member', 'other-team', 'Other', 'red', 'member', 'active', '` + now + `', '` + now + `')`,
		`INSERT INTO schedules(id, team_id, name, mode, timezone, status, created_by_member_id, created_at, updated_at)
		 VALUES ('manual', 'team', 'Manual', 'manual', 'Asia/Jakarta', 'active', 'owner', '` + now + `', '` + now + `')`,
		`INSERT INTO schedules(id, team_id, name, mode, timezone, status, created_by_member_id, created_at, updated_at)
		 VALUES ('rotation', 'team', 'Rotation', 'rotation', 'Asia/Jakarta', 'active', 'owner', '` + now + `', '` + now + `')`,
		`INSERT INTO schedule_members(schedule_id, member_id) VALUES ('manual', 'owner')`,
		`INSERT INTO schedule_members(schedule_id, member_id) VALUES ('rotation', 'owner')`,
		`INSERT INTO schedule_members(schedule_id, member_id) VALUES ('rotation', 'second')`,
	}
	for _, statement := range statements {
		if _, err := db.Exec(statement); err != nil {
			t.Fatal(err)
		}
	}
}
