USE [ClientManagerDb];
GO

-- Ensure stored procedures exist before seeding
IF OBJECT_ID('dbo.sp_CreateClient', 'P') IS NULL OR OBJECT_ID('dbo.sp_CreateContact', 'P') IS NULL
BEGIN
    RAISERROR('Required stored procedures not found. Ensure creation scripts have been run.', 16, 1);
    RETURN;
END
GO

PRINT 'Seeding sample data...';

-- Clean up existing sample data (optional, safe to run)
DELETE FROM dbo.ClientContacts;
DELETE FROM dbo.Contacts;
DELETE FROM dbo.Clients;
GO

-- Create Clients via stored procedure to generate ClientCode
DECLARE @ClientId INT;
DECLARE @ClientCode CHAR(6);

EXEC dbo.sp_CreateClient @Name = N'First National Bank', @OutClientId = @ClientId OUTPUT, @OutClientCode = @ClientCode OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId AS NVARCHAR(20)) + ' - ' + @ClientCode;

EXEC dbo.sp_CreateClient @Name = N'Protea', @OutClientId = @ClientId OUTPUT, @OutClientCode = @ClientCode OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId AS NVARCHAR(20)) + ' - ' + @ClientCode;

EXEC dbo.sp_CreateClient @Name = N'IT', @OutClientId = @ClientId OUTPUT, @OutClientCode = @ClientCode OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId AS NVARCHAR(20)) + ' - ' + @ClientCode;

EXEC dbo.sp_CreateClient @Name = N'App Dynamics', @OutClientId = @ClientId OUTPUT, @OutClientCode = @ClientCode OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId AS NVARCHAR(20)) + ' - ' + @ClientCode;

EXEC dbo.sp_CreateClient @Name = N'Alpha & Co', @OutClientId = @ClientId OUTPUT, @OutClientCode = @ClientCode OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId AS NVARCHAR(20)) + ' - ' + @ClientCode;

-- Create Contacts
DECLARE @ContactId INT;

EXEC dbo.sp_CreateContact @Name = N'John', @Surname = N'Doe', @Email = N'john.doe@example.com', @OutContactId = @ContactId OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId AS NVARCHAR(20)) + ' - john.doe@example.com';

EXEC dbo.sp_CreateContact @Name = N'Jane', @Surname = N'Smith', @Email = N'jane.smith@example.com', @OutContactId = @ContactId OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId AS NVARCHAR(20)) + ' - jane.smith@example.com';

EXEC dbo.sp_CreateContact @Name = N'Mike', @Surname = N'Ocean', @Email = N'mike.ocean@example.com', @OutContactId = @ContactId OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId AS NVARCHAR(20)) + ' - mike.ocean@example.com';

EXEC dbo.sp_CreateContact @Name = N'Alice', @Surname = N'Brown', @Email = N'alice.brown@example.com', @OutContactId = @ContactId OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId AS NVARCHAR(20)) + ' - alice.brown@example.com';

EXEC dbo.sp_CreateContact @Name = N'Bob', @Surname = N'Lee', @Email = N'bob.lee@example.com', @OutContactId = @ContactId OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId AS NVARCHAR(20)) + ' - bob.lee@example.com';

-- Link contacts to clients
-- Helper: get client ids by name
DECLARE @FNBId INT, @PROId INT, @ITId INT, @APPId INT, @ALPId INT;

SELECT @FNBId = ClientId FROM dbo.Clients WHERE Name = N'First National Bank';
SELECT @PROId = ClientId FROM dbo.Clients WHERE Name = N'Protea';
SELECT @ITId = ClientId FROM dbo.Clients WHERE Name = N'IT';
SELECT @APPId = ClientId FROM dbo.Clients WHERE Name = N'App Dynamics';
SELECT @ALPId = ClientId FROM dbo.Clients WHERE Name = N'Alpha & Co';

SELECT @ContactId = ContactId FROM dbo.Contacts WHERE Email = N'john.doe@example.com';
EXEC dbo.sp_LinkContactToClient @ClientId = @FNBId, @ContactId = @ContactId;
EXEC dbo.sp_LinkContactToClient @ClientId = @APPId, @ContactId = @ContactId;

SELECT @ContactId = ContactId FROM dbo.Contacts WHERE Email = N'jane.smith@example.com';
EXEC dbo.sp_LinkContactToClient @ClientId = @PROId, @ContactId = @ContactId;

SELECT @ContactId = ContactId FROM dbo.Contacts WHERE Email = N'mike.ocean@example.com';
EXEC dbo.sp_LinkContactToClient @ClientId = @PROId, @ContactId = @ContactId;
EXEC dbo.sp_LinkContactToClient @ClientId = @FNBId, @ContactId = @ContactId;

SELECT @ContactId = ContactId FROM dbo.Contacts WHERE Email = N'alice.brown@example.com';
EXEC dbo.sp_LinkContactToClient @ClientId = @ALPId, @ContactId = @ContactId;

SELECT @ContactId = ContactId FROM dbo.Contacts WHERE Email = N'bob.lee@example.com';
EXEC dbo.sp_LinkContactToClient @ClientId = @ITId, @ContactId = @ContactId;
EXEC dbo.sp_LinkContactToClient @ClientId = @ALPId, @ContactId = @ContactId;

PRINT 'Linking complete.';

-- Display seeded data summary
PRINT 'Clients:';
SELECT ClientId, Name, ClientCode, CreatedAt FROM dbo.Clients ORDER BY Name ASC;

PRINT 'Contacts:';
SELECT ContactId, Surname, Name, Email, CreatedAt FROM dbo.Contacts ORDER BY Surname ASC, Name ASC;

PRINT 'Client - Contact Links:';
SELECT cc.ClientId, c.Name AS ClientName, cc.ContactId, ct.Surname + ' ' + ct.Name AS ContactFullName, cc.LinkedAt
FROM dbo.ClientContacts cc
JOIN dbo.Clients c ON cc.ClientId = c.ClientId
JOIN dbo.Contacts ct ON cc.ContactId = ct.ContactId
ORDER BY c.Name ASC, ct.Surname ASC;
GO