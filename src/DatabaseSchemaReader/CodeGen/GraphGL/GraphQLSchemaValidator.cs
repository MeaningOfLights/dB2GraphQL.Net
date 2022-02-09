using DatabaseSchemaReader.DataSchema;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLSchemaValidator
    {
        public static string AllSchemaIssues(DatabaseSchema databaseSchema)
        {
            StringBuilder sb = new StringBuilder();
            CodeWriter cw = new CodeWriter(databaseSchema, new CodeWriterSettings { CodeTarget= CodeTarget.PocoGraphGL});
            List<DatabaseTable> tables = cw.GetNonSystemTables();

            sb.AppendLine(ReservedConnectionStringIssues(databaseSchema));
            sb.AppendLine(AlwaysHaveNONNULLPrimaryKeys(tables));
            sb.AppendLine(UnknownDataTypes(tables));
            sb.AppendLine(ReservedKeywords(tables));
            sb.AppendLine(EveryTableHasAPrimaryKey(tables));
            sb.AppendLine(AllTablesArePlural(tables));
            sb.AppendLine(AllTableColumnsAreNonPlural(tables));
            sb.AppendLine(AllTablePrimaryKeysAreNamedId(tables));
            sb.AppendLine(AllTableColumnsAreNotAcronyms(tables));
            if (sb.Length > 0)
            {
                sb.Insert(0, "====================================================================================\r\n");
                sb.Insert(0, "1. CRITICAL: ATTEND TO ANYTHING BELOW IT NEEDS FIXING!!!\r\n");
                sb.Insert(0, "====================================================================================\r\n");
            }

            sb.AppendLine(AllForeignKeysMapToTablePrimaryKeys(tables));
            sb.AppendLine(AllTableColumnsAreThreeLetters(tables));
            sb.AppendLine(AllTableForeignKeysEndWithId(tables));

            sb.Append(ObjectsWillBeRenamed(tables));

            return sb.ToString();
        }

        //It's a HotChocolate convention that database table names to be plural. 
        private static string AllTablesArePlural(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Table names MUST end with S:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                if (!databaseTable.Name.EndsWith("s", StringComparison.OrdinalIgnoreCase))
                {
                    wasIssue = true;
                    sb.AppendLine("FIX: " + databaseTable.Name);
                }
            }
            return wasIssue ? sb.ToString(): string.Empty;
        }

        //It's a HotChocolate convention that column names are singular and not pluralised. 
        private static string AllTableColumnsAreNonPlural(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Column names must NOT be plural, use Singular column names:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (NameFixer.IsPlural(col.Name))
                    {
                        wasIssue = true;
                        sb.AppendLine("FIX: " + databaseTable.Name + " Column: " + col.Name);
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }

        //Always use "Id" as the column name for every primary key.For foreign key columns, always use the foreign key table name and the primary key Id. 
        //For example a Employee table with a foriegn key "OccupationId" is easily seen to map to the "Occupation" table and its primary key "Id".

        private static string AllTablePrimaryKeysAreNamedId(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Table Primary Keys MUST be named Id:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (!col.IsPrimaryKey) continue;
                    if (col.Name != NameFixer.PrimaryKeyIdName)
                    {
                        wasIssue = true;
                        sb.AppendLine("FIX: " + databaseTable.Name + " Primary Key Column: " + col.Name);
                    }
                    break;
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }


        //Always have NON-NULL Primary Keys

        private static string AlwaysHaveNONNULLPrimaryKeys(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("Always have NON-NULL Primary Keys:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (!col.IsPrimaryKey) continue;
                    if (col.Nullable)
                    {
                        wasIssue = true;
                        sb.AppendLine("FIX: " + databaseTable.Name + " NULLABLE Primary Key Column: " + col.Name);
                    }
                    break;
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }
        public static string ReservedConnectionStringIssues(DatabaseSchema databaseSchema)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("Remove Connection String Keywords");
            sb.AppendLine("------------------------------------------------------");
            if ((ProviderToSqlType.Convert(databaseSchema.Provider) == SqlType.SQLite) && databaseSchema.ConnectionString.ToUpper().Contains("VERSION=3;"))
            {
                wasIssue = true;
                sb.AppendLine("Remove Reserved Connection String Keyword: Version=3;");
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }


        //Avoid Table Names that are HotChocolate Keywords:

        //- Location
        //- FieldCoordinate
        //- NameString
        //- SchemaCoordinate

        //Avoid Column Names:

        //- Setting

        private static string ReservedKeywords(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("Reserved Keywords:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                if ("Location,FieldCoordinate,NameString,SchemaCoordinate,".Contains(databaseTable.Name + ","))
                {
                    wasIssue = true;
                    sb.AppendLine("FIX: " + databaseTable.Name);
                }

                foreach (var column in databaseTable.Columns)
                {
                    if ("Setting,".Contains(column.Name + ","))
                    {
                        wasIssue = true;
                        sb.AppendLine("FIX: " + databaseTable.Name + " Column: " + column.Name);
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }

        private static string UnknownDataTypes(List<DatabaseTable> databaseTables)
        {
            DataTypeWriter dataTypeWriter = new DataTypeWriter(CodeTarget.PocoGraphGL);
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("Unknown DataTypes:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var column in databaseTable.Columns)
                {
                    if (dataTypeWriter.Write(column) == "object")
                    {
                        wasIssue = true;
                        sb.AppendLine("CODE IN A DATATYPE: " + databaseTable.Name + " Column: " + column.Name + " IS AN OBJECT!!!");
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }

        // Ensure every table has a Primary Key

        private static string EveryTableHasAPrimaryKey(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("Every Table Has A Primary Key:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                bool hasPrimaryKey = false;
                foreach (var col in databaseTable.Columns)
                {
                    if (col.IsPrimaryKey)
                    {
                        hasPrimaryKey = true;
                        break;
                    }
                }
                if (!hasPrimaryKey)
                {
                    wasIssue = true;
                    sb.AppendLine("FIX TABLE: " + databaseTable.Name + " - NO PRIMARY KEY COLUMN");
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }

        //Avoid Acronyms like DOB, use Dob or DateOfBirth instead.
        private static string AllTableColumnsAreNotAcronyms(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Column names MUST NOT be acronyms or in capital letters:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (col.Name.All(char.IsUpper))
                    {
                        wasIssue = true;
                        sb.AppendLine("FIX: " + databaseTable.Name + " Column: " + col.Name);
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }



        //Apart from ""Id"" avoid column names less than 3 letters, aim for a word or two.


        // Avoid the same column name like 'SharedAppId' in multple tables, instead use the Table-Id naming relationship syntax convention.
        //* Use polymorphic foreign keys (joins across multiple tables) is WIP, currectly tested with ReferenceTable-Table-Id naming convention. 

        //Sometimes it's not possible to honor the Table-Id convention. A common scenario is having columns named 'CreatedBy' and 'ModifiedBy' and that's fine
        //unless they're foreign keys to the User table. If it was one field then it should be called 'UserId' instead of 'CreatedBy', however we can't have
        //two columns named UserId. Therefore in this case we keep 'CreatedBy' and 'ModifiedBy' and manually tweak the codebase to suit.
        private static string AllForeignKeysMapToTablePrimaryKeys(List<DatabaseTable> databaseTables)
        {
            bool wasIssue1 = false;
            bool wasIssue2 = false;
            StringBuilder sb = new StringBuilder();
            StringBuilder sb1 = new StringBuilder();
            StringBuilder sb2 = new StringBuilder();

            sb.AppendLine("====================================================================================");
            sb.AppendLine("2. NOTE... AIM FOR THE TABLE-ID RELATIONSHIP NAMING CONVENTION:");
            sb.AppendLine("====================================================================================");
            sb.AppendLine("");
            sb1.AppendLine("All Foreign Keys should map to Table Primary Keys:");
            sb1.AppendLine("------------------------------------------------------");
            sb2.AppendLine("These Foreign Keys appear to be mapped to Table Primary Keys OK:");
            sb2.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (col.IsForeignKey)
                    {
                        if (col.Name.EndsWith(NameFixer.PrimaryKeyIdName))
                        {
                            // There's not any foreign tables named for this foreign key (could be a column aned CreatedBy mapping to a User.Id primary key)
                            if (!databaseTables.Any(d => NameFixer.MakeSingular(d.Name) == NameFixer.RemoveId(col.Name)))
                            {
                                bool foundAsForeignKey = false;
                                foreach (var fkey in databaseTable.ForeignKeys)
                                {
                                    if (fkey.Columns[0] == col.Name)
                                    {
                                        foundAsForeignKey = true;
                                        break;
                                    }
                                }

                                if (foundAsForeignKey)
                                {
                                    wasIssue2= true;
                                    sb2.AppendLine("NOTE: " + databaseTable.Name + " Column: " + col.Name  + " - check for any typo's causing inconsistent with Table-Id relationship");
                                }
                                else
                                {
                                    wasIssue1 = true;
                                    sb1.AppendLine("WARN: " + databaseTable.Name + " Column: " + col.Name);
                                }
                            }
                        }
                    }
                }
            }

            if (wasIssue1) sb.Append(sb1.ToString());
            if (wasIssue2) sb.Append(sb2.ToString());
            return sb.ToString();
        }


        private static string AllTableColumnsAreThreeLetters(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Table Column names should be 3 letters or longer:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (col.IsPrimaryKey) continue;
                    if (col.Name.Length < 3)
                    {
                        wasIssue = true;
                        sb.AppendLine("NOTE: " + databaseTable.Name + " Column: " + col.Name);
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }


        //It's also important to choose column names wisely as they make up the variable names in the codebase. Use CamelCase column names as underscores 
        //don't look good. This means that when working with Postgres databases all table and column names need to be enclosed with "double quotes".

        //Show column names that will translate to Plural Object Names
        private static string ObjectsWillBeRenamed(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("====================================================================================");
            sb.AppendLine("3. OBSERVATION:");
            sb.AppendLine("====================================================================================");

            sb.AppendLine("");
            sb.AppendLine("");
            sb.AppendLine("These classes/objects will have pluralized names:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                string pluralName = new PluralizingNamer().NameCollection(NameFixer.MakeSingular( databaseTable.Name));
                if (pluralName != databaseTable.Name)
                {
                    wasIssue = true;
                    sb.AppendLine("NOTE: " + databaseTable.Name + " will be named " + pluralName);
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }

        private static string AllTableForeignKeysEndWithId(List<DatabaseTable> databaseTables)
        {
            bool wasIssue = false;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("All Table Foreign Keys should be named Id:");
            sb.AppendLine("------------------------------------------------------");
            foreach (var databaseTable in databaseTables)
            {
                foreach (var col in databaseTable.Columns)
                {
                    if (col.IsForeignKey)
                    {
                        if (!col.Name.EndsWith(NameFixer.PrimaryKeyIdName))
                        {
                            wasIssue = true;
                            sb.AppendLine("Note: " + databaseTable.Name + " Foreign Column: " + col.Name);
                        }
                    }
                }
            }
            return wasIssue ? sb.ToString() : string.Empty;
        }


    }
}
