USE master;
GO

IF DB_ID('ClientManagerDB') IS NULL
BEGIN
    CREATE DATABASE ClientManagerDB;
END;
GO

USE ClientManagerDB;
GO

-- Drop views
IF OBJECT_ID('dbo.vw_ContactList', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ContactList;

IF OBJECT_ID('dbo.vw_ClientList', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ClientList;

-- Drop stored procedures
IF OBJECT_ID('dbo.sp_UnlinkContactFromClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UnlinkContactFromClient;

IF OBJECT_ID('dbo.sp_LinkContactToClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_LinkContactToClient;

IF OBJECT_ID('dbo.sp_CreateContact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateContact;

IF OBJECT_ID('dbo.sp_UpdateClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateClient;

IF OBJECT_ID('dbo.sp_CreateClient', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateClient;

IF OBJECT_ID('dbo.sp_GenerateUniqueClientCode', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GenerateUniqueClientCode;

-- Drop function
IF OBJECT_ID('dbo.fn_GetAlphaPart', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetAlphaPart;

-- Drop tables (order matters due to FKs)
IF OBJECT_ID('dbo.ClientContacts', 'U') IS NOT NULL
    DROP TABLE dbo.ClientContacts;

IF OBJECT_ID('dbo.Contacts', 'U') IS NOT NULL
    DROP TABLE dbo.Contacts;

IF OBJECT_ID('dbo.Clients', 'U') IS NOT NULL
    DROP TABLE dbo.Clients;

PRINT 'All objects inside ClientManagerDB dropped.';
GO

-- Create database if not exists and use it
IF DB_ID(N'ClientManagerDB') IS NULL
BEGIN
    CREATE DATABASE [ClientManagerDB];
    PRINT 'Database ClientManagerDB created.';
END
ELSE
BEGIN
    PRINT 'Database ClientManagerDB already exists.';
END
GO