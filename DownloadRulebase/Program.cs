using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;

namespace DownloadRulebase
{
    class Program
    {
        static void Main(string[] args)
        {
            ProcessStartInfo curlStartInfo = new ProcessStartInfo();
            int exitCode;
            
            curlStartInfo.FileName = @"E:\SNF\curl.exe"; // Environment.GetFolderPath( Environment.SpecialFolder.SystemX86) +  "\\cmd.exe";
            curlStartInfo.CreateNoWindow = false;
            curlStartInfo.WindowStyle = ProcessWindowStyle.Normal;
            //curlStartInfo.UseShellExecute = true;
            curlStartInfo.Arguments =" -v \"http://www.sortmonster.net/Sniffer/Updates/testmode.snf\" -o C:\\Temp\\LicenseID.new -S -R -H \"Accept-Encoding:gzip\" --compressed -u sniffer:ki11sp8m 2>> \"C:\\temp\\curlresult.txt\"";
            curlStartInfo.RedirectStandardOutput = true;
            
            try
	        {
	           
	            using (Process curlProcess = Process.Start(curlStartInfo))
	            {
		            curlProcess.WaitForExit();
                    exitCode = Environment.ExitCode;
	            }
	        }
	        catch(Exception e)
	        {
                Console.WriteLine(e.Message);
	            // Log error.
                 
	        }
        }
    }
}
