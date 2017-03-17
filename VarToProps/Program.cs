using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
namespace VarToProps
{
    class Program
    {
        static void Main(string[] args)
        {
            
        }
        void GlobalvarToProps()
        {
            int i = 0;
            string[] prop;
            StreamWriter fs;
            //File.Create("Properties.wxs");
            fs = new StreamWriter("Properties.wxs");

            string[] lines = File.ReadAllLines("main.nsi");
            while (lines.Length > i)
            {
                if (lines[i].StartsWith("VAR", StringComparison.InvariantCultureIgnoreCase) && lines[i].Contains("GLOBAL"))
                {
                    prop = lines[i].Split(' ');
                    fs.WriteLine("<Property Id=\"" + prop[2].ToUpper() + "\"" + " Secure=\"yes\"/>");


                }
                i++;
            }
            fs.Close();

        }
        void ReagRegStrToRegSearch()
        {
            int i = 0;
            string[] prop;
            StreamWriter fs;
            //File.Create("Properties.wxs");
            fs = new StreamWriter("RegistrySearch.wxs");

            string[] lines = File.ReadAllLines(@"D:\Linda\Sampat\main.nsi");
            while (lines.Length > i)
            {
                if (lines[i].StartsWith("ReadRegStr", StringComparison.InvariantCultureIgnoreCase))
                {
                    prop = lines[i].Split(' ');
                    //fs.WriteLine("<Property Id=\"" + prop[2].ToUpper() + "\"" + " Secure=\"yes\"/>");
                    fs.WriteLine("<RegistrySearch Id=");


                }
                i++;
            }
            fs.Close();
        }
    }
}
