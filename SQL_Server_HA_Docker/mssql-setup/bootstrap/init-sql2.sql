CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$(MASTER_KEY_PASSWORD)';
GO

CREATE CERTIFICATE dbm_certificate
    WITH SUBJECT = 'SQL2_dbm_certificate';
GO

BACKUP CERTIFICATE dbm_certificate
    TO FILE = '/certs/dbm_certificate_2.cer'
    WITH PRIVATE KEY (
        FILE = '/certs/dbm_certificate_2.pvk',
        ENCRYPTION BY PASSWORD = '$(CERT_PASSWORD)'
    );
GO

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
