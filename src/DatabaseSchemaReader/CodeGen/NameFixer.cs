using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;

namespace DatabaseSchemaReader.CodeGen
{
    /// <summary>
    /// Fixes database names to be pascal case and singular.
    /// Consider replacing this with something a little more powerful- eg Castle Project inflector 
    /// https://github.com/castleproject/Castle.ActiveRecord/blob/master/src/Castle.ActiveRecord/Framework/Internal/Inflector.cs
    /// Or https://alastaircrabtree.com/detecting-plurals-in-dot-net/
    /// </summary>
    public static class NameFixer
    {
#if !COREFX
        private static readonly System.CodeDom.Compiler.CodeDomProvider CSharpProvider = System.CodeDom.Compiler.CodeDomProvider.CreateProvider("C#");
#endif
        public static string PrimaryKeyIdName => "Id";
        public static string AppendId(string name)
        {
            name = RemoveId(name);
            return name + PrimaryKeyIdName;
        }
        public static string RemoveId(string name)
        {
            if (name.EndsWith(PrimaryKeyIdName, StringComparison.OrdinalIgnoreCase)) name = name.Substring(0, name.Length - PrimaryKeyIdName.Length);
            return name;
        }
        /// <summary>
        /// Fixes the specified name to be pascal cased and (crudely) singular.
        /// </summary>
        /// <param name="name">The name.</param>
        /// <returns></returns>
        /// <remarks>
        /// See C# language specification http://msdn.microsoft.com/en-us/library/aa664670.aspx
        /// </remarks>
        public static string ToPascalCase(string name)
        {
            if (string.IsNullOrEmpty(name)) return "A" + Guid.NewGuid().ToString("N");

            var endsWithId = Regex.IsMatch(name, "[a-z0-9 _]{1}(?<Id>ID)$");

            name = MakePascalCase(name);
            name = MakeSingular(name);

            if (endsWithId)
            {
                //ends with a capital "ID" in an otherwise non-capitalized word
                name = name.Substring(0, name.Length - 2) + "Id";
            }

            //remove all spaces
            name = Regex.Replace(name, @"[^\w]+", string.Empty);
            return name;
        }

        /// <summary>
        /// Fixes the specified name to be camel cased. No singularization.
        /// </summary>
        /// <param name="name">The name.</param>
        /// <returns></returns>
        public static string ToCamelCase(string name)
        {
            if (string.IsNullOrEmpty(name)) return "a" + Guid.NewGuid().ToString("N");

            var endsWithId = Regex.IsMatch(name, "[a-z0-9 _]{1}(?<Id>ID)$");

            name = MakePascalCase(name); //reuse this

            if (endsWithId)
            {
                //ends with a capital "ID" in an otherwise non-capitalized word
                name = name.Substring(0, name.Length - 2) + "Id";
            }

            //remove all spaces
            name = Regex.Replace(name, @"[^\w]+", string.Empty);

            if (Char.IsUpper(name[0]))
            {
                name = char.ToLowerInvariant(name[0]) +
                    (name.Length > 1 ? name.Substring(1) : string.Empty);
            }

            //this could still be a c# keyword
#if !COREFX
            if (!CSharpProvider.IsValidIdentifier(name))
            {
                //in practice all keywords are lowercase. 
                name = "@" + name;
            }
#endif
            return name;
        }

        private static string MakePascalCase(string name)
        {
            //make underscores into spaces, plus other odd punctuation
            name = name.Replace('_', ' ').Replace('$', ' ').Replace('#', ' ');

            //if it's all uppercase
            if (Regex.IsMatch(name, @"^[A-Z0-9 ]+$"))
            {
                //lowercase it
                name = CultureInfo.InvariantCulture.TextInfo.ToLower(name);
            }

            //if it's mixed case with no spaces, it's already pascal case
            if (name.IndexOf(' ') == -1 && !Regex.IsMatch(name, @"^[a-z0-9]+$"))
            {
                return name;
            }

            //titlecase it (words that are uppered are preserved)
            name = CultureInfo.InvariantCulture.TextInfo.ToTitleCase(name);

            return name;
        }

        /// <summary>
        /// Very simple singular inflections. "Works on my database" (TM)
        /// </summary>
        /// <param name="name">The name.</param>
        /// <returns></returns>
        public static string MakeSingular(string name)
        {
            if (name.EndsWith("ss", StringComparison.OrdinalIgnoreCase))
            {
                //ok, don't do anything. "Address" + X"ness" are valid singular
            }
            else if (name.EndsWith("us", StringComparison.OrdinalIgnoreCase))
            {
                //ok, don't do anything. "Status" + "Virus" are valid singular
            }
            else if (name.EndsWith("ses", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 2); //"Buses". Fails "Analyses" and "Cheeses". 
            }
            else if (name.EndsWith("ies", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 3) + "y"; //"Territories", "Categories"
            }
            else if (name.EndsWith("xes", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 3) + "x"; //"Boxes"
            }
            else if (name.EndsWith("s", StringComparison.OrdinalIgnoreCase))
            {
                name = name.Substring(0, name.Length - 1);
            }
            else if (name.Equals("People", StringComparison.OrdinalIgnoreCase))
            {
                name = "Person"; //add other irregulars.
            }
            else if (name.Equals("Children", StringComparison.OrdinalIgnoreCase))
            {
                name = "Child"; //add other irregulars.
            }
            return name;
        }



        private static readonly Dictionary<string, string> KnownCommonPluralsDictionary = new Dictionary<string, string>
        {
            {"children", "child"},
            {"people", "person"}
        };

        public static bool IsPlural(string plural)
        {
            plural = plural.ToLower();
            // babies => baby
            if (plural.EndsWith("ys"))
                return true;

            // catches => catch, axes => axis
            if (plural.EndsWith("es"))
                return true;

            // people => person and other "one off" edge cases
            if (KnownCommonPluralsDictionary.ContainsKey(plural))
                return true;

            //series => series
            if (plural.EndsWith("ies"))
                return true;

            //statuses => status
            if (plural.EndsWith("uses"))
                return true;

            //synopses => synopsis
            if (plural.EndsWith("ses"))
                return true;

            //halves => half  (shelves, scarves, greaves, dwarves, sheaves, wharves, starves)
            if (plural.EndsWith("ves"))
                return true;

            //vertices => vertex, matricies => matrix, indicies => index
            if (plural.EndsWith("ices"))
                return true;

            return false;
        }
    }
}
