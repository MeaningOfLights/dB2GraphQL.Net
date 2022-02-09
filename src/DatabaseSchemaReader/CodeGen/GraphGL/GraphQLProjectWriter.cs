using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Xml.Linq;
using DatabaseSchemaReader.DataSchema;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLProjectWriter
    {
        public static string GetGraphGLProjectUsingStatements(List<DatabaseTable> tablesInSchema, CodeWriterSettings codeWriterSettings)
        {
            StringBuilder sb = new StringBuilder();
            foreach (var table in tablesInSchema)
            {
                sb.AppendLine("using " + codeWriterSettings.Namespace + "." + table.Name + ";");
            }
            return sb.ToString();
        }
        public static string GenerateAppSettings(string connString)
        {
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\appsettings.json.txt"));
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine(@"""Logging"": {");
            sb.AppendLine(@"  ""LogLevel"": {");
            sb.AppendLine(@"    ""Default"": ""Information"",");
            sb.AppendLine(@"    ""Microsoft"": ""Warning"",");
            sb.AppendLine(@"    ""Microsoft.Hosting.Lifetime"": ""Information""");
            sb.AppendLine(@"  }");
            sb.AppendLine(@"},");
            sb.AppendLine(@"""ConnectionStrings"": {");
            //For Databases that are file paths be sure to escape the slashes
            if (connString.Contains(":\\")) connString = connString.Replace(@"\", @"\\");
            sb.AppendLine(@"  ""CommandConStr"" : """ + connString + @"""");
            //sb.AppendLine(@"  ""CommandConStr"" : ""Server=.;Database=CommandsDBGraphql;Integrated Security=True; """);
            sb.AppendLine(" }");
            sb.AppendLine("}");
            return sb.ToString();
        }

        public static string GenerateProgramFile(CodeWriterSettings codeWriterSettings)
        {
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\Program.cs.txt"));
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("global using System;");
            sb.AppendLine("using System.Collections.Generic;");
            sb.AppendLine("using System.Linq;");
            sb.AppendLine("using System.Threading.Tasks;");
            sb.AppendLine("using Microsoft.AspNetCore.Hosting;");
            sb.AppendLine("using Microsoft.Extensions.Configuration;");
            sb.AppendLine("using Microsoft.Extensions.Hosting;");
            sb.AppendLine("using Microsoft.Extensions.Logging;");
            sb.AppendLine("");
            sb.AppendLine("namespace " + codeWriterSettings.Namespace);
            sb.AppendLine("{");
            sb.AppendLine("    public class Program");
            sb.AppendLine("    {");
            sb.AppendLine("        public static void Main(string[] args)");
            sb.AppendLine("        {");
            sb.AppendLine("            CreateHostBuilder(args).Build().Run();");
            sb.AppendLine("        }");
            sb.AppendLine("");
            sb.AppendLine("        public static IHostBuilder CreateHostBuilder(string[] args) =>");
            sb.AppendLine("            Host.CreateDefaultBuilder(args)");
            sb.AppendLine("              .ConfigureWebHostDefaults(webBuilder =>");
            sb.AppendLine("              {");
            sb.AppendLine("                 webBuilder.UseStartup<Startup>();");
            sb.AppendLine("              });");
            sb.AppendLine("    }");
            sb.AppendLine("}");


            return sb.ToString();
        }

        public static string GenerateStartupFile(DatabaseSchema databaseSchema, CodeWriterSettings codeWriterSettings)
        {
            List<DatabaseTable> tablesInSchema = databaseSchema.Tables;
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\Startup.cs.txt"));
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("using System;");
            sb.AppendLine("using System.Collections.Generic;");
            sb.AppendLine("using System.Linq;");
            sb.AppendLine("using System.Threading.Tasks;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Models;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Data;");
            sb.AppendLine(GetGraphGLProjectUsingStatements(tablesInSchema, codeWriterSettings));

            sb.AppendLine("using GraphQL.Server.Ui.Voyager;");
            sb.AppendLine("using Microsoft.AspNetCore.Builder;");
            sb.AppendLine("using Microsoft.AspNetCore.Hosting;");
            sb.AppendLine("using Microsoft.AspNetCore.Http;");
            sb.AppendLine("using Microsoft.EntityFrameworkCore;");
            sb.AppendLine("using Microsoft.Extensions.Configuration;");
            sb.AppendLine("using Microsoft.Extensions.DependencyInjection;");
            sb.AppendLine("using Microsoft.Extensions.Hosting;");
            sb.AppendLine("");
            sb.AppendLine("namespace " + codeWriterSettings.Namespace);
            sb.AppendLine("{");
            sb.AppendLine("    //https://localhost:5001/ui/voyager  and");
            sb.AppendLine("    //https://localhost:5001/graphql/");
            sb.AppendLine("");
            sb.AppendLine("    public class Startup");
            sb.AppendLine("    {");
            sb.AppendLine("        private readonly IConfiguration Configuration;");
            sb.AppendLine("");
            sb.AppendLine("        public Startup(IConfiguration configuration)");
            sb.AppendLine("        {");
            sb.AppendLine("            Configuration = configuration;");
            sb.AppendLine("        }");
            sb.AppendLine("");
            sb.AppendLine("        public void ConfigureServices(IServiceCollection services)");
            sb.AppendLine("        {");

            switch (ProviderToSqlType.Convert(databaseSchema.Provider))
            {
                case SqlType.SqlServer:
                    sb.AppendLine("            services.AddPooledDbContextFactory<AppDbContext>(opt => opt.UseSqlServer");
                    sb.AppendLine(@"            (Configuration.GetConnectionString(""CommandConStr"")));");
                    break;
                case SqlType.PostgreSql:
                    sb.AppendLine("            services.AddPooledDbContextFactory<AppDbContext>(opt => opt.UseNpgsql");
                    sb.AppendLine(@"           (Configuration.GetConnectionString(""CommandConStr"")));");
                    break;
                case SqlType.SQLite:
                    sb.AppendLine("            services.AddPooledDbContextFactory<AppDbContext>(opt => opt.UseSqlite");
                    sb.AppendLine(@"            (Configuration.GetConnectionString(""CommandConStr"")));");
                    break;
                default:
                    break;
            }
            sb.AppendLine("");
            sb.AppendLine("            services");
            sb.AppendLine("             .AddGraphQLServer()");
            sb.AppendLine("             .AddQueryType<Query>()");
            sb.AppendLine("             .AddMutationType<Mutation>()");
            sb.AppendLine("             .AddSubscriptionType<Subscription>()");

            foreach(var table in tablesInSchema)
            {  
              sb.AppendLine("             .AddType<" + table.NetName + "Type>()");
              sb.AppendLine("             .AddType<Add" + table.NetName + "InputType>()");
              sb.AppendLine("             .AddType<Add" + table.NetName + "PayloadType>()");
            }
 
            sb.AppendLine("              .AddProjections()");
            sb.AppendLine("              .AddFiltering()");
            sb.AppendLine("              .AddSorting()");
            sb.AppendLine("              .AddInMemorySubscriptions();");
            sb.AppendLine("        }");
            sb.AppendLine("");
            sb.AppendLine("        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)");
            sb.AppendLine("        {");
            sb.AppendLine("            if (env.IsDevelopment())");
            sb.AppendLine("            {");
            sb.AppendLine("             app.UseDeveloperExceptionPage();");
            sb.AppendLine("            }");
            sb.AppendLine("");
            sb.AppendLine("            app.UseWebSockets();");
            sb.AppendLine("");
            sb.AppendLine("            app.UseRouting();");
            sb.AppendLine("");
            sb.AppendLine("            app.UseEndpoints(endpoints =>");
            sb.AppendLine("            {");
            sb.AppendLine("             endpoints.MapGraphQL();");
            sb.AppendLine("            });");
            sb.AppendLine("");
            sb.AppendLine(@"            app.UseGraphQLVoyager(""/ui/voyager"");");
            sb.AppendLine("        }");
            sb.AppendLine("    }");
            sb.AppendLine("}");

            return sb.ToString();
        }


        public static string GenerateProjectFile(DatabaseSchema databaseSchema)
        {
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\Project.csproj.txt"));
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(@"<Project Sdk = ""Microsoft.NET.Sdk.Web"">");
            sb.AppendLine(@"");
            sb.AppendLine(@"  <PropertyGroup>");
            sb.AppendLine(@"    <TargetFramework>net6.0</TargetFramework>");
            sb.AppendLine(@"  </PropertyGroup>");
            sb.AppendLine(@"");
            sb.AppendLine(@"  <ItemGroup>");
            sb.AppendLine(@"    <PackageReference Include = ""GraphQL.Server.Ui.Voyager"" Version=""5.2.0"" />");
            sb.AppendLine(@"    <PackageReference Include = ""HotChocolate.AspNetCore"" Version=""12.6.0"" />");
            sb.AppendLine(@"    <PackageReference Include = ""HotChocolate.Data.Entityframework"" Version=""12.6.0"" />");
            sb.AppendLine(@"    <PackageReference Include = ""Microsoft.EntityFrameworkCore"" Version=""6.0.1"" /> ");
            sb.AppendLine(@"    <PackageReference Include = ""Microsoft.EntityFrameworkCore.Design"" Version=""6.0.1"" > ");
            sb.AppendLine(@"      <PrivateAssets>all</PrivateAssets>");
            sb.AppendLine(@"      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>");
            sb.AppendLine(@"    </PackageReference>");


            switch (ProviderToSqlType.Convert(databaseSchema.Provider))
            {
                case SqlType.SqlServer:
                    sb.AppendLine(@"    <PackageReference Include = ""Microsoft.EntityframeworkCore.SqlServer"" Version=""6.0.1"" />");
                    break;
                case SqlType.PostgreSql:
                    sb.AppendLine(@"    <PackageReference Include = ""Npgsql.EntityFrameworkCore.PostgreSQL"" Version = ""6.0.3"" /> ");
                    break;
                case SqlType.SQLite:
                    sb.AppendLine(@"    <PackageReference Include = ""Microsoft.EntityframeworkCore.Sqlite"" Version=""6.0.1"" />");
                    break;
                default:
                    break;
            }


            sb.AppendLine(@"  </ItemGroup>");
            sb.AppendLine(@"");
            sb.AppendLine(@"</Project>");
            return sb.ToString();
        }
        public static string GenerateLaunchSettingsFile(CodeWriterSettings codeWriterSettings)
        {
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\launchSettings.json.txt"));
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(@"{");
            sb.AppendLine(@"  ""iisSettings"": {");
            sb.AppendLine(@"    ""windowsAuthentication"": false,");
            sb.AppendLine(@"    ""anonymousAuthentication"": true,");
            sb.AppendLine(@"    ""iisExpress"": {");
            sb.AppendLine(@"      ""applicationUrl"": ""http://localhost:50760"",");
            sb.AppendLine(@"      ""sslPort"": 44379");
            sb.AppendLine(@"    }");
            sb.AppendLine(@"  },");
            sb.AppendLine(@"  ""profiles"": {");
            sb.AppendLine(@"    ""IIS Express"": {");
            sb.AppendLine(@"      ""commandName"": ""IISExpress"",");
            sb.AppendLine(@"      ""launchBrowser"": true,");
            // this is done in the Launch.json Debug file - sb.AppendLine(@"      ""launchUrl"": ""graphql"",");
            sb.AppendLine(@"      ""environmentVariables"": {");
            sb.AppendLine(@"        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            sb.AppendLine(@"      }");
            sb.AppendLine(@"    },");
            sb.AppendLine(@"    """ + codeWriterSettings.Namespace + @""": {");
            sb.AppendLine(@"      ""commandName"": ""Project"",");
            sb.AppendLine(@"      ""dotnetRunMessages"": ""true"",");
            sb.AppendLine(@"      ""launchBrowser"": true,");
            sb.AppendLine(@"      ""applicationUrl"": ""https://localhost:5001;http://localhost:5000"",");
            sb.AppendLine(@"      ""environmentVariables"": {");
            sb.AppendLine(@"        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            sb.AppendLine(@"      }");
            sb.AppendLine(@"    }");
            sb.AppendLine(@"  }");
            sb.AppendLine(@"}");

            return sb.ToString();
        }


        public static string GenerateLaunchDebugFile(CodeWriterSettings codeWriterSettings)
        {
            //return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\launch.json.txt")).Replace("<NAMESPACE>", codeWriterSettings.Namespace);
            StringBuilder sb = new StringBuilder();

            //sb.AppendLine(@"{");
            //sb.AppendLine(@"""version"": ""0.2.0"",");
            //sb.AppendLine(@"   ""configurations"": [");
            //sb.AppendLine(@"        {");
            //sb.AppendLine(@"                    ""name"": "".NET Core Launch (web)"",");
            //sb.AppendLine(@"            ""type"": ""coreclr"",");
            //sb.AppendLine(@"            ""request"": ""launch"",");
            //sb.AppendLine(@"            ""preLaunchTask"": ""build"",");
            //sb.AppendLine(@"            // If you have changed target frameworks, make sure to update the program path.");
            //sb.AppendLine(@"            ""program"": ""${workspaceFolder}/bin/Debug/net6.0/" + codeWriterSettings.Namespace + @".dll"",");
            //sb.AppendLine(@"            ""args"": [],");
            //sb.AppendLine(@"            ""cwd"": ""${workspaceFolder}"",");
            //sb.AppendLine(@"            ""stopAtEntry"": false,");
            //sb.AppendLine(@"            ""internalConsoleOptions"": ""openOnSessionStart"",");
            //sb.AppendLine(@"            ""launchBrowser"": {");
            //sb.AppendLine(@"                        ""enabled"": true,");
            //sb.AppendLine(@"                ""args"": ""${auto-detect-url}"",");
            //sb.AppendLine(@"                ""windows"": {");
            //sb.AppendLine(@"                            ""command"": ""cmd.exe"",");
            //sb.AppendLine(@"                    ""args"": ""/C start ${auto-detect-url}""");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"                ""osx"": {");
            //sb.AppendLine(@"                            ""command"": ""open""");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"                ""linux"": {");
            //sb.AppendLine(@"                            ""command"": ""xdg-open""");
            //sb.AppendLine(@"                }");
            //sb.AppendLine(@"                    },");
            //sb.AppendLine(@"            ""env"": {");
            //sb.AppendLine(@"                        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            //sb.AppendLine(@"            },");
            //sb.AppendLine(@"            ""sourceFileMap"": {");
            //sb.AppendLine(@"                        ""/Views"": ""${workspaceFolder}/Views""");
            //sb.AppendLine(@"            }");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"        {");
            //sb.AppendLine(@"                    ""name"": "".NET Core Launch - Chrome"",");
            //sb.AppendLine(@"            ""type"": ""coreclr"",");
            //sb.AppendLine(@"            ""request"": ""launch"",");
            //sb.AppendLine(@"            ""preLaunchTask"": ""build"",");
            //sb.AppendLine(@"            // If you have changed target frameworks, make sure to update the program path.");
            //sb.AppendLine(@"            ""program"": ""${workspaceFolder}/bin/Debug/net6.0/" + codeWriterSettings.Namespace + @".dll"",");
            //sb.AppendLine(@"            ""args"": [],");
            //sb.AppendLine(@"            ""cwd"": ""${workspaceFolder}"",");
            //sb.AppendLine(@"            ""stopAtEntry"": false,");
            //sb.AppendLine(@"            ""internalConsoleOptions"": ""openOnSessionStart"",");
            //sb.AppendLine(@"            ""launchBrowser"": {");
            //sb.AppendLine(@"                        ""enabled"": true,");
            //sb.AppendLine(@"                ""args"": ""${auto-detect-url}"",");
            //sb.AppendLine(@"                ""windows"": {");
            //sb.AppendLine(@"                            ""command"": ""cmd.exe"",");
            //sb.AppendLine(@"                    ""args"": ""/C start \""\"" \""C:/Program Files (x86)/Google/Chrome/Application/chrome.exe\"" ${auto-detect-url}""");
            //sb.AppendLine(@"                }");
            //sb.AppendLine(@"                    },");
            //sb.AppendLine(@"            ""env"": {");
            //sb.AppendLine(@"                        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            //sb.AppendLine(@"            },");
            //sb.AppendLine(@"            ""sourceFileMap"": {");
            //sb.AppendLine(@"                        ""/Views"": ""${workspaceFolder}/Views""");
            //sb.AppendLine(@"            }");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"        {");
            //sb.AppendLine(@"                    ""name"": "".NET Core Launch - Firefox"",");
            //sb.AppendLine(@"            ""type"": ""coreclr"",");
            //sb.AppendLine(@"            ""request"": ""launch"",");
            //sb.AppendLine(@"            ""preLaunchTask"": ""build"",");
            //sb.AppendLine(@"            // If you have changed target frameworks, make sure to update the program path.");
            //sb.AppendLine(@"            ""program"": ""${workspaceFolder}/bin/Debug/net6.0/" + codeWriterSettings.Namespace + @".dll"",");
            //sb.AppendLine(@"            ""args"": [],");
            //sb.AppendLine(@"            ""cwd"": ""${workspaceFolder}"",");
            //sb.AppendLine(@"            ""stopAtEntry"": false,");
            //sb.AppendLine(@"            ""internalConsoleOptions"": ""openOnSessionStart"",");
            //sb.AppendLine(@"            ""launchBrowser"": {");
            //sb.AppendLine(@"                        ""enabled"": true,");
            //sb.AppendLine(@"                ""args"": ""${auto-detect-url}"",");
            //sb.AppendLine(@"                ""windows"": {");
            //sb.AppendLine(@"                            ""command"": ""cmd.exe"",");
            //sb.AppendLine(@"                    ""args"": ""/C start \""\"" \""C:/Program Files/Mozilla Firefox/firefox.exe\"" ${auto-detect-url}""");
            //sb.AppendLine(@"                }");
            //sb.AppendLine(@"                    },");
            //sb.AppendLine(@"            ""env"": {    ");
            //sb.AppendLine(@"                        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            //sb.AppendLine(@"            },");
            //sb.AppendLine(@"            ""sourceFileMap"": {");
            //sb.AppendLine(@"                        ""/Views"": ""${workspaceFolder}/Views""");
            //sb.AppendLine(@"            }");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"        {");
            //sb.AppendLine(@"                    ""name"": "".NET Core Launch - IE"", ");
            //sb.AppendLine(@"            ""type"": ""coreclr"",");
            //sb.AppendLine(@"            ""request"": ""launch"", ");
            //sb.AppendLine(@"            ""preLaunchTask"": ""build"",");
            //sb.AppendLine(@"            // If you have changed target frameworks, make sure to update the program path.");
            //sb.AppendLine(@"            ""program"": ""${workspaceFolder}/bin/Debug/net6.0/" + codeWriterSettings.Namespace + @".dll"",");
            //sb.AppendLine(@"            ""args"": [], ");
            //sb.AppendLine(@"            ""cwd"": ""${workspaceFolder}"",");
            //sb.AppendLine(@"            ""stopAtEntry"": false, ");
            //sb.AppendLine(@"            ""internalConsoleOptions"": ""openOnSessionStart"",");
            //sb.AppendLine(@"            ""launchBrowser"": {");
            //sb.AppendLine(@"                        ""enabled"": true,");
            //sb.AppendLine(@"                ""args"": ""${auto-detect-url}"",");
            //sb.AppendLine(@"                ""windows"": {");
            //sb.AppendLine(@"                            ""command"": ""cmd.exe"", ");
            //sb.AppendLine(@"                    ""args"": ""/C start \""\"" \""C:/Program Files/internet explorer/iexplore.exe\"" ${auto-detect-url}""");
            //sb.AppendLine(@"                }");
            //sb.AppendLine(@"                    },");
            //sb.AppendLine(@"            ""env"": {");
            //sb.AppendLine(@"                        ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            //sb.AppendLine(@"            },");
            //sb.AppendLine(@"            ""sourceFileMap"": {");
            //sb.AppendLine(@"                        ""/Views"": ""${workspaceFolder}/Views""");
            //sb.AppendLine(@"            }");
            //sb.AppendLine(@"                },");
            //sb.AppendLine(@"        {");
            //sb.AppendLine(@"                    ""name"": "".NET Core Attach"", ");
            //sb.AppendLine(@"            ""type"": ""coreclr"",");
            //sb.AppendLine(@"            ""request"": ""attach"", ");
            //sb.AppendLine(@"            ""processId"": ""${command:pickProcess}""");
            //sb.AppendLine(@"        }");
            //sb.AppendLine(@"    ]");
            //sb.AppendLine(@"}");

            sb.AppendLine(@"{");
            sb.AppendLine(@"   // Use IntelliSense to find out which attributes exist for C# debugging");
            sb.AppendLine(@"   // Use hover for the description of the existing attributes");
            sb.AppendLine(@"   // For further information visit https://github.com/OmniSharp/omnisharp-vscode/blob/master/debugger-launchjson.md");
            sb.AppendLine(@"   ""version"": ""0.2.0"",");
            sb.AppendLine(@"   ""configurations"": [");
            sb.AppendLine(@"        {");
            sb.AppendLine(@"            ""name"": "".NET Core Launch (web)"", ");
            sb.AppendLine(@"            ""type"": ""coreclr"",");
            sb.AppendLine(@"            ""request"": ""launch"", ");
            sb.AppendLine(@"            ""preLaunchTask"": ""build"",");
            sb.AppendLine(@"            // If you have changed target frameworks, make sure to update the program path.");
            sb.AppendLine(@"            ""program"": ""${workspaceFolder}/bin/Debug/net6.0/" + codeWriterSettings.Namespace + @".dll"",");
            sb.AppendLine(@"            ""args"": [], ");
            sb.AppendLine(@"            ""cwd"": ""${workspaceFolder}"",");
            sb.AppendLine(@"            ""stopAtEntry"": false, ");
            sb.AppendLine(@"            """"launchBrowser"": {");
            sb.AppendLine(@"            ""    ""enabled"": true,");
            sb.AppendLine(@"            ""    ""args"": ""http://localhost:5000/graphql"",");
            sb.AppendLine(@"            ""    ""windows"": {");
            sb.AppendLine(@"            ""        ""command"": ""cmd.exe"",");
            sb.AppendLine(@"            ""        ""args"": ""/C start http://localhost:5000/graphql""");
            sb.AppendLine(@"            ""    },");
            sb.AppendLine(@"            ""    ""osx"": {");
            sb.AppendLine(@"            ""        ""command"": ""open""");
            sb.AppendLine(@"            ""    },");
            sb.AppendLine(@"            ""    ""linux"": {");
            sb.AppendLine(@"            ""        ""command"": ""xdg-open""");
            sb.AppendLine(@"            ""    }");
            sb.AppendLine(@"            ""},");
            sb.AppendLine(@"            // Enable launching a web browser when ASP.NET Core starts. For more information: https://aka.ms/VSCode-CS-LaunchJson-WebBrowser");
            sb.AppendLine(@"            ""serverReadyAction"": {");
            sb.AppendLine(@"                ""action"": ""openExternally"",");
            sb.AppendLine(@"                ""pattern"": ""\\bNow listening on:\\s+(https?://\\S+)""");
            sb.AppendLine(@"            },");
            sb.AppendLine(@"            ""env"": {");
            sb.AppendLine(@"                ""ASPNETCORE_ENVIRONMENT"": ""Development""");
            sb.AppendLine(@"            },");
            sb.AppendLine(@"            ""sourceFileMap"": {");
            sb.AppendLine(@"                ""/Views"": ""${workspaceFolder}/Views""");
            sb.AppendLine(@"            }");
            sb.AppendLine(@"        },");
            sb.AppendLine(@"        {");
            sb.AppendLine(@"            ""name"": "".NET Core Attach"", ");
            sb.AppendLine(@"            ""type"": ""coreclr"",");
            sb.AppendLine(@"            ""request"": ""attach"", ");
            sb.AppendLine(@"            ""processId"": ""${command:pickProcess}""");
            sb.AppendLine(@"        }");
            sb.AppendLine(@"    ]");
            sb.AppendLine(@"}");


            return sb.ToString();
        }
        public static string GenerateTaskDebugFile(CodeWriterSettings codeWriterSettings)
        {
        //        return File.ReadAllText(Path.Combine(Directory.GetCurrentDirectory(), "\\tasks.json.txt")).Replace("<NAMESPACE>", codeWriterSettings.Namespace);

        StringBuilder sb = new StringBuilder();
            sb.AppendLine(@"{");
            sb.AppendLine(@"    ""version"": ""2.0.0"",");
            sb.AppendLine(@"    ""tasks"": [");
            sb.AppendLine(@"        {");
            sb.AppendLine(@"            ""label"": ""build"",");
            sb.AppendLine(@"            ""command"": ""dotnet"",");
            sb.AppendLine(@"            ""type"": ""process"",");
            sb.AppendLine(@"            ""args"": [");
            sb.AppendLine(@"                ""build"",");
            sb.AppendLine(@"                ""${workspaceFolder}/" + codeWriterSettings.Namespace + @".csproj"",");
            sb.AppendLine(@"                ""/property:GenerateFullPaths=true"",");
            sb.AppendLine(@"                ""/consoleloggerparameters:NoSummary""");
            sb.AppendLine(@"            ],");
            sb.AppendLine(@"            ""problemMatcher"": ""$msCompile""");
            sb.AppendLine(@"        },");
            sb.AppendLine(@"        {");
            sb.AppendLine(@"            ""label"": ""publish"",");
            sb.AppendLine(@"            ""command"": ""dotnet"",");
            sb.AppendLine(@"            ""type"": ""process"",");
            sb.AppendLine(@"            ""args"": [");
            sb.AppendLine(@"                ""publish"",");
            sb.AppendLine(@"                ""${workspaceFolder}/" + codeWriterSettings.Namespace + @".csproj"",");
            sb.AppendLine(@"                ""/property:GenerateFullPaths=true"",");
            sb.AppendLine(@"                ""/consoleloggerparameters:NoSummary""");
            sb.AppendLine(@"            ],");
            sb.AppendLine(@"            ""problemMatcher"": ""$msCompile""");
            sb.AppendLine(@"        },");
            sb.AppendLine(@"        {");
            sb.AppendLine(@"            ""label"": ""watch"",");
            sb.AppendLine(@"            ""command"": ""dotnet"",");
            sb.AppendLine(@"            ""type"": ""process"",");
            sb.AppendLine(@"            ""args"": [");
            sb.AppendLine(@"                ""watch"",");
            sb.AppendLine(@"                ""run"",");
            sb.AppendLine(@"                ""${workspaceFolder}/" + codeWriterSettings.Namespace + @".csproj"",");
            sb.AppendLine(@"                ""/property:GenerateFullPaths=true"",");
            sb.AppendLine(@"                ""/consoleloggerparameters:NoSummary""");
            sb.AppendLine(@"            ],");
            sb.AppendLine(@"            ""problemMatcher"": ""$msCompile""");
            sb.AppendLine(@"        }");
            sb.AppendLine(@"    ]");
            sb.AppendLine(@"}");
            return sb.ToString();
        }

    }
}
