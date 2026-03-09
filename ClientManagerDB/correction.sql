USE [ClientManagerDb]
GO
/****** Object:  StoredProcedure [dbo].[sp_GenerateUniqueClientCode]    Script Date: 2026/03/09 13:07:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_GenerateUniqueClientCode]
    @Name NVARCHAR(200),
    @OutClientCode CHAR(6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @alpha CHAR(3) = dbo.fn_GetAlphaPart(@Name);
    DECLARE @nextNum INT;

    SELECT @nextNum = ISNULL(MAX(CAST(RIGHT(ClientCode,3) AS INT)),0) + 1
    FROM dbo.Clients
    WHERE LEFT(ClientCode,3) = @alpha;

    IF @nextNum > 999
    BEGIN
        ;THROW 50001, 'Unable to generate unique client code - exceeded max limit', 1;
    END

    SET @OutClientCode = @alpha + RIGHT('000' + CAST(@nextNum AS VARCHAR(3)),3);
END