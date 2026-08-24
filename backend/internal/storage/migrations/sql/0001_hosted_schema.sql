CREATE TABLE users (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    google_subject TEXT,
    email TEXT COLLATE NOCASE,
    display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
    avatar_url TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_login_at TEXT,
    disabled_at TEXT,
    deleted_at TEXT,
    CHECK (
        (deleted_at IS NULL AND google_subject IS NOT NULL AND email IS NOT NULL)
        OR
        (deleted_at IS NOT NULL AND google_subject IS NULL AND email IS NULL
            AND avatar_url IS NULL)
    )
);

CREATE UNIQUE INDEX users_google_subject_unique
    ON users(google_subject) WHERE google_subject IS NOT NULL;
CREATE UNIQUE INDEX users_email_unique
    ON users(email COLLATE NOCASE) WHERE email IS NOT NULL;

CREATE TABLE teams (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    slug TEXT NOT NULL COLLATE NOCASE CHECK (length(trim(slug)) > 0),
    default_timezone TEXT NOT NULL CHECK (length(default_timezone) > 0),
    created_by_user_id TEXT NOT NULL REFERENCES users(id),
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    archived_at TEXT
);

CREATE UNIQUE INDEX teams_slug_unique ON teams(slug COLLATE NOCASE);

CREATE TABLE members (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    team_id TEXT NOT NULL REFERENCES teams(id),
    user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
    color TEXT NOT NULL CHECK (length(color) > 0),
    role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    status TEXT NOT NULL CHECK (status IN ('active', 'inactive')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    CHECK (status = 'inactive' OR role NOT IN ('owner', 'admin') OR user_id IS NOT NULL)
);

CREATE UNIQUE INDEX members_team_user_unique
    ON members(team_id, user_id) WHERE user_id IS NOT NULL;
CREATE INDEX members_team_status ON members(team_id, status);

CREATE TABLE schedules (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    team_id TEXT NOT NULL REFERENCES teams(id),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    mode TEXT NOT NULL CHECK (mode IN ('manual', 'rotation')),
    timezone TEXT NOT NULL CHECK (length(timezone) > 0),
    status TEXT NOT NULL CHECK (status IN ('draft', 'active', 'archived')),
    created_by_member_id TEXT NOT NULL REFERENCES members(id),
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX schedules_team_status ON schedules(team_id, status);

CREATE TABLE schedule_members (
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    member_id TEXT NOT NULL REFERENCES members(id),
    color_override TEXT,
    active_from TEXT,
    active_until TEXT,
    PRIMARY KEY (schedule_id, member_id),
    CHECK (active_until IS NULL OR active_from IS NULL OR active_from < active_until)
);

CREATE TABLE manual_assignments (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    member_id TEXT NOT NULL REFERENCES members(id),
    starts_at TEXT NOT NULL,
    ends_at TEXT NOT NULL,
    note TEXT,
    created_by_member_id TEXT NOT NULL REFERENCES members(id),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    CHECK (starts_at < ends_at)
);

CREATE INDEX manual_assignments_schedule_interval
    ON manual_assignments(schedule_id, starts_at, ends_at);

CREATE TABLE rotation_rules (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    effective_from TEXT NOT NULL,
    effective_until TEXT,
    anchor_local_date TEXT NOT NULL,
    anchor_member_id TEXT NOT NULL REFERENCES members(id),
    cadence_value INTEGER NOT NULL CHECK (cadence_value > 0),
    cadence_unit TEXT NOT NULL CHECK (cadence_unit IN ('minutes', 'hours', 'days', 'weeks')),
    handover_kind TEXT NOT NULL CHECK (handover_kind IN ('clock', 'prayer')),
    handover_time TEXT,
    prayer_name TEXT,
    latitude REAL,
    longitude REAL,
    prayer_method TEXT,
    asr_method TEXT,
    adjustment_minutes INTEGER NOT NULL DEFAULT 0,
    created_by_member_id TEXT NOT NULL REFERENCES members(id),
    created_at TEXT NOT NULL,
    CHECK (effective_until IS NULL OR effective_from < effective_until),
    CHECK (
        (handover_kind = 'clock' AND handover_time IS NOT NULL
            AND prayer_name IS NULL AND latitude IS NULL AND longitude IS NULL
            AND prayer_method IS NULL AND asr_method IS NULL)
        OR
        (handover_kind = 'prayer' AND handover_time IS NULL
            AND prayer_name IN ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')
            AND latitude BETWEEN -90 AND 90
            AND longitude BETWEEN -180 AND 180
            AND prayer_method IS NOT NULL AND asr_method IS NOT NULL
            AND cadence_unit IN ('days', 'weeks'))
    )
);

CREATE INDEX rotation_rules_schedule_interval
    ON rotation_rules(schedule_id, effective_from, effective_until);

CREATE TABLE rotation_rule_members (
    rotation_rule_id TEXT NOT NULL REFERENCES rotation_rules(id),
    member_id TEXT NOT NULL REFERENCES members(id),
    position INTEGER NOT NULL CHECK (position >= 0),
    PRIMARY KEY (rotation_rule_id, member_id),
    UNIQUE (rotation_rule_id, position)
);

CREATE TABLE replacements (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    unavailable_member_id TEXT NOT NULL REFERENCES members(id),
    replacement_member_id TEXT NOT NULL REFERENCES members(id),
    starts_at TEXT NOT NULL,
    ends_at TEXT NOT NULL,
    reason TEXT,
    status TEXT NOT NULL CHECK (status IN ('active', 'cancelled')),
    created_by_member_id TEXT NOT NULL REFERENCES members(id),
    created_at TEXT NOT NULL,
    cancelled_at TEXT,
    cancelled_by_member_id TEXT REFERENCES members(id),
    CHECK (starts_at < ends_at),
    CHECK (unavailable_member_id <> replacement_member_id),
    CHECK (
        (status = 'active' AND cancelled_at IS NULL AND cancelled_by_member_id IS NULL)
        OR
        (status = 'cancelled' AND cancelled_at IS NOT NULL
            AND cancelled_by_member_id IS NOT NULL)
    )
);

CREATE INDEX replacements_schedule_interval_status
    ON replacements(schedule_id, starts_at, ends_at, status);

CREATE TABLE local_imports (
    id TEXT PRIMARY KEY CHECK (length(id) > 0),
    user_id TEXT NOT NULL REFERENCES users(id),
    local_document_id TEXT NOT NULL CHECK (length(local_document_id) > 0),
    team_id TEXT NOT NULL REFERENCES teams(id),
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    imported_at TEXT NOT NULL,
    UNIQUE (user_id, local_document_id)
);

CREATE TRIGGER schedules_team_insert
BEFORE INSERT ON schedules
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM members
        WHERE id = NEW.created_by_member_id AND team_id = NEW.team_id
    ) THEN RAISE(ABORT, 'schedule creator must belong to the team') END;
END;

CREATE TRIGGER schedules_team_update
BEFORE UPDATE ON schedules
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM members
        WHERE id = NEW.created_by_member_id AND team_id = NEW.team_id
    ) THEN RAISE(ABORT, 'schedule creator must belong to the team') END;
END;

CREATE TRIGGER schedule_members_team_insert
BEFORE INSERT ON schedule_members
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s JOIN members m ON m.team_id = s.team_id
        WHERE s.id = NEW.schedule_id AND m.id = NEW.member_id
    ) THEN RAISE(ABORT, 'schedule member must belong to the schedule team') END;
END;

CREATE TRIGGER schedule_members_team_update
BEFORE UPDATE ON schedule_members
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s JOIN members m ON m.team_id = s.team_id
        WHERE s.id = NEW.schedule_id AND m.id = NEW.member_id
    ) THEN RAISE(ABORT, 'schedule member must belong to the schedule team') END;
END;

CREATE TRIGGER manual_assignments_insert
BEFORE INSERT ON manual_assignments
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members sm ON sm.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id AND s.mode = 'manual'
          AND sm.member_id = NEW.member_id AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'invalid manual assignment membership or mode') END;
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM manual_assignments a
        WHERE a.schedule_id = NEW.schedule_id
          AND NEW.starts_at < a.ends_at AND a.starts_at < NEW.ends_at
    ) THEN RAISE(ABORT, 'manual assignments must not overlap') END;
END;

CREATE TRIGGER manual_assignments_update
BEFORE UPDATE ON manual_assignments
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members sm ON sm.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id AND s.mode = 'manual'
          AND sm.member_id = NEW.member_id AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'invalid manual assignment membership or mode') END;
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM manual_assignments a
        WHERE a.schedule_id = NEW.schedule_id AND a.id <> NEW.id
          AND NEW.starts_at < a.ends_at AND a.starts_at < NEW.ends_at
    ) THEN RAISE(ABORT, 'manual assignments must not overlap') END;
END;

CREATE TRIGGER rotation_rules_insert
BEFORE INSERT ON rotation_rules
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members anchor ON anchor.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id AND s.mode = 'rotation'
          AND anchor.member_id = NEW.anchor_member_id
          AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'invalid rotation rule membership or mode') END;
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM rotation_rules r
        WHERE r.schedule_id = NEW.schedule_id
          AND NEW.effective_from < COALESCE(r.effective_until, '9999-12-31T23:59:59Z')
          AND r.effective_from < COALESCE(NEW.effective_until, '9999-12-31T23:59:59Z')
    ) THEN RAISE(ABORT, 'rotation rule effective ranges must not overlap') END;
END;

CREATE TRIGGER rotation_rules_update
BEFORE UPDATE ON rotation_rules
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members anchor ON anchor.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id AND s.mode = 'rotation'
          AND anchor.member_id = NEW.anchor_member_id
          AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'invalid rotation rule membership or mode') END;
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM rotation_rules r
        WHERE r.schedule_id = NEW.schedule_id AND r.id <> NEW.id
          AND NEW.effective_from < COALESCE(r.effective_until, '9999-12-31T23:59:59Z')
          AND r.effective_from < COALESCE(NEW.effective_until, '9999-12-31T23:59:59Z')
    ) THEN RAISE(ABORT, 'rotation rule effective ranges must not overlap') END;
END;

CREATE TRIGGER rotation_rule_members_insert
BEFORE INSERT ON rotation_rule_members
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM rotation_rules r
        JOIN schedule_members sm ON sm.schedule_id = r.schedule_id
        WHERE r.id = NEW.rotation_rule_id AND sm.member_id = NEW.member_id
    ) THEN RAISE(ABORT, 'rotation member must belong to the schedule') END;
END;

CREATE TRIGGER rotation_rule_members_update
BEFORE UPDATE ON rotation_rule_members
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM rotation_rules r
        JOIN schedule_members sm ON sm.schedule_id = r.schedule_id
        WHERE r.id = NEW.rotation_rule_id AND sm.member_id = NEW.member_id
    ) THEN RAISE(ABORT, 'rotation member must belong to the schedule') END;
END;

CREATE TRIGGER replacements_insert
BEFORE INSERT ON replacements
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members unavailable ON unavailable.schedule_id = s.id
        JOIN schedule_members replacement ON replacement.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id
          AND unavailable.member_id = NEW.unavailable_member_id
          AND replacement.member_id = NEW.replacement_member_id
          AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'replacement members must belong to the schedule team') END;
    SELECT CASE WHEN NEW.status = 'active' AND EXISTS (
        SELECT 1 FROM replacements r
        WHERE r.schedule_id = NEW.schedule_id AND r.status = 'active'
          AND r.unavailable_member_id = NEW.unavailable_member_id
          AND NEW.starts_at < r.ends_at AND r.starts_at < NEW.ends_at
    ) THEN RAISE(ABORT, 'active replacements must not conflict') END;
END;

CREATE TRIGGER replacements_update
BEFORE UPDATE ON replacements
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules s
        JOIN schedule_members unavailable ON unavailable.schedule_id = s.id
        JOIN schedule_members replacement ON replacement.schedule_id = s.id
        JOIN members creator ON creator.id = NEW.created_by_member_id
        WHERE s.id = NEW.schedule_id
          AND unavailable.member_id = NEW.unavailable_member_id
          AND replacement.member_id = NEW.replacement_member_id
          AND creator.team_id = s.team_id
    ) THEN RAISE(ABORT, 'replacement members must belong to the schedule team') END;
    SELECT CASE WHEN NEW.status = 'active' AND EXISTS (
        SELECT 1 FROM replacements r
        WHERE r.schedule_id = NEW.schedule_id AND r.id <> NEW.id
          AND r.status = 'active'
          AND r.unavailable_member_id = NEW.unavailable_member_id
          AND NEW.starts_at < r.ends_at AND r.starts_at < NEW.ends_at
    ) THEN RAISE(ABORT, 'active replacements must not conflict') END;
END;

CREATE TRIGGER local_imports_team_insert
BEFORE INSERT ON local_imports
BEGIN
    SELECT CASE WHEN NOT EXISTS (
        SELECT 1 FROM schedules
        WHERE id = NEW.schedule_id AND team_id = NEW.team_id
    ) THEN RAISE(ABORT, 'import schedule must belong to the imported team') END;
END;
