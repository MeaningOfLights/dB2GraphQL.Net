using DatabaseSchemaReader.DataSchema;
using System.Text;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLSubscription
    {
        public static string GetGraphGLUsingStatements(CodeWriterSettings codeWriterSettings)
        {           
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Models;");
            sb.AppendLine("using HotChocolate;");
            sb.AppendLine("using HotChocolate.Types;");
            sb.AppendLine("");
            sb.AppendLine("namespace " + codeWriterSettings.Namespace);
            return sb.ToString();
        }

        public static string BeginClass()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("    /// <summary>");
            sb.AppendLine("    /// Represents the subscriptions available.");
            sb.AppendLine("    /// </summary>");
            sb.AppendLine(@"    [GraphQLDescription(""Represents the subscriptions available."")]");
            sb.AppendLine("    public class Subscription");
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
            sb.AppendLine(@"        /// The subscription for added <see cref=""" + table.NetName + @"""/>.");
            sb.AppendLine("        /// </summary>");
            sb.AppendLine(@"        /// <param name=""" + NameFixer.ToCamelCase(table.NetName) + @""">The <see cref=""" + table.NetName + @"""/>.</param>");
            sb.AppendLine(@"        /// <returns>The added <see cref=""" + table.NetName + @"""/>.</returns>");
            sb.AppendLine("        [Subscribe]");
            sb.AppendLine("        [Topic]");
            sb.AppendLine(@"        [GraphQLDescription(""The subscription for added " + NameFixer.ToCamelCase(table.NetName) + @"."")]");
            sb.AppendLine("        public " + table.NetName + " On" + table.NetName + "Added([EventMessage] " + table.NetName + " " + NameFixer.ToCamelCase(table.NetName) + @")");
            sb.AppendLine("        {");
            sb.AppendLine("            return " + NameFixer.ToCamelCase(table.NetName) + ";");
            sb.AppendLine("        }");
            return sb.ToString();
        }
    }
}
