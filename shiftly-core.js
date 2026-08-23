(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.ShiftlyCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const VERSION = 2;
  const DAY_MS = 24 * 60 * 60 * 1000;
  const PERSON_COLORS = ['violet', 'orange', 'emerald', 'sky', 'rose', 'amber', 'indigo', 'teal'];

  function modulo(value, divisor) {
    return ((value % divisor) + divisor) % divisor;
  }

  function parseLocalDateTime(value) {
    if (value instanceof Date) return new Date(value.getTime());
    if (typeof value !== 'string') throw new TypeError('Expected a local date-time string or Date');

    const match = value.match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$/);
    if (!match) throw new Error(`Invalid local date-time: ${value}`);

    const [, year, month, day, hour = '00', minute = '00'] = match;
    const date = new Date(+year, +month - 1, +day, +hour, +minute, 0, 0);
    if (
      date.getFullYear() !== +year || date.getMonth() !== +month - 1 ||
      date.getDate() !== +day || date.getHours() !== +hour || date.getMinutes() !== +minute
    ) throw new Error(`Invalid local date-time: ${value}`);
    return date;
  }

  function formatLocalDateTime(value) {
    const date = parseLocalDateTime(value);
    const pad = number => String(number).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  function migrateLegacyEntry(raw) {
    if (!raw) return null;
    const legacyPerson = typeof raw === 'string' ? raw : raw.person;
    const personId = legacyPerson === 'A' ? 'person-1' : legacyPerson === 'B' ? 'person-2' : null;
    const note = typeof raw === 'object' && typeof raw.note === 'string' ? raw.note : '';
    if (!personId && !note) return null;
    return note ? { personId, note } : personId;
  }

  function createManualSchedule(legacyAssignments, legacyConfig) {
    const assignments = {};
    for (const [date, raw] of Object.entries(legacyAssignments || {})) {
      const entry = migrateLegacyEntry(raw);
      if (entry) assignments[date] = entry;
    }

    return {
      version: VERSION,
      id: 'default',
      mode: 'manual',
      people: [
        { id: 'person-1', name: legacyConfig?.nameA || '1', color: 'violet' },
        { id: 'person-2', name: legacyConfig?.nameB || '2', color: 'orange' }
      ],
      manual: { assignments },
      rotation: null,
      exceptions: []
    };
  }

  function createRotationSchedule(options) {
    const names = options?.names || ['1', '2'];
    const people = options?.people || names.map((name, index) => ({
      id: `person-${index + 1}`,
      name: name || String(index + 1),
      color: PERSON_COLORS[index % PERSON_COLORS.length]
    }));
    const order = options?.order || people.map(person => person.id);
    return {
      version: VERSION,
      id: options?.id || 'default',
      mode: 'rotation',
      people,
      manual: { assignments: {} },
      rotation: {
        anchor: formatLocalDateTime(options.anchor),
        anchorPersonId: options.anchorPersonId,
        durationDays: Number(options.durationDays),
        order,
        handover: {
          label: options.handoverLabel || 'Handover',
          time: options.handoverTime || formatLocalDateTime(options.anchor).slice(11)
        }
      },
      exceptions: []
    };
  }

  function normalizeSchedule(input) {
    const schedule = input && typeof input === 'object' ? input : createManualSchedule({}, {});
    schedule.version = VERSION;
    schedule.id ||= 'default';
    schedule.mode = schedule.mode === 'rotation' ? 'rotation' : 'manual';
    schedule.people = (schedule.people || []).map((person, index) => ({
      id: person.id || `person-${index + 1}`,
      name: person.name || `Person ${index + 1}`,
      color: person.color || PERSON_COLORS[index % PERSON_COLORS.length]
    }));
    if (schedule.people.length < 2) {
      while (schedule.people.length < 2) {
        const index = schedule.people.length;
        schedule.people.push({ id: `person-${index + 1}`, name: String(index + 1), color: PERSON_COLORS[index] });
      }
    }
    schedule.manual ||= { assignments: {} };
    schedule.manual.assignments ||= {};
    schedule.exceptions = Array.isArray(schedule.exceptions) ? schedule.exceptions : [];

    if (schedule.rotation) {
      const personIds = schedule.people.map(person => person.id);
      const existingOrder = Array.isArray(schedule.rotation.order) ? schedule.rotation.order : personIds;
      schedule.rotation.order = [
        ...existingOrder.filter((id, index) => personIds.includes(id) && existingOrder.indexOf(id) === index),
        ...personIds.filter(id => !existingOrder.includes(id))
      ];
      if (!personIds.includes(schedule.rotation.anchorPersonId)) {
        schedule.rotation.anchorPersonId = schedule.rotation.order[0];
      }
      schedule.rotation.handover ||= {
        label: 'Handover',
        time: schedule.rotation.anchor?.slice(11, 16) || '12:00'
      };
    }
    return schedule;
  }

  function assertRotationSchedule(schedule) {
    if (!schedule || schedule.version !== VERSION || schedule.mode !== 'rotation') {
      throw new Error('A version 2 rotation schedule is required');
    }
    if (!Array.isArray(schedule.people) || schedule.people.length < 2) {
      throw new Error('Rotation requires at least two people');
    }
    if (!schedule.rotation || !Number.isFinite(schedule.rotation.durationDays) || schedule.rotation.durationDays <= 0) {
      throw new Error('Rotation duration must be greater than zero');
    }
    const order = schedule.rotation.order || schedule.people.map(person => person.id);
    if (order.length < 2 || order.some(id => !schedule.people.some(person => person.id === id))) {
      throw new Error('Rotation order must contain schedule people');
    }
    if (!order.includes(schedule.rotation.anchorPersonId)) {
      throw new Error('Anchor person must belong to the schedule');
    }
  }

  function getShiftIntervalAt(schedule, datetime) {
    assertRotationSchedule(schedule);
    const point = parseLocalDateTime(datetime);
    const anchor = parseLocalDateTime(schedule.rotation.anchor);
    const durationMs = schedule.rotation.durationDays * DAY_MS;
    const shiftIndex = Math.floor((point.getTime() - anchor.getTime()) / durationMs);
    const order = schedule.rotation.order || schedule.people.map(person => person.id);
    const anchorPersonIndex = order.indexOf(schedule.rotation.anchorPersonId);
    const personIndex = modulo(anchorPersonIndex + shiftIndex, order.length);
    const start = new Date(anchor.getTime() + shiftIndex * durationMs);

    return {
      shiftIndex,
      personId: order[personIndex],
      start,
      end: new Date(start.getTime() + durationMs),
      durationMs
    };
  }

  function getScheduledAssignment(schedule, datetime) {
    return getShiftIntervalAt(schedule, datetime);
  }

  function getActualAssignment(schedule, datetime) {
    const point = parseLocalDateTime(datetime);
    const scheduled = getScheduledAssignment(schedule, point);
    const exceptions = Array.isArray(schedule.exceptions) ? schedule.exceptions : [];
    let applicable = null;

    for (const exception of exceptions) {
      const start = parseLocalDateTime(exception.start);
      const end = parseLocalDateTime(exception.end);
      if (
        point >= start && point < end &&
        scheduled.personId === exception.unavailablePersonId &&
        exception.replacementPersonId !== scheduled.personId
      ) applicable = exception;
    }

    return {
      ...scheduled,
      scheduledPersonId: scheduled.personId,
      actualPersonId: applicable ? applicable.replacementPersonId : scheduled.personId,
      isOverride: Boolean(applicable),
      exceptionId: applicable?.id || null,
      reason: applicable?.reason || ''
    };
  }

  function calculateCoverage(schedule) {
    assertRotationSchedule(schedule);
    const ledger = new Map();

    for (const exception of schedule.exceptions || []) {
      const exceptionStart = parseLocalDateTime(exception.start);
      const exceptionEnd = parseLocalDateTime(exception.end);
      if (exceptionEnd <= exceptionStart || exception.unavailablePersonId === exception.replacementPersonId) continue;

      let interval = getShiftIntervalAt(schedule, exceptionStart);
      while (interval.start < exceptionEnd) {
        const overlapStart = new Date(Math.max(interval.start.getTime(), exceptionStart.getTime()));
        const overlapEnd = new Date(Math.min(interval.end.getTime(), exceptionEnd.getTime()));

        if (interval.personId === exception.unavailablePersonId && overlapEnd > overlapStart) {
          const key = `${exception.replacementPersonId}->${exception.unavailablePersonId}`;
          if (!ledger.has(key)) {
            ledger.set(key, {
              replacementPersonId: exception.replacementPersonId,
              unavailablePersonId: exception.unavailablePersonId,
              coveredMs: 0,
              shiftEquivalent: 0,
              segments: []
            });
          }
          const entry = ledger.get(key);
          entry.coveredMs += overlapEnd.getTime() - overlapStart.getTime();
          entry.segments.push({
            exceptionId: exception.id,
            start: overlapStart,
            end: overlapEnd,
            completeShift: overlapStart.getTime() === interval.start.getTime() && overlapEnd.getTime() === interval.end.getTime()
          });
        }

        interval = getShiftIntervalAt(schedule, interval.end);
      }
    }

    for (const entry of ledger.values()) {
      entry.shiftEquivalent = entry.coveredMs / (schedule.rotation.durationDays * DAY_MS);
    }
    return Array.from(ledger.values());
  }

  function getManualEntry(schedule, isoDate) {
    const raw = schedule?.manual?.assignments?.[isoDate];
    if (!raw) return { personId: null, note: '' };
    if (typeof raw === 'string') return { personId: raw, note: '' };
    return { personId: raw.personId || null, note: raw.note || '' };
  }

  function resolveCalendarDate(schedule, isoDate) {
    if (schedule.mode === 'manual') {
      const entry = getManualEntry(schedule, isoDate);
      return {
        scheduledPersonId: entry.personId,
        actualPersonId: entry.personId,
        isOverride: false,
        exceptionId: null,
        reason: '',
        note: entry.note
      };
    }

    const handoverTime = schedule.rotation?.handover?.time || schedule.rotation.anchor.slice(11, 16);
    return { ...getActualAssignment(schedule, `${isoDate}T${handoverTime}`), note: '' };
  }

  return {
    VERSION,
    DAY_MS,
    PERSON_COLORS,
    parseLocalDateTime,
    formatLocalDateTime,
    createManualSchedule,
    createRotationSchedule,
    normalizeSchedule,
    getShiftIntervalAt,
    getScheduledAssignment,
    getActualAssignment,
    calculateCoverage,
    getManualEntry,
    resolveCalendarDate
  };
});
