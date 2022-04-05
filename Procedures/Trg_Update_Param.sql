/****** Object:  Trigger [dbo].[HRM_02_UpdateParamsTable]    Script Date: 2022-02-04 11:59:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE TRIGGER [dbo].[HRM_02_UpdateParamsTable]
ON [dbo].[Report_HTMLS]
AFTER INSERT, UPDATE

AS 
BEGIN

	SET NOCOUNT ON;

	DECLARE
			@tid INT
			,@tnazwa varchar(100)
			,@thtml nvarchar(max)
			,@tstartPatt nvarchar(10)
			,@tendPatt nvarchar(10)

	DECLARE @params AS TABLE (parameter NVARCHAR(100))

	DECLARE paramCursor CURSOR 
	FOR SELECT ID, HName, HTML, StartParamPattern, EndParamPattern FROM inserted;

	OPEN paramCursor;
	FETCH NEXT FROM paramCursor INTO @tid, @tnazwa, @thtml, @tstartPatt, @tendPatt;

	WHILE @@FETCH_STATUS = 0
	BEGIN

			INSERT INTO @params EXEC [dbo].[HRM_02_FindParameters]
										@html =  @thtml,
										@startPattern = @tstartPatt,
										@endPattern = @tendPatt

			IF	EXISTS(SELECT parameter FROM @params WHERE parameter NOT IN (SELECT paramName FROM dbo.Report_HTML_Params WHERE reportID = @tid))
				OR
				EXISTS(SELECT paramName FROM dbo.Report_HTML_Params WHERE reportID = @tid AND paramName NOT IN (SELECT parameter FROM @params))
			BEGIN

				DELETE FROM dbo.Report_HTML_Params
					WHERE reportID = @tid;
			
				INSERT INTO dbo.Report_HTML_Params
				SELECT DISTINCT @tid, parameter FROM @params

			END

			FETCH NEXT FROM paramCursor INTO @tid, @tnazwa, @thtml, @tstartPatt, @tendPatt;
			DELETE FROM @params;
	END

	CLOSE paramCursor;
	DEALLOCATE paramCursor;

END 
GO

ALTER TABLE [dbo].[Report_HTMLS] ENABLE TRIGGER [HRM_02_UpdateParamsTable]
GO


