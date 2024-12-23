-- Table: data_source
CREATE TABLE IF NOT EXISTS data_source
(
    data_source_id UUID PRIMARY KEY      DEFAULT gen_random_uuid(),
    name           VARCHAR(255) NOT NULL,
    generation_id  INTEGER      NOT NULL DEFAULT 0,                 -- incremented on each audit/sync
    last_snapshot  TIMESTAMPTZ  NULL,                               -- last completed snapshot
    created_at     TIMESTAMPTZ           DEFAULT CURRENT_TIMESTAMP, -- TBD; tracks when first imported
    UNIQUE (name)
);

-- Table: event
-- Description:  outbox pattern table
CREATE TABLE IF NOT EXISTS data_change_event
(
    data_change_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type    VARCHAR(64) NOT NULL, -- Table name reference
    object_id      UUID        NOT NUll, -- Primary key
    parent_id      UUID        NULL,
    before_state   json        NULL,
    after_state    json        NULL,
    sequence_id    SERIAL,               -- track insertion order rather than rely on timestamp since precision may cause ambiguity
    created_at     TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP
);

-- Table: subscription
CREATE TABLE subscription
(
    subscription_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consumer_subscription_id UUID,
    filter                   TEXT,
    callback                 TEXT    NOT NULL,
    event_cursor             INTEGER NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ      DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_callback UNIQUE (callback)
);

-- Table: node_cluster_type
CREATE TABLE IF NOT EXISTS node_cluster_type
(
    node_cluster_type_id UUID PRIMARY KEY,
    name                 VARCHAR(255) NOT NULL,
    description          TEXT         NOT NULL,
    extensions           json         NULL,
    data_source_id       UUID         NOT NULL,
    generation_id        INTEGER      NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ           DEFAULT CURRENT_TIMESTAMP, -- TBD; tracks when first imported
    FOREIGN KEY (data_source_id) REFERENCES data_source (data_source_id)  -- Manual cascade required for events
);

-- Table: node_cluster
CREATE TABLE IF NOT EXISTS node_cluster
(
    node_cluster_id                  UUID PRIMARY KEY,
    node_cluster_type_id             UUID,
    client_node_cluster_id           UUID,
    name                             VARCHAR(255) NOT NULL,
    description                      TEXT         NOT NULL,
    extensions                       json         NULL,
    cluster_distribution_description VARCHAR(255),
    artifact_resource_id             UUID         NOT NULL,
    cluster_resource_groups          UUID[]       NULL,
    data_source_id                   UUID         NOT NULL,
    generation_id                    INTEGER      NOT NULL DEFAULT 0,
    external_id                      VARCHAR(255) NOT NULL,                           -- FQDN of resource in downstream data source (e.g., id=XXX)
    created_at                       TIMESTAMPTZ           DEFAULT CURRENT_TIMESTAMP, -- TBD; tracks when first imported
    FOREIGN KEY (node_cluster_type_id) REFERENCES node_cluster_type (node_cluster_type_id),-- Manual cascade required for events
    FOREIGN KEY (data_source_id) REFERENCES data_source (data_source_id)              -- Manual cascade required for events
);

-- Table: cluster_resource_type
CREATE TABLE IF NOT EXISTS cluster_resource_type
(
    cluster_resource_type_id UUID PRIMARY KEY,
    name                     VARCHAR(255) NOT NULL,
    description              TEXT         NOT NULL,
    extensions               json         NULL,
    data_source_id           UUID         NOT NULL,
    generation_id            INTEGER      NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ           DEFAULT CURRENT_TIMESTAMP, -- TBD; tracks when first imported
    FOREIGN KEY (data_source_id) REFERENCES data_source (data_source_id)      -- Manual cascade required for events
);

-- Table: cluster_resource
CREATE TABLE IF NOT EXISTS cluster_resource
(
    cluster_resource_id      UUID PRIMARY KEY,
    cluster_resource_type_id UUID,
    name                     VARCHAR(255) NOT NULL,
    node_cluster_id          UUID         NOT NULL,
    description              TEXT         NOT NULL,
    extensions               json         NULL,
    artifact_resource_ids    UUID[]       NULL,
    resource_id              UUID         NOT NULL,
    data_source_id           UUID         NOT NULL,
    generation_id            INTEGER      NOT NULL DEFAULT 0,
    external_id              VARCHAR(255) NOT NULL,                           -- FQDN of resource in downstream data source (e.g., id=XXX)
    created_at               TIMESTAMPTZ           DEFAULT CURRENT_TIMESTAMP, -- TBD; tracks when first imported
    FOREIGN KEY (node_cluster_id) REFERENCES node_cluster (node_cluster_id),-- Manual cascade required for events
    FOREIGN KEY (cluster_resource_type_id) REFERENCES cluster_resource_type (cluster_resource_type_id),-- Manual cascade required for events
    FOREIGN KEY (data_source_id) REFERENCES data_source (data_source_id)      -- Manual cascade required for events
);

-- Table: cached_alarm_dictionary
CREATE TABLE cached_alarm_dictionary
(
    alarm_dictionary_id             UUID PRIMARY KEY,
    resource_type_id                UUID         NOT NULL,
    alarm_dictionary_version        VARCHAR(50)  NOT NULL,
    alarm_dictionary_schema_version VARCHAR(50)  NOT NULL,
    entity_type                     VARCHAR(255) NOT NULL,
    vendor                          VARCHAR(255) NOT NULL,
    management_interface_id         VARCHAR(50)[] DEFAULT ARRAY ['O2IMS']::VARCHAR[],
    pk_notification_field           TEXT[]        DEFAULT ARRAY ['alarm_dictionary_id']::TEXT[],
    created_at                      TIMESTAMPTZ   DEFAULT CURRENT_TIMESTAMP
);

-- Table: cached_alarm_definition
CREATE TABLE cached_alarm_definition
(
    alarm_definition_id     UUID PRIMARY KEY,
    alarm_dictionary_id     UUID         NOT NULL,
    alarm_name              VARCHAR(255) NOT NULL,
    alarm_last_change       VARCHAR(50)  NOT NULL,
    alarm_description       TEXT         NOT NULL,
    proposed_repair_actions TEXT         NOT NULL,
    alarm_additional_fields JSONB,
    alarm_change_type       INTEGER      NOT NULL,
    clearing_type           INTEGER      NOT NULL,
    management_interface_id VARCHAR(50)[] DEFAULT ARRAY ['O2IMS']::VARCHAR[],
    pk_notification_field   TEXT[]        DEFAULT ARRAY ['alarm_definition_id']::TEXT[],
    created_at              TIMESTAMPTZ   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (alarm_dictionary_id) REFERENCES cached_alarm_dictionary (alarm_dictionary_id),
    CONSTRAINT unique_alarm_name_last_change UNIQUE (alarm_name, alarm_last_change)
);