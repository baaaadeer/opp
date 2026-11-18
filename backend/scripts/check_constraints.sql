BEGIN;

INSERT INTO users (id, name, role, email, password_hash) VALUES
 ('00000000-0000-0000-0000-000000000001', 'Тимлид',   'TEAM_LEAD', 'lead@x', 'h'),
 ('00000000-0000-0000-0000-000000000002', 'Разраб',   'DEVELOPER', 'dev@x',  'h'),
 ('00000000-0000-0000-0000-000000000003', 'Тестер',   'TESTER',    'qa@x',   'h'),
 ('00000000-0000-0000-0000-000000000004', 'Чужой QA', 'TESTER',    'qa2@x',  'h');
INSERT INTO projects (id, name, description, team_lead_id) VALUES
 ('10000000-0000-0000-0000-000000000001', 'П', 'описание', '00000000-0000-0000-0000-000000000001');
INSERT INTO project_members VALUES
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003');
INSERT INTO project_versions VALUES ('10000000-0000-0000-0000-000000000001', '1.0', 'PLANNED', NULL);
INSERT INTO tickets (project_id, number, title, description, creator_id) VALUES
 ('10000000-0000-0000-0000-000000000001', 1, 'Баг', 'опис', '00000000-0000-0000-0000-000000000003');

SET CONSTRAINTS ALL IMMEDIATE;
SAVEPOINT s;

\echo '== должно пройти: тикет в работу -> исправление -> проверка -> закрытие'
UPDATE tickets SET status = 'IN_PROGRESS', assignee_id = '00000000-0000-0000-0000-000000000002',
                   deadline = now() + interval '3 days', planning_reason = 'спринт 1';
INSERT INTO fixes (project_id, ticket_number, number, description, submitted_at, developer_id, version_number)
  VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'фикс', now(), '00000000-0000-0000-0000-000000000002', '1.0');
UPDATE fixes SET review_result = 'ACCEPTED', reviewed_at = now(), reviewer_id = '00000000-0000-0000-0000-000000000003';
UPDATE tickets SET status = 'CLOSED', closed_at = now();
INSERT INTO attachments VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'лог', 'LOG', now(), 's3/key', NULL);
INSERT INTO attachments VALUES ('10000000-0000-0000-0000-000000000001', 1, 2, 'MR', 'COMMIT_LINK', now(), NULL, 'https://git/mr/1');
UPDATE project_versions SET status = 'RELEASED', release_date = now();
ROLLBACK TO s;

\echo '== должно пройти: удаление проекта каскадом'
DELETE FROM projects;
ROLLBACK TO s;

\echo '== 2: недопустимая роль — должно упасть'
INSERT INTO users (name, role, email, password_hash) VALUES ('x', 'ADMIN', 'a@x', 'h');
ROLLBACK TO s;

\echo '== 3: недопустимый статус версии — должно упасть'
INSERT INTO project_versions VALUES ('10000000-0000-0000-0000-000000000001', '2.0', 'BETA', NULL);
ROLLBACK TO s;

\echo '== 4: недопустимый статус тикета — должно упасть'
UPDATE tickets SET status = 'DONE';
ROLLBACK TO s;

\echo '== 5: недопустимый приоритет — должно упасть'
UPDATE tickets SET priority = 'URGENT';
ROLLBACK TO s;

\echo '== 7: недопустимый тип вложения — должно упасть'
INSERT INTO attachments VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'x', 'VIDEO', now(), 'k', NULL);
ROLLBACK TO s;

\echo '== 8: тимлид проекта — разработчик — должно упасть'
INSERT INTO projects (name, description, team_lead_id) VALUES ('x', 'x', '00000000-0000-0000-0000-000000000002');
ROLLBACK TO s;

\echo '== 8: ответственный — тестировщик — должно упасть'
UPDATE tickets SET assignee_id = '00000000-0000-0000-0000-000000000003';
ROLLBACK TO s;

\echo '== 8: смена роли у задействованного пользователя — должно упасть'
UPDATE users SET role = 'DEVELOPER' WHERE email = 'qa@x';
ROLLBACK TO s;

\echo '== 9: проект без участников — должно упасть'
INSERT INTO projects (name, description, team_lead_id) VALUES ('x', 'x', '00000000-0000-0000-0000-000000000001');
ROLLBACK TO s;

\echo '== 10: выпущенная версия без даты — должно упасть'
UPDATE project_versions SET status = 'RELEASED';
ROLLBACK TO s;

\echo '== 11: дедлайн раньше создания — должно упасть'
UPDATE tickets SET deadline = created_at - interval '1 day', planning_reason = 'x';
ROLLBACK TO s;

\echo '== 12: дедлайн без основания — должно упасть'
UPDATE tickets SET deadline = now() + interval '1 day';
ROLLBACK TO s;

\echo '== 13: закрыт без даты закрытия — должно упасть'
UPDATE tickets SET status = 'CLOSED', assignee_id = '00000000-0000-0000-0000-000000000002';
ROLLBACK TO s;

\echo '== 14: в работе без ответственного — должно упасть'
UPDATE tickets SET status = 'IN_PROGRESS';
ROLLBACK TO s;

\echo '== 14: причина переназначения без ответственного — должно упасть'
UPDATE tickets SET reassignment_reason = 'x';
ROLLBACK TO s;

\echo '== 15: автор тикета не участник проекта — должно упасть'
INSERT INTO tickets (project_id, number, title, description, creator_id)
  VALUES ('10000000-0000-0000-0000-000000000001', 2, 'x', 'x', '00000000-0000-0000-0000-000000000004');
ROLLBACK TO s;

\echo '== 15: исключить из проекта автора тикета — должно упасть'
DELETE FROM project_members WHERE user_id = '00000000-0000-0000-0000-000000000003';
ROLLBACK TO s;

\echo '== 16: результат проверки без проверяющего — должно упасть'
INSERT INTO fixes (project_id, ticket_number, number, description, submitted_at, review_result, reviewed_at, developer_id, version_number)
  VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'x', now(), 'ACCEPTED', now(), '00000000-0000-0000-0000-000000000002', '1.0');
ROLLBACK TO s;

\echo '== 17: проверка раньше передачи — должно упасть'
INSERT INTO fixes (project_id, ticket_number, number, description, submitted_at, review_result, reviewed_at, reviewer_id, developer_id, version_number)
  VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'x', now(), 'REJECTED', now() - interval '1 hour',
          '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '1.0');
ROLLBACK TO s;

\echo '== 18: два непроверенных исправления — должно упасть'
INSERT INTO fixes (project_id, ticket_number, number, description, developer_id, version_number) VALUES
  ('10000000-0000-0000-0000-000000000001', 1, 1, 'a', '00000000-0000-0000-0000-000000000002', '1.0'),
  ('10000000-0000-0000-0000-000000000001', 1, 2, 'b', '00000000-0000-0000-0000-000000000002', '1.0');
ROLLBACK TO s;

\echo '== 19: ссылка на коммит без URL — должно упасть'
INSERT INTO attachments VALUES ('10000000-0000-0000-0000-000000000001', 1, 1, 'x', 'COMMIT_LINK', now(), 'k', NULL);
ROLLBACK TO s;

\echo '== несуществующая версия — должно упасть'
UPDATE tickets SET version_number = '9.9';
ROLLBACK TO s;

ROLLBACK;
