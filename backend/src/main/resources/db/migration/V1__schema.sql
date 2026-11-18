CREATE TABLE users (
    id            uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    name          varchar(200) NOT NULL,
    role          varchar(20)  NOT NULL CHECK (role IN ('TEAM_LEAD', 'DEVELOPER', 'TESTER')),
    email         varchar(320) NOT NULL UNIQUE,
    password_hash varchar(100) NOT NULL
);

CREATE TABLE projects (
    id           uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    name         varchar(200) NOT NULL,
    description  text         NOT NULL,
    team_lead_id uuid         NOT NULL REFERENCES users (id)
);

CREATE TABLE project_members (
    project_id uuid NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES users (id),
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE project_versions (
    project_id   uuid        NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    number       varchar(50) NOT NULL,
    status       varchar(20) NOT NULL DEFAULT 'PLANNED' CHECK (status IN ('PLANNED', 'RELEASED')),
    release_date timestamptz,
    PRIMARY KEY (project_id, number),

    CONSTRAINT project_versions_release_date_check
        CHECK (status <> 'RELEASED' OR release_date IS NOT NULL)
);

CREATE TABLE tickets (
    project_id          uuid         NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    number              integer      NOT NULL CHECK (number > 0),
    title               varchar(300) NOT NULL,
    description         text         NOT NULL,
    steps_to_reproduce  text,
    status              varchar(20)  NOT NULL DEFAULT 'DRAFT'
                        CHECK (status IN ('DRAFT', 'OPEN', 'IN_PROGRESS', 'IN_REVIEW', 'CLOSED')),
    priority            varchar(10)  CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    created_at          timestamptz  NOT NULL DEFAULT now(),
    deadline            timestamptz,
    planning_reason     text,
    reassignment_reason text,
    closed_at           timestamptz,
    creator_id          uuid         NOT NULL,
    assignee_id         uuid,
    version_number      varchar(50),
    PRIMARY KEY (project_id, number),
    FOREIGN KEY (project_id, version_number) REFERENCES project_versions (project_id, number),

    FOREIGN KEY (project_id, creator_id)  REFERENCES project_members (project_id, user_id),
    FOREIGN KEY (project_id, assignee_id) REFERENCES project_members (project_id, user_id),

    CONSTRAINT tickets_dates_check
        CHECK (deadline >= created_at AND closed_at >= created_at),
    CONSTRAINT tickets_planning_check
        CHECK ((deadline IS NULL) = (planning_reason IS NULL)),
    CONSTRAINT tickets_closed_check
        CHECK ((status = 'CLOSED') = (closed_at IS NOT NULL)),
    CONSTRAINT tickets_assignee_check
        CHECK (status NOT IN ('IN_PROGRESS', 'IN_REVIEW', 'CLOSED') OR assignee_id IS NOT NULL),
    CONSTRAINT tickets_reassignment_check
        CHECK (reassignment_reason IS NULL OR assignee_id IS NOT NULL)
);

CREATE TABLE fixes (
    project_id     uuid        NOT NULL,
    ticket_number  integer     NOT NULL,
    number         integer     NOT NULL CHECK (number > 0),
    description    text        NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    submitted_at   timestamptz,
    review_result  varchar(10) CHECK (review_result IN ('ACCEPTED', 'REJECTED')),
    review_comment text,
    reviewed_at    timestamptz,
    developer_id   uuid        NOT NULL,
    version_number varchar(50) NOT NULL,
    reviewer_id    uuid,
    PRIMARY KEY (project_id, ticket_number, number),
    FOREIGN KEY (project_id, ticket_number)  REFERENCES tickets (project_id, number) ON DELETE CASCADE,
    FOREIGN KEY (project_id, version_number) REFERENCES project_versions (project_id, number),

    FOREIGN KEY (project_id, developer_id) REFERENCES project_members (project_id, user_id),
    FOREIGN KEY (project_id, reviewer_id)  REFERENCES project_members (project_id, user_id),

    CONSTRAINT fixes_review_check CHECK (
        (review_result IS NULL) = (reviewed_at IS NULL)
        AND (review_result IS NULL) = (reviewer_id IS NULL)
        AND (review_result IS NULL OR submitted_at IS NOT NULL)
    ),
    CONSTRAINT fixes_dates_check
        CHECK (submitted_at >= created_at AND reviewed_at >= submitted_at)
);

CREATE UNIQUE INDEX fixes_one_pending_per_ticket
    ON fixes (project_id, ticket_number) WHERE review_result IS NULL;

CREATE TABLE attachments (
    project_id    uuid          NOT NULL,
    ticket_number integer       NOT NULL,
    number        integer       NOT NULL CHECK (number > 0),
    name          varchar(300)  NOT NULL,
    type          varchar(20)   NOT NULL CHECK (type IN ('LOG', 'SCREENSHOT', 'FILE', 'COMMIT_LINK')),
    added_at      timestamptz   NOT NULL DEFAULT now(),
    file_key      varchar(500),
    url           varchar(2000),
    PRIMARY KEY (project_id, ticket_number, number),
    FOREIGN KEY (project_id, ticket_number) REFERENCES tickets (project_id, number) ON DELETE CASCADE,

    CONSTRAINT attachments_content_check CHECK (
        (type = 'COMMIT_LINK' AND url IS NOT NULL AND file_key IS NULL)
        OR (type <> 'COMMIT_LINK' AND file_key IS NOT NULL AND url IS NULL)
    )
);
