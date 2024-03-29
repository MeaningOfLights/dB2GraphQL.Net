﻿using System;
using System.Globalization;
using System.Text;

namespace DatabaseSchemaReader.CodeGen
{
    /// <summary>
    /// Writes a class while retaining indenting
    /// </summary>
    public class ClassBuilder
    {
        readonly StringBuilder _sb = new StringBuilder();
        private string _indent = string.Empty;
        private int _indentLevel;

        /// <summary>
        /// Appends the line.
        /// </summary>
        /// <param name="s">The string.</param>
        public void AppendLine(string s)
        {
            _sb.Append(_indent);
            _sb.AppendLine(s);
        }

        /// <summary>
        /// Appends the format.
        /// </summary>
        /// <param name="s">The string.</param>
        /// <param name="args">The arguments.</param>
        public void AppendFormat(string s, params object[] args)
        {
            _sb.Append(_indent);
            _sb.AppendLine(string.Format(CultureInfo.InvariantCulture, s, args));
        }

        internal void AppendXmlSummary(string summary)
        {
            if (string.IsNullOrEmpty(summary)) return;
            _sb.Append(_indent);
            _sb.AppendLine("/// <summary>");
            _sb.Append(_indent);
            _sb.AppendLine("/// " + summary);
            _sb.Append(_indent);
            _sb.AppendLine("/// </summary>");
        }

        internal Nester BeginNest(string s)
        {
            return BeginNest(s, null);
        }

        internal Nester BeginNest(string s, string summary)
        {
            AppendXmlSummary(summary);
            _sb.Append(_indent);
            _sb.AppendLine(s); 
            _sb.Append(_indent);
            _sb.AppendLine("{");
            PushIndent();
            return new Nester(this);
        }

        internal Nester BeginBrace(string s)
        {
            //simple bracing, no leading line
            _sb.Append(_indent);
            _sb.AppendLine(s);
            _sb.Append(_indent);
            _sb.AppendLine("{");
            PushIndent();
            return new Nester(this);
        }

        internal void AppendAutomaticProperty(string dataType, string propertyName)
        {
            AppendAutomaticProperty(dataType, propertyName, true);
        }

        internal void AppendAutomaticProperty(string dataType, string propertyName, bool isVirtual)
        {
            var line = string.Format(
                CultureInfo.InvariantCulture,
                "{0}public {1}{2} {3} {{ get; set; }}",
                _indent,
                isVirtual ? "virtual " : string.Empty,
                dataType,
                propertyName);

            _sb.AppendLine(line);
            _sb.AppendLine(); //add an empty line
        }

        internal void AppendAutomaticCollectionProperty(string dataType, string propertyName)
        {
            AppendAutomaticCollectionProperty(dataType, propertyName, false);
        }
        internal void AppendAutomaticCollectionProperty(string dataType, string propertyName, bool protectedSetter)
        {
            var line = string.Format(
                CultureInfo.InvariantCulture,
                "{0}public virtual {1} {2} {{ get; {3} set; }}",
                _indent,
                dataType,
                propertyName,
                //Starting with NH 3.2, setters must be protected, not private
                protectedSetter ? "protected" : "private");

            _sb.AppendLine(line);
            _sb.AppendLine(); //add an empty line
        }

        internal void EndNest()
        {
            PopIndent(); //pop before writing close brace
            _sb.Append(_indent);
            _sb.AppendLine("}");
        }

        private void PushIndent()
        {
            _indentLevel++;
            _indent = new string(' ', _indentLevel * 4);
        }
        private void PopIndent()
        {
            _indentLevel--;
            //if (_indentLevel > -1) throw new Exception("Developer Error, you've used one extra EndNest than needed... FIX IT!");
            //if (_indentLevel > -1) 
            _indent = new string(' ', _indentLevel * 4);
        }

        /// <summary>
        /// Returns a <see cref="System.String" /> that represents the source code.
        /// </summary>
        /// <returns>
        /// A <see cref="System.String" /> that represents the source code.
        /// </returns>
        public override string ToString()
        {
            return _sb.ToString();
        }
    }
}
