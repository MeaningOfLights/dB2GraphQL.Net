using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using DatabaseSchemaReader.DataSchema;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    class GraphGLMappingWriter
    {
        private readonly DatabaseTable _table;
        private readonly CodeWriterSettings _codeWriterSettings;
        private readonly MappingNamer _mappingNamer;
        private readonly ClassBuilder _cb;
        private DatabaseTable _inheritanceTable;
        private readonly List<DatabaseConstraint> _foreignKeyResolverLookUps;
        private readonly List<DatabaseConstraint> _singleTableKeyResolverLookUps;

        public GraphGLMappingWriter(DatabaseTable table, CodeWriterSettings codeWriterSettings, MappingNamer mappingNamer, List<DatabaseConstraint> foreignKeyResolverLookUps, List<DatabaseConstraint> singleTableKeyResolverLookUps)
        {
            if (table == null) throw new ArgumentNullException("table");
            if (mappingNamer == null) throw new ArgumentNullException("mappingNamer");

            _table = table;
            _codeWriterSettings = codeWriterSettings;
            _mappingNamer = mappingNamer;
            _foreignKeyResolverLookUps = foreignKeyResolverLookUps;
            _singleTableKeyResolverLookUps = singleTableKeyResolverLookUps;
            _cb = new ClassBuilder();
        }

        /// <summary>
        /// Gets the name of the mapping class.
        /// </summary>
        /// <value>
        /// The name of the mapping class.
        /// </value>
        public string MappingClassName { get; private set; }

        public string Write()
        {
            // Name of the single C# file that holds all the dB table classes/records 
            MappingClassName = _mappingNamer.NameMappingClass(_table.NetName);

            _cb.AppendLine("using System.Linq;");
            _cb.AppendLine("using " + _codeWriterSettings.Namespace + ".Data;");
            _cb.AppendLine("using " + _codeWriterSettings.Namespace + ".Models;");
            _cb.AppendLine("using HotChocolate;");
            _cb.AppendLine("using HotChocolate.Types;");

            // Generate this GraphQL Models: Input, Payload, Mappings, Descriptors and Resolvers
            using (_cb.BeginNest("namespace " + _codeWriterSettings.Namespace + "." + _table.NetName + "s"))
            {
                AddType();
                //The following classes/records only have a single dependancy on "using HotChocolate.Types;"
                //I've combined them into one file for project management (as the dBs will typically have a large number of tables to warrent a code generator)
                AddInput();
                AddInputType();
                AddPayload();
                AddPayloadType();

                //TO DO - Add Update functionaity
                //https://stackoverflow.com/questions/61064861/how-can-i-create-a-graphql-partial-update-with-hotchocolate-and-efcore
            }
            return _cb.ToString();
        }

        private void AddType()
        {
            using (_cb.BeginNest("public class " + _table.NetName + "Type: ObjectType<" + _table.NetName + ">", "Record mapping GraphQL type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IObjectTypeDescriptor<" + _table.NetName + "> descriptor)", _table.Name + " Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents any executable " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WritePayloadTypeDescriptors();

                    WritePayloadForeignTableDescriptors();
                }

                AddResolvers();
            }
            _cb.AppendLine("");
        }

        private void WritePayloadForeignTableDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            //.Field(c => c.Platform)
            //.ResolveWith<Resolvers>(c => c.GetPlatform(default!, default!))
            //.UseDbContext<AppDbContext>()
            //.Description("This is the platform to which the command belongs.");

            char letter = _table.Name[0];

            foreach (var fKey in _table.ForeignKeys)
            {
                if (Equals(fKey.ReferencedTable(_table.DatabaseSchema), _inheritanceTable))
                    continue;

                string fKeyTableName = NameFixer.MakeSingular(fKey.RefersToTable);

                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");

                // When we encounter a foreign key column that doesn't map to the 'Table-Id' convention,
                // then there could be multiple of these columns so we need to name the methods uniquely from GetSomeThing to GetSomeThing-BySomeThingID:
                if (NameFixer.RemoveId(fKey.Columns[0]) != fKeyTableName && fKey.Columns[0].Contains("Id"))
                {
                    sb.Append(NameFixer.RemoveId(fKey.Columns[0]));
                    sb.Append(")");
                    sb.Append(".ResolveWith<Resolvers>(");
                    sb.Append(letter);
                    sb.Append(" => ");
                    sb.Append(letter);
                    sb.Append(".Get");
                    sb.Append(fKeyTableName);
                    sb.Append("By");
                    sb.Append(fKey.Columns[0]);

                    if (!_singleTableKeyResolverLookUps.Contains(fKey)) _singleTableKeyResolverLookUps.Add(fKey);
                }
                else
                {
                    sb.Append(fKeyTableName);
                    sb.Append(")");
                    sb.Append(".ResolveWith<Resolvers>(");
                    sb.Append(letter);
                    sb.Append(" => ");
                    sb.Append(letter);
                    sb.Append(".Get");
                    sb.Append(fKeyTableName);
                }

                sb.Append("(default!, default!)).UseDbContext<AppDbContext>()");
                sb.Append(@".Description(""This is the " + fKeyTableName + " to which the " + _table.NetName + @" relates."");");

                _cb.AppendLine(sb.ToString());
            }
        }

        private void AddResolvers()
        {
            string tableNamePascalCase = NameFixer.ToCamelCase(_table.NetName);
            using (_cb.BeginNest("public class Resolvers", "Resolvers"))
            {
                // EXAMPLE OUTPUT
                //public IQueryable<Command> GetCommands(Platform platform, [ScopedService] AppDbContext context)
                //{
                //    return context.Commands.Where(p => p.PlatformId == platform.Id);
                //}
                string refersToTable = String.Empty;
                string table = string.Empty;
                char letter = _table.NetName[0];

                // When we encounter a foreign key column that doesn't map to the 'Table-Id' convention,  
                // then there could be more than one and we need to add multiple resolvers for each of the lookups
                var singleTableResolvers = _singleTableKeyResolverLookUps.Where(a => a.RefersToTable == _table.Name);
                if (singleTableResolvers.Count() > 0)
                {
                    foreach (var resolver in singleTableResolvers)
                    {
                        refersToTable = NameFixer.MakeSingular(resolver.TableName);
                        table = NameFixer.MakeSingular(_table.Name);
                        using (_cb.BeginNest("public IQueryable<" + refersToTable + "> Get" + resolver.TableName + "By" + resolver.Columns[0] + "([Parent]" + table + " " + NameFixer.ToCamelCase(table) + ", [ScopedService] AppDbContext context)"))
                        {
                            StringBuilder sb = new StringBuilder();
                            sb.Append("return context.");
                            sb.Append(resolver.TableName);
                            letter = resolver.TableName[0];
                            sb.Append(".Where(");
                            sb.Append(letter);
                            sb.Append(" => ");
                            sb.Append(letter);
                            sb.Append(".");
                            sb.Append(resolver.Columns[0]);
                            sb.Append(" == ");
                            sb.Append(NameFixer.ToCamelCase(table));
                            sb.Append(".");
                            sb.Append(_table.PrimaryKey.Columns[0]); //This equals what the resolver.RefersToConstraint points to.
                            sb.Append(");");
                            _cb.AppendLine(sb.ToString());
                        }
                    }
                }

                var reverseLookUps = _foreignKeyResolverLookUps.Where(s => s.RefersToTable == _table.Name);
                foreach (var lookup in reverseLookUps)
                {
                    // A SingleTable may have foreign keys explicitly added above
                    if (singleTableResolvers.Any(a => a.RefersToTable == lookup.RefersToTable)) continue;

                    StringBuilder sb = new StringBuilder();

                    refersToTable = NameFixer.MakeSingular(lookup.TableName);
                    table = NameFixer.MakeSingular(lookup.RefersToTable);
                    using (_cb.BeginNest("public IQueryable<" + refersToTable + "> Get" + lookup.TableName + "([Parent]" + table + " " + NameFixer.ToCamelCase(table) + ", [ScopedService] AppDbContext context)"))
                    {
                        sb.Append("return context.");
                        sb.Append(lookup.TableName);
                        letter = lookup.TableName[0];
                        sb.Append(".Where(");
                        sb.Append(letter);
                        sb.Append(" => ");
                        sb.Append(letter);
                        sb.Append(".");
                        sb.Append(table);
                        sb.Append(lookup.RefersToConstraint); //The Primary Key column name - typically "Id"
                        sb.Append(" == ");
                        sb.Append(NameFixer.ToCamelCase(table));
                        sb.Append(".");
                        sb.Append(lookup.RefersToConstraint);
                        sb.Append(");");
                        _cb.AppendLine(sb.ToString());
                    }
                }
               
                foreach (var fKey in _table.ForeignKeys.Distinct())
                {
                    if (Equals(fKey.ReferencedTable(_table.DatabaseSchema), _inheritanceTable))
                        continue;

                    string fKeyTableName = NameFixer.MakeSingular(fKey.RefersToTable);
                    letter = fKeyTableName[0];

                    // When we encounter a foreign key column that doesn't map to the 'Table-Id' convention, then there could be multiple of these columns so we need to name the methods uniquely from GetSomeThing to GetSomeThing-BySomeThingID:
                    if (NameFixer.RemoveId(fKey.Columns[0]) != fKeyTableName && fKey.Columns[0].Contains("Id"))
                    {
                        using (_cb.BeginNest("public " + fKeyTableName + " Get" + fKeyTableName + "By" + fKey.Columns[0] + "([Parent]" + _table.NetName + " " + tableNamePascalCase + ", [ScopedService] AppDbContext context)", "Resolvers"))
                        {
                            _cb.AppendLine(" return context." + fKey.RefersToTable + ".FirstOrDefault(" + letter + " => " + letter + ".Id == " + tableNamePascalCase + "." + fKey.Columns[0] + ");");
                        }
                    }
                    else
                    {
                        using (_cb.BeginNest("public " + fKeyTableName + " Get" + fKeyTableName + "([Parent]" + _table.NetName + " " + tableNamePascalCase + ", [ScopedService] AppDbContext context)", "Resolvers"))
                        {                       
                            _cb.AppendLine(" return context." + fKey.RefersToTable + ".FirstOrDefault(" + letter + " => " + letter + ".Id == " + tableNamePascalCase + "." + fKey.Columns[0] + ");");
                        }
                    }
                }
            }
        }

        private void AddInput()
        {
            _cb.AppendXmlSummary("Record mapping GraphQL input to " + _table.Name + " table");
            _cb.AppendLine("public record Add" + _table.NetName + "Input(" + WriteParameterOfArgs() + ");");
            _cb.AppendLine("");
        }

        private void AddInputType()
        {
            using (_cb.BeginNest("public class Add" + _table.NetName + "InputType: InputObjectType<Add" + _table.NetName + "Input>", "Class mapping GraphQL input type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IInputObjectTypeDescriptor<Add" + _table.NetName + "Input> descriptor)", "Input Type Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents the input type for the " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WriteInputTypeDescriptors();

                    _cb.AppendLine("base.Configure(descriptor);");
                }
            }
            _cb.AppendLine("");
        }

        private void AddPayload()
        {
            _cb.AppendXmlSummary("Record mapping GraphQL input payload to " + _table.Name + " table");
            _cb.AppendLine("public record Add" + _table.NetName + "Payload(" + _table.NetName + " " + NameFixer.ToCamelCase(_table.NetName) + ");");
            _cb.AppendLine("");
        }

        private void AddPayloadType()
        {
            using (_cb.BeginNest("public class Add" + _table.NetName + "PayloadType: ObjectType<Add" + _table.NetName + "Payload>", "Class mapping GraphQL payload type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IObjectTypeDescriptor<Add" + _table.NetName + "Payload> descriptor)", "Payload Type Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents the payload to return for an added " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WritePayloadTypeDescriptor();

                    _cb.AppendLine("base.Configure(descriptor);");
                }
            }
            _cb.AppendLine("");
        }

        private string WriteParameterOfArgs()
        {
            //string howTo, string commandLine, 
            StringBuilder sb = new StringBuilder();
            DataTypeWriter dataTypeWriter = new DataTypeWriter(CodeTarget.PocoGraphGL);
            foreach (var column in _table.Columns)
            {
                if (column.IsPrimaryKey) continue;
                sb.Append(dataTypeWriter.Write(column));
                sb.Append(" ");
                sb.Append(column.Name);
                sb.Append(", ");
            }
            return sb.ToString().TrimEnd(new char[] {',',' '});
        }

        private void WriteInputTypeDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            //    .Field(c => c.HowTo)
            //    .Description("Represents the how-to for the command.");

            char letter = _table.Name[0];
            foreach (var column in _table.Columns)
            {
                if (column.IsPrimaryKey) continue;
                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");
                sb.Append(column.Name);
                sb.Append(")");
                sb.AppendLine(@".Description(""Represents the " + column.Name + " for the " + _table.NetName + @"."");");
                _cb.AppendLine(sb.ToString());
            }
        }

        private void WritePayloadTypeDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            // .Field(c => c.Id)
            // .Description("Represents the added command.");

            char letter = _table.Name[0];
            foreach (var column in _table.Columns)
            {
                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");
                sb.Append(column.Name);
                sb.Append(")");
                sb.AppendLine(@".Description(""Represents the " + column.Name + " of the added " + _table.NetName + @"."");");
                _cb.AppendLine(sb.ToString());
            }
        }

        private void WritePayloadTypeDescriptor()
        {
            // EXAMPLE OUTPUT
            //descriptor
            // .Field(c => c.command)
            // .Description("Represents the added command.");

            char letter = _table.NetName[0];
            StringBuilder sb = new StringBuilder();
            sb.Append("descriptor.Field(");
            sb.Append(letter);
            sb.Append(" => ");
            sb.Append(letter);
            sb.Append(".");
            sb.Append(NameFixer.ToCamelCase(_table.NetName));
            sb.Append(")");
            sb.AppendLine(@".Description(""Represents the added " + _table.NetName + @"."");");
            _cb.AppendLine(sb.ToString());            
        }        
    }
}
