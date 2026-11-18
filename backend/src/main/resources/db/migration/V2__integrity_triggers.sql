CREATE FUNCTION check_role(p_user uuid, p_role text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT role FROM users WHERE id = p_user) <> p_role THEN
        RAISE EXCEPTION 'Пользователь % должен иметь роль %', p_user, p_role;
    END IF;
END $$;

CREATE FUNCTION check_project_roles() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM check_role(NEW.team_lead_id, 'TEAM_LEAD');
    RETURN NEW;
END $$;

CREATE TRIGGER projects_roles BEFORE INSERT OR UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION check_project_roles();

CREATE FUNCTION check_ticket_roles() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM check_role(NEW.creator_id, 'TESTER');
    PERFORM check_role(NEW.assignee_id, 'DEVELOPER');
    RETURN NEW;
END $$;

CREATE TRIGGER tickets_roles BEFORE INSERT OR UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION check_ticket_roles();

CREATE FUNCTION check_fix_roles() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM check_role(NEW.developer_id, 'DEVELOPER');
    PERFORM check_role(NEW.reviewer_id, 'TESTER');
    RETURN NEW;
END $$;

CREATE TRIGGER fixes_roles BEFORE INSERT OR UPDATE ON fixes
    FOR EACH ROW EXECUTE FUNCTION check_fix_roles();

CREATE FUNCTION check_role_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM projects WHERE team_lead_id = NEW.id)
       OR EXISTS (SELECT 1 FROM tickets WHERE NEW.id IN (creator_id, assignee_id))
       OR EXISTS (SELECT 1 FROM fixes WHERE NEW.id IN (developer_id, reviewer_id)) THEN
        RAISE EXCEPTION 'Нельзя сменить роль пользователя %: он уже задействован в проектах', NEW.id;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER users_role_change BEFORE UPDATE OF role ON users
    FOR EACH ROW WHEN (OLD.role <> NEW.role) EXECUTE FUNCTION check_role_change();

CREATE FUNCTION check_project_has_members() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    pid uuid;
BEGIN
    IF TG_OP = 'INSERT' THEN
        pid := NEW.id;
    ELSE
        pid := OLD.project_id;
    END IF;

    IF EXISTS (SELECT 1 FROM projects WHERE id = pid)
       AND NOT EXISTS (SELECT 1 FROM project_members WHERE project_id = pid) THEN
        RAISE EXCEPTION 'У проекта % должен быть хотя бы один участник', pid;
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER projects_has_members AFTER INSERT ON projects
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_project_has_members();

CREATE CONSTRAINT TRIGGER project_members_not_empty AFTER DELETE OR UPDATE ON project_members
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_project_has_members();
