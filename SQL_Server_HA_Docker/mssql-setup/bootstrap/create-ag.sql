-- Import SQL2 and SQL3 certificates on SQL1 (Primary)
-- ============================================================

CREATE CERTIFICATE dbm_certificate_2
    FROM FILE = '/certs/dbm_certificate_2.cer';
GO

CREATE LOGIN sql2_login
    FROM CERTIFICATE dbm_certificate_2;
GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [sql2_login];
GO

CREATE CERTIFICATE dbm_certificate_3
    FROM FILE = '/certs/dbm_certificate_3.cer';
GO

CREATE LOGIN sql3_login
    FROM CERTIFICATE dbm_certificate_3;
GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [sql3_login];
GO

-- ============================================================
-- Create Availability Group
-- ============================================================
CREATE AVAILABILITY GROUP [AG_HA_LAB]
    WITH (CLUSTER_TYPE = NONE)
    FOR DATABASE [HADemoDB]
    REPLICA ON
    N'sql1' WITH (
        ENDPOINT_URL = N'TCP://172.25.0.11:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    ),
    N'sql2' WITH (
        ENDPOINT_URL = N'TCP://172.25.0.12:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    ),
    N'sql3' WITH (
        ENDPOINT_URL = N'TCP://172.25.0.13:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    );
GO

ALTER AVAILABILITY GROUP [AG_HA_LAB]
    GRANT CREATE ANY DATABASE;
GO
