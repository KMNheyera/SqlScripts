USE [ ];
GO


-- =========================
-- Create Clients
-- =========================
DECLARE @ClientId1 INT, @ClientCode1 CHAR(6);
DECLARE @ClientId2 INT, @ClientCode2 CHAR(6);
DECLARE @ClientId3 INT, @ClientCode3 CHAR(6);

PRINT @ClientId3;


EXEC dbo.sp_CreateClient
    @Name = N'First National Bank',
    @OutClientId = @ClientId1 OUTPUT,
    @OutClientCode = @ClientCode1 OUTPUT;
PRINT 'Created Client: ' + CAST(@ClientId1 AS NVARCHAR(20)) + ' - ' + ISNULL(@ClientCode1,'');

-- =========================
-- Update Clients
-- =========================
-- Change name without regenerating code
IF @ClientId1 IS NOT NULL
BEGIN
    EXEC dbo.sp_UpdateClient
        @ClientId = @ClientId1,
        @NewName = N'First National Bank Ltd',
        @RegenerateCode = 0;
    PRINT 'Updated client name for ClientId=' + CAST(@ClientId1 AS NVARCHAR(20)) + ' (code kept)';
END

-- Change name and regenerate code
IF @ClientId2 IS NOT NULL
BEGIN
    EXEC dbo.sp_UpdateClient
        @ClientId = @ClientId2,
        @NewName = N'Protea Solutions',
        @RegenerateCode = 1;
    PRINT 'Updated client name and regenerated code for ClientId=' + CAST(@ClientId2 AS NVARCHAR(20));
END

-- =========================
-- Create Contacts
-- =========================
DECLARE @ContactId1 INT, @ContactId2 INT, @ContactId3 INT;

EXEC dbo.sp_CreateContact
    @Name = N'John',
    @Surname = N'Doe',
    @Email = N'john.doe@example.com',
    @OutContactId = @ContactId1 OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId1 AS NVARCHAR(20)) + ' - john.doe@example.com';

EXEC dbo.sp_CreateContact
    @Name = N'Jane',
    @Surname = N'Smith',
    @Email = N'jane.smith@example.com',
    @OutContactId = @ContactId2 OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId2 AS NVARCHAR(20)) + ' - jane.smith@example.com';

EXEC dbo.sp_CreateContact
    @Name = N'Alice',
    @Surname = N'Brown',
    @Email = N'alice.brown@example.com',
    @OutContactId = @ContactId3 OUTPUT;
PRINT 'Created Contact: ' + CAST(@ContactId3 AS NVARCHAR(20)) + ' - alice.brown@example.com';

-- =========================
-- Link Contacts to Clients
-- =========================
-- Link John Doe to First National Bank and IT
IF @ClientId1 IS NOT NULL AND @ContactId1 IS NOT NULL
BEGIN
    EXEC dbo.sp_LinkContactToClient @ClientId = @ClientId1, @ContactId = @ContactId1;
    PRINT 'Linked ContactId=' + CAST(@ContactId1 AS NVARCHAR(20)) + ' to ClientId=' + CAST(@ClientId1 AS NVARCHAR(20));
END

IF @ClientId3 IS NOT NULL AND @ContactId1 IS NOT NULL
BEGIN
    EXEC dbo.sp_LinkContactToClient @ClientId = @ClientId3, @ContactId = @ContactId1;
    PRINT 'Linked ContactId=' + CAST(@ContactId1 AS NVARCHAR(20)) + ' to ClientId=' + CAST(@ClientId3 AS NVARCHAR(20));
END

-- Link Jane Smith to Protea (which may have had code regenerated)
IF @ClientId2 IS NOT NULL AND @ContactId2 IS NOT NULL
BEGIN
    EXEC dbo.sp_LinkContactToClient @ClientId = @ClientId2, @ContactId = @ContactId2;
    PRINT 'Linked ContactId=' + CAST(@ContactId2 AS NVARCHAR(20)) + ' to ClientId=' + CAST(@ClientId2 AS NVARCHAR(20));
END

-- Link Alice to Protea and First National Bank
IF @ClientId2 IS NOT NULL AND @ContactId3 IS NOT NULL
BEGIN
    EXEC dbo.sp_LinkContactToClient @ClientId = @ClientId2, @ContactId = @ContactId3;
    EXEC dbo.sp_LinkContactToClient @ClientId = @ClientId1, @ContactId = @ContactId3;
    PRINT 'Linked ContactId=' + CAST(@ContactId3 AS NVARCHAR(20)) + ' to ClientId=' + CAST(@ClientId2 AS NVARCHAR(20)) + ' and ClientId=' + CAST(@ClientId1 AS NVARCHAR(20));
END

-- =========================
-- Verify Links (selects)
-- =========================
PRINT 'Contacts linked to ClientId1:';
EXEC dbo.sp_GetContactsByClient @ClientId = @ClientId1;

PRINT 'Clients linked to ContactId1:';
EXEC dbo.sp_GetClientsByContact @ContactId = @ContactId1;

-- =========================
-- Unlink Contacts from Clients
-- =========================
-- Unlink Alice from First National Bank
IF @ClientId1 IS NOT NULL AND @ContactId3 IS NOT NULL
BEGIN
    EXEC dbo.sp_UnlinkContactFromClient @ClientId = @ClientId1, @ContactId = @ContactId3;
    PRINT 'Unlinked ContactId=' + CAST(@ContactId3 AS NVARCHAR(20)) + ' from ClientId=' + CAST(@ClientId1 AS NVARCHAR(20));
END

-- Unlink John from IT
IF @ClientId3 IS NOT NULL AND @ContactId1 IS NOT NULL
BEGIN
    EXEC dbo.sp_UnlinkContactFromClient @ClientId = @ClientId3, @ContactId = @ContactId1;
    PRINT 'Unlinked ContactId=' + CAST(@ContactId1 AS NVARCHAR(20)) + ' from ClientId=' + CAST(@ClientId3 AS NVARCHAR(20));
END

-- Verify unlink results
PRINT 'Contacts linked to ClientId1 after unlink:';
EXEC dbo.sp_GetContactsByClient @ClientId = @ClientId1;

PRINT 'Clients linked to ContactId1 after unlink:';
EXEC dbo.sp_GetClientsByContact @ContactId = @ContactId1;

-- =========================
-- Error demonstration: create contact with duplicate email (should raise error)
-- =========================
BEGIN TRY
    EXEC dbo.sp_CreateContact
        @Name = N'Duplicate',
        @Surname = N'Example',
        @Email = N'john.doe@example.com', -- duplicate
        @OutContactId = @ContactId1 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Expected error creating duplicate contact: ' + ERROR_MESSAGE();
END CATCH

PRINT '--- END: Execute examples ---';
GO