/****** Object:  StoredProcedure [dbo].[HRM_02_FindParameters]    Script Date: 05.01.2022 11:13:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[HRM_02_FindParameters] 
(
	@html NVARCHAR(MAX)
	,@startPattern NVARCHAR(10) = '++@'
	,@endPattern NVARCHAR(10) = '@++'
)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE 
			@startPos AS INT = 1
			,@endPos AS INT = 1
			,@htmlLen AS INT = LEN(@html)
			,@sPatLen AS INT
			,@ePatLen AS INT 

	DECLARE @params AS TABLE (paramName NVARCHAR(100));

	SET @sPatLen = LEN(@startPattern);
	SET @ePatLen = LEN(@endPattern);

	SET @startPattern = '%' + @startPattern + '%';
	SET @endPattern = '%' + @endPattern + '%';
	
	WHILE @endPos <= @htmlLen
	BEGIN

		SET @startPos = PATINDEX(@startPattern, @html);
		IF @startPos = 0
			BREAK;

		SET @startPos = @startPos + @sPatLen;

		SET @endPos = PATINDEX(@endPattern, @html)
		IF @endPos = 0 
			BREAK; 

		INSERT INTO @params VALUES ( SUBSTRING(@html, @startPos, (@endPos - @startPos)) );
		
		SET @endPos = @endPos + @ePatLen;
		SET @html = SUBSTRING(@html, @endPos, (@htmlLen - @startPos));

	END

	SELECT * FROM @params; 

END
GO


