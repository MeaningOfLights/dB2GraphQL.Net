using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using DatabaseSchemaReader.CodeGen.CodeFirst;
using DatabaseSchemaReader.CodeGen.GraphGL;
using DatabaseSchemaReader.CodeGen.NHibernate;
using DatabaseSchemaReader.CodeGen.Procedures;
using DatabaseSchemaReader.DataSchema;

namespace DatabaseSchemaReader.CodeGen
{
    /// <summary>
    /// A *simple* code generation
    /// </summary>
    public class CodeWriter
    {
        private readonly DatabaseSchema _schema;
        private string _mappingPath;
        private MappingNamer _mappingNamer;
        private readonly CodeWriterSettings _codeWriterSettings;
        private readonly ProjectVersion _projectVersion;

        /// <summary>
        /// Initializes a new instance of the <see cref="CodeWriter"/> class.
        /// </summary>
        /// <param name="schema">The schema.</param>
        public CodeWriter(DatabaseSchema schema)
            : this(schema, new CodeWriterSettings())
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="CodeWriter"/> class.
        /// </summary>
        /// <param name="schema">The schema.</param>
        /// <param name="codeWriterSettings">The code writer settings.</param>
        public CodeWriter(DatabaseSchema schema, CodeWriterSettings codeWriterSettings)
        {
            if (schema == null) throw new ArgumentNullException("schema");
            if (codeWriterSettings == null) throw new ArgumentNullException("codeWriterSettings");

            _schema = schema;
            _codeWriterSettings = codeWriterSettings;

            var vs2010 = _codeWriterSettings.WriteProjectFile;
            var vs2015 = _codeWriterSettings.WriteProjectFileNet46;
            _projectVersion = vs2015 ? ProjectVersion.Vs2015 : vs2010 ? ProjectVersion.Vs2010 : ProjectVersion.Vs2008;
            //cannot be .net 3.5
            if (IsCodeFirst() && _projectVersion == ProjectVersion.Vs2008) _projectVersion = ProjectVersion.Vs2015;

            PrepareSchemaNames.Prepare(schema, codeWriterSettings.Namer);
        }


        /// <summary>
        /// Uses the specified schema to write class files, NHibernate/EF CodeFirst mapping and a project file. Any existing files are overwritten. If not required, simply discard the mapping and project file. Use these classes as ViewModels in combination with the data access strategy of your choice.
        /// </summary>
        /// <param name="directory">The directory to write the files to. Will create a subdirectory called "mapping". The directory must exist- any files there will be overwritten.</param>
        /// <exception cref="ArgumentNullException"/>
        /// <exception cref="InvalidOperationException"/>
        /// <exception cref="IOException"/>
        /// <exception cref="UnauthorizedAccessException"/>
        /// <exception cref="System.Security.SecurityException" />
        public void Execute(DirectoryInfo directory)
        {
            if (directory == null)
                throw new ArgumentNullException("directory");
            if (!directory.Exists)
                throw new InvalidOperationException("Directory does not exist: " + directory.FullName);


            List<DatabaseConstraint> foreignKeyReverseGetLookUps = new List<DatabaseConstraint>();
            List<DatabaseConstraint> singleTableKeyResolverLookUps = new List<DatabaseConstraint>();
        StringBuilder sbDbContext = new StringBuilder();
            StringBuilder sbMutations = new StringBuilder();
            StringBuilder sbQueries = new StringBuilder();
            StringBuilder sbSubscriptions = new StringBuilder();

            var pw = CreateProjectWriter();

            InitMappingProjects(directory, pw);
            _mappingNamer = new MappingNamer();

            List<DatabaseTable> tables = GetNonSystemTables();

            if (_codeWriterSettings.CodeTarget == CodeTarget.PocoGraphGL)
            {
                foreach (var table in _schema.Tables)
                {
                    foreach (var foreignKeyChild in table.ForeignKeyChildren)
                    {
                        if (table.IsSharedPrimaryKey(foreignKeyChild)) continue;
                        foreignKeyReverseGetLookUps.Add(new DatabaseConstraint { TableName = foreignKeyChild.Name, RefersToTable = table.Name, RefersToConstraint = foreignKeyChild.PrimaryKeyColumn.Name });
                    }

                    //TO DO Combine these two ForeignKey lookups (above & below)into a single loop
                    foreach (var fKey in table.ForeignKeys)
                    {
                        string fKeyTableName = NameFixer.MakeSingular(fKey.RefersToTable);
                        // When we encounter a foreign key column that doesn't map directly (it could refer to a Single Table), then there could be multiple of these columns so we need to remove ambiguity:
                        if (NameFixer.RemoveId(fKey.Columns[0]) != fKeyTableName && fKey.Columns[0].Contains("Id"))
                        {
                            if (singleTableKeyResolverLookUps.Contains(fKey)) continue;
                            singleTableKeyResolverLookUps.Add(fKey);
                        }
                    }
                }


                sbDbContext.Append(GraphQLdBContext.GetGraphGLUsingStatements(_codeWriterSettings));
                sbDbContext.Append(GraphQLdBContext.BeginClass());

                sbMutations.Append(GraphQLMutation.GetGraphGLUsingStatements(tables, _codeWriterSettings));
                sbMutations.Append(GraphQLMutation.BeginClass());

                sbQueries.Append(GraphQLQuery.GetGraphGLUsingStatements(_codeWriterSettings));
                sbQueries.Append(GraphQLQuery.BeginClass());

                sbSubscriptions.Append(GraphQLSubscription.GetGraphGLUsingStatements(_codeWriterSettings));
                sbSubscriptions.Append(GraphQLSubscription.BeginClass());
            }


            foreach (var table in tables) //_schema.Tables)
            {
                //if (FilterIneligible(table)) continue;
                var className = table.NetName;
                UpdateEntityNames(className, table.Name);

                var cw = new ClassWriter(table, _codeWriterSettings);
                var txt = cw.Write();

                var fileName = WriteClassFile(new DirectoryInfo(directory.FullName + "\\Models"), className, txt);
                pw.AddClass(fileName);

                WriteMapping(table, pw, foreignKeyReverseGetLookUps, singleTableKeyResolverLookUps);

                if (_codeWriterSettings.CodeTarget == CodeTarget.PocoGraphGL)
                {
                    sbDbContext.Append(GraphQLdBContext.AddContext(table.Name));
                    sbMutations.Append(GraphQLMutation.AddContext(table));
                    sbQueries.Append(GraphQLQuery.AddContext(table));
                    sbSubscriptions.Append(GraphQLSubscription.AddContext(table));
                }
            }

            if (_codeWriterSettings.IncludeViews)
            {
                foreach (var view in _schema.Views)
                {
                    var className = view.NetName;
                    UpdateEntityNames(className, view.Name);

                    var cw = new ClassWriter(view, _codeWriterSettings);
                    var txt = cw.Write();

                    var fileName = WriteClassFile(directory, className, txt);
                    pw.AddClass(fileName);

                    WriteMapping(view, pw, null, null);
                }
            }


            string contextName = null;
            if (IsCodeFirst() && _codeWriterSettings.CodeTarget != CodeTarget.PocoGraphGL) contextName = WriteDbContext(directory, pw);


            //we could write functions (at least scalar functions- not table value functions)
            //you have to check the ReturnType (and remove it from the arguments collections).
            if (_codeWriterSettings.WriteStoredProcedures)
            {
                WriteStoredProcedures(directory.FullName, pw);
                WritePackages(directory.FullName, pw);
            }
            if (_codeWriterSettings.WriteUnitTest) WriteUnitTest(directory.FullName, contextName);

            if (_codeWriterSettings.CodeTarget == CodeTarget.PocoGraphGL)
            {
                sbMutations.Append(GraphQLMutation.EndClass());
                sbQueries.Append(GraphQLQuery.EndClass());
                sbSubscriptions.Append(GraphQLSubscription.EndClass());

                sbDbContext.Append(GraphQLdBContext.BeginReferentialIntegrity());
                foreach (var lookup in foreignKeyReverseGetLookUps)
                {
                    sbDbContext.Append(GraphQLdBContext.AddDBReferentialIntegrity(lookup, singleTableKeyResolverLookUps));
                }
                sbDbContext.AppendLine(GraphQLdBContext.EndReferentialIntegrity());
                sbDbContext.Append(GraphQLdBContext.EndClass());

                WriteClassFile(directory, "AppDbContext", sbDbContext.ToString());
                WriteClassFile(directory, "Mutation", sbMutations.ToString());
                WriteClassFile(directory, "Query", sbQueries.ToString());
                WriteClassFile(directory, "Subscription", sbSubscriptions.ToString());

                WriteClassFile(directory, "Program", GraphQLProjectWriter.GenerateProgramFile(_codeWriterSettings));
                WriteClassFile(directory, "Startup", GraphQLProjectWriter.GenerateStartupFile(_schema, _codeWriterSettings));
                WriteClassFile(directory, _codeWriterSettings.Namespace, GraphQLProjectWriter.GenerateProjectFile(_schema), ".csproj");
                WriteClassFile(directory, "launchSettings", GraphQLProjectWriter.GenerateLaunchSettingsFile(_codeWriterSettings), ".json");
                WriteClassFile(directory, "appsettings", GraphQLProjectWriter.GenerateAppSettings(_schema.ConnectionString), ".json");
                WriteClassFile(directory, "appsettings.Development", GraphQLProjectWriter.GenerateAppSettings(_schema.ConnectionString), ".json");

                WriteClassFile(new DirectoryInfo(directory.FullName + "\\.vscode"), "launch", GraphQLProjectWriter.GenerateLaunchDebugFile(_codeWriterSettings), ".json");
                WriteClassFile(new DirectoryInfo(directory.FullName + "\\.vscode"), "tasks", GraphQLProjectWriter.GenerateTaskDebugFile(_codeWriterSettings), ".json");
            }
            else
            {
                //The GraphQL Poco has its own .Net 6.0 csproj file
                WriteProjectFile(directory, pw);
            }
        }

        public List<DatabaseTable> GetNonSystemTables()
        {
            List<DatabaseTable> tables = new List<DatabaseTable>();
            foreach (var table in _schema.Tables)
            {
                if (FilterIneligible(table)) continue;
                tables.Add(table);
            }
            return tables;
        }
        /// <summary>
        /// Creates the project writer, using either 2008 or 2010 or VS2015 format.
        /// </summary>
        /// <returns></returns>
        private ProjectWriter CreateProjectWriter()
        {
            var pw = new ProjectWriter(_codeWriterSettings.Namespace, _projectVersion);
            return pw;
        }

        private static string WriteClassFile(DirectoryInfo directory, string className, string txt, string fileExtension = ".cs")
        {
            var fileName = className + fileExtension;
            var path = Path.Combine(directory.FullName, fileName);
            if (!directory.Exists) directory.Create();
            File.WriteAllText(path, txt);
            return fileName;
        }

        private void WriteProjectFile(DirectoryInfo directory, ProjectWriter pw)
        {
            if (_codeWriterSettings.CodeTarget == CodeTarget.PocoEfCore)
            {
                //for Core we might be project.json. 
                //Even for csproj Nuget restore is too complex so skip this.
                return;
            }
            var vs2010 = _codeWriterSettings.WriteProjectFile;
            var vs2008 = _codeWriterSettings.WriteProjectFileNet35;
            var vs2015 = _codeWriterSettings.WriteProjectFileNet46;
            if (IsCodeFirst()) vs2008 = false;
            //none selected, do nothing
            if (!vs2010 && !vs2008 && !vs2015) return;

            var projectName = _codeWriterSettings.Namespace ?? "Project";

            File.WriteAllText(
                    Path.Combine(directory.FullName, projectName + ".csproj"),
                    pw.Write());
        }

        private bool IsCodeFirst()
        {
            return _codeWriterSettings.CodeTarget == CodeTarget.PocoEntityCodeFirst ||
                _codeWriterSettings.CodeTarget == CodeTarget.PocoGraphGL ||
                _codeWriterSettings.CodeTarget == CodeTarget.PocoEfCore;
        }

        private bool FilterIneligible(DatabaseTable table)
        {
            if (!IsCodeFirst() && _codeWriterSettings.CodeTarget != CodeTarget.PocoGraphGL) return false;
            if (table.IsManyToManyTable() && _codeWriterSettings.CodeTarget == CodeTarget.PocoEntityCodeFirst)
                return true;
            if (table.PrimaryKey == null)
                return true;
            if (table.Name.Equals("__MigrationHistory", StringComparison.OrdinalIgnoreCase)) //EF 6
                return true;
            if (table.Name.Equals("__EFMigrationsHistory", StringComparison.OrdinalIgnoreCase)) //EF Core1
                return true;
            if (table.Name.Equals("EdmMetadata", StringComparison.OrdinalIgnoreCase))
                return true;
            if (table.Name.Equals("sysdiagrams", StringComparison.OrdinalIgnoreCase))
                return true;
            return false;
        }

        private void UpdateEntityNames(string className, string tableName)
        {
            if (_mappingNamer.EntityNames.Contains(className))
            {
                Debug.WriteLine("Name conflict! " + tableName + "=" + className);
            }
            else
            {
                _mappingNamer.EntityNames.Add(className);
            }
        }

        private string WriteDbContext(FileSystemInfo directory, ProjectWriter projectWriter)
        {
            var writer = new CodeFirstContextWriter(_codeWriterSettings);
            if (ProviderToSqlType.Convert(_schema.Provider) == SqlType.Oracle)
            {
                writer.IsOracle = true;
                projectWriter.AddDevartOracleReference();
            }
            var databaseTables = _schema.Tables.Where(t => !FilterIneligible(t))
                .ToList();
            if (_codeWriterSettings.IncludeViews)
            {
                databaseTables.AddRange(_schema.Views.OfType<DatabaseTable>());
            }
            var txt = writer.Write(databaseTables);
            var fileName = writer.ContextName + ".cs";
            File.WriteAllText(
                Path.Combine(directory.FullName, fileName),
                txt);
            projectWriter.AddClass(fileName);
            return writer.ContextName;
        }

        private void InitMappingProjects(FileSystemInfo directory, ProjectWriter pw)
        {
            if (_codeWriterSettings.CodeTarget == CodeTarget.Poco) return;

            var mapping = new DirectoryInfo(Path.Combine(directory.FullName, "Mapping"));
            if (!mapping.Exists) mapping.Create();
            _mappingPath = mapping.FullName;

            var packWriter = new PackagesWriter(_projectVersion);
            if (RequiresOracleManagedClient) packWriter.AddOracleManagedClient();

            //no need to reference NHibernate for HBMs
            switch (_codeWriterSettings.CodeTarget)
            {
                case CodeTarget.PocoNHibernateFluent:
                    pw.AddNHibernateReference();
                    var packs = packWriter.WriteFluentNHibernate();
                    WritePackagesConfig(directory, pw, packs);
                    break;
                case CodeTarget.PocoEntityCodeFirst:
                case CodeTarget.PocoRiaServices:
                    pw.AddEntityFrameworkReference();
                    WritePackagesConfig(directory, pw, packWriter.WriteEntityFramework());
                    break;
            }
        }

        private void WritePackagesConfig(FileSystemInfo directory, ProjectWriter pw, string xml)
        {
            pw.AddPackagesConfig();
            File.WriteAllText(
                Path.Combine(directory.FullName, "packages.config"),
                xml);
        }

        private void WriteMapping(DatabaseTable table, ProjectWriter pw, List<DatabaseConstraint> foreignKeyReverseGetLookUps, List<DatabaseConstraint> singleTableKeyResolverLookUps)
        {
            string fileName;
            switch (_codeWriterSettings.CodeTarget)
            {
                case CodeTarget.PocoNHibernateFluent:
                    fileName = WriteFluentMapping(table);
                    pw.AddClass(@"Mapping\" + fileName);
                    break;
                case CodeTarget.PocoNHibernateHbm:
                    //TPT subclasses are mapped in base class
                    if (table.FindInheritanceTable() != null) return;
                    var mw = new NHibernate.MappingWriter(table, _codeWriterSettings);
                    var txt = mw.Write();

                    fileName = table.NetName + ".hbm.xml";
                    var path = Path.Combine(_mappingPath, fileName);
                    File.WriteAllText(path, txt);
                    pw.AddMap(@"mapping\" + fileName);
                    break;
                case CodeTarget.PocoEntityCodeFirst:
                case CodeTarget.PocoRiaServices:
                case CodeTarget.PocoEfCore:
                    var cfmw = new CodeFirstMappingWriter(table, _codeWriterSettings, _mappingNamer);
                    var cfmap = cfmw.Write();

                    fileName = cfmw.MappingClassName + ".cs";

                    var filePath = Path.Combine(_mappingPath, fileName);
                    File.WriteAllText(filePath, cfmap);
                    pw.AddClass(@"Mapping\" + fileName);
                    break;
                case CodeTarget.PocoGraphGL:
                    fileName = WriteGraphQLMapping(table, foreignKeyReverseGetLookUps, singleTableKeyResolverLookUps);
                    pw.AddClass(@"Mapping\" + fileName);
                    break;
            }
        }

        private string WriteFluentMapping(DatabaseTable table)
        {
            var fluentMapping = new FluentMappingWriter(table, _codeWriterSettings, _mappingNamer);
            var txt = fluentMapping.Write();
            var fileName = fluentMapping.MappingClassName + ".cs";
            var path = Path.Combine(_mappingPath, fileName);
            File.WriteAllText(path, txt);
            return fileName;
        }

        private string WriteGraphQLMapping(DatabaseTable table, List<DatabaseConstraint> foreignKeyReverseGetLookUps, List<DatabaseConstraint> _singleTableKeyResolverLookUps)
        {
            var graphQLMapping = new GraphGLMappingWriter(table, _codeWriterSettings, _mappingNamer, foreignKeyReverseGetLookUps, _singleTableKeyResolverLookUps);
            var txt = graphQLMapping.Write();
            var fileName = graphQLMapping.MappingClassName + ".cs";
            var path = Path.Combine(_mappingPath, fileName);
            File.WriteAllText(path, txt);
            return fileName;

        }
        private void WriteStoredProcedures(string directoryFullName, ProjectWriter pw)
        {
            if (!_schema.StoredProcedures.Any()) return;

            //we'll put stored procedures in a "Procedures" subdirectory
            const string procedures = "Procedures";
            var commands = new DirectoryInfo(Path.Combine(directoryFullName, procedures));
            if (!commands.Exists) commands.Create();
            var ns = _codeWriterSettings.Namespace;
            if (!string.IsNullOrEmpty(ns)) ns += "." + procedures;

            foreach (var sproc in _schema.StoredProcedures)
            {
                WriteStoredProcedure(procedures, commands.FullName, ns, sproc, pw);
            }
        }

        private bool RequiresOracleManagedClient
        {
            get
            {
                var provider = _schema.Provider;
                if (provider == null) return false;
                return provider.StartsWith("Oracle.ManagedDataAccess", StringComparison.OrdinalIgnoreCase);
            }
        }

        private void WriteStoredProcedure(string procedures, string directoryPath, string @namespace, DatabaseStoredProcedure sproc, ProjectWriter pw)
        {
            //if no .net classname, don't process
            if (string.IsNullOrEmpty(sproc.NetName)) return;

            var sw = new SprocWriter(sproc, @namespace);
            var txt = sw.Write();
            var fileName = sproc.NetName + ".cs";
            var path = Path.Combine(directoryPath, fileName);
            File.WriteAllText(path, txt);
            pw.AddClass(procedures + @"\" + fileName);
            if (sw.RequiresOracleReference)
            {
                if (sw.RequiresDevartOracleReference)
                    pw.AddDevartOracleReference();
                else if (RequiresOracleManagedClient)
                    pw.AddOracleManagedReference();
                else
                    pw.AddOracleReference();
            }

            if (sw.HasResultClass)
            {
                var rs = new SprocResultWriter(sproc, @namespace);
                txt = rs.Write();
                fileName = rs.ClassName + ".cs";
                path = Path.Combine(directoryPath, fileName);
                File.WriteAllText(path, txt);
                pw.AddClass(procedures + @"\" + fileName);
            }
        }

        private void WritePackages(string directoryFullName, ProjectWriter pw)
        {
            foreach (var package in _schema.Packages)
            {
                if (string.IsNullOrEmpty(package.NetName)) continue;
                if (package.StoredProcedures.Count == 0) continue;

                WritePackage(package, directoryFullName, pw);
            }
        }

        private void WritePackage(DatabasePackage package, string directoryFullName, ProjectWriter pw)
        {
            //we'll put stored procedures in subdirectory
            var packDirectory = new DirectoryInfo(Path.Combine(directoryFullName, package.NetName));
            if (!packDirectory.Exists) packDirectory.Create();
            var ns = _codeWriterSettings.Namespace;
            if (!string.IsNullOrEmpty(ns)) ns += "." + package.NetName;

            foreach (var sproc in package.StoredProcedures)
            {
                WriteStoredProcedure(package.NetName, packDirectory.FullName, ns, sproc, pw);
            }
        }

        private void WriteUnitTest(string directoryFullName, string contextName)
        {
            var tw = new UnitTestWriter(_schema, _codeWriterSettings);
            if (!string.IsNullOrEmpty(contextName)) tw.ContextName = contextName;
            var txt = tw.Write();
            if (string.IsNullOrEmpty(txt)) return;
            var fileName = tw.ClassName + ".cs";
            var path = Path.Combine(directoryFullName, fileName);
            File.WriteAllText(path, txt);
            //not included in project as this is just for demo
        }
    }
}
