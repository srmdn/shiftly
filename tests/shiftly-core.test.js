const assert = require('node:assert/strict');
const test = require('node:test');
const Core = require('../shiftly-core.js');

function referenceSchedule() {
  const schedule = Core.createRotationSchedule({
    names: ['Imam 1', 'Imam 2'],
    anchor: '2026-08-24T12:00',
    anchorPersonId: 'person-2',
    durationDays: 2,
    handoverLabel: 'Zuhur',
    handoverTime: '12:00'
  });
  schedule.exceptions.push({
    id: 'exception-1',
    start: '2026-09-03T12:00',
    end: '2026-09-06T12:00',
    unavailablePersonId: 'person-1',
    replacementPersonId: 'person-2',
    reason: 'Leave'
  });
  return schedule;
}

test('legacy data migrates to a non-destructive v2 manual shape', () => {
  const schedule = Core.createManualSchedule({
    '2026-08-24': 'A',
    '2026-08-25': { person: 'B', note: 'Swap' }
  }, { nameA: 'Alpha', nameB: 'Beta' });

  assert.equal(schedule.version, 2);
  assert.equal(schedule.mode, 'manual');
  assert.deepEqual(schedule.people, [
    { id: 'person-1', name: 'Alpha', color: 'violet' },
    { id: 'person-2', name: 'Beta', color: 'orange' }
  ]);
  assert.equal(schedule.manual.assignments['2026-08-24'], 'person-1');
  assert.deepEqual(schedule.manual.assignments['2026-08-25'], { personId: 'person-2', note: 'Swap' });
});

test('rotation is deterministic before and after the anchor', () => {
  const schedule = referenceSchedule();
  const cases = [
    ['2026-08-22T12:00', 'person-1'],
    ['2026-08-24T12:00', 'person-2'],
    ['2026-08-26T12:00', 'person-1'],
    ['2026-09-01T12:00', 'person-2'],
    ['2026-09-03T12:00', 'person-1'],
    ['2026-09-05T12:00', 'person-2'],
    ['2026-09-07T12:00', 'person-1']
  ];
  for (const [datetime, personId] of cases) {
    assert.equal(Core.getScheduledAssignment(schedule, datetime).personId, personId, datetime);
  }
});

test('exception changes actual only during the unavailable person baseline', () => {
  const schedule = referenceSchedule();
  const covered = Core.getActualAssignment(schedule, '2026-09-03T12:00');
  assert.equal(covered.scheduledPersonId, 'person-1');
  assert.equal(covered.actualPersonId, 'person-2');
  assert.equal(covered.isOverride, true);

  const normal = Core.getActualAssignment(schedule, '2026-09-05T12:00');
  assert.equal(normal.scheduledPersonId, 'person-2');
  assert.equal(normal.actualPersonId, 'person-2');
  assert.equal(normal.isOverride, false);

  assert.equal(Core.getScheduledAssignment(schedule, '2026-09-07T12:00').personId, 'person-1');
});

test('coverage counts baseline overlap, not total leave duration', () => {
  const [coverage] = Core.calculateCoverage(referenceSchedule());
  assert.equal(coverage.replacementPersonId, 'person-2');
  assert.equal(coverage.unavailablePersonId, 'person-1');
  assert.equal(coverage.shiftEquivalent, 1);
  assert.equal(coverage.segments.length, 1);
  assert.equal(coverage.segments[0].completeShift, true);
  assert.equal(Core.formatLocalDateTime(coverage.segments[0].start), '2026-09-03T12:00');
  assert.equal(Core.formatLocalDateTime(coverage.segments[0].end), '2026-09-05T12:00');
});

test('partial coverage remains representable', () => {
  const schedule = referenceSchedule();
  schedule.exceptions = [{
    id: 'partial',
    start: '2026-09-04T12:00',
    end: '2026-09-05T12:00',
    unavailablePersonId: 'person-1',
    replacementPersonId: 'person-2'
  }];
  const [coverage] = Core.calculateCoverage(schedule);
  assert.equal(coverage.shiftEquivalent, 0.5);
  assert.equal(coverage.segments[0].completeShift, false);
});

test('three-person rotation follows explicit round-robin order', () => {
  const schedule = Core.createRotationSchedule({
    people: [
      { id: 'imam-a', name: 'Imam A', color: 'violet' },
      { id: 'imam-b', name: 'Imam B', color: 'orange' },
      { id: 'imam-c', name: 'Imam C', color: 'emerald' }
    ],
    order: ['imam-a', 'imam-b', 'imam-c'],
    anchor: '2026-08-24T12:00',
    anchorPersonId: 'imam-c',
    durationDays: 2,
    handoverLabel: 'Zuhur',
    handoverTime: '12:00'
  });

  assert.equal(Core.getScheduledAssignment(schedule, '2026-08-24T12:00').personId, 'imam-c');
  assert.equal(Core.getScheduledAssignment(schedule, '2026-08-26T12:00').personId, 'imam-a');
  assert.equal(Core.getScheduledAssignment(schedule, '2026-08-28T12:00').personId, 'imam-b');
  assert.equal(Core.getScheduledAssignment(schedule, '2026-08-30T12:00').personId, 'imam-c');
});

test('normalization upgrades an existing two-person v2 schedule with colors and order', () => {
  const schedule = Core.normalizeSchedule({
    version: 2,
    id: 'default',
    mode: 'rotation',
    people: [{ id: 'first', name: 'First' }, { id: 'second', name: 'Second' }],
    manual: { assignments: {} },
    rotation: {
      anchor: '2026-08-24T12:00',
      anchorPersonId: 'second',
      durationDays: 2,
      handover: { label: 'Zuhur', time: '12:00' }
    },
    exceptions: []
  });

  assert.deepEqual(schedule.rotation.order, ['first', 'second']);
  assert.equal(schedule.people[0].color, 'violet');
  assert.equal(schedule.people[1].color, 'orange');
});
