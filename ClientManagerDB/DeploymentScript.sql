USE master;
GO

IF NOT EXISTS (SELECT name 
               FROM sys.databases 
               WHERE name = N'ClientManagerDb')
BEGIN
    CREATE DATABASE ClientManagerDb;
END
GO


USE ClientManagerDb;
GO

-- ============ TABLES ============
-- Clients table
CREATE TABLE dbo.Clients
(
    ClientId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [Name] NVARCHAR(200) NOT NULL,
    ClientCode CHAR(6) NULL UNIQUE, -- generated after first save
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_Clients_Name ON dbo.Clients([Name] ASC);
GO

-- Contacts table
CREATE TABLE dbo.Contacts
(
    ContactId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Contacts PRIMARY KEY,
    [Name] NVARCHAR(100) NOT NULL,
    Surname NVARCHAR(100) NOT NULL,
    FullName AS (Surname + N' ' + [Name]) PERSISTED,
    Email NVARCHAR(255) NOT NULL CONSTRAINT UQ_Contacts_Email UNIQUE,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Contacts_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_Contacts_UpdatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_Contacts_FullName
ON dbo.Contacts (FullName);
GO

CREATE INDEX IX_Contacts_Surname
ON dbo.Contacts (Surname);
GO

-- ClientContacts linking table (many-to-many)
CREATE TABLE dbo.ClientContacts
(
    ClientId INT NOT NULL,
    ContactId INT NOT NULL,
    LinkedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ClientContacts PRIMARY KEY (ClientId, ContactId),
    CONSTRAINT FK_ClientContacts_Client FOREIGN KEY (ClientId) REFERENCES dbo.Clients(ClientId) ON DELETE CASCADE,
    CONSTRAINT FK_ClientContacts_Contact FOREIGN KEY (ContactId) REFERENCES dbo.Contacts(ContactId) ON DELETE CASCADE
);
GO

CREATE INDEX IX_ClientContacts_ContactId ON dbo.ClientContacts(ContactId);
CREATE INDEX IX_ClientContacts_ClientId ON dbo.ClientContacts(ClientId);
GO

-- ============ FUNCTION: fn_GetAlphaPart ============

CREATE OR ALTER FUNCTION [dbo].[fn_GetAlphaPart](@Name NVARCHAR(200))
RETURNS CHAR(3)
AS
BEGIN
    DECLARE @clean NVARCHAR(200) = UPPER(LTRIM(RTRIM(ISNULL(@Name,''))));
    DECLARE @result CHAR(3) = '   ';
    DECLARE @i INT = 1;

    -- Check if string has at least 3 words
    IF (LEN(@clean) - LEN(REPLACE(@clean,' ',''))) >= 2
    BEGIN
        DECLARE @word TABLE (id INT IDENTITY(1,1), w NVARCHAR(100));

        INSERT INTO @word
        SELECT value FROM STRING_SPLIT(@clean,' ');

        SELECT TOP 3
            @result = STUFF(@result,id,1,LEFT(w,1))
        FROM @word;

        RETURN @result;
    END

    -- Otherwise use original logic
    DECLARE @pos INT = 1;
    DECLARE @len INT = LEN(@clean);
    DECLARE @ch NCHAR(1);

    WHILE @pos <= @len AND @i <= 3
    BEGIN
        SET @ch = SUBSTRING(@clean,@pos,1);

        IF @ch BETWEEN 'A' AND 'Z'
        BEGIN
            SET @result = STUFF(@result,@i,1,@ch);
            SET @i = @i + 1;
        END

        SET @pos = @pos + 1;
    END

    -- Pad remaining with A
    WHILE @i <= 3
    BEGIN
        SET @result = STUFF(@result,@i,1,'A');
        SET @i = @i + 1;
    END

    RETURN @result;
END;
GO
-- ============ VIEWS ============
IF OBJECT_ID('dbo.vw_ClientList', 'V') IS NOT NULL DROP VIEW dbo.vw_ClientList;
GO

CREATE VIEW dbo.vw_ClientList
AS
SELECT
    c.ClientId,
    c.Name,
    c.ClientCode,
    ISNULL(cc.NumContacts, 0) AS NumContacts
FROM dbo.Clients c
LEFT JOIN (
    SELECT ClientId, COUNT(*) AS NumContacts
    FROM dbo.ClientContacts
    GROUP BY ClientId
) cc ON c.ClientId = cc.ClientId;
GO

IF OBJECT_ID('dbo.vw_ContactList', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ContactList;
GO

CREATE VIEW dbo.vw_ContactList
AS
SELECT
    ct.ContactId,
    ct.[Name],
    ct.Surname,
    ct.FullName,
    ct.Email,
    ISNULL(cl.NumClients, 0) AS NumClients
FROM dbo.Contacts ct
LEFT JOIN (
    SELECT ContactId, COUNT(*) AS NumClients
    FROM dbo.ClientContacts
    GROUP BY ContactId
) cl ON ct.ContactId = cl.ContactId;
GO

-- ============ Stored Procedures ============
-- ============ SP: sp_GenerateUniqueClientCode ============

CREATE PROCEDURE dbo.sp_GenerateUniqueClientCode
    @Name NVARCHAR(200),
    @OutClientCode CHAR(6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @alpha CHAR(3) = dbo.fn_GetAlphaPart(@Name);
    DECLARE @num INT = 1;
    DECLARE @candidate CHAR(6);
    DECLARE @exists INT = 1;

    WHILE @exists = 1
    BEGIN
        SET @candidate = @alpha + RIGHT('000' + CAST(@num AS VARCHAR(10)), 3);
        IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientCode = @candidate)
        BEGIN
            SET @exists = 0;
            SET @OutClientCode = @candidate;
        END
        ELSE
        BEGIN
            SET @num = @num + 1;
            IF @num > 999999
            BEGIN
                RAISERROR('Unable to generate unique client code - exceeded max attempts', 16, 1);
                RETURN;
            END
        END
    END
END;
GO

-- ============ SP: sp_CreateClient ============

CREATE PROCEDURE dbo.sp_CreateClient
    @Name NVARCHAR(200),
    @OutClientId INT OUTPUT,
    @OutClientCode CHAR(6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.Clients (Name)
        VALUES (@Name);

        SET @OutClientId = SCOPE_IDENTITY();

        -- Generate unique code
        EXEC dbo.sp_GenerateUniqueClientCode @Name = @Name, @OutClientCode = @OutClientCode OUTPUT;

        -- Update client row with code
        UPDATE dbo.Clients
        SET ClientCode = @OutClientCode, UpdatedAt = SYSUTCDATETIME()
        WHERE ClientId = @OutClientId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_CreateClient failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
GO

-- ============ SP: sp_UpdateClient ============
IF OBJECT_ID('dbo.sp_UpdateClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateClient;
GO

CREATE PROCEDURE dbo.sp_UpdateClient
    @ClientId INT,
    @NewName NVARCHAR(200),
    @RegenerateCode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.Clients
        SET Name = @NewName, UpdatedAt = SYSUTCDATETIME()
        WHERE ClientId = @ClientId;

        IF @RegenerateCode = 1
        BEGIN
            DECLARE @NewCode CHAR(6);
            EXEC dbo.sp_GenerateUniqueClientCode @Name = @NewName, @OutClientCode = @NewCode OUTPUT;

            UPDATE dbo.Clients
            SET ClientCode = @NewCode, UpdatedAt = SYSUTCDATETIME()
            WHERE ClientId = @ClientId;
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_UpdateClient failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
GO

-- ============ SP: sp_CreateContact ============
CREATE PROCEDURE dbo.sp_CreateContact
    @Name NVARCHAR(100),
    @Surname NVARCHAR(100),
    @Email NVARCHAR(255),
    @OutContactId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        -- Ensure email unique
        IF EXISTS (SELECT 1 FROM dbo.Contacts WHERE Email = @Email)
        BEGIN
            RAISERROR('Email already exists', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END

        INSERT INTO dbo.Contacts (Name, Surname, Email)
        VALUES (@Name, @Surname, @Email);

        SET @OutContactId = SCOPE_IDENTITY();

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_CreateContact failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
GO

-- ============ SP: sp_LinkContactToClient ============
CREATE PROCEDURE dbo.sp_LinkContactToClient
    @ClientId INT,
    @ContactId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Ensure both exist
        IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientId = @ClientId)
        BEGIN
            RAISERROR('Client not found', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Contacts WHERE ContactId = @ContactId)
        BEGIN
            RAISERROR('Contact not found', 16, 1);
            RETURN;
        END

        -- Insert if not exists
        IF NOT EXISTS (SELECT 1 FROM dbo.ClientContacts WHERE ClientId = @ClientId AND ContactId = @ContactId)
        BEGIN
            INSERT INTO dbo.ClientContacts (ClientId, ContactId) VALUES (@ClientId, @ContactId);
        END
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_LinkContactToClient failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
GO

-- ============ SP: sp_UnlinkContactFromClient ============
CREATE PROCEDURE dbo.sp_UnlinkContactFromClient
    @ClientId INT,
    @ContactId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DELETE FROM dbo.ClientContacts WHERE ClientId = @ClientId AND ContactId = @ContactId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_UnlinkContactFromClient failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
GO

USE [ClientManagerDB];
GO

-- =========================
-- Get all clients (optionally paged)
-- Returns: ClientId, Name, ClientCode, NumContacts
-- Params:
--   @PageNumber INT (1-based, optional)
--   @PageSize INT (optional). If NULL or 0, returns all rows.
--   @OrderBy NVARCHAR(100) - allowed values: 'Name','ClientCode','NumContacts'
--   @OrderDir NVARCHAR(4) - 'ASC' or 'DESC'
-- =========================
IF OBJECT_ID('dbo.sp_GetClients', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetClients;
GO

CREATE PROCEDURE dbo.sp_GetClients
    @PageNumber INT = 1,
    @PageSize INT = 0,
    @OrderBy NVARCHAR(100) = N'Name',
    @OrderDir NVARCHAR(4) = N'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate order direction
    IF UPPER(@OrderDir) NOT IN ('ASC','DESC') SET @OrderDir = 'ASC';

    DECLARE @sql NVARCHAR(MAX) = N'
    SELECT ClientId, Name, ClientCode, NumContacts
    FROM dbo.vw_ClientList
    ORDER BY ' + QUOTENAME(@OrderBy) + ' ' + @OrderDir;

    IF @PageSize IS NULL OR @PageSize <= 0
    BEGIN
        EXEC sp_executesql @sql;
        RETURN;
    END

    -- Compute offsets for paging (SQL Server 2012+)
    DECLARE @offset INT = (@PageNumber - 1) * @PageSize;
    SET @sql = @sql + ' OFFSET ' + CAST(@offset AS NVARCHAR(20)) + ' ROWS FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(20)) + ' ROWS ONLY;';
    EXEC sp_executesql @sql;
END;
GO

-- =========================
-- Get all contacts (optionally paged)
-- Returns: ContactId, Name, Surname, Email, NumClients
-- Params: same as sp_GetClients but default OrderBy = 'Surname'
-- =========================
IF OBJECT_ID('dbo.sp_GetContacts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetContacts;
GO

CREATE PROCEDURE dbo.sp_GetContacts
    @PageNumber INT = 1,
    @PageSize INT = 0,
    @OrderBy NVARCHAR(100) = N'FullName',
    @OrderDir NVARCHAR(4) = N'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    IF UPPER(@OrderDir) NOT IN ('ASC','DESC') SET @OrderDir = 'ASC';

    DECLARE @sql NVARCHAR(MAX) = N'
    SELECT ContactId, Name, Surname, FullName, Email, NumClients
    FROM dbo.vw_ContactList
    ORDER BY ' + QUOTENAME(@OrderBy) + ' ' + @OrderDir;

    IF @PageSize IS NULL OR @PageSize <= 0
    BEGIN
        EXEC sp_executesql @sql;
        RETURN;
    END

    DECLARE @offset INT = (@PageNumber - 1) * @PageSize;
    SET @sql = @sql + ' OFFSET ' + CAST(@offset AS NVARCHAR(20)) + ' ROWS FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(20)) + ' ROWS ONLY;';
    EXEC sp_executesql @sql;
END;
GO

-- =========================
-- Get contacts linked to a client
-- Returns: ContactId, FullName (Surname + ' ' + Name), Email
-- Params:
--   @ClientId INT (required)
-- =========================
IF OBJECT_ID('dbo.sp_GetContactsByClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetContactsByClient;
GO

CREATE PROCEDURE dbo.sp_GetContactsByClient
    @ClientId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Clients WHERE ClientId = @ClientId)
    BEGIN
        RAISERROR('Client not found', 16, 1);
        RETURN;
    END

    SELECT
        c.ContactId,
        c.Surname + N' ' + c.Name AS FullName,
        c.Email
    FROM dbo.ClientContacts cc
    INNER JOIN dbo.Contacts c ON cc.ContactId = c.ContactId
    WHERE cc.ClientId = @ClientId
    ORDER BY c.Surname ASC, c.Name ASC;
END;
GO

-- =========================
-- Get clients linked to a contact
-- Returns: ClientId, Name, ClientCode
-- Params:
--   @ContactId INT (required)
-- =========================
IF OBJECT_ID('dbo.sp_GetClientsByContact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetClientsByContact;
GO

CREATE PROCEDURE dbo.sp_GetClientsByContact
    @ContactId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Contacts WHERE ContactId = @ContactId)
    BEGIN
        RAISERROR('Contact not found', 16, 1);
        RETURN;
    END

    SELECT
        cl.ClientId,
        cl.[Name],
        cl.ClientCode
    FROM dbo.ClientContacts cc
    INNER JOIN dbo.Clients cl ON cc.ClientId = cl.ClientId
    WHERE cc.ContactId = @ContactId
    ORDER BY cl.Name ASC;
END;
GO

-- =========================
-- Get single client by id (including linked contact count)
-- Returns: ClientId, Name, ClientCode, NumContacts
-- =========================
IF OBJECT_ID('dbo.sp_GetClientById', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetClientById;
GO

CREATE PROCEDURE dbo.sp_GetClientById
    @ClientId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ClientId, Name, ClientCode, NumContacts
    FROM dbo.vw_ClientList
    WHERE ClientId = @ClientId;
END;
GO

-- =========================
-- Get single contact by id (including linked client count)
-- Returns: ContactId, Name, Surname, Email, NumClients
-- =========================
IF OBJECT_ID('dbo.sp_GetContactById', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetContactById;
GO

CREATE PROCEDURE dbo.sp_GetContactById
    @ContactId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ContactId, [Name], Surname, Email, NumClients
    FROM dbo.vw_ContactList
    WHERE ContactId = @ContactId;
END;
GO
