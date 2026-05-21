-- ============================================================
-- Import Primary (SQL1) certificate
-- ============================================================
CREATE CERTIFICATE dbm_certificate_1
    FROM FILE = '/certs/dbm_certificate_1.cer';
GO

CREATE LOGIN sql1_login
    FROM CERTIFICATE dbm_certificate_1;
GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [sql1_login];
GO

-- ============================================================
-- Join Availability Group (with retry)
-- ============================================================
DECLARE @retry INT = 0;
DECLARE @maxRetry INT = 30;

WHILE @retry < @maxRetry
BEGIN
    BEGIN TRY
        ALTER AVAILABILITY GROUP [AG_HA_LAB] JOIN;
        BREAK;
    END TRY
    BEGIN CATCH
        SET @retry = @retry + 1;
        IF @retry >= @maxRetry
        BEGIN
            DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR('Failed to join AG after %d retries: %s', 16, 1, @maxRetry, @errMsg);
        END
        WAITFOR DELAY '00:00:05';
    END CATCH
END
GO

ALTER AVAILABILITY GROUP [AG_HA_LAB]
    GRANT CREATE ANY DATABASE;
GO
