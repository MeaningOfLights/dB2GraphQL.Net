USE [BakerXchange]

/****** Object:  Table [dbo].[BakerProducts]    Script Date: 6/02/2022 12:11:50 PM ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE TABLE [dbo].[BakerProducts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BakerId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[PricingDate] [datetime] NOT NULL,
	[Price] [money] NOT NULL,
	[StockLevel] [bigint] NOT NULL,
 CONSTRAINT [PK_BakerProducts] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Table [dbo].[Bakers]    Script Date: 6/02/2022 12:11:50 PM ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE TABLE [dbo].[Bakers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[BakerName] [varchar](max) NULL,
	[Telephone] [varchar](max) NULL,
	[Address] [varchar](max) NULL,
 CONSTRAINT [PK_Bakers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

/****** Object:  Table [dbo].[Orders]    Script Date: 6/02/2022 12:11:50 PM ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE TABLE [dbo].[Orders](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrderDate] [datetime] NULL,
	[DeliveryDate] [datetime] NULL,
	[CustomerId] [int] NULL,
 CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Table [dbo].[ProductOrders]    Script Date: 6/02/2022 12:11:50 PM ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE TABLE [dbo].[ProductOrders](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrderId] [int] NOT NULL,
	[BakerProductId] [int] NOT NULL,
	[OrderQuantity] [bigint] NOT NULL,
 CONSTRAINT [PK_ProductOrders] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

/****** Object:  Table [dbo].[Products]    Script Date: 6/02/2022 12:11:50 PM ******/
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE TABLE [dbo].[Products](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProductName] [varchar](max) NULL,
	[ProductDescription] [varchar](max) NULL,
 CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

/****** Object:  Index [U_BakerProductsPrice]    Script Date: 6/02/2022 12:11:50 PM ******/
ALTER TABLE [dbo].[BakerProducts] ADD  CONSTRAINT [U_BakerProductsPrice] UNIQUE NONCLUSTERED 
(
	[BakerId] ASC,
	[ProductId] ASC,
	[PricingDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

ALTER TABLE [dbo].[BakerProducts]  WITH CHECK ADD  CONSTRAINT [FK_BakerProductsBakers] FOREIGN KEY([BakerId])
REFERENCES [dbo].[Bakers] ([Id])

ALTER TABLE [dbo].[BakerProducts] CHECK CONSTRAINT [FK_BakerProductsBakers]

ALTER TABLE [dbo].[BakerProducts]  WITH CHECK ADD  CONSTRAINT [FK_BakerProductsProducts] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])

ALTER TABLE [dbo].[BakerProducts] CHECK CONSTRAINT [FK_BakerProductsProducts]

ALTER TABLE [dbo].[ProductOrders]  WITH CHECK ADD  CONSTRAINT [FK_ProductOrders_Orders] FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])

ALTER TABLE [dbo].[ProductOrders] CHECK CONSTRAINT [FK_ProductOrders_Orders]

ALTER TABLE [dbo].[ProductOrders]  WITH CHECK ADD  CONSTRAINT [FK_ProductsOrdersBakersProducts] FOREIGN KEY([BakerProductId])
REFERENCES [dbo].[BakerProducts] ([Id])

ALTER TABLE [dbo].[ProductOrders] CHECK CONSTRAINT [FK_ProductsOrdersBakersProducts]




Declare @Id int
Set @Id = 1

While @Id <= 100
Begin 
   Insert Into Bakers values ('Bakers - ' + CAST(@Id as nvarchar(10)), ABS(CHECKSUM(NewId())) % 99999999,
              'Address - ' + CAST(@Id as nvarchar(10)) + ' name')
   --Print @Id
   Set @Id = @Id + 1
End

select * from Bakers


--Declare @Id int
Declare @randomProduct nvarchar(MAX)
Set @Id = 1
while @Id <= 100
Begin 
with names as (
      select  'Bread ' as name union all
      select  'Rolls ' union all
      select  'Pie ' union all
      select  'Sausage Roll ' union all
      select  'Choc Eclaire ' union all
      select  'Wagon Wheel ' union all
      select  'Coke ' union all
      select  'Sprite ' union all
      select  'Baguette ' union all
      select  'Custard Tart '
)

	SELECT @randomProduct = CAST((select top 1 [name] from names order by newid())  as nvarchar(50))+ CAST(@Id as nvarchar(10))
    Insert Into Products values (@randomProduct, @randomProduct)
    --Print @Id
    Set @Id = @Id + 1
End

select * from Products order by id desc



Declare @LowerLimitForBakerId int
Declare @UpperLimitForBakerId int

Set @LowerLimitForBakerId = 1
Set @UpperLimitForBakerId = 100

Declare @LowerLimitForProductId int
Declare @UpperLimitForProductId int

Set @LowerLimitForProductId = 1
Set @UpperLimitForProductId = 100

Declare @LowerLimitForPrice int
Declare @UpperLimitForPrice int

Set @LowerLimitForPrice = 50 
Set @UpperLimitForPrice = 100 

Declare @LowerLimitForStock int
Declare @UpperLimitForStock int

Set @LowerLimitForStock = 1
Set @UpperLimitForStock = 10


Declare @RandomBakerId int
Declare @RandomProductId int
Declare @RandomPrice int
Declare @RandomStock int
Declare @RandDate DateTime
--Declare @Id int
Set @Id = 1
While @Id <= 10000
Begin 

   Select @RandomBakerId = Round(((@UpperLimitForBakerId - @LowerLimitForBakerId) * Rand()) + @LowerLimitForBakerId, 0)
   Select @RandomProductId = Round(((@UpperLimitForProductId - @LowerLimitForProductId) * Rand()) + @LowerLimitForProductId, 0)
   Select @RandomPrice = Round(((@UpperLimitForPrice - @LowerLimitForPrice) * Rand()) + @LowerLimitForPrice, 0)
   Select @RandomStock= Round(((@UpperLimitForStock - @LowerLimitForStock) * Rand()) + @LowerLimitForStock, 0)
   SELECT @RandDate = DATEADD(DAY, -1 * CEILING(RAND()*1000) , GETDATE())


   Insert Into BakerProducts values (@RandomBakerId,@RandomProductId, @RandDate, @RandomPrice, @RandomStock)
   --Print @Id
   Set @Id = @Id + 1
End

select * from BakerProducts




--Declare @Id int
Declare @RandOrderDate DateTime
Declare @RandDelDate DateTime
Declare @RandomCustId int
Set @Id = 1
While @Id <= 1200
Begin 

   SELECT @RandOrderDate = DATEADD(DAY, -1 * CEILING(RAND()*1000) , GETDATE())
   SELECT @RandDelDate = DATEADD(DAY, -1 * CEILING(RAND()*1000) , GETDATE())
   Select @RandomCustId = Round(1000 * Rand() , 0)

   Insert Into Orders values (@RandOrderDate,@RandDelDate, @RandomCustId)
   --Print @Id
   Set @Id = @Id + 1
End

select * from Orders



--Declare @Id int
Declare @LowerLimitForBakerProductId int
Declare @UpperLimitForBakerProductId int

Set @LowerLimitForBakerProductId = 1
Set @UpperLimitForBakerProductId = 10000

Declare @LowerLimitForOrderId int
Declare @UpperLimitForOrderId int

Set @LowerLimitForOrderId = 1
Set @UpperLimitForOrderId = 1200

Declare @LowerLimitForQuantity int
Declare @UpperLimitForQuantity int

Set @LowerLimitForQuantity = 1
Set @UpperLimitForQuantity = 10


Declare @RandomOrderId int
Declare @RandomBakerProductId int
Declare @RandomQuantity int

Set @Id = 1

While @Id <= 5000
Begin 

   Select @RandomOrderId = Round(((@UpperLimitForOrderId - @LowerLimitForOrderId) * Rand()) + @LowerLimitForOrderId, 0)
   Select @RandomBakerProductId = Round(((@UpperLimitForBakerProductId - @LowerLimitForBakerProductId) * Rand()) + @LowerLimitForBakerProductId, 0)
   Select @RandomQuantity= Round(((@UpperLimitForQuantity - @LowerLimitForQuantity) * Rand()) + @LowerLimitForQuantity, 0)

   Insert Into ProductOrders values (@RandomOrderId,@RandomBakerProductId, @RandomQuantity)
   --Print @Id
   Set @Id = @Id + 1
End

select * from ProductOrders

