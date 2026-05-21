-- Creates the HADR database mirroring endpoint.
-- Run this after certificates are created on each node.

CREATE ENDPOINT [Hadr_endpoint]
    STATE = STARTED
    AS TCP (
        LISTENER_PORT = 5022,
        LISTENER_IP = ALL
    )
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );
GO
