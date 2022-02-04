
/****** Object:  Table [dbo].[Report_HTMLS]    Script Date: 05.01.2022 11:03:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Report_HTMLS](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[HName] [varchar](100) NOT NULL,
	[HTML] [nvarchar](max) NOT NULL,
	[StartParamPattern] [nvarchar](10) NOT NULL,
	[EndParamPattern] [nvarchar](10) NOT NULL,
	[prefixHtmlID] [int] NULL,
	[suffixHtmlID] [int] NULL,
	[databaseName] [nvarchar](200) NULL,
	[schemaName] [nvarchar](200) NULL,
	[datasourceName] [nvarchar](200) NULL,
	[datasourceType] [varchar](1) NULL,
	[fnctArgs] [nvarchar](max) NULL,
	[returnAsOneHtml] [nvarchar](1) NULL,
	[orderByColumn] [nvarchar](max) NULL,
	[splitResultSetBy] [nvarchar](max) NULL,
	[mSubjectColName] [nvarchar](max) NULL,
	[mAddressColName] [nvarchar](max) NULL,
	[outputMode] [nvarchar](1) NULL,
	[mailProfile] [varchar](100) NULL,
 CONSTRAINT [PK_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[Report_HTMLS] ADD  DEFAULT ('++@') FOR [StartParamPattern]
GO

ALTER TABLE [dbo].[Report_HTMLS] ADD  DEFAULT ('@++') FOR [EndParamPattern]
GO

ALTER TABLE [dbo].[Report_HTMLS]  WITH CHECK ADD FOREIGN KEY([prefixHtmlID])
REFERENCES [dbo].[Report_HTMLS] ([ID])
GO

ALTER TABLE [dbo].[Report_HTMLS]  WITH CHECK ADD FOREIGN KEY([prefixHtmlID])
REFERENCES [dbo].[Report_HTMLS] ([ID])
GO

ALTER TABLE [dbo].[Report_HTMLS]  WITH CHECK ADD FOREIGN KEY([suffixHtmlID])
REFERENCES [dbo].[Report_HTMLS] ([ID])
GO

ALTER TABLE [dbo].[Report_HTMLS]  WITH CHECK ADD FOREIGN KEY([suffixHtmlID])
REFERENCES [dbo].[Report_HTMLS] ([ID])
GO


