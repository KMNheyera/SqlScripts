USE [ClientManagerDB];
GO
EXEC dbo.sp_GetClients;

EXEC dbo.sp_GetClients @PageNumber = 1, @PageSize = 5;

EXEC dbo.sp_GetClients @PageNumber = 1, @PageSize = 0, @OrderBy = N'NumContacts', @OrderDir = N'DESC';

EXEC dbo.sp_GetContacts;

EXEC dbo.sp_GetContacts @PageNumber = 2, @PageSize = 3;

EXEC dbo.sp_GetContacts @PageNumber = 1, @PageSize = 0, @OrderBy = N'NumClients', @OrderDir = N'DESC';

DECLARE @SampleClientId INT = (SELECT TOP 1 ClientId FROM dbo.Clients ORDER BY Name ASC);
DECLARE @SampleContactId INT = (SELECT TOP 1 ContactId FROM dbo.Contacts ORDER BY Surname ASC);

PRINT 'Using SampleClientId = ' + CAST(ISNULL(@SampleClientId,0) AS NVARCHAR(10));
PRINT 'Using SampleContactId = ' + CAST(ISNULL(@SampleContactId,0) AS NVARCHAR(10));

EXEC dbo.sp_GetContactsByClient @ClientId = @SampleClientId;

EXEC dbo.sp_GetClientsByContact @ContactId = @SampleContactId;

EXEC dbo.sp_GetClientById @ClientId = @SampleClientId;

EXEC dbo.sp_GetContactById @ContactId = @SampleContactId;

EXEC dbo.sp_GetContactsByClient @ClientId = 1;

EXEC dbo.sp_GetClientsByContact @ContactId = 1;

EXEC dbo.sp_GetClientById @ClientId = 2;

EXEC dbo.sp_GetContactById @ContactId = 3;