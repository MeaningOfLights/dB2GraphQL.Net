
--Manually create a SQL Database called CommandsDBGraphql then run this script...

USE [CommandsDBGraphql]
GO
/****** Object:  Table [dbo].[Commands]    Script Date: 4/02/2022 4:36:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Commands](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[HowTo] [nvarchar](max) NOT NULL,
	[CommandLine] [nvarchar](max) NOT NULL,
	[PlatformId] [int] NOT NULL,
 CONSTRAINT [PK_Commands] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Platforms]    Script Date: 4/02/2022 4:36:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Platforms](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
	[LicenseKey] [nvarchar](max) NULL,
 CONSTRAINT [PK_Platforms] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET IDENTITY_INSERT [dbo].[Commands] ON 
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (1, N'Lists Files and Folders', N'ls', 1)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (6, N'Lists Files and Folders', N'dir', 2)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (7, N'Ouput', N'Debug.Write', 3)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (9, N'Debugger', N'Debugger', 3)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (10, N'Output', N'print()', 4)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (11, N'Range', N'Range[]', 4)
GO
INSERT [dbo].[Commands] ([Id], [HowTo], [CommandLine], [PlatformId]) VALUES (13, N'MsgBox', N'Alert()', 5)
GO
SET IDENTITY_INSERT [dbo].[Commands] OFF
GO
SET IDENTITY_INSERT [dbo].[Platforms] ON 
GO
INSERT [dbo].[Platforms] ([Id], [Name], [LicenseKey]) VALUES (1, N'Linux', NULL)
GO
INSERT [dbo].[Platforms] ([Id], [Name], [LicenseKey]) VALUES (2, N'Windows', NULL)
GO
INSERT [dbo].[Platforms] ([Id], [Name], [LicenseKey]) VALUES (3, N'.Net', NULL)
GO
INSERT [dbo].[Platforms] ([Id], [Name], [LicenseKey]) VALUES (4, N'Python', NULL)
GO
INSERT [dbo].[Platforms] ([Id], [Name], [LicenseKey]) VALUES (5, N'Javascript', NULL)
GO
SET IDENTITY_INSERT [dbo].[Platforms] OFF
GO
ALTER TABLE [dbo].[Commands]  WITH CHECK ADD  CONSTRAINT [FK_Commands_Platforms_PlatformId] FOREIGN KEY([PlatformId])
REFERENCES [dbo].[Platforms] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Commands] CHECK CONSTRAINT [FK_Commands_Platforms_PlatformId]
GO
