using DatabaseSchemaReader.DataSchema;
using System.Text;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLQuery
    {
        public static string GetGraphGLUsingStatements(CodeWriterSettings codeWriterSettings)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("using System.Linq;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Data;");
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Models;");

            sb.AppendLine("using HotChocolate;");
            sb.AppendLine("using HotChocolate.Data;");
            sb.AppendLine("");

            sb.AppendLine("namespace " + codeWriterSettings.Namespace);
            return sb.ToString();
        }
        public static string BeginClass()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("    /// <summary>");
            sb.AppendLine("    /// Represents the queries available.");
            sb.AppendLine("    /// </summary>");
            sb.AppendLine(@"    [GraphQLDescription(""Represents the queries available."")]");
            sb.AppendLine("    public class Query");
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
            sb.AppendLine(@"        /// Gets the queryable <see cref=""" + table.NetName + @"""/>.");
            sb.AppendLine("        /// </summary>");
            sb.AppendLine(@"        /// <param name=""context"">The <see cref=""AppDbContext""/>.</param>");
            sb.AppendLine(@"        /// <returns>The queryable <see cref=""" + table.NetName + @"""/>.</returns>");
            sb.AppendLine(@"        /// Attribute Order: UseDbContext -> UsePaging -> UseProjection -> UseFiltering -> UseSorting.");
            sb.AppendLine("        [UseDbContext(typeof(AppDbContext))]");
            sb.AppendLine("        [UseProjection]"); 
            sb.AppendLine("        [UseFiltering]");
            sb.AppendLine("        [UseSorting]");
            sb.AppendLine(@"        [GraphQLDescription(""Gets the queryable " + NameFixer.ToCamelCase(table.NetName) + @"."")]");
            sb.AppendLine("        public IQueryable<" + table.NetName + "> Get" + table.NetName + "([ScopedService] AppDbContext context)");
            sb.AppendLine("        {");
            sb.AppendLine("            return context." + table.Name + ";");
            sb.AppendLine("        }"); 
            return sb.ToString();
        }
    }
}
