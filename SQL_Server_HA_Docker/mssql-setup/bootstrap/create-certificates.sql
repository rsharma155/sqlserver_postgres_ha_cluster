-- Creates the database mirroring certificate and backs it up to shared volume.
-- Run this on each node individually. The NODE_ID must be set appropriately.

CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$(MASTER_KEY_PASSWORD)';
GO

CREATE CERTIFICATE dbm_certificate
    WITH SUBJECT = 'SQL$(NODE_ID)_dbm_certificate';
GO

BACKUP CERTIFICATE dbm_certificate
    TO FILE = '/certs/dbm_certificate_$(NODE_ID).cer'
    WITH PRIVATE KEY (
        FILE = '/certs/dbm_certificate_$(NODE_ID).pvk',
        ENCRYPTION BY PASSWORD = '$(CERT_PASSWORD)'
    );
GO
