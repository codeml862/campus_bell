// Run against the Firestore emulator only:
// firebase emulators:exec --only firestore --project demo-campusbell "node test/firestore_rules_test.mjs"
import assert from 'node:assert/strict';

const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw new Error('Local emulator required');
const project = 'demo-campusbell';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const encode = (value) => {
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === 'string') return { stringValue: value };
  throw new Error('Unsupported fixture value');
};
const token = (uid) => {
  if (uid === 'owner') return uid;
  const now = Math.floor(Date.now() / 1000);
  return [
    { alg: 'none', typ: 'JWT' },
    { sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`,
      iat: now, exp: now + 3600, firebase: { sign_in_provider: 'password' } },
  ].map((part) => Buffer.from(JSON.stringify(part)).toString('base64url')).join('.') + '.';
};
async function write(uid, path, data, allowed = true, patch = false) {
  const params = patch
    ? '?' + new URLSearchParams(Object.keys(data).map((key) => ['updateMask.fieldPaths', key]))
    : '';
  const response = await fetch(`${base}/${path}${params}`, {
    method: 'PATCH', headers: { Authorization: `Bearer ${token(uid)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encode(value)])) }),
  });
  const result = await response.json();
  assert.equal(response.ok, allowed, `${uid} writes ${path}: ${JSON.stringify(result)}`);
  if (!allowed) assert.equal(response.status, 403);
  return result;
}
const user = (role, department = 'CSE', status = 'active') => ({ role, department, status, name: role });
await write('owner', 'users/teacher', user('Professor'));
await write('owner', 'users/otherTeacher', user('Assistant Professor'));
await write('owner', 'users/student', user('Student'));
await write('owner', 'users/peer', user('Student'));
await write('owner', 'users/outsider', user('Student', 'MBA'));
await write('owner', 'users/disabled', user('Student', 'CSE', 'disabled'));
await write('owner', 'users/admin', user('Administrator', 'Administration'));
const group = { name: 'Class', department: 'CSE', ownerUid: 'teacher', memberUids: [], adminUids: [] };
await write('teacher', 'groups/class', group);
await write('student', 'groups/unauthorized', { ...group, ownerUid: 'student' }, false);
await write('otherTeacher', 'groups/class', { name: 'Hijack' }, false, true);
await write('student', 'groups/class', { memberUids: ['student'] }, true, true);
await write('student', 'groups/class', { memberUids: ['student'] }, true, true);
await write('student', 'groups/class', { memberUids: ['student', 'peer'] }, false, true);
await write('student', 'groups/class', { adminUids: ['student'] }, false, true);
await write('outsider', 'groups/class', { memberUids: ['student', 'outsider'] }, false, true);
await write('disabled', 'groups/class', { memberUids: ['student', 'disabled'] }, false, true);
await write('teacher', 'groups/class', { memberUids: ['student', 'peer'], adminUids: ['student'] }, true, true);
await write('student', 'groups/class', { memberUids: ['student'] }, true, true);
await write('student', 'groups/class', { memberUids: ['student', 'peer'], adminUids: ['student', 'peer'] }, true, true);
await write('teacher', 'groups/class', { memberUids: ['peer'], adminUids: ['peer'] }, true, true);
await write('student', 'groups/class', { name: 'Revoked admin' }, false, true);
await write('peer', 'groups/class', { ownerUid: 'peer' }, false, true);
await write('peer', 'groups/class', { department: 'MBA' }, false, true);
await write('peer', 'groups/class', { adminUids: ['peer', 'outsider'] }, false, true);
await write('admin', 'users/peer', { department: 'MBA' }, true, true);
await write('peer', 'groups/class', { name: 'Moved department' }, false, true);
await write('peer', 'users/peer', { department: 'CSE' }, false, true);

// The department query immediately moves the student between department lists.
async function departmentUsers(department) {
  const response = await fetch(`${base}:runQuery`, {
    method: 'POST', headers: { Authorization: `Bearer ${token('student')}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'users' }],
      where: { fieldFilter: { field: { fieldPath: 'department' }, op: 'EQUAL', value: encode(department) } } } }),
  });
  assert.equal(response.ok, true);
  return (await response.json()).flatMap((entry) => entry.document ? [entry.document.name.split('/').at(-1)] : []);
}
assert.equal((await departmentUsers('CSE')).includes('peer'), false);
assert.equal((await departmentUsers('MBA')).includes('peer'), true);
console.log('Firestore rules passed: teacher creation, self-join, department move, admin delegation/removal and denied escalation.');
