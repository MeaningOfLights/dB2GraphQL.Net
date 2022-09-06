
# dB 2 GraphQL .Net

A cross-database GraphQL HotChocolate POCO generator!  

![How dB2GraphQL Works](/Media/HowToDb2Graph.gif "dB 2 GraphQL .Net Generator")  

Databases supported by Microsoft ADO.Net provider can be read  (SqlServer, SqlServer CE 4, MySQL, SQLite, System.Data.OracleClient, ODP, Devart, PostgreSql, DB2...) into a single standard model. 

For .Net Core, we support SqlServer, SqlServer CE 4, SQLite, PostgreSql, MySQL and Oracle (even if the database clients are not yet available in .net Core, we are ready for them).


## Purpose

* To read database schemas, plus:  
  
* To generate .Net code:  
  * GraphQL classes - NEW !  
  * Classes for tables, NHibernate or EF Code First mapping files, and  
  * Generate simple ADO classes to use stored procedures  
* Simple sql generation:  
  * Generate table DDL (and translate to another SQL syntax)  
  * Generate CRUD stored procedures (for SqlServer, Oracle, MySQL, DB2)  
* Copy a database schema and data from any provider (SqlServer, Oracle etc) to a new SQLite database (and, with limitations, to SqlServer CE 4)  
* Compare two schemas to generate a migration script  
* Simple cross-database migrations generator  


## History - dB2GraphQL.Net

* 1.10:	Added a Postgres Test Database [4. PostgreSQL Singular Settings Table - EventOrganiser](TestDatabases) to demonstrate Singular Tables (Many-Columns-To-One-'Settings'-Table Relationships)"", plus tweaks to Config/Descriptors/Resolvers for Singular Tables
* 1.09	Added a ReadMe and included an animated gif with instructions on how to use the system  
* 1.08:	Support for Circular References, Sqlite Driver and an example Sqlite Database to demonstrate Circular References ""3. Sqlite CircularRef - SeparationOfPowers""
* 1.07:	Support for PostGres Driver   
* 1.06:	Support for Singular Tables (Many-Columns-To-One-'Settings'-Table Relationships)  
* 1.05:	Support got GraphQL Attributes [UseProjections], [Parent] and Decimal Types with Annotations  
* 1.04:	Support for Many-To-Many Relationships  
* 1.03:	Validation of Database Schema for GraphQL POCO Models  
* 1.02:	Completed GraphQL POCO Model generation with Foreign Keys, Resolvers, Descriptors & etc  
* 1.01:	Built in generator for GraphQL POCO Models	  
* 1.00:	Forked project from https://github.com/martinjw/dbschemareader

## Not Supported

Denormalised, meta-meta, inheritance and NoSQL databases.

## Connection String examples

PostgresQL:
Server=host;Port=5432;User Id=username;Password=secret;Database=databasename;

SQLServer:
Server=.;Database=databasename;Integrated Security=True;

## Known Error:

Running the application you get the error:

Severity	Code	Description	Project	File	Line	Suppression State
Error	MSB3644	The reference assemblies for .NETFramework,Version=v4.0 were not found. To resolve this, install the Developer Pack (SDK/Targeting Pack) for this framework version or retarget your application. You can download .NET Framework Developer Packs at https://aka.ms/msbuild/developerpacks	DatabaseSchemaReader	C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\amd64\Microsoft.Common.CurrentVersion.targets	1220	

Copy the DLLs in the Debug folder to the DatabaseSchemaReader\bin\Debug\ folder. Then just run project with the Viewer set as StartUp Project.

## To Do

* Add Update functionaity
* Do a diff compare with the PocoCodeFirst flag
* Resolvers are mapped using Froeign Keys, it would be better using the actual column names. Sometime they're not named the same!
* Related to the above TODO, support for Primary Keys other than "Id". See ""BakersYchange"" sample for the problems non-Id PK columns cause: DatabaseSchemaViewer > TestDatabases
* Support for StoredProcedures & Functions
* Support Enum DataTypes (in PostGres)
* Command Line usage to run on Mac & Linux 

## Instructions with handy tips!

### Coding Changes
You may need to delete the bin#obj folders in the\dBSchemaReaderPoco.NetGen\DatabaseSchemaReader & Viewer project before seeing your changes take affect.


### Compiling

BUILD DatabaseSchemaReader.csproj - that will fail.

Then run the project and ignore the one error:

Severity	Code	Description	Project	File	Line	Suppression State
Error	MSB3644	The reference assemblies for .NETFramework,Version=v4.5 were not found. To resolve this, install the Developer Pack
(SDK/Targeting Pack) for this framework version or retarget your application.


### Running

After compiling and running it will load a browser, be sure to visit both these pages:

https://localhost:5001/ui/voyager and https://localhost:5001/graphql/

If you haven't created a Database yet the scripts are located here:
https://github.com/MeaningOfLights/dB2GraphQL.Net/tree/master/TestDatabases



## Database Design Considerations

The tool contains a button **Validate Schema** for GraphQL - run this and tells you any issues by detecting the following:

- Any database table names that are plural, its a HotChocolate convention. 

- Any column names that are singular, also a HotChocolate convention  . 

- When using special database types such as Enums they may not translate to a .Net DataType and instead show up in the output as "object".
Its critical you manually fix these up. In the case of Enums you need to manually declare them in the codebase replacing all "object" variable declarations!

- Every primary key must use "Id" as the column name. For foreign key columns always use the foreign key table name and the primary key Id. For example, an **Employee** table with a foriegn key **OccupationId** is easily seen to map to the **Occupation** table and its primary key **Id**.

- Avoid Acronyms like DOB, use Dob or DateOfBirth instead.

- Apart from ""Id"" avoid column names less than 3 letters; aim for a word or two to explain the field.

- It's important to choose column names wisely as they make up the variable names in the codebase. Choose  CamelCase column names instead of underscores as they don't look good. Note when working with Postgres databases all table and column names need to be enclosed with "double quotes".

- Avoid the same column name like 'SharedAppId' in multple tables, instead use the Table-Id naming relationship syntax convention! 

- *You CANNOT use polymorphic foreign keys such as a ServiceID and also a ProductID to reference to different tables from one key field.

- You can have tables with columns that refer to one table. See the Settings table in the Test Database example "4. PostgreSQL Singular Settings Table - EventOrganiser".

- You can use Single Table Inheritance https://www.martinfowler.com/eaaCatalog/singleTableInheritance.html. Essentially a single table to hold all the 
settings/values of multiple small tables, with a structure such as: Id|ParentCodeId|CodeId|Setting|Value|Description|IsDeleted). 

- Sometimes it's not possible to honor the Table-Id relationship naming convention. A common scenario is having columns named 'CreatedBy' and 'ModifiedBy' 
and that's fine unless they're foreign keys to the User table. If it was one field then it should be called 'UserId' instead of 'CreatedBy', however we can't have
two columns named 'UserId'. In this case we can use the Singular Table design and name the columns 'CreatedByUserId' and 'ModifiedByUserId' which is explained next. 

- In Test Databses 4. PostgreSQL Singular Settings Table - EventOrganiser.sql, I demo using a single Settings table to hold Industry, Title & Country values
that are shared to multiple tables. Notice the naming convention IndustrySettingId, TitleSettingId, CountrySettingId. Same as I did with CreatedByUserID:

![Single Settings Table](/TestDatabases/4.%20PostgreSQL%20Singular%20Settings%20Table%20-%20EventOrganiser.png "Many-Columns-To-One")  


## Reserved Keywords

Avoid Table and Column names that are HotChocolate Keywords:

- Location
- FieldCoordinate
- NameString
- SchemaCoordinate

Avoid Column Names:

- Setting



## After Generating the GraphQL DataBase

After generating, open the solution in Visual Studio and make sure the Nuget Packages are referenced.

Go through all the errors, typically pressing Ctrl + Space over any red squiggle lines and fixing any issues.


## Credits

CREDIT - Original https://dbschemareader.codeplex.com/

CREDIT - DB SCHEMA READER:
https://github.com/martinjw/dbschemareader

CREDIT - dB2GRAPHQL.Net:
https://github.com/MeaningOfLights/dB2GraphQL.Net
