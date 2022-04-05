/****** Object:  StoredProcedure [dbo].[HRM_01_DeleteHtml]    Script Date: 05.01.2022 11:23:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[HRM_01_DeleteHtml]
	-- Add the parameters for the stored procedure here
	@htmlID INT
AS
BEGIN
	
	DELETE FROM dbo.Report_HTML_Params
	WHERE reportID = @htmlID;

	DELETE FROM dbo.Report_HTMLS
	WHERE ID = @htmlID;

END
GO


CREATE PROCEDURE [dbo].[HRM_03_ReturnParamsList] 
	-- Add the parameters for the stored procedure here
	@reportId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
	[paramID] AS ParamID
	,[reportID] AS ReportID
    ,[paramName] AS ParamName

  FROM [dbo].[Report_HTML_Params] 
  
  WHERE [reportID] = @reportId 
		OR
		[reportID] IN (SELECT prefixHtmlID FROM dbo.Report_HTMLS WHERE [ID] = @reportId
						UNION
					   SELECT suffixHtmlID FROM dbo.Report_HTMLS WHERE [ID] = @reportId)
END
GO


CREATE PROCEDURE [dbo].[HRM_04_ReturnHTemplateInfo]
	-- Add the parameters for the stored procedure here
	@id INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT
			[ID] as  htmlID
			,[HName] as htmlName
			,[HTML] as htmlCode
			,[StartParamPattern] as sParamPattern
			,[EndParamPattern] as  eParamPattern
			,[prefixHtmlID] as preffixHtmlId
			,[suffixHtmlID] as suffixHtmlId
			,[datasourceName]
			
			,dbo.HRM_00_QuoteIfNotQuoted([databaseName])	+ '.' + 
				dbo.HRM_00_QuoteIfNotQuoted([schemaName])	+ '.' + 
				dbo.HRM_00_QuoteIfNotQuoted([datasourceName]) + 
				case when [datasourceType] = 'F' then '(' + [fnctArgs] + ')' else '' end 
				
				as fullDatasourceName
			
			,[datasourceType]		
			,[returnAsOneHtml] 
			,[orderByColumn] 
			,[splitResultSetBy] 
			,[mSubjectColName] 
			,[mAddressColName] 
			,[outputMode] 

	  FROM 
	  
		(
			SELECT 2 AS [LP], * FROM dbo.Report_HTMLS  WHERE [ID] = @id 
			UNION ALL
			SELECT 1 AS [LP], * FROM dbo.Report_HTMLS  WHERE [ID] = (SELECT prefixHtmlID FROM dbo.Report_HTMLS WHERE [ID] = @id)
			UNION ALL
			SELECT 3 AS [LP], * FROM dbo.Report_HTMLS  WHERE [ID] = (SELECT suffixHtmlID FROM dbo.Report_HTMLS WHERE [ID] = @id)

		) HelperTable

		ORDER BY [LP]


END
GO