using DatabaseSchemaReader.DataSchema;
using System;
using System.Collections.Generic;
using System.Text;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLMutation
    {
        public static string GetGraphGLUsingStatements(List<DatabaseTable> tablesInSchema, CodeWriterSettings codeWriterSettings)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("using System.Threading;");
            sb.AppendLine("using System.Threading.Tasks;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Data;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Models;");

            sb.AppendLine(GraphQLProjectWriter.GetGraphGLProjectUsingStatements(tablesInSchema, codeWriterSettings));
            
            sb.AppendLine("using HotChocolate;");
            sb.AppendLine("using HotChocolate.Data;");
            sb.AppendLine("using HotChocolate.Subscriptions;");
            sb.AppendLine("");

            sb.AppendLine("namespace " + codeWriterSettings.Namespace);
            return sb.ToString();
        }
        public static string BeginClass()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("    /// <summary>");
            sb.AppendLine("    /// Represents the mutations available.");
            sb.AppendLine("    /// </summary>");
            sb.AppendLine(@"    [GraphQLDescription(""Represents the mutations available."")]");
            sb.AppendLine("    public class Mutation");
            sb.AppendLine("    {");
            return sb.ToString();
        }
        public static string EndClass()
        {
            StringBuilder sb = new StringBuilder();         
            sb.AppendLine("    }");
            sb.AppendLine("}");
            return sb.ToString();
        }
        public static string AddContext(DatabaseTable table)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("        /// <summary>");
            sb.AppendLine(@"        /// Adds a <see cref=""" + table.NetName + @"""/> based on <paramref name=""input""/>.");
            sb.AppendLine("        /// </summary>");
            sb.AppendLine(@"        /// <param name=""input"">The <see cref=""Add" + table.NetName + @"Input""/>.</param>");
            sb.AppendLine(@"        /// <param name=""context"">The <see cref=""AppDbContext""/>.</param>");
            sb.AppendLine(@"        /// <param name=""eventSender"">The <see cref=""ITopicEventSender""/>.</param>");
            sb.AppendLine(@"        /// <param name=""cancellationToken"">The <see cref=""CancellationToken""/>.</param>");
            sb.AppendLine(@"        /// <returns>The added <see cref=""" + table.NetName + @"""/>.</returns>");
            sb.AppendLine("        [UseDbContext(typeof(AppDbContext))]");
            sb.AppendLine(@"        [GraphQLDescription(""Adds a " + table.NetName + @"."")]");
            sb.AppendLine("        public async Task<Add" + table.NetName + "Payload> Add" + table.NetName + "Async(Add" + table.NetName + "Input input, [ScopedService] AppDbContext context, [Service] ITopicEventSender eventSender, CancellationToken cancellationToken)");
            sb.AppendLine("        {");
            sb.AppendLine("            var " + NameFixer.ToCamelCase(table.NetName) + " = new  Models." + table.NetName);
            sb.AppendLine("            {");
            sb.Append(AddMutationParameters(table));
            sb.AppendLine("            };");
            sb.AppendLine("            context." + table.Name + ".Add(" + NameFixer.ToCamelCase(table.NetName) + ");");
            sb.AppendLine("            await context.SaveChangesAsync(cancellationToken);");
            sb.AppendLine("            await eventSender.SendAsync(nameof(Subscription.On" + table.NetName + "Added), " + NameFixer.ToCamelCase(table.NetName) + ", cancellationToken);");
            sb.AppendLine("            return new Add" + table.NetName + "Payload(" + NameFixer.ToCamelCase(table.NetName) + ");");
            sb.AppendLine("        }");
            sb.AppendLine("");
            return sb.ToString();

        }
        private static string AddMutationParameters(DatabaseTable table)
        {
            StringBuilder sb = new StringBuilder();
            foreach(var column in table.Columns)
            {
                if (column.IsPrimaryKey) continue;
                sb.Append("                ");
                sb.Append(column.Name);
                sb.Append(" = ");
                sb.Append("input.");
                sb.Append(column.Name);
                sb.AppendLine(",");
            }
            return sb.ToString().TrimEnd(',', '\r','\n') + Environment.NewLine;
        }
    }
}
