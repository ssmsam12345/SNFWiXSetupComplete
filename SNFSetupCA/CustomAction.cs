using System;
using System.Collections.Generic;
using System.Text;
using System.Linq;
using Microsoft.Deployment.WindowsInstaller;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using System.Net;
namespace SNFSetupCA
{
    public class CustomActions
    {
        [CustomAction]
        public static ActionResult ValidteLicenseandAuth(Session session)
        {
           // Debugger.Break();
            //Debugger.Launch();
            session.Log("Begin CustomAction1");
            session["IS_LICENSE_AUTH_VALID"] = "Valid";
            string LicenseID = session["LICENSEID"];
            string Authentication = session["AUTHENTICATION"];

            if(LicenseID.Length != 8)
            {
                MessageBox.Show("License ID should be of 8 Characters, Please check your License ID");
                session["IS_LICENSE_AUTH_VALID"] = "Invalid";
            }
           else if(Authentication.Length != 16)
            {
                MessageBox.Show("License ID should be of 8 Characters, Please check your License ID");
                session["IS_LICENSE_AUTH_VALID"] = "Invalid";
            }
           else if (string.IsNullOrWhiteSpace(LicenseID) && (!LicenseID.Any(char.IsLetter) || !LicenseID.Any(char.IsDigit)))
            {
                MessageBox.Show("The License ID should be alphanumeric and should not contain any spaces");
                session["IS_LICENSE_AUTH_VALID"] = "Invalid";
            }
            else if(string.IsNullOrWhiteSpace(Authentication) && (!Authentication.Any(char.IsLetter) || !Authentication.Any(char.IsDigit)))
            {
                MessageBox.Show("The Authentication should be alphanumeric and should not contain any spaces");
                session["IS_LICENSE_AUTH_VALID"] = "Invalid";
            }
            else
                session["IS_LICFENSE_AUTH_VALID"] = "Valid";

            return ActionResult.Success;
        }

        [CustomAction]
        public static ActionResult GenerateMailServersList(Session session)
        {
            
            Microsoft.Deployment.WindowsInstaller.View listBoxView;
            
            //Debugger.Break();

             listBoxView = session.Database.OpenView("DELETE FROM ListBox");
            listBoxView.Execute();
            //listBoxView.Close();
             listBoxView = session.Database.OpenView("SELECT* FROM ListBox");
            listBoxView.Execute();
            
            session["CAN_INSERT_SMWD"] = !string.IsNullOrEmpty(session["ISSMARTERMAILINSTALLED"]) && !string.IsNullOrEmpty(session["DECLUDE_INSTALL_FOLDER"]) ? "SMWD" : "";
            session["OTHER"] = "OTHER";
            Record listBoxRecord;
            List<string> platformsToBeInsterted = new List<string> { "CAN_INSERT_SMWD", "OTHER" }; //, "MINIMIINSTALLFOLDER", "ISALLIGATEINSTALLED" };
            Dictionary<string, string> pfs = new Dictionary<string,string>();
            pfs.Add("ISIMAILINSTALLED", "Imail w/ Declude Install");
            pfs.Add("MINIMIINSTALLFOLDER", "Imail w/MINIMI for SNF");
            pfs.Add("ISALLIGATEINSTALLED", "Alligate Install");
           
            pfs.Add("CAN_INSERT_SMWD", "Smartermail w/ Declude Install");
            pfs.Add("OTHER", "Other");
            int i = 1;

            Dictionary<string, string> pfsValue = new Dictionary<string, string>();
            pfsValue.Add("CAN_INSERT_SMWD", "SMWD");
            pfsValue.Add("OTHER", "OTHER");


            string Text, pfValue;
            //TODO : set the property to mark this CA has already run , add condition here not to insert the records this time, as they have already been inserted if property is set
            foreach (string pf in platformsToBeInsterted)
            {
            //        if (pfs.TryGetValue(pf, out propertValue))
            //        {
                        if (!string.IsNullOrEmpty(session[pf]))
                        {
                           try
                            {
                                pfs.TryGetValue(pf, out Text);
                                pfsValue.TryGetValue(pf, out pfValue);    
                                listBoxRecord = session.Database.CreateRecord(4);
                                listBoxRecord.SetString(1, "SELECTEDPLATFORM");
                                listBoxRecord.SetInteger(2, i);
                                listBoxRecord.SetString(3, session[pf]);
                                listBoxRecord.SetString(4, Text);
                                listBoxView.Modify(ViewModifyMode.InsertTemporary, listBoxRecord);

                                

                            }
                            catch(Exception ex)
                            {
                                session.Log(ex.Message);
                                return ActionResult.Success;
                            }


                        }
            //        }
                    i++;
                }
            ////}
            
            listBoxView.Close();

            return ActionResult.Success;
        }

        [CustomAction]
        public static ActionResult PopulateListBox(Session session)
        {

            return ActionResult.Success;
        }

        [CustomAction]
        public static ActionResult SetPlatformProperties(Session session)
        {
            //Debugger.Break();
            string selectedPlatform = session["SELECTEDPLATFORM"];
            switch (selectedPlatform)
            {
                case"SMWD":
                    session["SELECTEDPLATFORM_TEXT"] = "You have chosen to install Sniffer under Declude with an Imail configuration.  You will need to confirm the location of the following items:";
                    session["PLATFORMFOUND_TEXT"] = "Imail was found.  Please confirm the folder for Declude's global.cfg file.";
                    break;

                case "OTHER":
                case "other":

                    session["SELECTEDPLATFORM_TEXT"] = "You have chosen to install Sniffer in a stand alone.  You will need to confirm the location of the install directory.";
                    session["PLATFORMFOUND_TEXT"] = " ";
                    break;
            }

            return ActionResult.Success;
        }

        [CustomAction]
        public static ActionResult LaunchHelpWebPage(Session session)
        {
            Process.Start(session["HELPWEBPAGELINK"]);
            return ActionResult.Success;

        }
       
        [CustomAction]
        public static ActionResult DownloadRulebase(Session session)
        {
            string CURLPATH   = session.CustomActionData["CURLPATH"];
            string LICENSEID_SNF  = session.CustomActionData["LICENSEID"] + ".snf"; 
            ProcessStartInfo curlStartInfo = new ProcessStartInfo();

            curlStartInfo.FileName = Environment.GetFolderPath(Environment.SpecialFolder.SystemX86) + "\\cmd.exe";
            curlStartInfo.CreateNoWindow = true;
            curlStartInfo.WindowStyle = ProcessWindowStyle.Hidden;
            curlStartInfo.UseShellExecute = true;
            curlStartInfo.Arguments = "/c " + "\"" + CURLPATH + "\"" + " -v \"http://www.sortmonster.net/Sniffer/Updates/testmode.snf\" -o " + LICENSEID_SNF + " -S -R -H \"Accept-Encoding:gzip\" --compressed -u sniffer:ki11sp8m 2>> \"C:\\temp\\curlresult.txt\"";
            curlStartInfo.RedirectStandardOutput = false;

            try
            {

                using (Process curlProcess = Process.Start(curlStartInfo))
                {
                    curlProcess.WaitForExit();
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
                // Log error.
                return ActionResult.Failure;

            }

            return ActionResult.Success;
        }
        [CustomAction]
        public static ActionResult SearchAndReplace(Session session)
        {
            String FilePath = @session.CustomActionData["GetRulebaseCmdFile"];
            String FileContents = File.ReadAllText(FilePath);
            FileContents.Replace("INSTALLDIR", session.CustomActionData["INSTALLDIR"]);
            FileContents.Replace("AUTHENTICATION", session.CustomActionData["AUTHENTICATION"]);
            FileContents.Replace("LICENSE", session.CustomActionData["LICENSEID"]);
            File.WriteAllText(FilePath, FileContents);

            return ActionResult.Success;
        }
        [CustomAction]
        public static ActionResult CheckInternetConnection(Session session)
        {
            try
            {
                using (var client = new WebClient())
                {
                    using (var stream = client.OpenRead("http://www.google.com"))
                    {
                        return ActionResult.Success;
                    }
                }
            }
            catch
            {
               DialogResult btnClicked = MessageBox.Show("System is not Connected to the internet. This installation requires the system to be connected to the internet.", "Internet Connection Check", MessageBoxButtons.AbortRetryIgnore, MessageBoxIcon.Warning);
               switch (btnClicked)
               {
                   case DialogResult.Abort: return ActionResult.UserExit;
                   case DialogResult.Ignore: return ActionResult.Success;
                   case DialogResult.Retry : return ActionResult.Success;
               }
            }
            return ActionResult.Success;
        }
       
        public static void AddListBoxEntry(Session session, string propertyName, int order, string value, string text) 
        {
             

            Record newEntry = new Record(4); 
            newEntry[0] = propertyName; 
            newEntry[1] = order; 
            newEntry[2] = value; 
            newEntry[3] = text; 

            try 
            {
                Microsoft.Deployment.WindowsInstaller.View listBoxView = session.Database.OpenView("SELECT * FROM ComboBox"); //`Property`, `Order`, `Value`, `Text`
                listBoxView.Execute();
                listBoxView.Modify(ViewModifyMode.InsertTemporary, newEntry);
                listBoxView.Close(); 
            } 
            catch (InstallerException ix) 
            { 
                //RecurseLogInstallerException(session, ix, 0); 
                session.Log(ix.Message);
            } 

            

        }  
    }
}
