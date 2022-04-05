/****** Object:  UserDefinedFunction [dbo].[HRM_00_BuildQueryForDSColumnNames]    Script Date: 05.01.2022 11:17:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================

CREATE FUNCTION [dbo].[HRM_00_QuoteIfNotQuoted]
(
	-- Add the parameters for the function here
	@string NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @len INT = 0
			,@first VARCHAR = ''
			,@last VARCHAR = ''
			,@result NVARCHAR(MAX);
	
	SET @len = ISNULL(LEN(@string), 0);

	IF @len = 0
		RETURN NULL;
	
	SELECT	@first = SUBSTRING(@string, 1, 1)
			,@last = SUBSTRING(@string, @len, 1)

	IF @first = '[' AND @last = ']'
		SET @result =  @string;
	ELSE
		set @result = N'[' + @string + N']'

	RETURN @result;

END
GO


CREATE FUNCTION[dbo].[HRM_00_UnQuoteIfQuoted]
(
	-- Add the parameters for the function here
	@string NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	
	DECLARE @len INT = 0
			,@first VARCHAR = ''
			,@last VARCHAR = ''
			,@result NVARCHAR(MAX);
	
	SET @len = ISNULL(LEN(@string), 0);

	IF @len = 0
		RETURN NULL;
	
	SELECT	@first = SUBSTRING(@string, 1, 1)
			,@last = SUBSTRING(@string, @len, 1)

	IF @first = '[' AND @last = ']'
		SET @result =  SUBSTRING(@string, 2, @len-2)
	ELSE
		set @result = @string

	RETURN @result;

END
GO



--ZAPYTANIE DO ODCZYTANIA WSZYSTKICH ORYGINALNYCH NAZW KOLUMN ZE ŹRÓDŁA DANYCH
--DATASOURCE TYPE: V - VIEW, F - TABLE FUNCTION, T - TABLE
CREATE FUNCTION [dbo].[HRM_00_BuildQueryForDSColumnNames]
(
	-- Add the parameters for the function here
	@datasourceType VARCHAR(1)
	,@databaseName NVARCHAR(200)
	,@datasourceName NVARCHAR(200)
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @tempQuery NVARCHAR(MAX);

	SET @datasourceName = dbo.HRM_00_UnQuoteIfQuoted(@datasourceName);

	IF @datasourceType = 'V'
		SET @tempQuery = N'SELECT COLUMN_NAME FROM ' + @databaseName + N'.INFORMATION_SCHEMA.VIEWS V JOIN ' + @databaseName + N'.INFORMATION_SCHEMA.COLUMNS C ON' + ' C.TABLE_SCHEMA = V.TABLE_SCHEMA AND C.TABLE_NAME = V.TABLE_NAME WHERE V.TABLE_NAME = ''' + @datasourceName + '''';
	
	ELSE IF @datasourceType = 'T'
		SET @tempQuery = N'SELECT COLUMN_NAME FROM ' + @databaseName + N'.INFORMATION_SCHEMA.TABLES T JOIN ' + @databaseName + N'.INFORMATION_SCHEMA.COLUMNS C ON' + ' C.TABLE_SCHEMA = T.TABLE_SCHEMA AND T.TABLE_NAME = C.TABLE_NAME WHERE T.TABLE_NAME = ''' + @datasourceName + '''';
	
	ELSE IF @datasourceType = 'F'
		SET @tempQuery = N'SELECT COLUMN_NAME FROM ' + @databaseName + N'.INFORMATION_SCHEMA.ROUTINES R JOIN ' + @databaseName + N'.INFORMATION_SCHEMA.ROUTINE_COLUMNS C ON' + ' C.TABLE_SCHEMA = R.ROUTINE_SCHEMA AND R.ROUTINE_NAME = C.TABLE_NAME WHERE R.ROUTINE_NAME = ''' + @datasourceName + '''';

	ELSE 
		SET @tempQuery = NULL;

	-- Return the result of the function
	RETURN @tempQuery

END
GO

CREATE FUNCTION [dbo].[HRM_00_BuildSelectStatement]
(
	-- Add the parameters for the function here
	@columnList NVARCHAR(MAX)
	,@dataSource NVARCHAR(MAX)
	,@distinct BIT = 0
	,@topRows INT = NULL
	,@percent BIT = 0
	,@withTies BIT = 0
	,@dstTableName NVARCHAR(MAX) = NULL
	,@whereConditions NVARCHAR(MAX) = NULL
	,@groupBy NVARCHAR(MAX) = NULL
	,@havingConditions NVARCHAR(MAX) = NULL
	,@orderBy NVARCHAR(MAX) = NULL

)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @resultQuery NVARCHAR(MAX);

	SET @resultQuery = N'SELECT ';
	
	IF ISNULL(@distinct, 0) != 0
		SET @resultQuery += N'DISTINCT ';

	IF ISNULL(@topRows, 0) != 0
		SET @resultQuery += N'TOP ' + CAST(@topRows AS NVARCHAR) + N' ';
	
	IF ISNULL(@percent, 0) != 0
		SET @resultQuery += N'PERCENT '; 

	IF ISNULL(@withTies, 0) != 0
		SET @resultQuery += N'WITH TIES '; 

	SET @resultQuery += @columnList + N' '; 

	IF ISNULL(@dstTableName, '') != ''
		SET @resultQuery += N'INTO ' + @dstTableName + N' ';

	SET @resultQuery += N'FROM ' + @dataSource + N' ';
	
	IF ISNULL(@whereConditions, '') != ''
		SET @resultQuery += N'WHERE ' + @whereConditions + N' ';

	IF ISNULL(@groupBy, '') != ''
		SET @resultQuery += N'GROUP BY ' + @groupBy + N' ';

	IF ISNULL(@havingConditions, '') != ''
		SET @resultQuery += N'HAVING ' + @havingConditions + N' ';

	IF ISNULL(@orderBy, '') != ''
		SET @resultQuery += N'ORDER BY ' + @orderBy + N' ';


	-- Return the result of the function
	RETURN  @resultQuery;

END
GO


