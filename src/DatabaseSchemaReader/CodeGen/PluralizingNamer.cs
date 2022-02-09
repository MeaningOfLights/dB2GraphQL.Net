using System;

namespace DatabaseSchemaReader.CodeGen
{
    /// <summary>
    /// Names collections by trying to pluralize them. Use with caution!
    /// </summary>
    public class PluralizingNamer : Namer
    {
        #region Override Implementation of ICollectionNamer

        /// <summary>
        /// Names the collection.
        /// </summary>
        /// <param name="className">Name of the class.</param>
        /// <returns></returns>
        public override string NameCollection(string className)
        {
            //you can reference System.Data.Entity.Design.dll
            //use System.Data.Entity.Design.PluralizationServices.PluralizationService.CreateService(CultureInfo.GetCultureInfo("en-us"))
            //it'll be a bit better than this! (though English pluralizing rules are more complex...)
            if (className.EndsWith("ss", StringComparison.OrdinalIgnoreCase))
            {
                return className + "es"; //Addresses
            }
            else if (className.EndsWith("o", StringComparison.OrdinalIgnoreCase))
            {
                return className + "es"; //heroes, but not photos, kimonos
            }
            else if (className.EndsWith("x", StringComparison.OrdinalIgnoreCase))
            {
                return className + "es"; //Boxes
            }
            else if (className.EndsWith("y", StringComparison.OrdinalIgnoreCase))
            {
                return className.Substring(0, className.Length - 1) + "ies"; //Categories
            }
            else if (className.Equals("Person", StringComparison.OrdinalIgnoreCase))
            {
                className = "People"; //add other irregulars.
            }
            else if (className.Equals("Child", StringComparison.OrdinalIgnoreCase))
            {
                className = "Children"; //add other irregulars.
            }

            //sorry for farming applications which will have sheeps
            return className + "s";
        }

        #endregion
    }

    /// <summary>
    /// Fixes database names to be pascal case and singular.
    /// Consider replacing this with something a little more powerful- eg Castle Project inflector 
    /// https://github.com/castleproject/Castle.ActiveRecord/blob/master/src/Castle.ActiveRecord/Framework/Internal/Inflector.cs
    /// Or https://alastaircrabtree.com/detecting-plurals-in-dot-net/
    /// </summary>
    /// 
    //You can make your own by inheriting from DatabaseSchemaReader.CodeGen.Namer, and overridding NameCollection
    //public class MsPluralizingNamer : PluralizingNamer
    //{
    //    public override string NameCollection(string className)
    //    {
    //        var service =
    //            System.Data.Entity.Design.PluralizationServices.PluralizationService.CreateService(
    //                CultureInfo.GetCultureInfo("en-us"));
    //        return service.Pluralize(className);
    //    }
    //}
}
