!verbose 2
!define TEMP1 $R0 ;Temp variable
!define SNIFFER_SERVER_SPECIFIER "V3.2.0-E3.2.0" ; This is the ending of the product specific server file.... not the default Server.exe file.
; MessageSnifferRestorer1_1_1.nsi
;
; This script produces an included installer file that is packed inside the MessageSniffer Installer utility.
; It is in charge of installing fresh files, and for restoring from an older pre-existing directory.
;--------------------------------

; The name of the installer
Name "Message Sniffer Install/Restore Utility 1_0"

; The file to write
OutFile "Restorer.exe"

; End word searching subroutine vars.

; Standard vars for the license page.
LicenseText "Approve License Agreement:"  ; title
LicenseData "License.txt"         ; pointer to set the target of the license file.


VAR /GLOBAL SNFServerInstallDir ; Root to the $INSTDIR.  ## ERROR... this note should read ROOT to the platform that is USING sniffer... ##.... confirm this.

Var /GLOBAL LicenseID         ; Holds user entered License ID.
Var /GLOBAL Authentication    ; Holds user entered Authentication ID

Var /GLOBAL InstallerCompletedRestore ; A onetime bit flag that determines if the installer needs to jump to the restore success screen or
                                      ; move on into the License screen.

Var /GLOBAL OpenGBUIgnoreFileOnClose ; Flag for determining if I should open GBUdbIgnoreList.txt on exit of installer.
Var /GLOBAL HasStickyPots            ; Flag for running the email entry list.
Var /GLOBAL UseDetectedRulebase      ; Flag for skipping download of huge rulebase if you have one existing.

Var /GLOBAL DownloadFailed ; $DownloadFailed This Variable declared in on init and defaulted to "0".

Var /GLOBAL AUTO_UPDATE_ONOFF_FLAG ; This is the flag to turn on or off the automatic upload file feature in the snfmdplugin.xml file

Var /GLOBAL RetainExistingSettings ; flag for later logic to copy config files into new install folder.
Var /GLOBAL CommandLineParameters  ; flag to hold parameters send on the command line to the Restorer.exe program.

Var /Global shortInstallPath ; used to shorten the pathnames for the variables for output.

#################################################
Var /GLOBAL localINSTDIR  ; used in subs like editglobalCFG and editMXGuard.ini to hold the local
Var /GLOBAL localSERVDIR  ; and the intended install paths.
Var /GLOBAL registryTempData ; tempvar to read in from registry for that purpose.
#################################################

#################################################
## These variables used for File management functions and for Get Time
Var OUT1
Var OUT2
Var OUT3
Var OUT4
Var OUT5
Var OUT6
Var OUT7
; end File Managment subroutine vars.
########################
## Vars for the License and Authentication Display Screen
VAR testInputLength
Var EDITLicense
Var EDITAuthentication
Var CHECKBOX
########################
## Vars for the AlphaNumerical Test Function
VAR /GLOBAL AlphanumericalTestString ; Holds the definition of all alpha numerical digits that are acceptable for the License and the Authentication String..
VAR /GLOBAL AlphaNumericsSourceString ; local SourceString to test all char components.
VAR /GLOBAL AlphaNumericalTestChar ; local working char
VAR /GLOBAL AlphaNumericalResult ; 1 if ok, 0 if failed .
VAR /GLOBAL AlphaNumericalSSLen  ; local length counter
VAR /GLOBAL SNF2Check            ; local variable for holding the result of the snf2check call.


########################################################################################################################################################
## ADDINGPLATFORM ## 0 The block of variables below are used to point and source files that are being handled by the rollback function,
## but that need special handling.  Its easier to be explicit so the code is readable.  If you are going to need to hijack the stomping of a file
## during rollback and strip/replace data rather than replace/delete the entire file, then you will need to define all these items.

# Vars used to determine the direction of edit functions.  
VAR /GLOBAL healFromOldFile             ; used to flag putting stuff back.
VAR /GLOBAL collectedArchiveData        ; store these lines, collected from the file.
VAR /GLOBAL succededAtPlacingArchivedData ; true if we have already written data to the new file.
# Edit or Rollback Vars for GLOBAL.cfg
VAR /GLOBAL archivedGLOBALcfgPath       ; file to use for putting stuff back.
VAR /GLOBAL archivedGLOBALcfgFileHandle ; handle for file to read in the stuff to put back....
# Edit or Rollback Vars for MXGuard.ini
VAR /GLOBAL archivedMXGUARDiniPath
VAR /GLOBAL archivedMXGUARDiniFileHandle ; handle for file to read in the stuff to put back....

VAR /GLOBAL archivedMDPluginsDatPath
VAR /GLOBAL archivedMDPluginsDatFileHandle ; handle for file to read in the stuff to put back....


VAR /GLOBAL UnpackedCURLStuff ; This is a flag so that if you go back to the screen that calls the unpacking of curl etc, it doesn't do it again,
                              ; and continue to add it to the rollback file.

!include "LogicLib.nsh" ; needed for if than do while.
!include "FileFunc.nsh" ; needed for ifFileExists, FileOpen, FileWrite, FileClose
!include "Sections.nsh" ; required.

!include "WinMessages.nsh" ; needed for Word searching of the Plugins.dat file.
!include "WordFunc.nsh"    ; needed for Word searching of the Plugins.dat file.

!include "nsDialogs.nsh"  ; needed to dynamically handle custom page creation
; !include "StrRep.nsh"

!insertmacro WordFind      ; compiler macro... needed to call before use
!insertmacro un.WordFind      ; compiler macro... needed to call before use
!insertmacro WordFind2X      ; compiler macro... needed to call before use
!insertmacro un.WordFind2X      ; compiler macro... needed to call before use!insertmacro GetParameters
!insertmacro GetOptions
!insertmacro GetTime       ; compiler macro... needed to call before use

!insertmacro un.DirState      ; compiler macro... needed to call before use
!insertmacro un.GetTime       ; compiler macro... needed to call before use
!insertmacro un.GetParent     ; replace the moveup directory function.....

########################################################################################################################################################
## ADDINGPLATFORM ## Notes 1 If you have completed the adding platform  notes in the Installer.exe code, then you are now moving to the next step.
## The previous efforts were all about deciding WHERE to put the install, and ensuring that its in the right place.  The Installer eventually will call
## the Restorer.  A left over dichotomy from the original design.  It does serve to break installer presentation/validation from installation.  Since the
## installation is pretty much the same screens for all the platforms.
## The Installer.exe creates a .txt file that has server location, and the installer location defined.  Those two vars are loaded onInit, and begin the
## install process.
##
## For files that are being edited, the automatic restore macro's will copy and manage putting files back, on uninstall.  Besure to make the appropriate
## calls.  There is a difference for a file that you are putting in place, vs, a file you are editing in place.  It will make sense when you get to the code.
##
## Remember that even though you have a lot of conditional execution for all the multiple platforms, only one sniffer installation will be live at a time.
## If the Restorer detects via the registry that there is an old version, it uninstalls that first.  Then will install the new version on the platform that
## was identified by the Installer.exe via the LocalRoot.txt file.
##
## Also, be careful to note when/if you need to put in file adjusting subroutines, that you will need to typically duplicate it for the un.installersubs
## if you need to manage the un-doing of those edits.  Sometimes you won't if you're happy with file replacement of the old file.
## NSIS requires the namespace for subroutines be different, even though the declared global variables are all valid for the uninstaller as well.
########################################################################################################################################################


; Sets up the left side picture on the installer.
AddBrandingImage left 140

!macro BIMAGE IMAGE PARMS
	Push $0
	GetTempFileName $0
	File /oname=$0 "${IMAGE}"
	SetBrandingImage ${PARMS} $0
	Delete $0
	Pop $0
!macroend


; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------
XPStyle on ; for custom page look.

; Pages
Page license "nsSetupLicenseTitle" "" ""

Page custom nsDialogsUserName nsDialogsUserName_leave "User name and Authentication:"
Page custom nsDialogsGetRulebase nsDialogsGetRulebase_leave "Downloading Sniffer Rulebase File:"
Page custom nsDialogsWaitingForRulebase "" "Downloading Sniffer Rulebase File:"


Page components "nsSetupcomponentTitle" "" "nsinstfilesExitSub"
Page instfiles  "nsSetupInstallationTitle" "" ""
Page custom finishedFilesDisplay finishedFilesQuit

UninstallText "This will uninstall the previous version of Message Sniffer." "Location:"
UninstPage uninstConfirm
#UninstPage custom un.Restore "un.BeSure" ": Restore or Remove"
UninstPage instfiles

Function nsSetupLicenseTitle
  !insertmacro BIMAGE "SnifferBanner.bmp" ""

  SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Approve License Before Continuing:"
FunctionEnd

Function nsSetupcomponentTitle
  !insertmacro BIMAGE "SnifferBanner.bmp" ""
  SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Adjust Component Selection:"
  
  ;if We haven't been to this screen before, the case flag will be zero.  And we leave teh Next button disabled.... otherwise we leave it enabled:
             ; Disable the next button until selection is made.
             Var /GLOBAL BackButton
             GetDlgItem $BackButton $HWNDPARENT 3
             EnableWindow $BackButton "0"
  
FunctionEnd

Function nsSetupInstallationTitle
   !insertmacro BIMAGE "SnifferBanner.bmp" ""

  SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Completing Server Installation:"
FunctionEnd

###############################################################################
##
##  Open source functional additions from NSIS website.  Provided by users.
##
##
###############################################################################



;----------------------------------------------------------------------------
; Title             : Go to a NSIS page
; Short Name        : RelGotoPage
; Last Changed      : 22/Feb/2005
; Code Type         : Function
; Code Sub-Type     : Special Restricted Call, One-way StrCpy Input
;----------------------------------------------------------------------------
; Description       : Makes NSIS to go to a specified page relatively from
;                     the current page. See this below for more information:
;                     "http://nsis.sf.net/wiki/Go to a NSIS page"
;----------------------------------------------------------------------------
; Function Call     : StrCpy $R9 "(number|X)"
;
;                     - If a number &gt; 0: Goes foward that number of
;                       pages. Code of that page will be executed, not
;                       returning to this point. If it excess the number of
;                       pages that are after that page, it simulates a
;                       "Cancel" click.
;
;                     - If a number &lt; 0: Goes back that number of pages.
;                       Code of that page will be executed, not returning to
;                       this point. If it excess the number of pages that
;                       are before that page, it simulates a "Cancel" click.
;
;                     - If X: Simulates a "Cancel" click. Code will go to
;                       callback functions, not returning to this point.
;
;                     - If 0: Continues on the same page. Code will still
;                        be running after the call.
;
;                     Call RelGotoPage
;----------------------------------------------------------------------------
; Author            : Diego Pedroso
; Author Reg. Name  : deguix
;----------------------------------------------------------------------------

Function RelGotoPage
  IntCmp $R9 0 0 Move Move
    StrCmp $R9 "X" 0 Move
      StrCpy $R9 "120"

  Move:
  SendMessage $HWNDPARENT "0x408" "$R9" ""
FunctionEnd



###############################################################################
## This allows me to determine how many times I want to replace instead of it being recursive...
###############################################################################
Function AdvReplaceInFile
Exch $0 ;file to replace in
Exch
Exch $1 ;number to replace after
Exch
Exch 2
Exch $2 ;replace and onwards
Exch 2
Exch 3
Exch $3 ;replace with
Exch 3
Exch 4
Exch $4 ;to replace
Exch 4
Push $5 ;minus count
Push $6 ;universal
Push $7 ;end string
Push $8 ;left string
Push $9 ;right string
Push $R0 ;file1
Push $R1 ;file2
Push $R2 ;read
Push $R3 ;universal
Push $R4 ;count (onwards)
Push $R5 ;count (after)
Push $R6 ;temp file name

  GetTempFileName $R6
  FileOpen $R1 $0 r ;file to search in
  FileOpen $R0 $R6 w ;temp file
   StrLen $R3 $4
   StrCpy $R4 -1
   StrCpy $R5 -1

loop_read:
 ClearErrors
 FileRead $R1 $R2 ;read line
 IfErrors exit

   StrCpy $5 0
   StrCpy $7 $R2

loop_filter:
   IntOp $5 $5 - 1
   StrCpy $6 $7 $R3 $5 ;search
   StrCmp $6 "" file_write2
   StrCmp $6 $4 0 loop_filter

StrCpy $8 $7 $5 ;left part
IntOp $6 $5 + $R3
IntCmp $6 0 is0 not0
is0:
StrCpy $9 ""
Goto done
not0:
StrCpy $9 $7 "" $6 ;right part
done:
StrCpy $7 $8$3$9 ;re-join

IntOp $R4 $R4 + 1
StrCmp $2 all file_write1
StrCmp $R4 $2 0 file_write2
IntOp $R4 $R4 - 1

IntOp $R5 $R5 + 1
StrCmp $1 all file_write1
StrCmp $R5 $1 0 file_write1
IntOp $R5 $R5 - 1
Goto file_write2

file_write1:
 FileWrite $R0 $7 ;write modified line
Goto loop_read

file_write2:
 FileWrite $R0 $R2 ;write unmodified line
Goto loop_read

exit:
  FileClose $R0
  FileClose $R1

   SetDetailsPrint none
  Delete $0
  Rename $R6 $0
  Delete $R6
   SetDetailsPrint BOTH

Pop $R6
Pop $R5
Pop $R4
Pop $R3
Pop $R2
Pop $R1
Pop $R0
Pop $9
Pop $8
Pop $7
Pop $6
Pop $5
Pop $0
Pop $1
Pop $2
Pop $3
Pop $4
FunctionEnd
######################### End of Advanced Replace in File.

###############################################################################
; The following code is for finding strings inbetween two markers... reguardless of linefeeds.

!macro GetBetween This AndThis In Return
Push "${This}"
Push "${AndThis}"
Push "${In}"
 Call GetBetween
Pop "${Return}"
!macroend
!define GetBetween "!insertmacro GetBetween"

!macro un.GetBetween This AndThis In Return
Push "${This}"
Push "${AndThis}"
Push "${In}"
 Call un.GetBetween
Pop "${Return}"
!macroend
!define un.GetBetween "!insertmacro un.GetBetween"


Function GetBetween
 Exch $R0 ; file    ; $R0_Old + AndThis + This + Stack
 Exch               ;  AndThis + $R0_Old + This + Stack
 Exch $R1 ; before this (marker 2)  ;  $R1_Old + $R0_Old + This + Stack
 Exch 2             ;  This + $R0_Old + $R1_Old + Stack
 Exch $R2 ; after this  (marker 1) $R2_Old + $R0_OLD + $R1_Old + Stack
 Exch 2             ; $R1_Old + $R0_OLD + $R2_Old + Stack
 Exch               ; $R0_Old + $R1_OLD + $R2_Old + Stack
 Exch 2             ; $R2_Old + $R1_OLD + $R0_Old + Stack
 Push $R3 ; marker 1 len R3,R2,R1,R0,Stack
 Push $R4 ; marker 2 len R4,R3,R2,R1,R0,Stack
 Push $R5 ; marker pos   R5,R4,R3,R2,R1,R0,Stack
 Push $R6 ; file handle  R6,R5,R4,R3,R2,R1,R0,Stack
 Push $R7 ; current line string R7,R6,R5,R4,R3,R2,R1,R0,Stack
 Push $R8 ; current chop R8,R7,R6,R5,R4,R3,R2,R1,R0,Stack

 FileOpen $R6 $R0 r

 StrLen $R4 $R2
 StrLen $R3 $R1

 StrCpy $R0 ""

 Read1:
  ClearErrors
  FileRead $R6 $R7
  IfErrors Done
  StrCpy $R5 0

 FindMarker1:
  IntOp $R5 $R5 - 1
  StrCpy $R8 $R7 $R4 $R5
  StrCmp $R8 "" Read1
  StrCmp $R8 $R2 0 FindMarker1
   IntOp $R5 $R5 + $R4
   StrCpy $R7 $R7 "" $R5

  StrCpy $R5 -1
  Goto FindMarker2

 Read2:
  ClearErrors
  FileRead $R6 $R7
  IfErrors Done
  StrCpy $R5 -1

 FindMarker2:
  IntOp $R5 $R5 + 1
  StrCpy $R8 $R7 $R3 $R5
  StrCmp $R8 "" 0 +3
   StrCpy $R0 $R0$R7
  Goto Read2
  StrCmp $R8 $R1 0 FindMarker2
   StrCpy $R7 $R7 $R5
   StrCpy $R0 $R0$R7

 Done:
  FileClose $R6

 Pop $R8
 Pop $R7
 Pop $R6
 Pop $R5
 Pop $R4
 Pop $R3
 Pop $R2
 Pop $R1
 Exch $R0
FunctionEnd

Function un.GetBetween
 Exch $R0 ; file    ; $R0_Old + AndThis + This + Stack
 Exch               ;  AndThis + $R0_Old + This + Stack
 Exch $R1 ; before this (marker 2)  ;  $R1_Old + $R0_Old + This + Stack
 Exch 2             ;  This + $R0_Old + $R1_Old + Stack
 Exch $R2 ; after this  (marker 1) $R2_Old + $R0_OLD + $R1_Old + Stack
 Exch 2             ; $R1_Old + $R0_OLD + $R2_Old + Stack
 Exch               ; $R0_Old + $R1_OLD + $R2_Old + Stack
 Exch 2             ; $R2_Old + $R1_OLD + $R0_Old + Stack
 Push $R3 ; marker 1 len R3,R2,R1,R0,Stack
 Push $R4 ; marker 2 len R4,R3,R2,R1,R0,Stack
 Push $R5 ; marker pos   R5,R4,R3,R2,R1,R0,Stack
 Push $R6 ; file handle  R6,R5,R4,R3,R2,R1,R0,Stack
 Push $R7 ; current line string R7,R6,R5,R4,R3,R2,R1,R0,Stack
 Push $R8 ; current chop R8,R7,R6,R5,R4,R3,R2,R1,R0,Stack


 FileOpen $R6 $R0 r

 StrLen $R4 $R2
 StrLen $R3 $R1

 StrCpy $R0 ""

 Read1:
  ClearErrors
  FileRead $R6 $R7
  IfErrors Done
  StrCpy $R5 0

 FindMarker1:
  IntOp $R5 $R5 - 1
  StrCpy $R8 $R7 $R4 $R5
  StrCmp $R8 "" Read1
  StrCmp $R8 $R2 0 FindMarker1
   IntOp $R5 $R5 + $R4
   StrCpy $R7 $R7 "" $R5

  StrCpy $R5 -1
  Goto FindMarker2

 Read2:
  ClearErrors
  FileRead $R6 $R7
  IfErrors Done
  StrCpy $R5 -1

 FindMarker2:
  IntOp $R5 $R5 + 1
  StrCpy $R8 $R7 $R3 $R5
  StrCmp $R8 "" 0 +3
   StrCpy $R0 $R0$R7
  Goto Read2
  StrCmp $R8 $R1 0 FindMarker2
   StrCpy $R7 $R7 $R5
   StrCpy $R0 $R0$R7

 Done:
  FileClose $R6

 Pop $R8
 Pop $R7
 Pop $R6
 Pop $R5
 Pop $R4
 Pop $R3
 Pop $R2
 Pop $R1
 Exch $R0
FunctionEnd

; End code for FindBetween functions and macro

##############################
## ADDINGPLATFORM ## Step 1 ##
########################################################################################################################################################
## These functions are callbacks.  When you're using the restore macros you can specifiy callbacks if you need to micromanage the restore .
## The call backs need to take the top item of the stack and put it in the expected global var for the function.
## then the function will note the state of healFromOldFile, and it knows to find that in the appropriate var specific to the subroutine.
##
## Yes, we could have just used the register, but it becomes so damn unreadable and confusing. We're not doing anyting so heavily memory intensive that
## a few globals affect the performance.  But it DOES affect the readability of the code.
########################################################################################################################################################
##
##
## Sample:
##
## Function restoreMYNEWPLATFORM_ConfigFile
##  ; Ok, if you're restoring from the old File we'll need to strip out the relevant section, and put it back without stomping any other changes
##  ; to the MXGuard file.
##  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back carefuly versus a complete revert.
##  Exch $0                                 ; swap the top of the stack with the zero register.
##  StrCpy $archivedMXGUARDiniPath $0       ; Put that in the archivedMYNEWPLATFORMPath var
##  pop $0  ;restore                        ; put the top of the stack back into the register. ( Its original value. )
##  call editMYNEWPLATFORM_ConfigFile       ; call the callback that is expecting to handle $healFromOldFile and $archivedMYNEWPLATFORMPath
##  FunctionEnd
########################################################################################################################################################

Function restoreMDaemonDAT
  ; Ok, if you're restoring from the old Plugins.dat File we'll need to strip out the relevant section,
  ; and put it back without stomping any other changes
  ; to the Plugins.dat MDaemon file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedMDPluginsDatPath $0       ; file to read for stripping SNF OUT and putting stuff back.
  pop $0  ;restore

  call editMDPluginsFile
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function un.restoreMDaemonDAT
  ; Ok, if you're restoring from the old Plugins.dat File we'll need to strip out the relevant section,
  ; and put it back without stomping any other changes
  ; to the Plugins.dat MDaemon file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedMDPluginsDatPath $0       ; file to read for stripping SNF OUT and putting stuff back.
  pop $0  ;restore

  call un.editMDPluginsFile
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function restoreMXGuardINI
  ; Ok, if you're restoring from the old MXGuardFile we'll need to strip out the relevant section, and put it back without stomping any other changes
  ; to the MXGuard file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedMDPluginsDatPath $0       ; file to use for putting stuff back.
  ;MessageBox MB_OK "INI File archived here:$archivedMXGUARDiniPath"
  pop $0  ;restore
  call editMXGuardINI
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function un.restoreMXGuardINI
  ; Ok, if you're restoring from the old MXGuardFile we'll need to strip out the relevant section, and put it back without stomping any other changes
  ; to the MXGuard file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedMXGUARDiniPath $0       ; file to use for putting stuff back.
  ;MessageBox MB_OK "INI File archived here:$archivedMXGUARDiniPath"
  pop $0  ;restore
  call un.editMXGuardINI
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function restoreGLOBALcfg
  ; MessageBox MB_OK "Called restoreGLOBALcfg"
  ; In order for this to be complete, we need to strip the old file, and insert into the new file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedGLOBALcfgPath $0       ; file to use for putting stuff back.
  pop $0  ;restore
  call editglobalCFG
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function un.restoreGLOBALcfg
  ; MessageBox MB_OK "Called restoreGLOBALcfg"
  ; In order for this to be complete, we need to strip the old file, and insert into the new file.
  StrCpy $healFromOldFile "1"             ; used to flag putting stuff back.
  Exch $0 ;swap
  StrCpy $archivedGLOBALcfgPath $0       ; file to use for putting stuff back.
  pop $0  ;restore
  call un.editglobalCFG
  StrCpy $healFromOldFile "0"             ; clear flag.
FunctionEnd

Function restoreCONTENTxml
    call editContentXML
FunctionEnd
Function un.restoreCONTENTxml
    call un.editContentXML
FunctionEnd

Function restoreMINIMIini
  ; MessageBox MB_OK "Called restoreMINIMIini"
FunctionEnd
Function un.restoreMINIMIini
  ; MessageBox MB_OK "Called restoreMINIMIini"
FunctionEnd

Function restoreXYNTini
  ; MessageBox MB_OK "Called restoreXYNTini"
FunctionEnd
Function un.restoreXYNTini
  ; MessageBox MB_OK "Called restoreXYNTini"
FunctionEnd

Function restoreGETRULBASEcmd
  ; MessageBox MB_OK "Called restoreGETRULBASEcmd"
  
FunctionEnd
Function un.restoreGETRULBASEcmd
  ; MessageBox MB_OK "Called restoreGETRULBASEcmd"

FunctionEnd

#########################################################
Function ResolveFunction
  ; This function abstracts a string into a function call.  All strings that are known to be used as callbacks with files, need to be defined here
  ; as the response for the callback handler.  It pushes the callback function name, and the file that the rollback WOULD be overwriting if it
  ; were to continue without the callback interrupt.
  
  push $R0  ; stack is $R0 CallbackFunction FilePath Stack
  Exch      ; stack is CallbackFunction $R0 FilePath Stack
  pop $R0   ; stack is $R0 FilePath Stack
  push $R1  ; stack is $R1 $R0 FilePath Stack ; thought we might use it but not right now.....
  Exch 2    ; stack is FilePath $R0 $R1 Stack
  pop $R1   ; stack is $R0 $R1 Stack
  
        ##############################
        ## ADDINGPLATFORM ## Step 2 ##
        ########################################################################################################################################################
        ## Here is how we explicitly define the callback functions.  If you NEED to handle the callback, you need to define it here.
        ## Sounds wierd but theren's no runtime binding to function vars in NSIS.
        ## i.e. You can't read a piece of text and say, call eval($myString)
        ## This is the best you can do.
        ##
        ## Note:  If you desire to provide a reference to the file to use as the source, you need to push the file back onto the stack to be retrieved
        ##        by the Step 1 Restore function.

         ${Switch} $R0
            ${Case} "restoreMXGuardINI"
                push $R1 ; Stack is now MXGuardiniFilePath  +  $R0 $R1 stack
                call restoreMXGuardINI
                goto doneResolving
            ${Case} "restoreGLOBALcfg"
                push $R1 ; Stack is now Global.cfgFilePath  + $R0 $R1 stack
                call restoreGLOBALcfg ; This function pops for the filepath. Stack is now $R0 $R1 Stack
                goto doneResolving
            ${Case} "restoreMINIMIini"
                call restoreMINIMIini
                goto doneResolving
            ${Case} "restoreXYNTini"
                call restoreXYNTini
                goto doneResolving
            ${Case} "restoreGETRULBASEcmd"
                call restoreGETRULBASEcmd
                goto doneResolving
            ${Case} "restoreCONTENTxml"
                call restoreCONTENTxml
                goto doneResolving
            ${Case} "restoreMDaemonDAT"
                push $R1 ; Stack is now MDaemonDATFILEPATH + stack
                call restoreMDaemonDAT
                goto doneResolving
          ${EndSwitch}
  doneResolving:
  pop $R0   ;restore
  pop $R1   ;restore
FunctionEnd



#########################################################
Function un.ResolveFunction
  ; This function abstracts a string into a function call.  All strings that are known to be used as callbacks with files, need to be defined here
  ; as the response for the callback handler.
  push $R0  ; stack is $R0 CallbackFunction FilePath Stack
  Exch      ; stack is CallbackFunction $R0 FilePath Stack
  pop $R0   ; stack is $R0 FilePath Stack
  push $R1  ; stack is $R1 $R0 FilePath Stack ; thought we might use it but not right now.....
  Exch 2    ; stack is FilePath $R0 $R1 Stack
  pop $R1   ; stack is $R0 $R1 Stack


##############################
## ADDINGPLATFORM ## Step 2 ##
########################################################################################################################################################
## Here is how we explicitly define the callback functions for the uninstaller.  If you NEED to handle the callback, you need to define it here.
## Sounds wierd but theren's no runtime binding to function vars in NSIS.
## i.e. You can't read a piece of text and say, call eval($myString)
## This is the best you can do.
##
## Note:  If you desire to provide a reference to the file to use as the source, you need to push the file back onto the stack to be retrieved
##        by the Step 1 Restore function.

         ${Switch} $R0
            ${Case} "restoreMXGuardINI"
                push $R1 ; Stack is now MXGuardiniFilePath  + stack
                call un.restoreMXGuardINI
                goto doneResolving
            ${Case} "restoreGLOBALcfg"
                push $R1 ; Stack is now Global.cfgFilePath  + stack
                call un.restoreGLOBALcfg ; This function pops for the filepath. Stack is now $R0 $R1 Stack
                goto doneResolving
            ${Case} "restoreMINIMIini"
                call un.restoreMINIMIini
                goto doneResolving
            ${Case} "restoreXYNTini"
                call un.restoreXYNTini
                goto doneResolving
            ${Case} "restoreGETRULBASEcmd"
                call un.restoreGETRULBASEcmd
                goto doneResolving
            ${Case} "restoreCONTENTxml"
                call un.restoreCONTENTxml
                goto doneResolving
            ${Case} "restoreMDaemonDAT"
                push $R1 ; Stack is now MDaemonDATFILEPATH + stack
                call un.restoreMDaemonDAT
                goto doneResolving
          ${EndSwitch}
  doneResolving:
  pop $R0   ;restore
  pop $R1   ;restore
FunctionEnd

########################################################## Utilities For Archiving purposes #################################################33
##
## Rollback.nsh   - Written By Andrew Wallo for Microneil Research, Arm Research general permissions granted.
##
## Reqires the definition of the GetBetween macros.... ( NOTE:  The macros shown on the NSIS website have a stack registry error as of Aug 18th 2008)
## Code was repaired and sent in.
!include "rollback.nsh"  
##################################################### End Utilities for Archiving. #######################################################

; StrReplace
; Replaces all ocurrences of a given needle within a haystack with another string
; Written by dandaman32

Var STR_REPLACE_VAR_0
Var STR_REPLACE_VAR_1
Var STR_REPLACE_VAR_2
Var STR_REPLACE_VAR_3
Var STR_REPLACE_VAR_4
Var STR_REPLACE_VAR_5
Var STR_REPLACE_VAR_6
Var STR_REPLACE_VAR_7
Var STR_REPLACE_VAR_8

Function StrReplace
  Exch $STR_REPLACE_VAR_2
  Exch 1
  Exch $STR_REPLACE_VAR_1
  Exch 2
  Exch $STR_REPLACE_VAR_0
    StrCpy $STR_REPLACE_VAR_3 -1
    StrLen $STR_REPLACE_VAR_4 $STR_REPLACE_VAR_1
    StrLen $STR_REPLACE_VAR_6 $STR_REPLACE_VAR_0
    loop:
      IntOp $STR_REPLACE_VAR_3 $STR_REPLACE_VAR_3 + 1
      StrCpy $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_4 $STR_REPLACE_VAR_3
      StrCmp $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_1 found
      StrCmp $STR_REPLACE_VAR_3 $STR_REPLACE_VAR_6 done
      Goto loop
    found:
      StrCpy $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_3
      IntOp $STR_REPLACE_VAR_8 $STR_REPLACE_VAR_3 + $STR_REPLACE_VAR_4
      StrCpy $STR_REPLACE_VAR_7 $STR_REPLACE_VAR_0 "" $STR_REPLACE_VAR_8
      StrCpy $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_5$STR_REPLACE_VAR_2$STR_REPLACE_VAR_7
      StrLen $STR_REPLACE_VAR_6 $STR_REPLACE_VAR_0
      Goto loop
    done:
  Pop $STR_REPLACE_VAR_1 ; Prevent "invalid opcode" errors and keep the
  Pop $STR_REPLACE_VAR_1 ; stack as it was before the function was called
  Exch $STR_REPLACE_VAR_0
FunctionEnd

Function un.StrReplace
  Exch $STR_REPLACE_VAR_2
  Exch 1
  Exch $STR_REPLACE_VAR_1
  Exch 2
  Exch $STR_REPLACE_VAR_0
    StrCpy $STR_REPLACE_VAR_3 -1
    StrLen $STR_REPLACE_VAR_4 $STR_REPLACE_VAR_1
    StrLen $STR_REPLACE_VAR_6 $STR_REPLACE_VAR_0
    loop:
      IntOp $STR_REPLACE_VAR_3 $STR_REPLACE_VAR_3 + 1
      StrCpy $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_4 $STR_REPLACE_VAR_3
      StrCmp $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_1 found
      StrCmp $STR_REPLACE_VAR_3 $STR_REPLACE_VAR_6 done
      Goto loop
    found:
      StrCpy $STR_REPLACE_VAR_5 $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_3
      IntOp $STR_REPLACE_VAR_8 $STR_REPLACE_VAR_3 + $STR_REPLACE_VAR_4
      StrCpy $STR_REPLACE_VAR_7 $STR_REPLACE_VAR_0 "" $STR_REPLACE_VAR_8
      StrCpy $STR_REPLACE_VAR_0 $STR_REPLACE_VAR_5$STR_REPLACE_VAR_2$STR_REPLACE_VAR_7
      StrLen $STR_REPLACE_VAR_6 $STR_REPLACE_VAR_0
      Goto loop
    done:
  Pop $STR_REPLACE_VAR_1 ; Prevent "invalid opcode" errors and keep the
  Pop $STR_REPLACE_VAR_1 ; stack as it was before the function was called
  Exch $STR_REPLACE_VAR_0
FunctionEnd

!macro _strReplaceConstructor OUT NEEDLE NEEDLE2 HAYSTACK
  Push "${HAYSTACK}"
  Push "${NEEDLE}"
  Push "${NEEDLE2}"
  Call StrReplace
  Pop "${OUT}"
!macroend

!macro un._strReplaceConstructor OUT NEEDLE NEEDLE2 HAYSTACK
  Push "${HAYSTACK}"
  Push "${NEEDLE}"
  Push "${NEEDLE2}"
  Call un.StrReplace
  Pop "${OUT}"
!macroend

!define StrReplace '!insertmacro "_strReplaceConstructor"'
!define un.StrReplace '!insertmacro "un._strReplaceConstructor"'

!macro ReplaceInFile SOURCE_FILE SEARCH_TEXT REPLACEMENT
  Push "${SOURCE_FILE}"
  Push "${SEARCH_TEXT}"
  Push "${REPLACEMENT}"
  Call RIF
!macroend

!macro un.ReplaceInFile SOURCE_FILE SEARCH_TEXT REPLACEMENT
  Push "${SOURCE_FILE}"
  Push "${SEARCH_TEXT}"
  Push "${REPLACEMENT}"
  Call un.RIF
!macroend

Function RIF

  ClearErrors  ; want to be a newborn

  Exch $0      ; REPLACEMENT
  Exch
  Exch $1      ; SEARCH_TEXT
  Exch 2
  Exch $2      ; SOURCE_FILE

  Push $R0     ; SOURCE_FILE file handle
  Push $R1     ; temporary file handle
  Push $R2     ; unique temporary file name
  Push $R3     ; a line to sar/save
  Push $R4     ; shift puffer

  IfFileExists $2 +1 RIF_error      ; knock-knock
  FileOpen $R0 $2 "r"               ; open the door

  GetTempFileName $R2               ; who's new?
  FileOpen $R1 $R2 "w"              ; the escape, please!

  RIF_loop:                         ; round'n'round we go
    FileRead $R0 $R3                ; read one line
    IfErrors RIF_leaveloop          ; enough is enough
    RIF_sar:                        ; sar - search and replace
      Push "$R3"                    ; (hair)stack
      Push "$1"                     ; needle
      Push "$0"                     ; blood
      Call StrReplace               ; do the bartwalk
      StrCpy $R4 "$R3"              ; remember previous state
      Pop $R3                       ; gimme s.th. back in return!
      StrCmp "$R3" "$R4" +1 RIF_sar ; loop, might change again!
    FileWrite $R1 "$R3"             ; save the newbie
  Goto RIF_loop                     ; gimme more

  RIF_leaveloop:                    ; over'n'out, Sir!
    FileClose $R1                   ; S'rry, Ma'am - clos'n now
    FileClose $R0                   ; me 2
    ;MessageBox MB_OK "Files Closed. $R1 , $R0"
    Delete "$2.old"                 ; go away, Sire
    ;MessageBox MB_OK "Deleete $2.old"
    Rename "$2" "$2.old"            ; step aside, Ma'am
    ;MessageBox MB_OK "Rename $2 to $2.old"
    Rename "$R2" "$2"               ; hi, baby!
    ;MessageBox MB_OK "Rename $R2 to $2"
    Delete "$2.old"
    ClearErrors                     ; now i AM a newborn
    Goto RIF_out                    ; out'n'away

  RIF_error:                        ; ups - s.th. went wrong...
    SetErrors                       ; ...so cry, boy!

  RIF_out:                          ; your wardrobe?
  Pop $R4
  Pop $R3
  Pop $R2
  Pop $R1
  Pop $R0
  Pop $2
  Pop $0
  Pop $1

FunctionEnd

Function un.RIF

  ClearErrors  ; want to be a newborn

  Exch $0      ; REPLACEMENT
  Exch
  Exch $1      ; SEARCH_TEXT
  Exch 2
  Exch $2      ; SOURCE_FILE

  Push $R0     ; SOURCE_FILE file handle
  Push $R1     ; temporary file handle
  Push $R2     ; unique temporary file name
  Push $R3     ; a line to sar/save
  Push $R4     ; shift puffer

  IfFileExists $2 +1 RIF_error      ; knock-knock
  FileOpen $R0 $2 "r"               ; open the door

  GetTempFileName $R2               ; who's new?
  FileOpen $R1 $R2 "w"              ; the escape, please!

  RIF_loop:                         ; round'n'round we go
    FileRead $R0 $R3                ; read one line
    IfErrors RIF_leaveloop          ; enough is enough
    RIF_sar:                        ; sar - search and replace
      Push "$R3"                    ; (hair)stack
      Push "$1"                     ; needle
      Push "$0"                     ; blood
      Call un.StrReplace               ; do the bartwalk
      StrCpy $R4 "$R3"              ; remember previous state
      Pop $R3                       ; gimme s.th. back in return!
      StrCmp "$R3" "$R4" +1 RIF_sar ; loop, might change again!
    FileWrite $R1 "$R3"             ; save the newbie
  Goto RIF_loop                     ; gimme more

  RIF_leaveloop:                    ; over'n'out, Sir!
    FileClose $R1                   ; S'rry, Ma'am - clos'n now
    FileClose $R0                   ; me 2
    ;MessageBox MB_OK "Files Closed. $R1 , $R0"
    Delete "$2.old"                 ; go away, Sire
    ;MessageBox MB_OK "Deleete $2.old"
    Rename "$2" "$2.old"            ; step aside, Ma'am
    ;MessageBox MB_OK "Rename $2 to $2.old"
    Rename "$R2" "$2"               ; hi, baby!
    ;MessageBox MB_OK "Rename $R2 to $2"
    Delete "$2.old"
    ClearErrors                     ; now i AM a newborn
    Goto RIF_out                    ; out'n'away

  RIF_error:                        ; ups - s.th. went wrong...
    SetErrors                       ; ...so cry, boy!

  RIF_out:                          ; your wardrobe?
  Pop $R4
  Pop $R3
  Pop $R2
  Pop $R1
  Pop $R0
  Pop $2
  Pop $0
  Pop $1

FunctionEnd

Function nsinstfilesExitSub
  ;MessageBox MB_OK "I'm out."
FunctionEnd
#################################################################################################################################
# This function tests to ensure that all the chars in its SourceString are included in its TestString.
# Its output is in the AlphaNumericalResult which, as long as its > 0 indicates the validity of all chars in the string.
# It depends on the WORDFIND library.
Function TestAlphaNumerics

  ; load the alphanumerical test string
  StrCpy $AlphanumericalTestString "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyz" ; for alphnumeric, char must be in here.
  ; Now test the words.
          ; Seed the testChar...
          StrCpy $AlphaNumericalTestChar $AlphaNumericsSourceString 1 0 ; take the first character from the working License string.

          ; ${WordFind} $AlphanumericalTestString $AlphaNumericalTestChar "*" $AlphaNumericalResult ; This will return in #R0 the number of times the delimiter  was found in teh testString.
          TestAlphaNumerics_getchar: ${WordFind} $AlphanumericalTestString $AlphaNumericalTestChar "E+1{" $AlphaNumericalResult
	    IfErrors AlphaNumerics_notfound AlphaNumerics_found
            AlphaNumerics_found: ; things are ok, handle next char.
	      StrLen $AlphaNumericalSSLen $AlphaNumericsSourceString ; get the current length of the source string
              ${IF}  $AlphaNumericalSSLen > 1 ; if we don't have any more chars... then we quit, otherwize continue.
                StrCpy $AlphaNumericsSourceString $AlphaNumericsSourceString "" 1   ; trim off the leading char.

                StrCpy $AlphaNumericalTestChar $AlphaNumericsSourceString 1 0       ; strip off the next one to test.
                Goto TestAlphaNumerics_getchar
              ${ELSE}
                ; exit test
                StrCpy $AlphaNumericalResult "1"
                return
              ${ENDIF}

	    AlphaNumerics_notfound:
	      ;MessageBox MB_OK "$AlphaNumericsSourceString,$AlphaNumericalTestChar,$AlphaNumericalResult"
	      StrCpy $AlphaNumericalResult "0"
              return
FunctionEnd




Function nsDialogsUserName
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Enter License and Authentication:"
        !insertmacro BIMAGE "SnifferBannerIdentity.bmp" ""

	nsDialogs::Create /NOUNLOAD 1018
	Pop $0

        ${NSD_CreateLabel} 0 20 60% 8u "Enter License (8 Chars)"
	Pop $0

	${NSD_CreateText} 0 40 40% 12u $LicenseID
	Pop $EDITLicense
	GetFunctionAddress $0 OnChangeLicense
	nsDialogs::OnChange /NOUNLOAD $EDITLicense $0

        ${NSD_CreateLabel} 50% 20 60% 8u "Enter Authentication (16 Chars)"
	Pop $0

        ${NSD_CreateText} 50% 40 40% 12u $Authentication
	Pop $EDITAuthentication
	GetFunctionAddress $0 OnChangeAuthentication
	nsDialogs::OnChange /NOUNLOAD $EDITAuthentication $0

        ${NSD_CreateCheckbox} 0 50u 100% 16u "  Select this if you have email accounts that intentionally receive spam.$\n  ( Will automatically open file for editing email accounts after install. )"
	Pop $CHECKBOX
	GetFunctionAddress $0 OnCheckStickyPot
	nsDialogs::OnClick /NOUNLOAD $CHECKBOX $0

	${NSD_CreateCheckbox} 0 80u 100% 16u "  Select if you have gateways that need to be entered into the Ignore List.$\n  ( Will automatically open file for editing Gateway IP's after install. )"
	Pop $CHECKBOX
	GetFunctionAddress $0 OnCheckboxGateway
	nsDialogs::OnClick /NOUNLOAD $CHECKBOX $0

        Var /GLOBAL HelpMeButton
        ${NSD_CreateButton} 0 110u 100% 16u "Help! I don't have a license key.  Do you have a webpage to help me?"
        Pop $HelpMeButton
        ${NSD_OnClick} $HelpMeButton OpenHelpMePage


	nsDialogs::Show
FunctionEnd

Function OpenHelpMePage
  ExecShell "open" "http://www.armresearch.com/products/trial.jsp"
FunctionEnd

Function nsDialogsUserName_leave

	  StrLen $testInputLength $LicenseID;
          ; test to ensure that we have a non-zero string length;
          ${If} $testInputLength != "9" ; Include one for the nullterminator.  i.e. an 8char LicsenseID will read 9 for string lenght.
            MessageBox MB_OK "License Keys are eight characters in length.  Please double check your License Key."
            abort
          ${EndIf}

          StrLen $testInputLength $Authentication;
          ; test to ensure that we have a non-zero string length;
          ${If} $testInputLength != "17" ; Include one for the nullterminator.  i.e. an 16char LicsenseID will read 17 for string lenght.
            MessageBox MB_OK "Authentication Keys are sixteen characters in length.  Please double check your Authentication String."
    	    abort
    	   ${EndIf}

          ; TODO TODO TODO : When a user hits back, the page loads unmarked checkboxes.... it doesnt' remember state.  It should.

          ; LICENSE ID ALPHANUMERIAL TEST
          ; Now test to ensure that we are using alpha numerical characters not puncutation etc.

          StrCpy $AlphaNumericsSourceString $LicenseID 8 0 ; Copy the License String into a working string to be abused. Trim null terminator char for comparsion.

          Call TestAlphaNumerics ; test the string.
          StrCmp $AlphaNumericalResult "1" nextTest nextLine ; skip command if equal, otherwise fall through and abort.
            nextline:
            MessageBox MB_OK "License and Authentication strings must be alphanumerical. A-Z,a-Z,0-9"
            abort ; advance one command if not equal, and fail.
          ; system ok.
          nextTest: StrCpy $AlphaNumericsSourceString $Authentication 16 0 ; Copy the License String into a working string to be abused. Trim null terminator char for comparsion.
          Call TestAlphaNumerics ; test the string.
          StrCmp $AlphaNumericalResult "1" done nextAbort ; skip command if equal, otherwise fall through and abort.
            nextAbort:
            MessageBox MB_OK "License and Authentication strings must be alphanumerical. A-Z,a-Z,0-9"
            abort ; advance one command if not equal, and fail.
          ; system ok.
          
          done:
          ; clear flag for use rulebase
          StrCpy $UseDetectedRulebase "0"
FunctionEnd

Function nsDialogsGetRulebase
        !insertmacro BIMAGE "SnifferBannerFindingRulebase.bmp" ""
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Finding Rulebase:"
       ;MessageBox MB_OK "inside nsDialogsGetRulebase"
        nsDialogs::Create /NOUNLOAD 1018
	Pop $0

        ; Ensure to set the global test variable to zero
        StrCpy $SNF2Check "1" ; Default to fail.  If we come back to this page it will reset and test again anyway.  That is good.
        ; This holds the result of the sniffer2check test.
        ; And clear the checkbox for reusing the rulebase too.
        StrCpy $UseDetectedRulebase "0" ; clear flag for use rulebase
          
       ; Set output path to the installation directory.
       SetOutPath $INSTDIR ;
       ; NOTE installing and unpacking the getRulebase.cmd was moved here to keep the relevant actions together.  It was commented out in other places.
       ; ALL versions and installs must fire this page.  So its version safe.  Even if you don't download a new rulebase.
       
       StrCmp $UnpackedCURLStuff "1" SkipUnpacking 0  ; Don't continue to add this to the rollback file, if you are backing up in the user screens.
               ; Ok because of either retaining settings, or resetting settings,
               ; we'll either put the existing rulebase file back later ( In the section for handling this feature, or we'll
               ; leave this one in place.  Either way, it doesn't hurt to just stomp it here and resolve the retain-settings later.
               ${Install_with_RollbackControl} "getRulebase.cmd" "" "" ; Before with callback... but not needed... file level ok for GetRulebase... "restoreGETRULBASEcmd" ""

               # If you delete it prior to installing with rollback control, it won't have a copy in rollback
               ;ifFileExists "curl.exe" 0 +2
                 ;Delete "curl.exe" ; reinstore the newer version.
               ${Install_with_RollbackControl} "curl.exe" "" ""
               ;ifFileExists "gzip.exe" 0 +2
                 ;Delete "gzip.exe"
               ;${Install_with_RollbackControl} "gzip.exe" "" ""
               ;ifFileExists "snf2Check.exe" 0 +2
                 ;Delete "snf2Check.exe"
               ${Install_with_RollbackControl} "snf2Check.exe" "" ""
       StrCpy $UnpackedCURLStuff "1"
       SkipUnpacking:
       
       Call editGetRulebase ; Finds Opens edits the Path  License and Authentication strings in the getRulebase file.
       ; This is done because you need it set propelry for executing the rulebase download.
       
        Var /GLOBAL DownloadText
        Var /GLOBAL NextButton
        ; If this is an upgrade from a previous state, we just copy the rulebase and we move on to the next page.
        ; Now find all the folders in the Archive Direcotry
        ;GetDlgItem $NextButton $HWNDPARENT 1
        ;EnableWindow $NextButton "0"

        ifFileExists "$INSTDIR\$LicenseID.snf" 0 NothingDetected
          ; Default is to use the detected rulebase, so set the flag.
          StrCpy $UseDetectedRulebase "1"
          ${NSD_CreateLabel} 0 0 25% 30 "Rulebase detected."
          Pop $0
          ${NSD_CreateCheckbox} 100 00 15 20 ""
          Pop $CHECKBOX
          ${NSD_CreateLabel} 120 0 65% 40 "Check if you want to download the newest rulebase.$\nLeave unchecked to use the existing rulebase."
          Pop $0

	  GetFunctionAddress $8 OnUseDetected
	  nsDialogs::OnClick /NOUNLOAD $CHECKBOX $8
          Goto EndDetectionLabel
        
        NothingDetected:
          ${NSD_CreateLabel} 0 0 100% 15 "No Rulebase detected. { Download is required. }"
          Pop $0
        EndDetectionLabel:

        ${NSD_CreateLabel} 0 35 100% 60 "Please be patient as this may take a few minutes depending upon your bandwidth.$\n$\nIf the installer cannot download a rulebase, your LicenseID or Authentication may$\nbe entered incorrectly."
        Pop $0
        ${NSD_CreateLabel} 0 100 100% 90 "Note: You may be so eager to use Message Sniffer that you have attempted to install it before our server could compile your first rulebase.  $\n$\nIf this happens just wait a few minutes or check your email for the update notification to inform you that your first rulebase has been created.  Thank you."
        Pop $0
        
	nsDialogs::Show
	
FunctionEnd

Function OnUseDetected
  	Pop $0 # HWND
	${IF} $UseDetectedRulebase == 1
          StrCpy $UseDetectedRulebase "0";
	${ELSE}
	  StrCpy $UseDetectedRulebase "1";
	${ENDIF}
FunctionEnd

Function nsDialogsGetRulebase_leave
        !insertmacro BIMAGE "SnifferBannerFindingRulebase.bmp" ""
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Downloading Rulebase:"
        ;MessageBox MB_OK "inside nsDialogsGetRulebase"
    
        ;MessageBox MB_OK "inside nsDialogsGetRulebase_leave"

        ; Ok we're leaving but if we're using an existing rulebase, we still should test the sniffer2check test for the new authentication string..
        StrCmp $UseDetectedRulebase "1" 0 GetTheRulebaseNow
            ; Ok, well do the sniffer2check for concurrance....
            ;ExecWait 'snf2check.exe $LicenseID.snf "$Authentication"' $9
            ;pop $9
            nsExec::ExecToLog '"$INSTDIR\snf2check.exe" "$LicenseID.snf" "$Authentication"'
            pop $0
            ;DetailPrint "Snf2Check Reports:$0$\r$\n"
            ;MessageBox MB_OK "Snf2Check Reports:$0$\r$\n"
            StrCpy $SNF2Check $0 ; Set this to determine the message for the next screen, or if we just pass through. ( 0 result is clean )
        Return
        
        
    GetTheRulebaseNow:
        ; Else download and report.
        ;nsDialogs::Create /NOUNLOAD 1018
	;Pop $0

        ${NSD_CreateLabel} 0 180 100% 30 "Starting download attempt... Approximate Size of Rulebase: 20Mb"
        Pop $DownloadText
        StrCpy $DownloadFailed "0"
        ; Now grey out the next until we complete or fail....
        GetDlgItem $NextButton $HWNDPARENT 1
        EnableWindow $NextButton "0"

                  Var /GLOBAL TempBatchFileHandle
                  Var /GLOBAL ThreadHandleExitCode
                  
                  ifFileExists "$INSTDIR\$LicenseID.new" 0 +2  ; test for file.
                    Delete "$INSTDIR\$LicenseID.new"           ; clean up old file.
                  ifFileExists "$INSTDIR\curlresult.txt" 0 +2  ; test for file.
                    Delete "$INSTDIR\curlresult.txt"           ; clean up old file.

                  ;Curl new file.
                  FileOpen $TempBatchFileHandle "$INSTDIR\TempGetCall.cmd" w         ; Removing the conditional on download.  We ALWAYS want it to download. -z $LicenseID.snf
                  ;FileWrite $TempBatchFileHandle "wget -a wgetreport.txt http://www.sortmonster.net/Sniffer/Updates/$LicenseID.snf -O $LicenseID.new.gz --header=Accept-Encoding:gzip --http-user=sniffer --http-passwd=ki11sp8m"
                  FileWrite $TempBatchFileHandle  'curl -v "http://www.sortmonster.net/Sniffer/Updates/$LicenseID.snf" -o $LicenseID.new -S -R -H "Accept-Encoding:gzip" --compressed -u sniffer:ki11sp8m 2>> "$INSTDIR\curlresult.txt"'
                  FileClose $TempBatchFileHandle


                  ;ExecDos::Exec /NOUNLOAD /ASYNC 'curl -v "http://www.sortmonster.net/Sniffer/Updates/$LicenseID.snf" -o $LicenseID.new -S -R -H "Accept-Encoding:gzip" --compressed -u sniffer:ki11sp8m 2>> "$INSTDIR\curlresult.txt"'
                  ExecDos::Exec /NOUNLOAD /ASYNC "$INSTDIR\TempGetCall.cmd"
                  Pop $ThreadHandleExitCode ; exit code

                  ;ExecDos::Exec /NOUNLOAD /ASYNC "TempGetCall.cmd" ""  ""
                  ;Pop $ThreadHandleExitCode ; exit code

                  Var /GLOBAL progressTextFile ; the handle to the file log 'wgetreport.txt'
                  Var /GLOBAL progressTextLine ; line handle
                  Var /GLOBAL progressLastLine ; last line string....
                  ifFileExists "$INSTDIR\TEMPcurlresult.txt" 0 +2
                      Delete "$INSTDIR\TEMPcurlresult.txt" ; Delete it.

                  LoopAgain:
                    Sleep 2000

                      ifFileExists "$INSTDIR\curlresult.txt" 0 CheckForExit  ; Ok, if the file doesn't exist you can't get parameters.
                       CopyFiles /SILENT "$INSTDIR\curlresult.txt" "$INSTDIR\TEMPcurlresult.txt"
                       FileOpen $progressTextFile "$INSTDIR\TEMPcurlresult.txt" r

                      findEndOfFile:
                      FileSeek $progressTextFile -63 "END"
                      FileRead $progressTextFile $progressTextLine
                      StrCpy $progressLastLine $progressTextLine 6 0
                       ;FileRead $progressTextFile $progressTextLine [256]
                       ;ifErrors +3 0 ; If there are errors then we found the end, print the next to last line of text.
                       ;  StrCpy $progressLastLine $progressTextLine "" -20 ; otherwise save next to last line, and loop again.
                       ;  Goto findEndOfFile ; go back for more....
                         ; Now change the label on the screen.
                         SendMessage $DownloadText ${WM_SETTEXT} 0 "STR:File Progress: $progressLastLine byte"
                         ShowWindow $DownloadText ${SW_SHOW} ; show it.
                         FileClose $progressTextFile  ; Close the working file.
                         Delete "$INSTDIR\TEMPcurlresult.txt"

                CheckForExit:
                       ExecDos::isdone /NOUNLOAD $ThreadHandleExitCode
                       Pop $R9 ; keep stack clean
                  StrCmp $R9 1 0 LoopAgain

                ; This will handle cleanup and failure.
                Delete "$INSTDIR\curlresult.txt"

                ;StrCmp $9 "error" CleanupMess 0
                ;ifFileExists "$INSTDIR\$LicenseID.new.gz" 0 CleanupMess
                ; ExecWait "gzip -d -f $LicenseID.new.gz" $9
                ;nsExec::Exec 'gzip -d -f "$INSTDIR\$LicenseID.new.gz"'
                ;pop $9
                ;StrCmp $9 "1" CleanupMess 0 ; success is reported with a '0', failed-with-errors with a '1'.

                ;ExecWait '"$INSTDIR\snf2check.exe" $LicenseID.new "$Authentication"' $0
                nsExec::Exec '"$INSTDIR\snf2check.exe" $LicenseID.new "$Authentication"'
                pop $0
                
                VAR /GLOBAL snf2CheckERROR
                ;MessageBox MB_OK "Snf2Check Reports:$0$\r$\n"
                  ${Switch} $0
                    ${Case} "0"
                        StrCpy $snf2CheckERROR " SNFClient successfuly connected with SNFServer."
                        Goto EndSNF2CheckTest
                    ${Case} "65"
                        StrCpy $snf2CheckERROR  " {65} ERROR_CMDLINE.  SNF was called improperly."
                        Goto EndSNF2CheckTest
                     ${Case} "66"
                        StrCpy $snf2CheckERROR  " {66}ERROR_LOGFILE Cannot open logfile."
                        Goto EndSNF2CheckTest
                     ${Case} "67"
                        StrCpy $snf2CheckERROR  " {67} ERROR RULE FILE.  Cannot open rules file."
                        Goto EndSNF2CheckTest
                     ${Case} "68"
                        StrCpy $snf2CheckERROR  " {68} ERROR_RULE_DATA Cannot create pattern matrix."
                        Goto EndSNF2CheckTest
                     ${Case} "69"
                        StrCpy $snf2CheckERROR  " {69} ERROR_MSG_FILE Cannot open message file."
                        Goto EndSNF2CheckTest
                     ${Case} "70"
                        StrCpy $snf2CheckERROR  " {70} ERROR_ALLOCATION Allocation error during processing."
                        Goto EndSNF2CheckTest
                     ${Case} "71"
                        StrCpy $snf2CheckERROR  " {71} ERROR_BAD_MATRIX Pattern trace went out of range."
                        Goto EndSNF2CheckTest
                     ${Case} "72"
                        StrCpy $snf2CheckERROR  " {72} ERROR_MAX_EVALS The maximum number of evaluation paths was exceeded."
                        Goto EndSNF2CheckTest
                     ${Case} "73"
                        StrCpy $snf2CheckERROR  " {73} ERROR_RULE_AUTH The rulebase file did not authenticate properly."
                        Goto EndSNF2CheckTest
                     ${Case} "99"
                        StrCpy $snf2CheckERROR  " {99} ERROR_UNKNOWN"
                        Goto EndSNF2CheckTest
                  ${EndSwitch}
                EndSNF2CheckTest:
                
                StrCpy $SNF2Check $0 ; set up flag for retaining the result fo this test.
                               
                StrCmp $SNF2Check "0" 0 CleanupMess
                ;if errorlevel not zero goto CLEANUP

                ifFileExists "$INSTDIR\$LicenseID.old" 0 +2
                  Delete "$INSTDIR\$LicenseID.old"
                ifFileExists  "$INSTDIR\$LicenseID.snf" 0 +2
                  rename "$INSTDIR\$LicenseID.snf" "$INSTDIR\$LicenseID.old"
                ifFileExists  "$INSTDIR\$LicenseID.new" 0 +2
                  rename "$INSTDIR\$LicenseID.new" "$INSTDIR\$LicenseID.snf"

                ifFileExists "$INSTDIR\UpdateReady.txt" 0 +2
                  delete  "$INSTDIR\UpdateReady.txt"
                ifFileExists "$INSTDIR\UpdateReady.lck" 0 +2
                  delete  "$INSTDIR\UpdateReady.lck"

                 ; Now trigger the system to enable the AutoUpdater to pull the next rulebase.
                  VAR /GLOBAL UpdateRulebaseHandle
                  FileOpen  $UpdateRulebaseHandle "$INSTDIR\UpdateReady.txt" w
                  FileWrite $UpdateRulebaseHandle " "
                  FileClose $UpdateRulebaseHandle

                  StrCpy $DownloadFailed "0"
                  
                  Delete "$INSTDIR\TempGetCall.cmd"
             Return

                CleanupMess:
                
                ifFileExists "$INSTDIR\TempGetCall.cmd" 0 +2
                  Delete "$INSTDIR\TempGetCall.cmd"
                ifFileExists "$INSTDIR\UpdateReady.txt" 0 +2
                  delete  "$INSTDIR\UpdateReady.txt"
                ifFileExists "$INSTDIR\TempGetCall.cmd" 0 +2
                  delete  "$INSTDIR\TempGetCall.cmd"
                ifFileExists "$INSTDIR\$LicenseID.new" 0 +2
                  delete  "$INSTDIR\$LicenseID.new"
                ifFileExists "$INSTDIR\UpdateReady.lck" 0 +2
                  delete  "$INSTDIR\UpdateReady.lck"
                ifFileExists "$INSTDIR\$LicenseID.new.gz" 0 +2
                  delete  "$INSTDIR\$LicenseID.new.gz"

                StrCpy $DownloadFailed "1"
                Return

FunctionEnd

## Unload the plugin so that the progress bar can be deleted!
;Function .onGUIEnd
;  ;RealProgress::Unload
;FunctionEnd

Function nsDialogsWaitingForRulebase

        !insertmacro BIMAGE "SnifferBannerFindingRulebase.bmp" ""
        ;MessageBox MB_OK "inside nsDialogsWaitingForRulebase"
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Downloading Rulebase:"
        nsDialogs::Create /NOUNLOAD 1018
	Pop $0
	
        
        StrCmp $UseDetectedRulebase "1" 0 NotifyAll  ; If we're not downloading, possibley just skip to components...
          StrCmp $SNF2Check "0" 0 NofityAuthFailure  ; but only if it passes authentication test.... opps... notify and refuse passage.
          ;MessageBox MB_OK "SNF2Check: $SNF2Check "  ; debug....
          Return ; only get to here if all is good... this will progress to next page.

        NotifyAll:
        ; $DownloadFailed This Variable declared in ONinit and defaulted to "0".
        ; If this is an upgrade from a previous state, we just copy the rulebase and we move on to the next page.
        ; Now find all the folders in the Archive Direcotry

        StrCmp $DownloadFailed "1" 0 AllowNext  ; if the download HAS failed we must display a screen.  We may also jump in here if the auth fails.

            Var /GLOBAL ErrorMessage
            StrCpy $ErrorMessage "Your rulebase file could not be authenticated:$\n$\n      $snf2CheckERROR$\n$\n"
            StrCpy $ErrorMessage "$ErrorMessage If the installer cannot download / update your rulebase then:$\n$\n"
            StrCpy $ErrorMessage "$ErrorMessage    * Your License ID and/or Authentication may be entered incorrectly.$\n       Check your entries on the previous screen.$\n$\n"
            StrCpy $ErrorMessage "$ErrorMessage    * If you are new to Message Sniffer your rulebase might not be ready yet.$\n       Check your email for your first update notification email.$\n"

        StrCmp $SNF2Check "0" 0 NofityAuthFailure ; if snf2check was zero and error was because of something else...give normal notification.
          ;GetDlgItem $NextButton $HWNDPARENT 1   ; stop next button from working
          ;EnableWindow $NextButton "0"
          ;${NSD_CreateLabel} 0 70 100% 65 "Download Failed: $snf2CheckERROR  Check your License ID and try again. If you have not yet received an update notification, your rulebase file might not be ready."
          ;Pop $DownloadText
          ;nsDialogs::Show
          ;Return
          
         NofityAuthFailure:  ; failed because of snf2check authroization failure.
            GetDlgItem $NextButton $HWNDPARENT 1 ; stop next button from working
            EnableWindow $NextButton "0"
            ;${NSD_CreateLabel} 0 70 100% 65 "Your rulebase file could not be authenticated: $snf2CheckERROR Please go back and check your License Id and Authentication string and try again.  If you do find a typo in your authentication string, try to use the existing rulebase you have downloaded before trying to download a second copy.  Snf2check will probably authenticate correctly."
            ${NSD_CreateLabel} 0 30 100% 130 $ErrorMessage
            Pop $DownloadText
    	    nsDialogs::Show
            Return


        AllowNext: ; only get to here if download didn't fail.
          ${NSD_CreateLabel} 0 70 100% 30 "The download of your Message Sniffer Rulebase completed successfully. You may proceed with the rest of the installation."
          Pop $DownloadText
    	  nsDialogs::Show
    	return
FunctionEnd

Function OnChangeLicense

	Pop $0 # HWND

	System::Call user32::GetWindowText(i$EDITLicense,t.r0,i${NSIS_MAX_STRLEN})
        StrCpy $LicenseID $0 ; Set the global variable to the new license ID.

FunctionEnd

Function OnChangeAuthentication

	Pop $0 # HWND

	System::Call user32::GetWindowText(i$EDITAuthentication,t.r0,i${NSIS_MAX_STRLEN})

        StrCpy $Authentication $0 ; Set the global variable to the new authentication ID.

FunctionEnd

Function OnCheckStickyPot
	Pop $0 # HWND
	${IF} $HasStickyPots == 1
          StrCpy $HasStickyPots "0";
	${ELSE}
	  StrCpy $HasStickyPots "1";
	${ENDIF}
FunctionEnd

Function OnCheckboxGateway
	Pop $0 # HWND
        ${IF} $OpenGBUIgnoreFileOnClose == "1"
          StrCpy $OpenGBUIgnoreFileOnClose "0";
	${ELSE}
	  StrCpy $OpenGBUIgnoreFileOnClose "1";
	${ENDIF}
FunctionEnd


Function editLicenseFile
          ; In the case of a re-install we don't to stomp the file.. ( Though we did already in the file write... but we'll do this
          ; as a good premtive measure.

          IfFileExists "$INSTDIR\identity.xml" filedoesexist repairfile ; Skip to second instruction if it doesnt' exist.
          repairfile:
          ; This shouldn't happen unless you corrupt or fail in the install of the file from the packed installer.....
          ClearErrors
            FileOpen $0 "$INSTDIR\identity.xml" w
            IfErrors FailedIdentityRepair ; otherwise clear for attempting to recreate.
            FileWrite $0 "<snf><identity licenseid='$LicenseID' authentication='$Authentication'/></snf>" ;
            FileClose $0
            ; MessageBox MB_OK "Installer successfully rebuilt the identity.xml file."
        Goto done

        filedoesexist:
        ; now rename and write new one.
        Delete "$INSTDIR\identity.xml" ; Always stomp with new ID.
        ; because this will always be operating with a newly upacked file, that is there only if the user
        ; wants to do a manual install.
        ; This will only be called after the archived folder has been moved,
        ; and new files are installed.  So stomp the identity.xml file so its ok.
        ClearErrors
                   FileOpen $0 "$INSTDIR\identity.xml" w
                   IfErrors FailedIdentityArchive ; otherwise clear for writing
                   FileWrite $0 "<snf><identity licenseid='$LicenseID' authentication='$Authentication'/></snf>" ;
        FileClose $0
        Goto done
        FailedIdentityRepair:
          MessageBox MB_OK "Installer seemed unable to repair identity.xml file.  Perhaps the file is locked.  Please attempt to create this file manually with the xml contents: <snf><identity licenseid='$LicenseID' authentication='$Authentication'/></snf>"
        Goto  done
        FailedIdentityArchive:
          MessageBox MB_OK "Installer seemed unable to archive identity.xml file.  Perhaps the file is locked.  Please attempt to re/create this file manually with the xml contents: <snf><identity licenseid='$LicenseID' authentication='$Authentication'/></snf>"
        done:
FunctionEnd

Function finishedFilesDisplay
FunctionEND

Function finishedFilesQuit
  Quit ; Don't want to continue to the next page.
FunctionEND

Function finishedRestoreDisplay
        Var /GLOBAL CancelButton
        GetDlgItem $CancelButton $HWNDPARENT 2
        EnableWindow $CancelButton "0"

  StrCmp $InstallerCompletedRestore "1" 0 doneSplashScreen
        nsDialogs::Create /NOUNLOAD 1018
	Pop $0

        Var /GLOBAL IMAGECTL
        Var /GLOBAL IMAGE
	nsDialogs::CreateItem /NOUNLOAD STATIC "" ${WS_VISIBLE}|${WS_CHILD}|${WS_CLIPSIBLINGS}|${SS_BITMAP} 25 60 0 64 64
	Pop $IMAGECTL
	SetOutPath $INSTDIR
        File "SuccessInstall.bmp"
	StrCpy $0 "$INSTDIR\SuccessInstall.bmp"
	System::Call 'user32::LoadImage(i 0, t r0, i ${IMAGE_BITMAP}, i 0, i 0, i ${LR_LOADFROMFILE}) i.s'
	Pop $IMAGE
	SendMessage $IMAGECTL ${STM_SETIMAGE} ${IMAGE_BITMAP} $IMAGE

        nsDialogs::Show
   doneSplashScreen:
   return
FunctionEND

Function finishedRestoreQuit
  StrCmp $InstallerCompletedRestore "1" 0 +2
    Quit ; The Installer is done.
  Return
FunctionEND


!macro handleShortPath Result_Path Source_Path
  Push "${Source_Path}"
  Push "${Result_Path}"
  Call handleShortFilePath
  Pop "${Result_Path}"
!macroend
!define handleShortPath "!insertmacro handleShortPath"

Function handleShortFilePath
   Var /Global local_sourcePath ; where we put the result
   Var /Global local_resultPath ; what we work from
   Var /Global local_searchResults ; WordFind temp var.
   
   pop $local_resultPath
   pop $local_sourcePath
   ${WordFind} $local_sourcePath " " "E+1}" $local_searchResults
   ifErrors 0 FoundSpaceInString ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
     push $local_sourcePath
     return
FoundSpaceInString:
   GetFullPathName /SHORT $local_resultPath $local_sourcePath
   push $local_resultPath
   return
FunctionEnd


!macro un.handleShortPath unResult_Path unSource_Path
  Push "${unSource_Path}"
  Push "${unResult_Path}"
  Call un.handleShortFilePath
  Pop "${unResult_Path}"
!macroend
!define un.handleShortPath "!insertmacro un.handleShortPath"

Function un.handleShortFilePath
   Var /Global unlocal_sourcePath ; where we put the result
   Var /Global unlocal_resultPath ; what we work from
   Var /Global unlocal_searchResults ; WordFind temp var.

   pop $unlocal_resultPath
   pop $unlocal_sourcePath
   ${un.WordFind} $unlocal_sourcePath " " "E+1}" $unlocal_searchResults
   ifErrors 0 unFoundSpaceInString ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
     push $unlocal_sourcePath
     return
unFoundSpaceInString:
   GetFullPathName /SHORT $unlocal_resultPath $unlocal_sourcePath
   push $unlocal_resultPath
   return
FunctionEnd

## This edits the service init file
## so that when you call the XYNTService it will
## Properly boot and start the SNFServer.
Function editXYNTServiceINI
  ;MessageBox MB_OK "Installing XYNTSErviceINI"
  ; Just easier to write it all out.
  Var /GLOBAL iniHandle

  FileOpen $iniHandle "$INSTDIR\XYNTService.ini" w
  FileWrite $iniHandle "[Settings]$\r$\n"
  FileWrite $iniHandle "ProcCount=1$\r$\n" ;
  FileWrite $iniHandle "ServiceName=SNFService$\r$\n"
  FileWrite $iniHandle "CheckProcessSeconds = 30$\r$\n"
  FileWrite $iniHandle "[Process0]$\r$\n"
  
  Var /GLOBAL ShortPathTempVar ; use this to hold the Short Windows Progr~1 path references...
  ;GetFullPathName /SHORT $ShortPathTempVar $INSTDIR
  ${handleShortPath} $ShortPathTempVar $INSTDIR
  
  ;FileWrite $iniHandle "CommandLine = '$\"$INSTDIR\SNFServer.exe$\" $\"$INSTDIR\snf_engine.xml$\"'$\r$\n"
  ;FileWrite $iniHandle "WorkingDir= $\"$INSTDIR$\"$\r$\n"

  FileWrite $iniHandle "CommandLine = '$\"$ShortPathTempVar\SNFServer.exe$\" $\"$ShortPathTempVar\snf_engine.xml$\"'$\r$\n"
  FileWrite $iniHandle "WorkingDir= $\"$ShortPathTempVar$\"$\r$\n"
  FileWrite $iniHandle "PauseStart= 100$\r$\n"
  FileWrite $iniHandle "PauseEnd= 100$\r$\n"
  FileWrite $iniHandle "UserInterface = No$\r$\n"
  FileWrite $iniHandle "Restart = Yes$\r$\n"
  ;FileWrite $iniHandle "UserName =$\r$\n"
  ;FileWrite $iniHandle "Domain =$\r$\n"
  ;FileWrite $iniHandle "Password =$\r$\n"
  
  FileClose $iniHandle
FunctionEnd

##############################
## ADDINGPLATFORM ## Step 3 ##
########################################################################################################################################################
## If the new platform requires complex service handeling, you can group that here to simplify.  Don't forget to support the uninstaller.
##
Function restartMDaemon
     nsExec::Exec "NET STOP MDaemon" "" SH_HIDE
     nsExec::Exec "NET START MDaemon" "" SH_HIDE
FunctionEND

Function un.restartMDaemon
     nsExec::Exec "NET STOP MDaemon" "" SH_HIDE
     nsExec::Exec "NET START MDaemon" "" SH_HIDE
FunctionEND

Function stopMDaemon
    nsExec::Exec "NET STOP MDaemon" "" SH_HIDE
FunctionEnd
Function un.stopMDaemon
    nsExec::Exec "NET STOP MDaemon" "" SH_HIDE
FunctionEnd

Function un.stopSNFServer
  nsExec::Exec "NET STOP SNFService" "" SH_HIDE
FunctionEnd

Function stopSNFServer
     nsExec::Exec "NET STOP SNFService" "" SH_HIDE
FunctionEnd

Function startSNFServer
   ;MessageBox MB_OK "Entering Telemetry generator"
      ;nsExec::Exec "NET START SNFService > '$INSTDIR\Telemetry.txt'" "" SH_HIDE
      nsExec::Exec "NET START SNFService" "" SH_HIDE
      pop $0
      StrCmp $0 "0" 0 +2
        return
      ;MessageBox MB_OK "Staring SNFService return code:$0"
FunctionEnd

## Call the XYNTService to start.
Function startXYNTService
    ; presumes that the .ini file is in the same location.
    nsExec::Exec "XYNTService -r" "" SH_HIDE

FunctionEnd

Function stopXYNTService
    ; presumes that the .ini file is in the same location.
    nsExec::Exec "XYNTService -k" "" SH_HIDE
FunctionEnd

Function un.UninstallXYNTService
   ; This uninstalls the XYNTService
    nsExec::Exec "NET STOP SNFService" "" SH_HIDE
    nsExec::Exec "XYNTService -u" "" SH_HIDE
FunctionEnd

Function installXYNTService
# Function is deprecated because of the FILE Handling managed elsewhere in the flow... and of the new rollback scheme for files....
    Call stopSNFServer ; if it there it will stop it.
    Call stopXYNTService ; if its there, stop it.
    ;MessageBox MB_OK "Starting SNFService"
    SetOutPath $INSTDIR
    File "XYNTService.exe" ; Unpack the files.
    File "XYNTService.ini"
    ; First properly handle the ini file.
    call editXYNTServiceINI
    nsExec::Exec "XYNTService -u" "" SH_HIDE ; uninstall it if it exists....
    ; presumes that the .ini file is in the same location.
    nsExec::Exec "XYNTService -i" "" SH_HIDE ; install XYNTService
    nsExec::Exec "XYNTService -r" "" SH_HIDE ; restart XYNTService

    call startSNFServer     ;nsExec::Exec "NET START SNFService" "" SH_HIDE
    Return

FunctionEnd


Function removeShortcuts
  ##################
  ## Shortcuts removed, from a different user context.
  ; Remove shortcuts, if any
  SetShellVarContext all ; this makes it backward/forwrad compatible  Without it Vista will have problems removing shortcuts.
                         ; Essentially, we said put these shortcuts into the all-users profile of the machine
  Delete "$SMPROGRAMS\MessageSniffer\*.*"
  RMDir "$SMPROGRAMS\MessageSniffer"
  Delete "$INSTDIR\shortcuts.xml"
  ##################
FunctionEnd

Function un.removeShortcuts
  ##################
  ## Shortcuts removed, from a different user context.
  ; Remove shortcuts, if any
  SetShellVarContext all ; this makes it backward/forwrad compatible  Without it Vista will have problems removing shortcuts.
                         ; Essentially, we said put these shortcuts into the all-users profile of the machine
  Delete "$SMPROGRAMS\MessageSniffer\*.*"
  RMDir "$SMPROGRAMS\MessageSniffer"
  Delete "$INSTDIR\shortcuts.xml"
  ##################
FunctionEnd

Function editGetRulebase
  IfFileExists "$INSTDIR\getRulebase.cmd" 0 DoneWithErrors
; This is what is getting edited.
;REM ----- Edit This Section --------;
;
;SET SNIFFER_PATH=c:\SNF
;SET AUTHENTICATION=authenticationxx
;SET LICENSE_ID=licensid
;
;REM --------------------------------

;  Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
;  GetFullPathName /SHORT $ShortPathTempVar $INSTDIR ; for windows greeking.
${handleShortPath} $ShortPathTempVar $INSTDIR

      ${GetBetween} "SET SNIFFER_PATH=" "$\r$\n" "$INSTDIR\getRulebase.cmd" "$R0"  ; This makes it not brittly dependant on the default value. i.e. It would
      !insertmacro ReplaceInFile "$INSTDIR\getRulebase.cmd" "SET SNIFFER_PATH=$R0$\r$\n" "SET SNIFFER_PATH=$ShortPathTempVar$\r$\n"
      ClearErrors
      ${GetBetween} "SET AUTHENTICATION=" "$\r$\n" "$INSTDIR\getRulebase.cmd" "$R0"  ; This makes it not brittly dependant on the default value. i.e. It would
      !insertmacro ReplaceInFile "$INSTDIR\getRulebase.cmd" "SET AUTHENTICATION=$R0$\r$\n" "SET AUTHENTICATION=$Authentication$\r$\n"
      ClearErrors
      ${GetBetween} "SET LICENSE_ID=" "$\r$\n" "$INSTDIR\getRulebase.cmd" "$R0"  ; This makes it not brittly dependant on the default value. i.e. It would
      !insertmacro ReplaceInFile "$INSTDIR\getRulebase.cmd" "SET LICENSE_ID=$R0$\r$\n" "SET LICENSE_ID=$LicenseID$\r$\n"
      ClearErrors
      return

          DoneWithErrors:
            MessageBox MB_OK "Unable to edit getRulebase.cmd.  Unexpected Installer Environment.  Please notify Message Sniffer Support Personel Immediately.  Thank you."
            Quit
          
FunctionEnd



##############################
## ADDINGPLATFORM ## Step 4 ##
########################################################################################################################################################
## Write the editor function for inserting any code you need for manipulating text files.  Decludes editglobalCFG has a lot of the appropriate comments
## for building a fresh version.  use editglobalCFG as a template of a very complex edit/replace example.  It supports the healFromOldFile typology.
## But lots of systems don't use the heal from old file requirements.  It depends.  Icewarp for example, rewrites and edits whats there each time and doens't
## use the archive as a source.




#######################################
## editMDPluginsFile function will search the existing plugins.dat file for a SNF or a SNIFFER section.
## It will strip that section and insert its own new version.  Either from the local Plugins.dat file on a fresh install.
## or via the callback function during a rollback.
##
## If the ResolveFunction is using the Callback function from the Rollback feature to call editMDPluginsFile then
## it will have set the flags for 'healing' the existing file and the source file to use.  The challenge is that we don't really want to rollback the entire
## file, because the Plugins.dat file may have changed, and we dont' want to break those changes.  That's why the callback function
## calls restoreMDPlugins which calls this, after setting the flags.  This will then have interrupted the 'copying' of the rollback file, and
## give the function the chance to pull the sourced path data out of the old file.
#######################################
Function editMDPluginsFile

  ;Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
  ${handleShortPath} $localINSTDIR $INSTDIR
  ${handleShortPath} $localSERVDIR $SNFServerInstallDir
  
  
      ## ? WHAT IS SRS_INSTDIR ?
      ## ADDING sensitivity to the functions being called to enable them to look up the proper path values in the event that the
      ## rollback sequence is not in the current INSTDIR and $SNFServerInstallDir locations.  i.e. Those parsing functions need to be able
      ## to find the correct file to be editing.  If its rolling back an older version cross platform, then it needs to redefine the file its
      ## targeting, not just assume that its in the INSTDIR or the $SNFServerInstallDir.  I added two registry keys to the EndRollbackSequence
      ## subroutine called SRS_INSTDIR and SRS_SERVDIR to cover the lookup during rollback....since by this point INSTDIR is defined,
      ## just having SRS_INSTDIR different from INSTDIR should be enough key to use the SRS_INSTDIR.... and if the SRS_INSTDIR doesnt' exist,
      ## ( because it wouldn't be entered until the end of the rollback sequence, then the functions will know they are in the new install, and
      ## will use the current INSTDIR as their paths.....
  Clearerrors
  ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_INSTDIR"
    iferrors 0 handleReset
      goto doneCheckingRollbackVars ; the keys didn't exist so don't hijack.
    handleReset:
      ; they exist so hijack.  i.e. Anytime a rollback file exists, ITS local pointers to the relevant INSTDIR and SERVDIR will be valid.
      ; because when you're done running the rollback, the markers are gone.  And a fresh install will replace relevent markers.  Even if its
      ; in the same spot.
      StrCpy $localINSTDIR $registryTempData
      ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_SERVDIR"
      StrCpy $localSERVDIR $registryTempData
       ## Handle the proper shortpaths if they need to be handled.
       ${handleShortPath} $localSERVDIR $localSERVDIR
       ${handleShortPath} $localINSTDIR $localINSTDIR
    doneCheckingRollbackVars:



    ## Ok, so we know what file we're editing, or un-editing.

        Var /GLOBAL lineDataHandle        ; these are the vars that will hold the line of text from the file.
        Var /GLOBAL tempVariableReadLine
        Var /GLOBAL SourcePluginsFileHandle ; File handles.
        Var /GLOBAL TargetPluginsFileHandle
        Var /GLOBAL insideSNFSectionFlag    ; Loop/Section Flag.
        StrCpy $insideSNFSectionFlag ""
        Var /GLOBAL PresetPluginsFileData ;  Blank Plugins file / snf section looks like this:
        StrCpy $PresetPluginsFileData "" ; clear this or else it builds up.
        StrCpy $collectedArchiveData ""  ; clear this or else it builds up.

        ## GET / FORMAT DATA FOR INSERTION INTO THE PLUGINS.DAT FILE  This will either come from the rolledback version, or the
        ## fresh formulation as depicted here, based on the healFromOldFile flag:
        
        StrCmp $healFromOldFile "1" GetSourceFromRollbackFile 0

          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\n[SNF]"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nMenuText=Configure SNF Plug-in"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nEnable=Yes"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nDllPath=$localINSTDIR\snfmdplugin.dll"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nStartupFuncName=Startup@4"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nConfigFuncName=ConfigFunc@4"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nPostMessageFuncName=MessageFunc@8"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nSMTPMessageFuncName=MessageIPFunc@8"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nShutdownFuncName=Shutdown@4"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nPluginDoesAllLogging=No"
          StrCpy $PresetPluginsFileData "$PresetPluginsFileData$\r$\nNonAuthOnly=Yes$\r$\n"
          Goto DataIsReady  ; Don't do Read-From-Rollback... not relevant.
          
        GetSourceFromRollbackFile:  ## Ok, so its a callback then.  Get the data from the rollback file.
        ## Open File, strip out the SNF section into a variable, and store it.  If none exists, leave empty.
        ################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
            StrCmp $healFromOldFile "1" 0 NoDataMining

              ## Then you need to strip the stuff to put back.
              IfFileExists $archivedMDPluginsDatPath 0 DoneReadingArchiveFile       ; if the file is valid.
              FileOpen $archivedMDPluginsDatFileHandle $archivedMDPluginsDatPath r  ; open file. 
                iferrors 0 +3
                  MessageBox MB_OK "Unable to restructure MDaemons Plugins.dat file from the rollback."
                  Goto DoneReadingArchiveFile
              ReadArchiveLine:
                 FileRead $archivedMDPluginsDatFileHandle $lineDataHandle           ; Master loop until we find our [SNF] marker in the Plugins.dat file.
                    ifErrors DoneReadingArchiveFile 0                               ; If we get to end with no lines... ok...
                    ; Primary test is that this a live sniffer line.
                    
                    ${WordFind2X} $lineDataHandle "[" "]" "E+1" $9
  	           IfErrors 0 +2                ; no errors means it found a string, so skip over and test
                      Goto ReadArchiveLine      ; if errors then get new line
                      
                     StrCmp $9 "SNF" FoundLiveArchiveSnifferLine TestTagForOldSniffer ; Test for SNF tag...
                     TestTagForOldSniffer: StrCmp $9 "SNIFFER" FoundLiveArchiveSnifferLine ReadArchiveLine  ; if not, then besure it isn't SNIFFER tag...
                                                                                                            ; go back and get a newline to test.
              ## IF here, then we broke out of the loop.
              FoundLiveArchiveSnifferLine: ; we found the open tag for the SNF.  So we read until we get another [] tag.
                StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is of interest, collect it.

                GetanInsideLine:                                                    ; as long as were inside the sniffer section, get lines here.
                       FileRead $archivedMDPluginsDatFileHandle $lineDataHandle
                       IfErrors DoneReadingArchiveFile
                       ${WordFind2X} $lineDataHandle "[" "]" "E+1" $9
                       IfErrors 0 FoundNewBracketMarker ; Drop through if errors, ( No delimiter found ) If we have zero errors we've found
                                           ; a new section so then you should goto FoundNewBracketMarker label.
                                           ; If errors, then we keep going with more string compares..
                       ClearErrors         ; must clear the error condition returned from the WordFind before next line...
                       StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is still of interest, collect it.
                       Goto GetanInsideLine   ; Go get more.
                FoundNewBracketMarker:     ; Break.
                ; So we're done here then. Cause we don't care about the rest.  We only what what the SNF section was.  Any other changes to the target file stay in place.

            
            DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
              FileClose $archivedGLOBALcfgFileHandle ; Close file.
              StrCpy $lineDataHandle "" ; Clear line data.
              
          NoDataMining:
          ################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################
          StrCpy $PresetPluginsFileData $collectedArchiveData
        DataIsReady:
        ## Data is now collected and ready for insertion, whether its new, old, or empty.
        ;MessageBox MB_OK "$PresetPluginsFileData, $healFromOldFile, ::::::: $collectedArchiveData "
        
        IfFileExists "$localSERVDIR\App\Plugins.dat" filedoesexist 0 ; Skip to second instruction if it doesn't exist.
          ;filedoesNotExist: MessageBox MB_OK "No Plugins.dat file in the (expected) directory.  Creating fresh file."
            
          ; If the file is gone, it could have been deleted manually.  So just because its gone dosn't mean you wouldn't put back the rollback data
          ; into a new file.  Since this is already defined for new and rollback, (above) we are clear for a new file in either case.
          ClearErrors
              ## IF no file exists, then we open file, write new file, and be done. 
              FileOpen $TargetPluginsFileHandle "$localSERVDIR\App\Plugins.dat" w
              FileWrite $TargetPluginsFileHandle $PresetPluginsFileData ; dump the file....
              FileClose $TargetPluginsFileHandle
            
              IfErrors FailedRepair ; otherwise clear for attempting to recreate.
              ;MessageBox MB_OK "Installer successfully inserted new Plugins.dat file."
        Goto done

        filedoesexist:
                    
          ClearErrors
         ; So open the file that we're going to write INTO....
          FileOpen $TargetPluginsFileHandle $localINSTDIR\WorkingPlugins.dat  w ; rename and move new to old one
            IfErrors FailedWorking

                   ; Now open the file we're going to read from.
                   FileOpen $SourcePluginsFileHandle $localSERVDIR\App\Plugins.dat r ; open a new file for reading
                   ;MessageBox MB_OK $SourcePluginsFileHandle
                   IfErrors FailedEdit
                    
                   ; Here is where we need top copy everything from the first file, until we reach [SNF]
                   ; where we strip that out and will eventually add the new SNF data at the bottom...
                   ; then we copy everything again after we reach another open [
                   ; Ok, so while we read lines until the end of file,
                   ; we compare the line and look for  [SNF].
                   ; if We dont' find it. we copy the line to the new file.
                   ; once we find it, we start looking for the next open bracket [
                   ; and we don't write any lines to the new file until we find the next [
                   ; Then we write all lines until the end of the file.
                   ; then we write the [SNF] code to the end of the file,
                   ; and we close the file.
                   ; No while necessary.  Goto will loop to GetaLineHere: label if no SNF is identified.
                   GetaLineHere:
                    FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read the next line into our temp var. from the handle $0 ( attached above with FileOpen )
                    
                     ; NOW test for EOF.
                     IfErrors HandleEnding
                       ; then we have reached the end of the file without finding the SNF file.
                       ; go directly to writing the SNF information to the output file.


                     ; Now handle for being in the section where we have alredy detected the SNF flag.
                     ; The function jumps from this section to the Handle end flag, after it has finished copying the file.
                     StrCmp $insideSNFSectionFlag "1" 0 Not_In_SNF_Tagged_Section ; test to find new open '[' char and when we find it
                                                   ; take us out of SNF skip line mode.
                       ${WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9
                       IfErrors 0 noerrors ; Drop through if errors, ( No delimiter found ) If we have zero errors we've found
                                           ; a new section goto noerrors label.

                       FindNextTag:       ; Since where INSIDE the SNF tag, we're NOT copying it to the temp file.
                             ClearErrors   ; clear condition.
                             FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read next line.
                             IfErrors HandleEnding
                              ${WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9   ; Look for tag to kick us out of SNF/SNIFFER section.
                              IfErrors FindNextTag noerrors ; Go back if-errors, ( No delimiter found )
                              ;If we have zero errors we've found new section head.so goto noerrors label.

                       noerrors:           ; then ( since we were IN the snf section ) and we found a DIFFERENT identified tag in the file... dump rest of file in a tight loop.

                       ClearErrors ; clear error flag if exists from the above string compare.
	               copyRestOfFile: FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump temp string into new file.
                                       FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read line.
                                       IfErrors HandleEnding copyRestOfFile
                                       ; An error will indicate end of file. loop of not EOF otherwise proceed to ending.
	                               ; we've stripped out the old SNF section and copied the existing contents of the file.
                     Not_In_SNF_Tagged_Section:
                     
                    
                     ; we should never proceed directly from the above section to the next below.
                     ; if we enter the above section it only can exit into the HandleEnding area.

                   ; So if we're entering here. its because we read a line, and we need to test it because
                   ; we have not yet detected the SNF section.
                   ; Now we test to find the SNF
                   ${WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9 ; stuff what we find in register nine.
  	           IfErrors 0 +3                ; no errors means it found a string, so skip over and test
                      FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump nonflagged string into new file.
                      Goto GetaLineHere                                        ; get new line
                                                ; if errors we move get the next line to test.
                   StrCmp $9 "SNF" TagOK TestTagForOld                    ; check nine for SNF or SNIFFER Now.
                   TestTagForOld: StrCmp $9 "SNIFFER" TagOK TagNotSniffer
                     TagOK:
                       StrCpy $insideSNFSectionFlag "1"
                       Goto GetaLineHere ; This forces us into the top looping section where we srip it all out.
                     TagNotSniffer:
                       FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump temp string into new file.
                       Goto GetaLinehere ; Go back for more.
                      ; you should not just progress from this line to the Handle Ending.  The condition to move to handle ending
                      ; will always be predicated on reaching the end of the file.

                   HandleEnding: ; We will always get to the end of the file.
                                 ; Now we must output our SNF information, because
                                 ; either we cut it out, 
                                 ; or we didn't find it at all and in either case we must add it now.
                   FileClose $SourcePluginsFileHandle ; Close this because we read it all.

                   ClearErrors
                   FileWrite $TargetPluginsFileHandle "$\r$\n"

                   # It doesn't matter at this point, if we're doing a rollback or a new.
                   # We've handled loading what should be in PresetFileData at the beginning
                   # of this sub, based on the flags, the old file, etc.  If this $PresetPluginsFileData
                   # is empty here, then its supposed to be.  Write and Close.
                   FileWrite $TargetPluginsFileHandle $PresetPluginsFileData ; dump the file....

                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.

                     ifFileExists "$localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat" 0 +2
                       Delete $localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat ;
                     Rename $localSERVDIR\App\Plugins.dat $localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat ; store the old version.
                     Rename $localINSTDIR\WorkingPlugins.dat $localSERVDIR\App\Plugins.dat ; move the working version.
                     Goto done

        ; poorly simulated catch section.
        FailedRepair:
          MessageBox MB_OK "Installer seemed unable to create a new Plugins.dat file.  Perhaps the file is locked.  Please attempt to create/move this file manually into the MDaemon\App folder using the Plugins.dat file in the MDaemon\SNF directory according to the manual instructions: "
                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          ExecShell open notepad.exe $localINSTDIR\InstallInstructions_MDaemon.txt SW_SHOWNORMAL
        Goto  done
        FailedWorking:
          MessageBox MB_OK "Installer seemed unable to create a working file.  Perhaps the folders permissions are not enabling file creation. "
                   
                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          ExecShell open notepad.exe $localINSTDIR\InstallInstructions_MDaemon.txt SW_SHOWNORMAL
        Goto  done
        FailedEdit:
                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          MessageBox MB_OK "Installer seemed unable to edit the $localSERVDIR\App\Plugins.dat file.  Perhaps the file is locked.  This installation is incomplete. "
        done:

FunctionEnd



Function un.editMDPluginsFile

  ;Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
  ${un.handleShortPath} $localINSTDIR $INSTDIR
  ${un.handleShortPath} $localSERVDIR $SNFServerInstallDir


      ## ? WHAT IS SRS_INSTDIR ?
      ## ADDING sensitivity to the functions being called to enable them to look up the proper path values in the event that the
      ## rollback sequence is not in the current INSTDIR and $SNFServerInstallDir locations.  i.e. Those parsing functions need to be able
      ## to find the correct file to be editing.  If its rolling back an older version cross platform, then it needs to redefine the file its
      ## targeting, not just assume that its in the INSTDIR or the $SNFServerInstallDir.  I added two registry keys to the EndRollbackSequence
      ## subroutine called SRS_INSTDIR and SRS_SERVDIR to cover the lookup during rollback....since by this point INSTDIR is defined,
      ## just having SRS_INSTDIR different from INSTDIR should be enough key to use the SRS_INSTDIR.... and if the SRS_INSTDIR doesnt' exist,
      ## ( because it wouldn't be entered until the end of the rollback sequence, then the functions will know they are in the new install, and
      ## will use the current INSTDIR as their paths.....
  Clearerrors
  ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_INSTDIR"
    iferrors 0 handleReset
      goto doneCheckingRollbackVars ; the keys didn't exist so don't hijack.
    handleReset:
      ; they exist so hijack.  i.e. Anytime a rollback file exists, ITS local pointers to the relevant INSTDIR and SERVDIR will be valid.
      ; because when you're done running the rollback, the markers are gone.  And a fresh install will replace relevent markers.  Even if its
      ; in the same spot.
      StrCpy $localINSTDIR $registryTempData
      ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_SERVDIR"
      StrCpy $localSERVDIR $registryTempData
       ## Handle the proper shortpaths if they need to be handled.
       ${un.handleShortPath} $localSERVDIR $localSERVDIR
       ${un.handleShortPath} $localINSTDIR $localINSTDIR
    doneCheckingRollbackVars:



    ## Ok, so we know what file we're editing, or un-editing.

        ;Var /GLOBAL lineDataHandle        ; these are the vars that will hold the line of text from the file.
        ;Var /GLOBAL tempVariableReadLine
        ;Var /GLOBAL SourcePluginsFileHandle ; File handles.
        ;Var /GLOBAL TargetPluginsFileHandle
        ;Var /GLOBAL insideSNFSectionFlag    ; Loop/Section Flag.
        StrCpy $insideSNFSectionFlag ""
        ;Var /GLOBAL PresetPluginsFileData ;  Blank Plugins file / snf section looks like this:
        StrCpy $PresetPluginsFileData "" ; clear this or else it builds up.
        StrCpy $collectedArchiveData ""  ; clear this or else it builds up.

        ## GET / FORMAT DATA FOR INSERTION INTO THE PLUGINS.DAT FILE  This will either come from the rolledback version, or the
        ## fresh formulation as depicted here, based on the healFromOldFile flag:

        StrCmp $healFromOldFile "1" GetSourceFromRollbackFile 0

          StrCpy $PresetPluginsFileData "" ; this is either a call back to restore, or to remove... but its not putting it in.
          Goto DataIsReady  ; Don't do Read-From-Rollback... not relevant.

        GetSourceFromRollbackFile:  ## Ok, so its a callback then.  Get the data from the rollback file.
        ## Open File, strip out the SNF section into a variable, and store it.  If none exists, leave empty.
        ################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
            StrCmp $healFromOldFile "1" 0 NoDataMining

              ## Then you need to strip the stuff to put back.
              IfFileExists $archivedMDPluginsDatPath 0 DoneReadingArchiveFile       ; if the file is valid.
              FileOpen $archivedMDPluginsDatFileHandle $archivedMDPluginsDatPath r  ; open file.
                iferrors 0 +3
                  MessageBox MB_OK "Unable to restructure MDaemons Plugins.dat file from the rollback."
                  Goto DoneReadingArchiveFile
              ReadArchiveLine:
                 FileRead $archivedMDPluginsDatFileHandle $lineDataHandle           ; Master loop until we find our [SNF] marker in the Plugins.dat file.
                    ifErrors DoneReadingArchiveFile 0                               ; If we get to end with no lines... ok...
                    ; Primary test is that this a live sniffer line.

                    ${un.WordFind2X} $lineDataHandle "[" "]" "E+1" $9
  	           IfErrors 0 +2                ; no errors means it found a string, so skip over and test
                      Goto ReadArchiveLine      ; if errors then get new line

                     StrCmp $9 "SNF" FoundLiveArchiveSnifferLine TestTagForOldSniffer ; Test for SNF tag...
                     TestTagForOldSniffer: StrCmp $9 "SNIFFER" FoundLiveArchiveSnifferLine ReadArchiveLine  ; if not, then besure it isn't SNIFFER tag...
                                                                                                            ; go back and get a newline to test.
              ## IF here, then we broke out of the loop.
              FoundLiveArchiveSnifferLine: ; we found the open tag for the SNF.  So we read until we get another [] tag.
                StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is of interest, collect it.

                GetanInsideLine:                                                    ; as long as were inside the sniffer section, get lines here.
                       FileRead $archivedMDPluginsDatFileHandle $lineDataHandle
                       IfErrors DoneReadingArchiveFile
                       ${un.WordFind2X} $lineDataHandle "[" "]" "E+1" $9
                       IfErrors 0 FoundNewBracketMarker ; Drop through if errors, ( No delimiter found ) If we have zero errors we've found
                                           ; a new section so then you should goto FoundNewBracketMarker label.
                                           ; If errors, then we keep going with more string compares..
                       ClearErrors         ; must clear the error condition returned from the WordFind before next line...
                       StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is still of interest, collect it.
                       Goto GetanInsideLine   ; Go get more.
                FoundNewBracketMarker:     ; Break.
                ; So we're done here then. Cause we don't care about the rest.  We only what what the SNF section was.  Any other changes to the target file stay in place.


            DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
              FileClose $archivedGLOBALcfgFileHandle ; Close file.
              StrCpy $lineDataHandle "" ; Clear line data.

          NoDataMining:
          ################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################
          StrCpy $PresetPluginsFileData $collectedArchiveData
        DataIsReady:
         
        ## Data is now collected and ready for insertion, whether its new, old, or empty.
        ;MessageBox MB_OK "$PresetPluginsFileData, $healFromOldFile, ::::::: $collectedArchiveData "

        IfFileExists "$localSERVDIR\App\Plugins.dat" filedoesexist 0 ; Skip to second instruction if it doesn't exist.
          ;filedoesNotExist: MessageBox MB_OK "No Plugins.dat file in the (expected) directory.  Creating fresh file."

          ; If the file is gone, it could have been deleted manually.  So just because its gone dosn't mean you wouldn't put back the rollback data
          ; into a new file.  Since this is already defined for new and rollback, (above) we are clear for a new file in either case.
          ClearErrors
              ## IF no file exists, then we open file, write new file, and be done.
              FileOpen $TargetPluginsFileHandle "$localSERVDIR\App\Plugins.dat" w
              FileWrite $TargetPluginsFileHandle $PresetPluginsFileData ; dump the file....
              FileClose $TargetPluginsFileHandle

              IfErrors FailedRepair ; otherwise clear for attempting to recreate.
              ;MessageBox MB_OK "Installer successfully inserted new Plugins.dat file."
        Goto done

        filedoesexist:

          ClearErrors
         ; So open the file that we're going to write INTO....
          FileOpen $TargetPluginsFileHandle $localINSTDIR\WorkingPlugins.dat  w ; rename and move new to old one
            IfErrors FailedWorking

                   ; Now open the file we're going to read from.
                   FileOpen $SourcePluginsFileHandle $localSERVDIR\App\Plugins.dat r ; open a new file for reading
                   ;MessageBox MB_OK $SourcePluginsFileHandle
                   IfErrors FailedEdit

                   ; Here is where we need top copy everything from the first file, until we reach [SNF]
                   ; where we strip that out and will eventually add the new SNF data at the bottom...
                   ; then we copy everything again after we reach another open [
                   ; Ok, so while we read lines until the end of file,
                   ; we compare the line and look for  [SNF].
                   ; if We dont' find it. we copy the line to the new file.
                   ; once we find it, we start looking for the next open bracket [
                   ; and we don't write any lines to the new file until we find the next [
                   ; Then we write all lines until the end of the file.
                   ; then we write the [SNF] code to the end of the file,
                   ; and we close the file.
                   ; No while necessary.  Goto will loop to GetaLineHere: label if no SNF is identified.
                   GetaLineHere:
                    FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read the next line into our temp var. from the handle $0 ( attached above with FileOpen )

                     ; NOW test for EOF.
                     IfErrors HandleEnding
                       ; then we have reached the end of the file without finding the SNF file.
                       ; go directly to writing the SNF information to the output file.


                     ; Now handle for being in the section where we have alredy detected the SNF flag.
                     ; The function jumps from this section to the Handle end flag, after it has finished copying the file.
                     StrCmp $insideSNFSectionFlag "1" 0 Not_In_SNF_Tagged_Section ; test to find new open '[' char and when we find it
                                                   ; take us out of SNF skip line mode.
                       ${un.WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9
                       IfErrors 0 noerrors ; Drop through if errors, ( No delimiter found ) If we have zero errors we've found
                                           ; a new section goto noerrors label.

                       FindNextTag:       ; Since where INSIDE the SNF tag, we're NOT copying it to the temp file.
                             ClearErrors   ; clear condition.
                             FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read next line.
                             IfErrors HandleEnding
                              ${un.WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9   ; Look for tag to kick us out of SNF/SNIFFER section.
                              IfErrors FindNextTag noerrors ; Go back if-errors, ( No delimiter found )
                              ;If we have zero errors we've found new section head.so goto noerrors label.

                       noerrors:           ; then ( since we were IN the snf section ) and we found a DIFFERENT identified tag in the file... dump rest of file in a tight loop.

                       ClearErrors ; clear error flag if exists from the above string compare.
	               copyRestOfFile: FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump temp string into new file.
                                       FileRead $SourcePluginsFileHandle $tempVariableReadLine ; read line.
                                       IfErrors HandleEnding copyRestOfFile
                                       ; An error will indicate end of file. loop of not EOF otherwise proceed to ending.
	                               ; we've stripped out the old SNF section and copied the existing contents of the file.
                     Not_In_SNF_Tagged_Section:


                     ; we should never proceed directly from the above section to the next below.
                     ; if we enter the above section it only can exit into the HandleEnding area.

                   ; So if we're entering here. its because we read a line, and we need to test it because
                   ; we have not yet detected the SNF section.
                   ; Now we test to find the SNF
                   ${un.WordFind2X} $tempVariableReadLine "[" "]" "E+1" $9 ; stuff what we find in register nine.
  	           IfErrors 0 +3                ; no errors means it found a string, so skip over and test
                      FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump nonflagged string into new file.
                      Goto GetaLineHere                                        ; get new line
                                                ; if errors we move get the next line to test.
                   StrCmp $9 "SNF" TagOK TestTagForOld                    ; check nine for SNF or SNIFFER Now.
                   TestTagForOld: StrCmp $9 "SNIFFER" TagOK TagNotSniffer
                     TagOK:
                       StrCpy $insideSNFSectionFlag "1"
                       Goto GetaLineHere ; This forces us into the top looping section where we srip it all out.
                     TagNotSniffer:
                       FileWrite $TargetPluginsFileHandle $tempVariableReadLine ; Dump temp string into new file.
                       Goto GetaLinehere ; Go back for more.
                      ; you should not just progress from this line to the Handle Ending.  The condition to move to handle ending
                      ; will always be predicated on reaching the end of the file.

                   HandleEnding: ; We will always get to the end of the file.
                                 ; Now we must output our SNF information, because
                                 ; either we cut it out,
                                 ; or we didn't find it at all and in either case we must add it now.
                   FileClose $SourcePluginsFileHandle ; Close this because we read it all.

                   ClearErrors
                   FileWrite $TargetPluginsFileHandle "$\r$\n"

                   # It doesn't matter at this point, if we're doing a rollback or a new.
                   # We've handled loading what should be in PresetFileData at the beginning
                   # of this sub, based on the flags, the old file, etc.  If this $PresetPluginsFileData
                   # is empty here, then its supposed to be.  Write and Close.
                   FileWrite $TargetPluginsFileHandle $PresetPluginsFileData ; dump the file....

                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.

                     ifFileExists "$localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat" 0 +2
                       Delete $localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat ;
                     Rename $localSERVDIR\App\Plugins.dat $localSERVDIR\App\OLDPluginsDAT_PreSNFInstall.dat ; store the old version.
                     Rename $localINSTDIR\WorkingPlugins.dat $localSERVDIR\App\Plugins.dat ; move the working version.
                     Goto done

        ; poorly simulated catch section.
        FailedRepair:
          MessageBox MB_OK "Uninstaller seemed unable to create a new Plugins.dat file.  Perhaps the file is locked.  Please attempt to create/move this file manually into the MDaemon\App folder using the Plugins.dat file in the MDaemon\SNF directory according to the manual instructions: "
                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          ExecShell open notepad.exe $localINSTDIR\InstallInstructions_MDaemon.txt SW_SHOWNORMAL
        Goto  done
        FailedWorking:
          MessageBox MB_OK "Uninstaller seemed unable to create a working file.  Perhaps the folders permissions are not enabling file creation. "

                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          ExecShell open notepad.exe $localINSTDIR\InstallInstructions_MDaemon.txt SW_SHOWNORMAL
        Goto  done
        FailedEdit:
                   FileClose $TargetPluginsFileHandle ; Close MDaemon Plugins file.
                   FileClose $SourcePluginsFileHandle
          MessageBox MB_OK "Uninstaller seemed unable to edit the $localSERVDIR\App\Plugins.dat file.  Perhaps the file is locked.  This installation is incomplete. "
        done:

FunctionEnd


## Dont' need this now...
## Rollback handleds this at restore...
Function un.cleanGlobalCFG
  ;comment out every live line in the global.cfg file.
  Var /GLOBAL sourceFileHandle
  Var /GLOBAL targetFileHandle
  Var /GLOBAL str_line
  Var /GLOBAL results

  FileOpen $sourceFileHandle "$SNFServerInstallDir\global.cfg" r
  FileOpen $targetFileHandle "$SNFServerInstallDir\phase1global.cfg" w
  NextLine:
  FileRead $sourceFileHandle $str_line
    iferrors cleanupFiles 0
      StrCmp $LicenseID "" LookForBaseEXE 0 ; if for some reason the LicenseID is blank, we don't want to comment every ".exe"
      ${un.WordFind} $str_line "$LicenseID.exe" "E+1}" $results
           ifErrors LookForBaseEXE FoundLiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
      LookForBaseEXE:
      ${un.WordFind} $str_line "SNFClient.exe" "E+1}" $results
           ifErrors 0 FoundLiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
             FileWrite $targetFileHandle $str_line
             Goto NextLine
      FoundLiveSnifferLine:
        FileWrite $targetFileHandle "#$str_line"
        Goto NextLine
  cleanupFiles:
  FileClose $sourceFileHandle
  FileClose $targetFileHandle

  #Rename it now...
  ifFileExists "$SNFServerInstallDir\pre_snifferUNINSTALL_global.cfg.log" 0 +2
    Delete  "$SNFServerInstallDir\pre_snifferUNINSTALL_global.cfg.log"
    Rename "$SNFServerInstallDir\global.cfg" "$SNFServerInstallDir\pre_snifferUNINSTALL_global.cfg.log"
    Rename "$SNFServerInstallDir\phase1global.cfg" "$SNFServerInstallDir\global.cfg"
    ifFileExists "$SNFServerInstallDir\phase1global.cfg" 0 +2
      Delete "$SNFServerInstallDir\phase1global.cfg"

    Return
FunctionEND


Function editglobalCFG
  ; MessageBox MB_OK "Inside editglobalCFG"
  ; if we're here it means we checked for a global.cfg file, and it existed at the SNFServerInstallDir level... presumably decludes install pattern.
  ; so we are going to edit / add / replace the values that we are interested in.
  ; IF there is a file called cfgstring.xml in the folder, it means we are restoring from a previous archived version and we need to pull that string
  ; and consume the file.
  
  ; Adjustments to the parsing of the DECLUDE global.cfg are as follows:
  ; Upon uninstall, we comment all sniffer lines.
  ; Upon a reinstall/new install, we rip through and 'heal' or insert the sniffer directives.....
  ; the priority will be:  Just ahead of the first live sniffer line.
  ;                        Just after the  EXTERNAL TESTS marker if it exists.
  ;                        If none of those apply, we insert them at the top of the file.
  ;
  ;  Kicker is as follows, the NAME of the test is inconclusive to being able to identifiy it. i.e. beforeSniffer Sniffer afterSniffer are not
  ;  acceptible names to tag on... because they may be Spam Assasin before, or SA after or whatever....
  ;  The only acceptible tag to hit is the SNFClient.exe tag.  And to further complicate it it can be inside quotes or whatever, and we
  ;  need to respect that when we heal the path.
  ;
  ;  Process will utilize two temp files.  The first temp file is the file we write all non-relevent lines to BEFORE we hit the EXTERNAL TESTS marker.
  ;  The second temp file will hold all lines after that, until we find a live sniffer line.  Pending no sniffer lines, we insert after Eternal Tests
  ;  and append the second file and close.
    #VAR /GLOBAL healFromOldFile             ; used to flag putting stuff back.
    #VAR /GLOBAL archivedGLOBALcfgPath       ; file to use for putting stuff back.
    #VAR /GLOBAL archivedGLOBALcfgFileHandle ; handle for file to read in the stuff to put back....
    #VAR /GLOBAL collectedArchiveData        ; store these lines, collected from the file.
    #VAR /GLOBAL succededAtPlacingArchivedData ; true if we have already written data to the new file.
    

  ;  Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
  ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localINSTDIR $INSTDIR
  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

  ;GetFullPathName /SHORT $localSERVDIR $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localSERVDIR $SNFServerInstallDir
  
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.
  
      ## ADDING sensitivity to the functions being called to enable them to look up the proper path values in the event that the
      ## rollback sequence is not in the current INSTDIR and $SNFServerInstallDir locations.  i.e. Those parsing functions need to be able
      ## to find the correct file to be editing.  If its rolling back an older version cross platform, then it needs to redefine the file its
      ## targeting, not just assume that its in the INSTDIR or the $SNFServerInstallDir.  I added two registry keys to the EndRollbackSequence
      ## subroutine called SRS_INSTDIR and SRS_SERVDIR to cover the lookup during rollback....since by this point INSTDIR is defined,
      ## just having SRS_INSTDIR different from INSTDIR should be enough key to use the SRS_INSTDIR.... and if the SRS_INSTDIR doesnt' exist,
      ## ( because it wouldn't be entered until the end of the rollback sequence, then the functions will know they are in the new install, and
      ## will use the current INSTDIR as their paths.....
  Clearerrors
  ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_INSTDIR"
    iferrors 0 handleReset
      goto doneCheckingRollbackVars ; the keys didn't exist so don't hijack.
    handleReset:
      ; they exist so hijack.  i.e. Anytime a rollback file exists, ITS local pointers to the relevant INSTDIR and SERVDIR will be valid.
      ; because when you're done running the rollback, the markers are gone.  And a fresh install will replace relevent markers.  Even if its
      ; in the same spot.
      StrCpy $localINSTDIR $registryTempData
      ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_SERVDIR"
      StrCpy $localSERVDIR $registryTempData
       ## Handle the proper shortpaths if they need to be handled.
       ${handleShortPath} $localSERVDIR $localSERVDIR
       ${handleShortPath} $localINSTDIR $localINSTDIR
    doneCheckingRollbackVars:

    
    StrCpy $collectedArchiveData ""         ; set for default.
    StrCpy $succededAtPlacingArchivedData "0"
    
    VAR /GLOBAL decludeConfigFileHandle ; the existing live file....

    VAR /GLOBAL phase_FileHandle  ; holds the first half up to the External Tests or pending no External Test line... we have the entire file here.
    VAR /GLOBAL phase
    VAR /GLOBAL TargetSnifferString  ; could be SNFClient.exe or $LicenseID.exe
    StrCpy $phase "1" ; start in phase 1
  
    # Identify live sniffer lines, and heal them if possible.
    Var /GLOBAL foundAtLeastOneLiveSnifferLine
    StrCpy $foundAtLeastOneLiveSnifferLine "0" ; defaults to no.....
    
    ; Declared same var earlier.
    ;Var /GLOBAL lineDataHandle
    Var /GLOBAL WordFindResults
    Var /GLOBAL FirstCharTestVar
    Var /GLOBAL tempLineHandle ; holds a manipulated version of the line as we test it....
    Var /GLOBAL secondHalfOfLine ; holds the other side to rejoin it after we replace....
    Var /GLOBAL firstHalfOfLine ; holds all chars up to the encapsulator.
    Var /GLOBAL encapsulator   ; holds the type of quote if its quoted...

################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
    ${IF} $healFromOldFile = "1"
      ## Then you need to strip and make temporary file for the stuff to put back.
      IfFileExists $archivedGLOBALcfgPath 0 DoneReadingArchiveFile
      FileOpen $archivedGLOBALcfgFileHandle $archivedGLOBALcfgPath r
        iferrors 0 +3
          MessageBox MB_OK "Unable to restructure Decludes global.cfg file from the rollback."
          Goto DoneReadingArchiveFile
      ReadArchiveLine:
         FileRead $archivedGLOBALcfgFileHandle $lineDataHandle
            ifErrors DoneReadingArchiveFile 0
            ; Primary test is that this a live sniffer line.
            ${WordFind} $lineDataHandle "SNFClient.exe" "E+1}" $WordFindResults
                   ifErrors 0 FoundLiveArchiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            ${WordFind} $lineDataHandle "$LicenseID.exe" "E+1}" $WordFindResults
                   ifErrors 0 FoundLiveArchiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            Goto ReadArchiveLine ; go back and get a newline to test.
      FoundLiveArchiveSnifferLine:
        StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is of interest, even if its just a comment. collect it.
        Goto ReadArchiveLine
    ${ENDIF}
    DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
      FileClose $archivedGLOBALcfgFileHandle ; Close file.
      StrCpy $lineDataHandle "" ; Clear line data.
################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################


     
################################################### BEGIN PHASE 1 of the Main Global.cfg File Read. #################################
  clearerrors
  FileOpen $decludeConfigFileHandle "$localSERVDIR\global.cfg" r
    iferrors 0 OpenOK
      clearerrors
      MessageBox MB_OK "Error opening $localSERVDIR\global.cfg file. Do you have the file open?"
      FileClose $decludeConfigFileHandle
      FileOpen $decludeConfigFileHandle "$localSERVDIR\global.cfg" r
  OpenOK:
  FileOpen $phase_FileHandle "$localSERVDIR\phase1global.cfg" w

KeepReading:
    FileRead  $decludeConfigFileHandle $lineDataHandle  ; get the first line.
    ifErrors DoneReadingFile 0
      ; Primary test is is this a live sniffer line.
    ${WordFind} $lineDataHandle "SNFClient.exe" "E+1}" $WordFindResults
           ifErrors 0 FoundLiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
    ${WordFind} $lineDataHandle "$LicenseID.exe" "E+1}" $WordFindResults
           ifErrors 0 FoundLiveOLDSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
    ${WordFind} $lineDataHandle "EXTERNAL TEST" "E+1}" $WordFindResults
           ifErrors 0 FoundExternalTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
      FileWrite $phase_FileHandle $lineDataHandle ; dump line to phase1 file.
      Goto KeepReading ; go back and get a newline to test.

    FoundLiveSnifferLine:  ; ok, set TargetSnifferString to be abstract and work for either the new or the old naming convention.
      StrCpy $TargetSnifferString "SNFClient.exe" ; ok, set for regular sniffer....
      Goto TestForWhitespace
    FoundLiveOLDSnifferLine:
      StrCpy $TargetSnifferString "$LicenseID.exe" ; ok, set for regular sniffer....
    TestForWhitespace:
          ; ok, line contains SNFClient.exe or $LicenseID.exe we need to be sure it isn't a comment.
      StrCpy $tempLineHandle $lineDataHandle
      testNextChar:
      StrCpy $FirstCharTestVar $tempLineHandle 1 0
      StrCmp $FirstCharTestVar " " 0 CheckForCommentMarker
        StrCpy $tempLineHandle $tempLineHandle "" 1 ; cut off one char and test again.
        goto testNextChar
    CheckForCommentMarker:
      ; Skipped here because not blank space... so check for comment.
      StrCmp $FirstCharTestVar "#" 0 HandleValidLine
        ; Is a comment.  Dump to whatever phase is current.
        ; We don't allow Sniffer commented lines to build up..... so we remove it on this pass.
        ; FileWrite $phase_FileHandle $lineDataHandle ; dump line to phase1 file.
        Goto KeepReading ; go back and get a newline to test.

       HandleValidLine:
         StrCpy $foundAtLeastOneLiveSnifferLine "1"  ; set this to defer the phase change if it exists... and if it doesn't then thats ok.
         ; NOTE:  Special case..... we've found a valid line.  But if we're in ROLLBACK mode... then we don't want to copy this line, in, all valid lines
         ;        have been collected from the old file, and will now be deposited.  All further valid lines will be skipped. Thus:
         StrCmp $succededAtPlacingArchivedData "1" KeepReading 0 ; This aborts any new information from getting into the file. Get next line.
         StrCmp $healFromOldFile "1" 0 DealWithNormalConditions  ; skip forward and handle data.
           ; Ok, we're rolling back, but we haven't depositied data yet.
           FileWrite $phase_FileHandle $collectedArchiveData ; This puts all the valid lines from the archived section in place at the first found
                                                             ; live line of the current page.  Since the installer obeyd the protocol, its likely that its
                                                             ; in the correct spot.  If not, we'll put it back at the end.
           StrCpy $succededAtPlacingArchivedData "1"
           Goto KeepReading
       
       DealWithNormalConditions:
         ; Ok, we're here.  We have a good line... and we need to alter the path preceding the tag, and the name of the tag.
         ; We MAY be in the same folder.... but we may be in an entirely different folder... it doesn't matter.
         ${WordFind} $lineDataHandle $TargetSnifferString "+1}" $secondHalfOfLine ; load the last bit into the $secondHalfOfLine
           ; now test if its frst char is a white space.  If it is, then you're inside quotes, move forward till you find the quote, and then move back till you find it.
            ; It would be nice to have the algorithem just juse this as its solution, but it breaks because the old sniffer versions
             ; encapsulate the authentication inside the quotes.... and you could have 'Program Files' inside the quotes... so you can't trust
             ; a blank to be the pure encapsulator...  whats a hack to do...
             ; So we suggest that we take a test to see if there is one ', one ", or one ` in the secondHalfOfLine
             ; if there is we'll take a guess that the encapsulator isn't a blank, but that its a quote.....
             ;${WordFind} $secondHalfOfLine $TargetSnifferString "+1}" $secondHalfOfLine ; load the last bit into the $secondHalfOfLine
             
               ; Now we need to test to see if we have the authentication string in here.....
               Var /GLOBAL toTheFarRight
               ${WordFind} $secondHalfOfLine $Authentication "+1}" $toTheFarRight ; load the last far right bit into the $toTheFarRight
                  ifErrors  0 usefartherEncapsulator
                    ; ok, just find the one to the right of the targetSnifferString and use that on the left side.
                    StrCpy $encapsulator $secondHalfOfLine 1 0
                     Goto GrabLeft
                  usefartherEncapsulator: ; ok, well, then if the Authentication is there, then we need to use the quote type to the right of that.
                     StrCpy $encapsulator $toTheFarRight 1 0 ; ok, good to go unless its a space... which I don't think you can do if you're using the Auth....
           GrabLeft:
           ; Now we have a character in the encapsulator.  Its either a quote, or a whitespace.  If its whitespace, then the end of the path on
           ; the other side will be another space..... and if its a quote, it will be a quote... etc....
           ; So get the PRE-part of the line, and grab everything to the right of the last encapsulator var.....
           ;MessageBox MB_OK "The encapsulator is:$encapsulator And the Cut is:$secondHalfOfLine"
             ${WordFind} $lineDataHandle $TargetSnifferString "+1{" $tempLineHandle ; load the first bit into the tempLineHandle.
             ; So tempLineHandle holds the entire preline....before the Name.exe
             ${WordFind} $tempLineHandle $encapsulator "+1{" $firstHalfOfLine ; load the first bit into the tempLineHandle.
           
             ; Naturally this needs to be rebuilt as..... firsthalf+encapsulator+NEWPATH\NEWEXE+ secondhalf (Which includes the 2nd encapsulator...
             StrCpy $tempLineHandle "$firstHalfOfLine$encapsulator$localINSTDIR\SNFClient.exe$secondHalfOfLine"
             ; Now we replace the previous valid line, with the new path and exe....
             FileWrite $phase_FileHandle $tempLineHandle ; dump line to phase file. ; Since we're just fixing the lines... it should be ok....
             ; MessageBox MB_OK "Inside the valid line: $tempLineHandle phase:$phase"
             ; and at the end if we're in phase 1 then we never found an External test marker... and it doesn't matter.....
             ; and if we're in phase two, then we need to append phase1 and phase2.... the only situation we need phase1 and phase2 sepearte
             ; is if we never get into this part... and have to put in a fresh line somewhere.....
             StrCpy $foundAtLeastOneLiveSnifferLine "1"
             Goto KeepReading ; go back and get a newline to test.

    FoundExternalTestMarker:
      ; Here we've determined that we have found the end of phase one
      ; but if we found a live line, that trumps putting lines after the external test marker....
      StrCmp $foundAtLeastOneLiveSnifferLine "1" 0 Well_SplitPhasesThen
        FileWrite $phase_FileHandle  $lineDataHandle ; dump line to phase1 file.
        ; IF thats the case then we just go back to keep reading and don't move the phase file pointer...
        Goto KeepReading
      ; but with no live sniffer lines yet... its a different story, cause we'll need to come back to this break if we don't
      ; find ANY.....
      Well_SplitPhasesThen:
        ; put the external tests marker in phase1 file.
        FileWrite $phase_FileHandle  $lineDataHandle ; dump line to phase1 file.
        ; Thus close the phase one marker.  And use Phase Two.
        StrCpy $phase "2"
        FileClose $phase_FileHandle
        FileOpen  $phase_FileHandle  "$localSERVDIR\phase2global.cfg" w
      Goto KeepReading ; go back and get a newline to test.


    DoneReadingFile:
      FileClose $decludeConfigFileHandle  ; ok, now we need to know how to reasemble it....
      FileClose $phase_FileHandle

      StrCmp $phase "1" 0 handleRejoinPhases
        ; Ok, well that just means we didn't have a External Test marker... so test if we altered anything.
        StrCmp $foundAtLeastOneLiveSnifferLine "1" 0 AddLineAtStart ; and if we drop in, then we handled live lines....
            Rename "$localSERVDIR\phase1global.cfg" "$localSERVDIR\NEWglobal.cfg" ; set this up so its all the same for the RenamePhase.
            goto RenamePhase ; ok, if so, then we're done then, handle file renaming.
          AddLineAtStart:
            Var /GLOBAL prependFileHandle
            FileOpen  $prependFileHandle  "$localSERVDIR\NEWglobal.cfg" w
            ${IF} $healFromOldFile = "1" ; then we dump the archived stuff.....
              FileWrite $prependFileHandle "############################### SNIFFER TEST SECTION #################################$\r$\n"
              FileWrite $prependFileHandle $collectedArchiveData ; This puts the old valid lines back..... Its the only extra condition
            ${ELSE} ; then write the new data
              FileWrite $prependFileHandle "############################### SNIFFER TEST SECTION #################################$\r$\n"
              FileWrite $prependFileHandle 'SNIFFER external nonzero "$localINSTDIR\SNFClient.exe"$\t12$\t0$\r$\n'
            ${ENDIF}                                              ; if the data existed and a valid line was found, it would have been inserted.
            
            ; now dump it all in after....
            FileOpen  $decludeConfigFileHandle "$localSERVDIR\global.cfg" r ; reopen..
              ReadForPrePendNewLine:
              FileRead $decludeConfigFileHandle $lineDataHandle ; get new line..
                iferrors closeUpThePrepend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForPrePendNewLine                    ; go back for more.
              closeUpThePrepend:                                ; time to lock up
                FileClose $decludeConfigFileHandle
                FileClose $prependFileHandle
                Goto RenamePhase                                ; go and rename on top of the old file.
     ; Ok, but if we were in a phase 2 read.... it meant
     ; that we found an external test marker.... but we could have fond live lines....
     handleRejoinPhases:
          FileOpen $prependFileHandle "$localSERVDIR\NEWglobal.cfg" w ; open target....
            FileOpen $phase_FileHandle "$localSERVDIR\phase1global.cfg" r ; reopen..
              ReadForAppendPhaseOneLines:
              FileRead $phase_FileHandle $lineDataHandle ; get new line..
                iferrors closeUpPhaseOneAppend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForAppendPhaseOneLines                    ; go back for more.
              closeUpPhaseOneAppend:                                ; time to lock up
                FileClose $phase_FileHandle

      ; ok,If we have a phase one with no sniffer reference, and may or may not have one in the phase2 file....
      ; or a phase two that HAS the sniffer references.... then we just need to add 2 to 1 and rename.

      ; So find if we need to INSERT or just append phase2
      StrCmp $foundAtLeastOneLiveSnifferLine "1" FuseThePhaseBreak 0 ; if we jump then no extra is required....
        ; but if we fall through we need to insert.....and either ROLLBACK or insert fresh....
         ${IF} $healFromOldFile = "1" ; then we dump the archived stuff.....
           FileWrite $prependFileHandle $collectedArchiveData ; This puts the old valid lines back..... Its the only extra condition
          ${ELSE} ; then write the new data
            FileWrite $prependFileHandle 'SNIFFER external nonzero "$localINSTDIR\SNFClient.exe"$\t12$\t0$\r$\n'
          ${ENDIF}                                              ; if the data existed and a valid line was found, it would have been inserted.
         
        ; and drop into appending phase2
        FuseThePhaseBreak:
            FileOpen $phase_FileHandle "$localSERVDIR\phase2global.cfg" r ; reopen..
              ReadForAppendPhaseTwoLines:
              FileRead $phase_FileHandle $lineDataHandle ; get new line..
                iferrors closeUpPhaseTwoAppend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForAppendPhaseTwoLines                    ; go back for more.
              closeUpPhaseTwoAppend:                                ; time to lock up
                FileClose $phase_FileHandle
                
       FileClose $prependFileHandle
       goto RenamePhase ; ok, if so, then we're done then, handle file renaming.

RenamePhase:
  StrCpy $healFromOldFile "0" ; set this so that it doesn't try on the next call to this function.
  
  ifFileExists "$localSERVDIR\pre_snifferinstall_global.cfg.log" 0 +2
    Delete  "$localSERVDIR\pre_snifferinstall_global.cfg.log"
    Rename "$localSERVDIR\global.cfg" "$localSERVDIR\pre_snifferinstall_global.cfg.log"
    Rename "$localSERVDIR\NEWglobal.cfg" "$localSERVDIR\global.cfg"
    ifFileExists "$localSERVDIR\phase1global.cfg" 0 +2
      Delete "$localSERVDIR\phase1global.cfg"
    ifFileExists "$localSERVDIR\phase2global.cfg" 0 +2
      Delete "$localSERVDIR\phase2global.cfg"
    ifFileExists "$localSERVDIR\NEWglobal.cfg" 0 +2
      Delete "$localSERVDIR\NEWglobal.cfg"

    Return

FunctionEnd



# See editglobalCFG for documentation and explanation... this is the same but with a un. prepended.....
Function un.editglobalCFG
    StrCpy $collectedArchiveData ""         ; set for default.
    StrCpy $succededAtPlacingArchivedData "0"

    ;VAR /GLOBAL decludeConfigFileHandle ; the existing live file....

    ;VAR /GLOBAL phase_FileHandle  ; holds the first half up to the External Tests or pending no External Test line... we have the entire file here.
    ;VAR /GLOBAL phase
    ;VAR /GLOBAL TargetSnifferString  ; could be SNFClient.exe or $LicenseID.exe
    StrCpy $phase "1" ; start in phase 1

    # Identify live sniffer lines, and heal them if possible.
    ;Var /GLOBAL foundAtLeastOneLiveSnifferLine
    StrCpy $foundAtLeastOneLiveSnifferLine "0" ; defaults to no.....

  ;  Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
  ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
  ${un.handleShortPath} $localINSTDIR $INSTDIR
  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

  ;GetFullPathName /SHORT $localSERVDIR $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
  ${un.handleShortPath} $localSERVDIR $SNFServerInstallDir
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.


    ;Var /GLOBAL lineDataHandle
    ;Var /GLOBAL WordFindResults
    ;Var /GLOBAL FirstCharTestVar
    ;Var /GLOBAL tempLineHandle ; holds a manipulated version of the line as we test it....
    ;Var /GLOBAL secondHalfOfLine ; holds the other side to rejoin it after we replace....
    ;Var /GLOBAL firstHalfOfLine ; holds all chars up to the encapsulator.
    ;Var /GLOBAL encapsulator   ; holds the type of quote if its quoted...

################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
    ${IF} $healFromOldFile = "1"
      ## Then you need to strip and make temporary file for the stuff to put back.
      IfFileExists $archivedGLOBALcfgPath 0 DoneReadingArchiveFile
      FileOpen $archivedGLOBALcfgFileHandle $archivedGLOBALcfgPath r
        iferrors 0 +3
          MessageBox MB_OK "Unable to restructure Decludes global.cfg file from the rollback archive."
          Goto DoneReadingArchiveFile
      ReadArchiveLine:
         FileRead $archivedGLOBALcfgFileHandle $lineDataHandle
            ifErrors DoneReadingArchiveFile 0
            ; Primary test is that this a live sniffer line.
            ${un.WordFind} $lineDataHandle "SNFClient.exe" "E+1}" $WordFindResults
                   ifErrors 0 FoundLiveArchiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            ${un.WordFind} $lineDataHandle "$LicenseID.exe" "E+1}" $WordFindResults
                   ifErrors 0 FoundLiveArchiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            Goto ReadArchiveLine ; go back and get a newline to test.
      FoundLiveArchiveSnifferLine:
        StrCpy  $collectedArchiveData "$collectedArchiveData$lineDataHandle"  ; If here the line is of interest, even if its just a comment. collect it.
        Goto ReadArchiveLine
    ${ENDIF}
    DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
      FileClose $archivedGLOBALcfgFileHandle ; Close file.
      StrCpy $lineDataHandle "" ; Clear line data.
################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################



################################################### BEGIN PHASE 1 of the Main Global.cfg File Read. #################################
  FileOpen $decludeConfigFileHandle "$SNFServerInstallDir\global.cfg" r
    iferrors 0 OpenOK
      clearerrors
      MessageBox MB_OK "Error opening $SNFServerInstallDir\global.cfg file. Do you have the file open?"
      FileClose $decludeConfigFileHandle
      FileOpen $decludeConfigFileHandle "$SNFServerInstallDir\global.cfg" r
  OpenOK:
  FileOpen $phase_FileHandle "$SNFServerInstallDir\phase1global.cfg" w

KeepReading:
    FileRead  $decludeConfigFileHandle $lineDataHandle  ; get the first line.
    ifErrors DoneReadingFile 0
      ; Primary test is is this a live sniffer line?
    ${un.WordFind} $lineDataHandle "SNFClient.exe" "E+1}" $WordFindResults
           ifErrors 0 FoundLiveSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
    ${un.WordFind} $lineDataHandle "$LicenseID.exe" "E+1}" $WordFindResults
           ifErrors 0 FoundLiveOLDSnifferLine ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
    ${un.WordFind} $lineDataHandle "EXTERNAL TEST" "E+1}" $WordFindResults
           ifErrors 0 FoundExternalTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
           clearerrors
      FileWrite $phase_FileHandle $lineDataHandle ; dump line to phase1 file.
      Goto KeepReading ; go back and get a newline to test.

    FoundLiveSnifferLine:  ; ok, set TargetSnifferString to be abstract and work for either the new or the old naming convention.
      StrCpy $TargetSnifferString "SNFClient.exe" ; ok, set for regular sniffer....
      Goto TestForWhitespace
    FoundLiveOLDSnifferLine:
      StrCpy $TargetSnifferString "$LicenseID.exe" ; ok, set for regular sniffer....
    TestForWhitespace:
          ; ok, line contains SNFClient.exe or $LicenseID.exe we need to be sure it isn't a comment.
      StrCpy $tempLineHandle $lineDataHandle
      testNextChar:
      StrCpy $FirstCharTestVar $tempLineHandle 1 0
      StrCmp $FirstCharTestVar " " 0 CheckForCommentMarker
        StrCpy $tempLineHandle $tempLineHandle "" 1 ; cut off one char and test again.
        goto testNextChar
    CheckForCommentMarker:
      ; Skipped here because not blank space... so check for comment.
      StrCmp $FirstCharTestVar "#" 0 HandleValidLine
        ; Is a comment.  Dump to whatever phase is current.
        ; We don't allow Sniffer commented lines to build up..... so we remove it on this pass.
        ; FileWrite $phase_FileHandle $lineDataHandle ; dump line to phase1 file.
        Goto KeepReading ; go back and get a newline to test.

       HandleValidLine:
         StrCpy $foundAtLeastOneLiveSnifferLine "1"  ; set this to defer the phase change if it exists... and if it doesn't then thats ok.
         ; NOTE:  Special case..... we've found a valid line.  But if we're in ROLLBACK mode... then we don't want to copy this line, in, all valid lines
         ;        have been collected from the old file, and will now be deposited.  All further valid lines will be skipped. Thus:
         StrCmp $succededAtPlacingArchivedData "1" KeepReading 0 ; This aborts any new information from getting into the file. Get next line.
         StrCmp $healFromOldFile "1" 0 DealWithNormalConditions  ; skip forward and handle data.
           ; Ok, we're rolling back, but we haven't depositied data yet.
           FileWrite $phase_FileHandle $collectedArchiveData ; This puts all the valid lines from the archived section in place at the first found
                                                             ; live line of the current page.  Since the installer obeyd the protocol, its likely that its
                                                             ; in the correct spot.  If not, we'll put it back at the end.
           StrCpy $succededAtPlacingArchivedData "1"
           Goto KeepReading

       DealWithNormalConditions:
         ; Ok, we're here.  We have a good line... and we need to alter the path preceding the tag, and the name of the tag.
         ; We MAY be in the same folder.... but we may be in an entirely different folder... it doesn't matter.
         ${un.WordFind} $lineDataHandle $TargetSnifferString "+1}" $secondHalfOfLine ; load the last bit into the $secondHalfOfLine
           ; now test if its frst char is a white space.  If it is, then you're inside quotes, move forward till you find the quote, and then move back till you find it.
            ; It would be nice to have the algorithem just juse this as its solution, but it breaks because the old sniffer versions
             ; encapsulate the authentication inside the quotes.... and you could have 'Program Files' inside the quotes... so you can't trust
             ; a blank to be the pure encapsulator...  whats a hack to do...
             ; So we suggest that we take a test to see if there is one ', one ", or one ` in the secondHalfOfLine
             ; if there is we'll take a guess that the encapsulator isn't a blank, but that its a quote.....
             ;${WordFind} $secondHalfOfLine $TargetSnifferString "+1}" $secondHalfOfLine ; load the last bit into the $secondHalfOfLine

               ; Now we need to test to see if we have the authentication string in here.....
     ;          Var /GLOBAL toTheFarRight
               ${un.WordFind} $secondHalfOfLine $Authentication "+1}" $toTheFarRight ; load the last far right bit into the $toTheFarRight
                  ifErrors  0 usefartherEncapsulator
                    ; ok, just find the one to the right of the targetSnifferString and use that on the left side.
                    StrCpy $encapsulator $secondHalfOfLine 1 0
                     Goto GrabLeft
                  usefartherEncapsulator: ; ok, well, then if the Authentication is there, then we need to use the quote type to the right of that.
                     StrCpy $encapsulator $toTheFarRight 1 0 ; ok, good to go unless its a space... which I don't think you can do if you're using the Auth....
           GrabLeft:
           ; Now we have a character in the encapsulator.  Its either a quote, or a whitespace.  If its whitespace, then the end of the path on
           ; the other side will be another space..... and if its a quote, it will be a quote... etc....
           ; So get the PRE-part of the line, and grab everything to the right of the last encapsulator var.....
           ;MessageBox MB_OK "The encapsulator is:$encapsulator And the Cut is:$secondHalfOfLine"
             ${un.WordFind} $lineDataHandle $TargetSnifferString "+1{" $tempLineHandle ; load the first bit into the tempLineHandle.
             ; So tempLineHandle holds the entire preline....before the Name.exe
             ${un.WordFind} $tempLineHandle $encapsulator "+1{" $firstHalfOfLine ; load the first bit into the tempLineHandle.

             ; Naturally this needs to be rebuilt as..... firsthalf+encapsulator+NEWPATH\NEWEXE+ secondhalf (Which includes the 2nd encapsulator...
             StrCpy $tempLineHandle "$firstHalfOfLine$encapsulator$localINSTDIR\SNFClient.exe$secondHalfOfLine"
             ; Now we replace the previous valid line, with the new path and exe....
             FileWrite $phase_FileHandle $tempLineHandle ; dump line to phase file. ; Since we're just fixing the lines... it should be ok....
             ;MessageBox MB_OK "Inside the valid line: $tempLineHandle phase:$phase"
             ; and at the end if we're in phase 1 then we never found an External test marker... and it doesn't matter.....
             ; and if we're in phase two, then we need to append phase1 and phase2.... the only situation we need phase1 and phase2 sepearte
             ; is if we never get into this part... and have to put in a fresh line somewhere.....
             StrCpy $foundAtLeastOneLiveSnifferLine "1"
             Goto KeepReading ; go back and get a newline to test.

    FoundExternalTestMarker:
      ; Here we've determined that we have found the end of phase one
      ; but if we found a live line, that trumps putting lines after the external test marker....
      StrCmp $foundAtLeastOneLiveSnifferLine "1" 0 Well_SplitPhasesThen
        FileWrite $phase_FileHandle  $lineDataHandle ; dump line to phase1 file.
        ; IF thats the case then we just go back to keep reading and don't move the phase file pointer...
        Goto KeepReading
      ; but with no live sniffer lines yet... its a different story, cause we'll need to come back to this break if we don't
      ; find ANY.....
      Well_SplitPhasesThen:
        ; put the external tests marker in phase1 file.
        FileWrite $phase_FileHandle  $lineDataHandle ; dump line to phase1 file.
        ; Thus close the phase one marker.  And use Phase Two.
        StrCpy $phase "2"
        FileClose $phase_FileHandle
        FileOpen  $phase_FileHandle  "$SNFServerInstallDir\phase2global.cfg" w
      Goto KeepReading ; go back and get a newline to test.


    DoneReadingFile:
      FileClose $decludeConfigFileHandle  ; ok, now we need to know how to reasemble it....
      FileClose $phase_FileHandle

      StrCmp $phase "1" 0 handleRejoinPhases
        ; Ok, well that just means we didn't have a External Test marker... so test if we altered anything.
        StrCmp $foundAtLeastOneLiveSnifferLine "1" 0 AddLineAtStart ; and if we drop in, then we handled live lines....
            Rename "$SNFServerInstallDir\phase1global.cfg" "$SNFServerInstallDir\NEWglobal.cfg" ; set this up so its all the same for the RenamePhase.
            goto RenamePhase ; ok, if so, then we're done then, handle file renaming.
          AddLineAtStart:
      ;      Var /GLOBAL prependFileHandle
            FileOpen  $prependFileHandle  "$SNFServerInstallDir\NEWglobal.cfg" w
            ${IF} $healFromOldFile = "1" ; then we dump the archived stuff.....
              FileWrite $prependFileHandle "############################### SNIFFER TEST SECTION #################################$\r$\n"
              FileWrite $prependFileHandle $collectedArchiveData ; This puts the old valid lines back..... Its the only extra condition
            ${ELSE} ; then write the new data
              FileWrite $prependFileHandle "############################### SNIFFER TEST SECTION #################################$\r$\n"
              FileWrite $prependFileHandle 'SNIFFER external nonzero "$INSTDIR\SNFClient.exe"$\t12$\t0$\r$\n'
            ${ENDIF}                                              ; if the data existed and a valid line was found, it would have been inserted.

            ; now dump it all in after....
            FileOpen  $decludeConfigFileHandle "$SNFServerInstallDir\global.cfg" r ; reopen..
              ReadForPrePendNewLine:
              FileRead $decludeConfigFileHandle $lineDataHandle ; get new line..
                iferrors closeUpThePrepend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForPrePendNewLine                    ; go back for more.
              closeUpThePrepend:                                ; time to lock up
                FileClose $decludeConfigFileHandle
                FileClose $prependFileHandle
                Goto RenamePhase                                ; go and rename on top of the old file.
     ; Ok, but if we were in a phase 2 read.... it meant
     ; that we found an external test marker.... but we could have fond live lines....
     handleRejoinPhases:
          FileOpen $prependFileHandle "$SNFServerInstallDir\NEWglobal.cfg" w ; open target....
            FileOpen $phase_FileHandle "$SNFServerInstallDir\phase1global.cfg" r ; reopen..
              ReadForAppendPhaseOneLines:
              FileRead $phase_FileHandle $lineDataHandle ; get new line..
                iferrors closeUpPhaseOneAppend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForAppendPhaseOneLines                    ; go back for more.
              closeUpPhaseOneAppend:                                ; time to lock up
                FileClose $phase_FileHandle

      ; ok,If we have a phase one with no sniffer reference, and may or may not have one in the phase2 file....
      ; or a phase two that HAS the sniffer references.... then we just need to add 2 to 1 and rename.

      ; So find if we need to INSERT or just append phase2
      StrCmp $foundAtLeastOneLiveSnifferLine "1" FuseThePhaseBreak 0 ; if we jump then no extra is required....
        ; but if we fall through we need to insert.....and either ROLLBACK or insert fresh....
         ${IF} $healFromOldFile = "1" ; then we dump the archived stuff.....
           FileWrite $prependFileHandle $collectedArchiveData ; This puts the old valid lines back..... Its the only extra condition
          ${ELSE} ; then write the new data
            FileWrite $prependFileHandle 'SNIFFER external nonzero "$localINSTDIR\SNFClient.exe"$\t12$\t0$\r$\n'
          ${ENDIF}                                              ; if the data existed and a valid line was found, it would have been inserted.

        ; and drop into appending phase2
        FuseThePhaseBreak:
            FileOpen $phase_FileHandle "$SNFServerInstallDir\phase2global.cfg" r ; reopen..
              ReadForAppendPhaseTwoLines:
              FileRead $phase_FileHandle $lineDataHandle ; get new line..
                iferrors closeUpPhaseTwoAppend 0                    ; check for EOF
                  FileWrite $prependFileHandle $lineDataHandle  ; NO? Ok write the line to the new file.
                  Goto ReadForAppendPhaseTwoLines                    ; go back for more.
              closeUpPhaseTwoAppend:                                ; time to lock up
                FileClose $phase_FileHandle

       FileClose $prependFileHandle
       goto RenamePhase ; ok, if so, then we're done then, handle file renaming.

RenamePhase:
  StrCpy $healFromOldFile "0" ; set this so that it doesn't try on the next call to this function.

  ifFileExists "$SNFServerInstallDir\pre_snifferinstall_global.cfg.log" 0 +2
    Delete  "$SNFServerInstallDir\pre_snifferinstall_global.cfg.log"
    Rename "$SNFServerInstallDir\global.cfg" "$SNFServerInstallDir\pre_snifferinstall_global.cfg.log"
    Rename "$SNFServerInstallDir\NEWglobal.cfg" "$SNFServerInstallDir\global.cfg"
    ifFileExists "$SNFServerInstallDir\phase1global.cfg" 0 +2
      Delete "$SNFServerInstallDir\phase1global.cfg"
    ifFileExists "$SNFServerInstallDir\phase2global.cfg" 0 +2
      Delete "$SNFServerInstallDir\phase2global.cfg"
    ifFileExists "$SNFServerInstallDir\NEWglobal.cfg" 0 +2
      Delete "$SNFServerInstallDir\NEWglobal.cfg"

    Return

FunctionEnd





Function editMXGuardINI
  ; Ok we must have detected MXGuard's ini file. Therefore we are going to run a strip and fix on the MXGuard.ini file.

  VAR /GLOBAL newMXGuardINIFileHandle
  VAR /GLOBAL MXGuardINIFileHandle
  VAR /GLOBAL InsertAuthenticationString ; format this initially, and stop it with the restore value if we execute that paragraph.
  VAR /GLOBAL InsertPathString ; format this initially, and stop it with the restore value if we execute that paragraph.
  ; declared in the global.cfg editor that uses the same construct
  ;Var /GLOBAL registryTempData
  ;Var /GLOBAL lineDataHandle
  ;Var /GLOBAL WordFindResults
  ;Var /Global FirstCharTestVar
  ;Var /GLOBAL localINSTDIR
  ;Var /GLOBAL localSERVDIR

  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.
  ;  Var /GLOBAL ShortPathTempVar ; Defined earlier ... use this to hold the Short Windows Progr~1 path references...
  ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localINSTDIR $INSTDIR
  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

  ;GetFullPathName /SHORT $localSERVDIR $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localSERVDIR $SNFServerInstallDir
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.

      ## ADDING sensitivity to the functions being called to enable them to look up the proper path values in the event that the
      ## rollback sequence is not in the current INSTDIR and $SNFServerInstallDir locations.  i.e. Those parsing functions need to be able
      ## to find the correct file to be editing.  If its rolling back an older version cross platform, then it needs to redefine the file its
      ## targeting, not just assume that its in the INSTDIR or the $SNFServerInstallDir.  I added two registry keys to the EndRollbackSequence
      ## subroutine called SRS_INSTDIR and SRS_SERVDIR to cover the lookup during rollback....since by this point INSTDIR is defined,
      ## just having SRS_INSTDIR different from INSTDIR should be enough key to use the SRS_INSTDIR.... and if the SRS_INSTDIR doesnt' exist,
      ## ( because it wouldn't be entered until the end of the rollback sequence, then the functions will know they are in the new install, and
      ## will use the current INSTDIR as their paths.....
  Clearerrors
  ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_INSTDIR"
    iferrors 0 handleReset
      goto doneCheckingRollbackVars ; the keys didn't exist so don't hijack.
    handleReset:
      ; they exist so hijack.  i.e. Anytime a rollback file exists, ITS local pointers to the relevant INSTDIR and SERVDIR will be valid.
      ; because when you're done running the rollback, the markers are gone.  And a fresh install will replace relevent markers.  Even if its
      ; in the same spot.
      StrCpy $localINSTDIR $registryTempData
      ReadRegStr $registryTempData HKLM "Software\MessageSniffer" "SRS_SERVDIR"
      StrCpy $localSERVDIR $registryTempData
      
        ${handleShortPath} $localINSTDIR $localINSTDIR
        ${handleShortPath} $localSERVDIR $localSERVDIR
  doneCheckingRollbackVars:


  # Initialize these to the normal values as if this was an install....
  StrCpy $InsertAuthenticationString "$Authentication$\r$\n"
  StrCpy $InsertPathString "$localINSTDIR\SNFClient.exe$\r$\n"


  ## But if its a restore, then this will execute and overwrite the above two vars......
  ## The strip and fix will either put the new values that are necessary for the .exe's to function, or it will
  ## datamine the old file and insert into the existing file, the new values for the three editable line items pertaining
  ## to sniffer.
  ################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
    ${IF} $healFromOldFile = "1"
      ## Then you need to strip and make temporary file for the stuff to put back.
      clearerrors
      IfFileExists $archivedMXGUARDiniPath 0 DoneReadingArchiveFile
      FileOpen $archivedMXGUARDiniFileHandle $archivedMXGUARDiniPath r
        iferrors 0 ReadArchiveLine
          MessageBox MB_OK "Unable to read MXGuard's MXGuard.ini file from the rollback archive: $archivedMXGUARDiniPath"
          Goto DoneReadingArchiveFile
      ReadArchiveLine:
        FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
          ifErrors DoneReadingArchiveFile 0
            ${WordFind} $lineDataHandle "[Sniffer]" "E+1}" $WordFindResults
               ifErrors 0 FoundArchivedTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            Goto ReadArchiveLine ; go back and get a newline to test.
        FoundArchivedTestMarker:
          ; Ok, we're here and we need to read until we get the old AuthCode..... and store it...
              LookForAuth:
                FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
                ${WordFind} $lineDataHandle "AuthCode=" "E+1}" $WordFindResults
                 ifErrors LookForAuth 0 ; errors meant not in line...go back and look for Auth  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $InsertAuthenticationString $WordFindResults ; Save the insertable Authentication String.
              LookForPath:
                FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
                ${WordFind} $lineDataHandle "PathToEXE=" "E+1}" $WordFindResults
                 ifErrors LookForPath 0 ; errors meant not in line...go back and look for Auth  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $InsertPathString $WordFindResults ; Save the insertable Authentication String.
    ${ENDIF}
    DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
      FileClose $archivedMXGUARDiniFileHandle ; Close file.
      StrCpy $lineDataHandle "" ; Clear line data.
################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################

  # Open the current files.....
  FileOpen $MXGuardINIFileHandle "$localSERVDIR\mxGuard.ini" r
  ;MessageBox MB_OK "Opening $SNFServerInstallDir\mxGuard.ini"
  # The soon to be edited file...
  FileOpen $newMXGuardINIFileHandle "$localSERVDIR\NEWmxGuard.ini" w
  ;MessageBox MB_OK "Opening $SNFServerInstallDir\NEWmxGuard.ini"
  clearerrors
  KeepReading:

    FileRead  $MXGuardINIFileHandle $lineDataHandle
    ifErrors DoneReadingFile 0
    ${WordFind} $lineDataHandle "[Sniffer]" "E+1}" $WordFindResults
           ifErrors 0 FoundExternalTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.
      Goto KeepReading ; go back and get a newline to test.
  FoundExternalTestMarker:
      ; First put the marker  line. "[Sniffer]"
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.

              ; Then write teh Auth line.
              FileWrite $newMXGuardINIFileHandle "AuthCode=$InsertAuthenticationString"
              ; Read the line off the file, but don't write it.....
              FileRead  $MXGuardINIFileHandle $lineDataHandle
              ; Then write the Path line.
              FileWrite $newMXGuardINIFileHandle "PathToEXE=$InsertPathString"
              ; Read the line off the file, but don't write it.....
              FileRead  $MXGuardINIFileHandle $lineDataHandle

  ; DoneWritingEntry:
  ; now dump the rest of the file.
  KeepDumping:
    FileRead  $MXGuardINIFileHandle $lineDataHandle
    ifErrors DoneDumping 0
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.
    Goto KeepDumping ; go back and get a newline to test.

  DoneDumping:
   ; this should be id. Go home.
    FileClose $MXGuardINIFileHandle
    FileClose $newMXGuardINIFileHandle
    ifFileExists "$localSERVDIR\old_mxGuard.ini" 0 +2
      Delete "$localSERVDIR\old_mxGuard.ini"
    Rename "$localSERVDIR\mxGuard.ini" "$localSERVDIR\old_mxGuard.ini"
    Rename "$localSERVDIR\NEWmxGuard.ini" "$localSERVDIR\mxGuard.ini"
    Delete "$localSERVDIR\old_mxGuard.ini"
    StrCpy $healFromOldFile "0" ; Clear flag
    Return
    
  DoneReadingFile:
    ; this would be an error because no external SNIFFER marker was found.  Add marker but notify.
    MessageBox MB_OK "MXGuards INI file seems to be missing the [SNIFFER] section.  Adding [SNIFFER] section. "
    FileWrite $newMXGuardINIFileHandle "$\r$\n[SNIFFER]$\r$\n"
    ; Then write teh Auth line.
    FileWrite $newMXGuardINIFileHandle "AuthCode=$InsertAuthenticationString\r$\n"
    ; Then write the Path line.
    FileWrite $newMXGuardINIFileHandle "PathToEXE=$InsertPathString$\r$\n"
    FileClose $newMXGuardINIFileHandle
    FileClose $MXGuardINIFileHandle
    
    ifFileExists "$localSERVDIR\old_mxGuard.ini" 0 +2
      Delete "$localSERVDIR\old_mxGuard.ini"
     
    Rename "$localSERVDIR\mxGuard.ini" "$localSERVDIR\old_mxGuard.ini"
    Rename "$localSERVDIR\NEWmxGuard.ini" "$localSERVDIR\mxGuard.ini"
    
    Delete "$localSERVDIR\old_mxGuard.ini"
    StrCpy $healFromOldFile "0" ; Clear flag
    Return

FunctionEnd

# Same as above but needs to re-declared for the uninstaller.
Function un.editMXGuardINI
  ; Ok we must have detected MXGuard's ini file. Therefore we are going to run a strip and fix on the MXGuard.ini file.

;  VAR /GLOBAL newMXGuardINIFileHandle
 ; VAR /GLOBAL MXGuardINIFileHandle
;  VAR /GLOBAL InsertAuthenticationString ; format this initially, and stop it with the restore value if we execute that paragraph.
;  VAR /GLOBAL InsertPathString ; format this initially, and stop it with the restore value if we execute that paragraph.

  ; declared in the global.cfg editor that uses the same construct
  ;Var /GLOBAL lineDataHandle
  ;Var /GLOBAL WordFindResults
  ;Var /Global FirstCharTestVar

  ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
  ${un.handleShortPath} $localINSTDIR $INSTDIR
  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

  ;GetFullPathName /SHORT $localSERVDIR $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
  ${un.handleShortPath} $localSERVDIR $SNFServerInstallDir
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.


  # Initialize these to the normal values as if this was an install....
  StrCpy $InsertAuthenticationString "$Authentication$\r$\n"
  StrCpy $InsertPathString "$localINSTDIR\SNFClient.exe$\r$\n"


  ## But if its a restore, then this will execute and overwrite the above two vars......
  ## The strip and fix will either put the new values that are necessary for the .exe's to function, or it will
  ## datamine the old file and insert into the existing file, the new values for the three editable line items pertaining
  ## to sniffer.
  ################################################## HEAL FROM ARCHIVE DATA COLLECTION PHASE #######################################
    ${IF} $healFromOldFile = "1"
      ## Then you need to strip and make temporary file for the stuff to put back.
      clearerrors
      IfFileExists $archivedMXGUARDiniPath 0 DoneReadingArchiveFile
      FileOpen $archivedMXGUARDiniFileHandle $archivedMXGUARDiniPath r
        iferrors 0 ReadArchiveLine
          MessageBox MB_OK "Unable to read MXGuard's MXGuard.ini file from the rollback archive: $archivedMXGUARDiniPath"
          Goto DoneReadingArchiveFile
      ReadArchiveLine:
        FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
          ifErrors DoneReadingArchiveFile 0
            ${un.WordFind} $lineDataHandle "[Sniffer]" "E+1}" $WordFindResults
               ifErrors 0 FoundArchivedTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
            Goto ReadArchiveLine ; go back and get a newline to test.
        FoundArchivedTestMarker:
          ; Ok, we're here and we need to read until we get the old AuthCode..... and store it...
              LookForAuth:
                FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
                ${un.WordFind} $lineDataHandle "AuthCode=" "E+1}" $WordFindResults
                 ifErrors LookForAuth 0 ; errors meant not in line...go back and look for Auth  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $InsertAuthenticationString $WordFindResults ; Save the insertable Authentication String.
              LookForPath:
                FileRead  $archivedMXGUARDiniFileHandle $lineDataHandle
                ${un.WordFind} $lineDataHandle "PathToEXE=" "E+1}" $WordFindResults
                 ifErrors LookForPath 0 ; errors meant not in line...go back and look for Auth  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $InsertPathString $WordFindResults ; Save the insertable Authentication String.
    ${ENDIF}
    DoneReadingArchiveFile: ; By this point, either $collectedArchiveData has a bunch of stuff or it doesn't......
      FileClose $archivedMXGUARDiniFileHandle ; Close file.
      StrCpy $lineDataHandle "" ; Clear line data.
################################################### END HEAL FROM ARCHIVE DATA COLLECTION PHASE #################################

  # Open the current files.....
  FileOpen $MXGuardINIFileHandle "$SNFServerInstallDir\mxGuard.ini" r
  ;MessageBox MB_OK "Opening $SNFServerInstallDir\mxGuard.ini"
  # The soon to be edited file...
  FileOpen $newMXGuardINIFileHandle "$SNFServerInstallDir\NEWmxGuard.ini" w
  ;MessageBox MB_OK "Opening $SNFServerInstallDir\NEWmxGuard.ini"
  clearerrors
  KeepReading:

    FileRead  $MXGuardINIFileHandle $lineDataHandle
    ifErrors DoneReadingFile 0
    ${un.WordFind} $lineDataHandle "[Sniffer]" "E+1}" $WordFindResults
           ifErrors 0 FoundExternalTestMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.
      Goto KeepReading ; go back and get a newline to test.
  FoundExternalTestMarker:
      ; First put the marker  line. "[Sniffer]"
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.

              ; Then write teh Auth line.
              FileWrite $newMXGuardINIFileHandle "AuthCode=$InsertAuthenticationString"
              ; Read the line off the file, but don't write it.....
              FileRead  $MXGuardINIFileHandle $lineDataHandle
              ; Then write the Path line.
              FileWrite $newMXGuardINIFileHandle "PathToEXE=$InsertPathString"
              ; Read the line off the file, but don't write it.....
              FileRead  $MXGuardINIFileHandle $lineDataHandle

  ; DoneWritingEntry:
  ; now dump the rest of the file.
  KeepDumping:
    FileRead  $MXGuardINIFileHandle $lineDataHandle
    ifErrors DoneDumping 0
      FileWrite $newMXGuardINIFileHandle $lineDataHandle ; dump line to new file.
    Goto KeepDumping ; go back and get a newline to test.

  DoneDumping:
   ; this should be id. Go home.
    FileClose $MXGuardINIFileHandle
    FileClose $newMXGuardINIFileHandle
    ifFileExists "$SNFServerInstallDir\old_mxGuard.ini" 0 +2
      Delete "$SNFServerInstallDir\old_mxGuard.ini"
    Rename "$SNFServerInstallDir\mxGuard.ini" "$SNFServerInstallDir\old_mxGuard.ini"
    Rename "$SNFServerInstallDir\NEWmxGuard.ini" "$SNFServerInstallDir\mxGuard.ini"
    Delete "$SNFServerInstallDir\old_mxGuard.ini"
    StrCpy $healFromOldFile "0" ; Clear flag
    Return

  DoneReadingFile:
    ; this would be an error because no external SNIFFER marker was found.  Add marker but notify.
    MessageBox MB_OK "MXGuards INI file seems to be missing the [SNIFFER] section.  Adding [SNIFFER] section. "
    FileWrite $newMXGuardINIFileHandle "$\r$\n[SNIFFER]$\r$\n"
    ; Then write teh Auth line.
    FileWrite $newMXGuardINIFileHandle "AuthCode=$InsertAuthenticationString\r$\n"
    ; Then write the Path line.
    FileWrite $newMXGuardINIFileHandle "PathToEXE=$InsertPathString$\r$\n"
    FileClose $newMXGuardINIFileHandle
    FileClose $MXGuardINIFileHandle

    ifFileExists "$SNFServerInstallDir\old_mxGuard.ini" 0 +2
      Delete "$SNFServerInstallDir\old_mxGuard.ini"

    Rename "$SNFServerInstallDir\mxGuard.ini" "$SNFServerInstallDir\old_mxGuard.ini"
    Rename "$SNFServerInstallDir\NEWmxGuard.ini" "$SNFServerInstallDir\mxGuard.ini"

    Delete "$SNFServerInstallDir\old_mxGuard.ini"
    StrCpy $healFromOldFile "0" ; Clear flag
    Return

FunctionEnd


Function un.editContentXML
  ; Subroutine that REMOVES the XML to tie in Sniffer to the IceWarp merak\config\content.xml
  ; There are three situations.  First the file is empty, Second it doesn't have a sniffer tag, but there are other filters, third it has a sniffer tag.

  ; if Sniffer was installed as an AV filter... then call stripScanDAT will remove that.
  Call un.stripScanXML
  
  ; and now hande if we're inside the content.xml file.

    Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file.
    Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
    Var /GLOBAL IceWarpSnifferXMLExists
    Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
    Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    StrCpy $didWeOutput "0"
    StrCpy $IceWarpSnifferXMLExists "0" ; default flag to false.

    Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.
    FileOpen  $IceWarpAdjustedFileHandle "$SNFServerInstallDir\config\contentNEW.xml" w
    clearerrors
      IfFileExists "$SNFServerInstallDir\config\content.xml" 0 UnableToFindContentFileXML
      FileOpen $IceWarpContentFileHandle "$SNFServerInstallDir\config\content.xml" r
        iferrors 0 ReadContentLine
          MessageBox MB_OK "Unable to read IceWarps Content.XML file from: $SNFServerInstallDir\config\content.xml"
          Goto DoneReadingContentFile

      ; You can have an empty file.  With no headers... so first we either spin through without finding a valid header opener... and then
      ; open and enter our own filter at the end... or we'll find one, and enter into the valid filter sections.
      ReadForProperyHeaderedFilterFile:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingEmptyFile 0
            ${un.WordFind} $IceWarpContentXMLlinedata "<CONTENTFILTER>" "E+1}" $WordFindResults
               ifErrors 0 ProperlyHeaderedFile ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadForProperyHeaderedFilterFile ; go back and get a newline to test.
      ProperlyHeaderedFile:
        ; dump header line.
        FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.


      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${un.WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.

          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${un.WordFind} $IceWarpContentXMLlinedata "<TITLE>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and were here, then if we find the title and it IS sniffer.... then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${un.WordFind} $IceWarpContentXMLlinedata "SNIFFER" "E+1}" $WordFindResults
                 ifErrors 0 FoundSnifferSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.

            FoundSnifferSection:
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${un.WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:

            ; Ok, we stripped it.
            ; From here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.

    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:  
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$SNFServerInstallDir\config\contentNEW.xml"
      Return ;   fall through and close files up.

    ; we could jump to here from anywere indicating EOF.... so if if thats the game.  We store and swap.
    DoneReadingContentFile: 
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.

      ; Now swap out the files.
      Var /GLOBAL  var1
      Var /GLOBAL  var2
      Var /GLOBAL  var3
      Var /GLOBAL  var4
      Var /GLOBAL  var5
      Var /GLOBAL  var6
      Var /GLOBAL  var7
      ${un.GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      Rename "$SNFServerInstallDir\config\content.xml" "$SNFServerInstallDir\config\content_UnInstallLOG_$var1-$var2-$var4.xml"
      Rename "$SNFServerInstallDir\config\contentNEW.xml" "$SNFServerInstallDir\config\content.xml"
      Return

    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$SNFServerInstallDir\config\contentNEW.xml"
      Return

    UnableToFindContentFileXML:
      Return

FunctionEnd


Function stripContentXML
  ; Subroutine that REMOVES the XML to tie in Sniffer to the IceWarp merak\config\content.xml when installing as AV.. ( and it was pre-instaled )
  ; as a Content Filter.
  ; There are three situations.  First the file is empty, Second it doesn't have a sniffer tag, but there are other filters, third it has a sniffer tag.

  ; and now hande if we're inside the content.xml file.

   ;Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file.
   ;Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
   ;Var /GLOBAL IceWarpSnifferXMLExists
   ;Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
   ;Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    StrCpy $didWeOutput "0"
    StrCpy $IceWarpSnifferXMLExists "0" ; default flag to false.

    ;Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.
    FileOpen  $IceWarpAdjustedFileHandle "$SNFServerInstallDir\config\contentNEW.xml" w
    clearerrors
      IfFileExists "$SNFServerInstallDir\config\content.xml" 0 UnableToFindContentFileXML
      FileOpen $IceWarpContentFileHandle "$SNFServerInstallDir\config\content.xml" r
        iferrors 0 ReadContentLine
          MessageBox MB_OK "Unable to read IceWarps Content.XML file from: $SNFServerInstallDir\config\content.xml"
          Goto DoneReadingContentFile

      ; You can have an empty file.  With no headers... so first we either spin through without finding a valid header opener... and then
      ; open and enter our own filter at the end... or we'll find one, and enter into the valid filter sections.
      ReadForProperyHeaderedFilterFile:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingEmptyFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<CONTENTFILTER>" "E+1}" $WordFindResults
               ifErrors 0 ProperlyHeaderedFile ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadForProperyHeaderedFilterFile ; go back and get a newline to test.
      ProperlyHeaderedFile:
        ; dump header line.
        FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.


      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.

          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${WordFind} $IceWarpContentXMLlinedata "<TITLE>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and were here, then if we find the title and it IS sniffer.... then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${WordFind} $IceWarpContentXMLlinedata "SNIFFER" "E+1}" $WordFindResults
                 ifErrors 0 FoundSnifferSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.

            FoundSnifferSection:
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:

            ; Ok, we stripped it.
            ; From here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.

    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$SNFServerInstallDir\config\contentNEW.xml"
      Return ;   fall through and close files up.

    ; we could jump to here from anywere indicating EOF.... so if if thats the game.  We store and swap.
    DoneReadingContentFile:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.

      ; Now swap out the files.
      ;Var /GLOBAL  var1
      ;Var /GLOBAL  var2
      ;Var /GLOBAL  var3
      ;Var /GLOBAL  var4
      ;Var /GLOBAL  var5
      ;Var /GLOBAL  var6
      ;Var /GLOBAL  var7
      ${GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      Rename "$SNFServerInstallDir\config\content.xml" "$SNFServerInstallDir\config\content_UnInstallLOG_$var1-$var2-$var4.xml"
      Rename "$SNFServerInstallDir\config\contentNEW.xml" "$SNFServerInstallDir\config\content.xml"
      Return

    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$SNFServerInstallDir\config\contentNEW.xml"
      Return

    UnableToFindContentFileXML:
      Return

FunctionEnd


Function editContentXML
  ; Subroutine that inserts the XML to tie in Sniffer to the IceWarp merak\config\content.xml
  ; There are three situations.  First the file is empty, Second it doesn't have a sniffer tag, but there are other filters, third it has a sniffer tag.
  ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localINSTDIR $INSTDIR
  ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

  ;GetFullPathName /SHORT $localSERVDIR $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
  ${handleShortPath} $localSERVDIR $SNFServerInstallDir
  ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.



  Var /GLOBAL IceWarpType
  ReadRegStr  $IceWarpType HKLM "SOFTWARE\MessageSniffer" "IceWarpType"
  ; possible types are AV, CF and SS
  
  StrCmp $IceWarpType "AV" 0 useContentFilters
    Call editScanXML ; not using ContentFilter tie in.  Using Scan.dat file tie in.  Very similar, but slightly different.
    return
    

  useContentFilters:

  ; Ok, not inserting into AV position.  So we'll do the contentfilter stuff.
  ; but if we WE'RE installed there before... we need to strip it out from the AV tiein..
  Call stripScanXML

    Var /GLOBAL ContentXMLHeader
    Var /GLOBAL ContentXMLFooter
    Var /GLOBAL SnifferXMLContent
    Var /GLOBAL SnifferXMLContent2
    StrCpy $ContentXMLHeader '<?xml version="1.0" encoding="UTF-8"?>$\r$\n<CONTENTFILTER>$\r$\n' ; If nothing in file, when we need to write header and
    StrCpy $ContentXMLFooter "</CONTENTFILTER>"                                                    ; footer.
    
    StrCmp $IceWarpType "CF" 0 SetForSS  ; Only other setting is SS
        StrCpy $SnifferXMLContent "" ; Clear buffer.
            StrCpy $SnifferXMLContent "$SnifferXMLContent<FILTER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <ACTIVE>1</ACTIVE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <TITLE>SNIFFER</TITLE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <READONLY>0</READONLY>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <AND>1</AND>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <LOGICALNOT>0</LOGICALNOT>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <EXPRESSION>6</EXPRESSION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAINTYPE>8</CONTAINTYPE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZESMALLER>0</MESSAGESIZESMALLER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZE>1</MESSAGESIZE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  </CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <AND>1</AND>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <LOGICALNOT>0</LOGICALNOT>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <EXPRESSION>4</EXPRESSION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAINTYPE>8</CONTAINTYPE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAIN>$localINSTDIR\SNFClient.exe</CONTAIN>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZESMALLER>0</MESSAGESIZESMALLER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZE>2</MESSAGESIZE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  </CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <ACCEPT>0</ACCEPT>$\r$\n"
            StrCpy $SnifferXMLContent2 "  <REJECT>0</REJECT>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <DELETE>0</DELETE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <ENCRYPT>0</ENCRYPT>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <PRIORITY>0</PRIORITY>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <FLAGS>0</FLAGS>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <SCORE>500</SCORE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <MARKSPAM>1</MARKSPAM>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <STOP>0</STOP>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <EXECUTE>0</EXECUTE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <TARPITSENDER>0</TARPITSENDER>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <FIXRFC822>0</FIXRFC822>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <SMTPRESPONSE>0</SMTPRESPONSE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <STRIPALL>1</STRIPALL>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <HEADER>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2     <VAL>0X-SNIFFER-FLAG: Yes </VAL>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  </HEADER>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2</FILTER>$\r$\n"
            Goto FilterTextReady
    SetForSS:
      ; ok, not using the CF, we're using the spam score insertion method.
            StrCpy $SnifferXMLContent "$SnifferXMLContent<FILTER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <ACTIVE>1</ACTIVE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <TITLE>SNIFFER</TITLE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <READONLY>0</READONLY>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <AND>1</AND>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <LOGICALNOT>0</LOGICALNOT>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <EXPRESSION>6</EXPRESSION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAINTYPE>8</CONTAINTYPE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZESMALLER>0</MESSAGESIZESMALLER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZE>1</MESSAGESIZE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  </CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <AND>1</AND>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <LOGICALNOT>0</LOGICALNOT>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <EXPRESSION>4</EXPRESSION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAINTYPE>8</CONTAINTYPE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <CONTAIN>$localINSTDIR\SNFClient.exe</CONTAIN>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZESMALLER>0</MESSAGESIZESMALLER>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent     <MESSAGESIZE>2</MESSAGESIZE>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  </CONDITION>$\r$\n"
            StrCpy $SnifferXMLContent "$SnifferXMLContent  <ACCEPT>0</ACCEPT>$\r$\n"
            StrCpy $SnifferXMLContent2 "  <REJECT>0</REJECT>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <DELETE>0</DELETE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <ENCRYPT>0</ENCRYPT>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <PRIORITY>0</PRIORITY>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <FLAGS>0</FLAGS>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <SCORE>500</SCORE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <MARKSPAM>0</MARKSPAM>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <STOP>0</STOP>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <EXECUTE>0</EXECUTE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <TARPITSENDER>0</TARPITSENDER>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <FIXRFC822>0</FIXRFC822>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2  <SMTPRESPONSE>0</SMTPRESPONSE>$\r$\n"
            StrCpy $SnifferXMLContent2 "$SnifferXMLContent2</FILTER>$\r$\n"
      
FilterTextReady:
    #Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file. ALREADY DECLARED in un. function.
    #Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
    #Var /GLOBAL IceWarpSnifferXMLExists
    #Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
    #Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    #Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.


    StrCpy $didWeOutput "0"
    StrCpy $IceWarpSnifferXMLExists "0" ; default flag to false.
    
    FileOpen  $IceWarpAdjustedFileHandle "$SNFServerInstallDir\config\contentNEW.xml" w
    clearerrors
      IfFileExists "$SNFServerInstallDir\config\content.xml" 0 UnableToFindContentFileXML
      FileOpen $IceWarpContentFileHandle "$SNFServerInstallDir\config\content.xml" r
        iferrors 0 ReadContentLine
          MessageBox MB_OK "Unable to read IceWarps Content.XML file from: $SNFServerInstallDir\config\content.xml"
          Goto DoneReadingContentFile
          
      ; You can have an empty file.  With no headers... so first we either spin through without finding a valid header opener... and then
      ; open and enter our own filter at the end... or we'll find one, and enter into the valid filter sections.
      ReadForProperyHeaderedFilterFile:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingEmptyFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<CONTENTFILTER>" "E+1}" $WordFindResults
               ifErrors 0 ProperlyHeaderedFile ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadForProperyHeaderedFilterFile ; go back and get a newline to test.
      ProperlyHeaderedFile:
        ; dump header line.
        FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
        
        
      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
                ; BUT we could be reading the last line, in which case, we need to output before we close the content filter tag...
                ${WordFind} $IceWarpContentXMLlinedata "</CONTENTFILTER>" "E+1}" $WordFindResults
                  ifErrors NotEndingYet 0 ; errors meant not in line...  If we found it, then drop through and handle trivial ending.  Otherwise drop through
                     ; Ok here is where we put the new Sniffer... since we're about to end without finding one.
                     FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent ; and because this is a properly wrapped file, and there may be more filters after us.
                     FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent2
                     StrCpy $didWeOutput "1"                                 ; we continue through and write the rest till EOF.
                     FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; close the XML validily.
                     Goto DoneReadingContentFile
                  NotEndingYet:  ; ok if its not the trivial ending, then output line, and go back for more.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.
          
          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${WordFind} $IceWarpContentXMLlinedata "<TITLE>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and were here, then if we find the title and it IS sniffer.... then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${WordFind} $IceWarpContentXMLlinedata "SNIFFER" "E+1}" $WordFindResults
                 ifErrors 0 FoundSnifferSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.
                  
            FoundSnifferSection:
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:
              
            ; Ok here is where we put the new Sniffer... since we just cut out the old sniffer.
            FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent ; and because this is a properly wrapped file, and there may be more filters after us.
            FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent2
            StrCpy $didWeOutput "1"                                 ; we continue through and write the rest till EOF.

            ; Ok from here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.
              
    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:  ; this means we head, fill and footer the file ourselves.
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLHeader ; If nothing in file, when we need to write header and
        FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent
        FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent2
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLFooter ; and footer
        StrCpy $didWeOutput "1"                                            ; footer.
        ;   fall through and close files up.

    ; we could jump to here from anywere.  If we needed to write it out in the middle, we would have done it.
    DoneReadingContentFile:   ; only the trivial EOF early would trip with no output.... so if thats the case

      StrCmp $didWeOutput "0" 0 SkipOutputThisTime  ; we need to dump it all in, headers and footers too, and then close.
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLHeader ; If nothing in file, when we need to write header and
        FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent
        FileWrite $IceWarpAdjustedFileHandle $SnifferXMLContent2
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLFooter ; and footer ; if we didn't have a chance, then we output here.
        SkipOutputThisTime:
        ; potential for corrupted file if file ended with errors....

      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.
      
      ; Now swap out the files.
      #Var /GLOBAL  var1
      #Var /GLOBAL  var2
      #Var /GLOBAL  var3
      #Var /GLOBAL  var4
      #Var /GLOBAL  var5
      #Var /GLOBAL  var6
      #Var /GLOBAL  var7
      
      ${GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      ifFileExists "$SNFServerInstallDir\config\content_InstallLOG_$var1-$var2-$var4.xml" 0 +2
        Delete "$SNFServerInstallDir\config\content_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$SNFServerInstallDir\config\content.xml" "$SNFServerInstallDir\config\content_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$SNFServerInstallDir\config\contentNEW.xml" "$SNFServerInstallDir\config\content.xml"
      Return
      
    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$SNFServerInstallDir\config\contentNEW.xml"
      MessageBox MB_OK "Attempting to edit XML in: $SNFServerInstallDir\config\content.xml resulted in finding a corrupted construction.  Please check the new file, content.xml, manually."
      Return
      
    UnableToFindContentFileXML:
      MessageBox MB_OK "Unable to find IceWarps Content.XML file from: $SNFServerInstallDir\config\content.xml  You will have to tie-in manually with IceWarp."
      Return

FunctionEND


Function un.stripScanXML
 ; Subroutine that removes the XML to tie in Sniffer to the IceWarp merak\config\scan.dat file. ( As an AV filter )
  ; There are three situations.  First the file is empty, Second it doesn't have a SNFClient tag, but there are other filters, third it has a ClamAV tag.
    ;Var /GLOBAL WordFindResults
    ;Var /GLOBAL ContentXMLHeader
    ;Var /GLOBAL ContentXMLFooter
    ; Used for gettime functions.
    ;Var /GLOBAL var1
    ;Var /GLOBAL var2
    ;Var /GLOBAL var3
    ;Var /GLOBAL var4
    ;Var /GLOBAL var5
    ;Var /GLOBAL var6
    ;Var /GLOBAL var7
    Var /GLOBAL IceWarpInstallFolder
    StrCpy $IceWarpInstallFolder $SNFServerInstallDir ; set as source for file.... ( filter code was ported from the ClamAid Script )
    
    StrCpy $ContentXMLHeader '<FILTERS>$\r$\n' ; If nothing in file, when we need to write header and
    StrCpy $ContentXMLFooter "</FILTERS>$\r$\n"
                                                        ; footer.

    ;Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file. ALREADY DECLARED in un. function.
    ;Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
    ;Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
    ;Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    ;Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.

    StrCpy $didWeOutput "0"

    FileOpen  $IceWarpAdjustedFileHandle "$IceWarpInstallFolder\config\scanNEW.dat" w
    clearerrors
      IfFileExists "$IceWarpInstallFolder\config\scan.dat" 0 UnableToFindContentFileXML
      FileOpen $IceWarpContentFileHandle "$IceWarpInstallFolder\config\scan.dat" r
        iferrors 0 ReadContentLine
          MessageBox MB_OK "Unable to read IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat"
          Goto DoneReadingContentFile

      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${un.WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
                ; BUT we could be reading the last line, in which case, we need to output before we close the content filter tag...
                ${un.WordFind} $IceWarpContentXMLlinedata "</FILTERS>" "E+1}" $WordFindResults
                  ifErrors NotEndingYet 0 ; errors meant not in line...  If we found it, then drop through and handle trivial ending.  Otherwise drop through
                     ; this is the strip, so we're done now
                     StrCpy $didWeOutput "1"                                   ; we continue through and write the rest till EOF.
                     FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; close the XML validily.
                     Goto DoneReadingContentFile
                  NotEndingYet:  ; ok if its not the trivial ending, then output line, and go back for more.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.

          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${un.WordFind} $IceWarpContentXMLlinedata "<FILENAME>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and we're here, then if we find the title and it IS clamdscan then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${un.WordFind} $IceWarpContentXMLlinedata "SNFCLient.exe" "E+1}" $WordFindResults
                 ifErrors 0 FoundClamSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.

            FoundClamSection:
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${un.WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:

            ; Ok here is where we remove the Filter reference
            StrCpy $didWeOutput "1"        ; Now we continue through and write the rest till EOF.

            ; Ok from here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.

    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:  ; this means we don't need a header footer or anything.
        ; In this case, since we're stripping, $didWeOutput merely means have we satisified our conditions to end.
        StrCpy $didWeOutput "1"                                            ; footer.
        ;   fall through and close files up.

    ; we could jump to here from anywere.  If we needed to write it out in the middle, we would have done it.
    DoneReadingContentFile:   ; only the trivial EOF early would trip with no output.... so if thats the case

      StrCmp $didWeOutput "0" 0 SkipOutputThisTime  ; we need to dump it all in, headers and footers too, and then close.

      SkipOutputThisTime:
        ; potential for corrupted file if file ended with errors....

      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.

      ; Now swap out the files.
      #Var /GLOBAL  var1
      #Var /GLOBAL  var2
      #Var /GLOBAL  var3
      #Var /GLOBAL  var4
      #Var /GLOBAL  var5
      #Var /GLOBAL  var6
      #Var /GLOBAL  var7

      ${un.GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      ifFileExists "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml" 0 +2
        Delete "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scan.dat" "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scanNEW.dat" "$IceWarpInstallFolder\config\scan.dat"
      Return

    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$IceWarpInstallFolder\config\scanNew.dat"
      MessageBox MB_OK "Attempting to edit XML in: $IceWarpInstallFolder\config\scan.dat resulted in finding a corrupted construction.  Please check the new file, scan.dat, manually."
      Return

    UnableToFindContentFileXML:
      MessageBox MB_OK "Unable to find IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat  You will have to tie-in manually with IceWarp."
      Return

FunctionEnd


Function stripScanXML

  ; Subroutine that removes the XML to tie in Sniffer to the IceWarp merak\config\scan.dat file. ( As an AV filter )
  ; There are three situations.  First the file is empty, Second it doesn't have a SNFClient tag, but there are other filters, third it has a ClamAV tag.
    ;Var /GLOBAL WordFindResults
    ;Var /GLOBAL ContentXMLHeader
    ;Var /GLOBAL ContentXMLFooter
    ; Used for gettime functions.
    ;Var /GLOBAL var1
    ;Var /GLOBAL var2
    ;Var /GLOBAL var3
    ;Var /GLOBAL var4
    ;Var /GLOBAL var5
    ;Var /GLOBAL var6
    ;Var /GLOBAL var7
    ;Var /GLOBAL IceWarpInstallFolder

    
    StrCpy $IceWarpInstallFolder $SNFServerInstallDir ; set as source for file.... ( filter code was ported from the ClamAid Script )

    StrCpy $ContentXMLHeader '<FILTERS>$\r$\n' ; If nothing in file, when we need to write header and
    StrCpy $ContentXMLFooter "</FILTERS>$\r$\n"
                                                        ; footer.

    ;Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file. ALREADY DECLARED in un. function.
    ;Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
    ;Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
    ;Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    ;Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.

    StrCpy $didWeOutput "0"

    FileOpen  $IceWarpAdjustedFileHandle "$IceWarpInstallFolder\config\scanNEW.dat" w
    clearerrors
      IfFileExists "$IceWarpInstallFolder\config\scan.dat" 0 UnableToFindContentFileXML
      FileOpen $IceWarpContentFileHandle "$IceWarpInstallFolder\config\scan.dat" r
        iferrors 0 ReadContentLine
          MessageBox MB_OK "Unable to read IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat"
          Goto DoneReadingContentFile

      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
                ; BUT we could be reading the last line, in which case, we need to output before we close the content filter tag...
                ${WordFind} $IceWarpContentXMLlinedata "</FILTERS>" "E+1}" $WordFindResults
                  ifErrors NotEndingYet 0 ; errors meant not in line...  If we found it, then drop through and handle trivial ending.  Otherwise drop through
                     ; this is the strip, so we're done now
                     StrCpy $didWeOutput "1"                                   ; we continue through and write the rest till EOF.
                     FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; close the XML validily.
                     Goto DoneReadingContentFile
                  NotEndingYet:  ; ok if its not the trivial ending, then output line, and go back for more.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.

          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${WordFind} $IceWarpContentXMLlinedata "<FILENAME>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and we're here, then if we find the title and it IS clamdscan then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${WordFind} $IceWarpContentXMLlinedata "SNFCLient.exe" "E+1}" $WordFindResults
                 ifErrors 0 FoundSnifferSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.

            FoundSnifferSection:
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:

            ; Ok here is where we remove the Filter reference
            StrCpy $didWeOutput "1"        ; Now we continue through and write the rest till EOF.

            ; Ok from here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.

    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:  ; this means we don't need a header footer or anything.
        ; In this case, since we're stripping, $didWeOutput merely means have we satisified our conditions to end.
        StrCpy $didWeOutput "1"                                            ; footer.
        ;   fall through and close files up.

    ; we could jump to here from anywere.  If we needed to write it out in the middle, we would have done it.
    DoneReadingContentFile:   ; only the trivial EOF early would trip with no output.... so if thats the case

      StrCmp $didWeOutput "0" 0 SkipOutputThisTime  ; we need to dump it all in, headers and footers too, and then close.

      SkipOutputThisTime:
        ; potential for corrupted file if file ended with errors....

      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.

      ; Now swap out the files.
      #Var /GLOBAL  var1
      #Var /GLOBAL  var2
      #Var /GLOBAL  var3
      #Var /GLOBAL  var4
      #Var /GLOBAL  var5
      #Var /GLOBAL  var6
      #Var /GLOBAL  var7

      ${GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      ifFileExists "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml" 0 +2
        Delete "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scan.dat" "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scanNEW.dat" "$IceWarpInstallFolder\config\scan.dat"
      Return

    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$IceWarpInstallFolder\config\scanNew.dat"
      MessageBox MB_OK "Attempting to edit XML in: $IceWarpInstallFolder\config\scan.dat resulted in finding a corrupted construction.  Please check the new file, scan.dat, manually."
      Return

    UnableToFindContentFileXML:
      #MessageBox MB_OK "Unable to find IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat  You will have to tie-in manually with IceWarp."
      Return

FunctionEnd



Function editScanXML
  ; Subroutine that inserts the XML to tie in IceWarp to the IceWarp merak\config\scan.dat file as well as adjusting a couple line items in the ClamAV
  ; config file.

  ; We only want it installed in Icewarp one way at a time.
  call stripContentXML ; Remove the installation XML if it was put in place as a Content Filter.

  ; These are declared in the .UN version of the sub... globals cross the UN barrier.... functions don't... sigh.
  
  ; There are three situations.  First the file is empty, Second it doesn't have a ClamAV tag, but there are other filters, third it has a ClamAV tag.
    ;Var /GLOBAL WordFindResults
    ;Var /GLOBAL ContentXMLHeader
    ;Var /GLOBAL ContentXMLFooter
    Var /GLOBAL SnifferAVXMLContent
    ; Used for gettime functions.
    ;Var /GLOBAL var1
    ;Var /GLOBAL var2
    ;Var /GLOBAL var3
    ;Var /GLOBAL var4
    ;Var /GLOBAL var5
    ;Var /GLOBAL var6
    ;Var /GLOBAL var7
    ;Var /GLOBAL IceWarpInstallFolder

    
    StrCpy $IceWarpInstallFolder $SNFServerInstallDir ; set as source for file.... ( filter code was ported from the ClamAid Script )

    ;GetFullPathName /SHORT $localINSTDIR $INSTDIR ; for windows greeking. ; Seed with the default values.
    ${handleShortPath} $localINSTDIR $INSTDIR
    ;StrCpy $localINSTDIR $INSTDIR               ; Seed the default values.

    ; GetFullPathName /SHORT $IceWarpInstallFolder $SNFServerInstallDir ; for windows greeking. ; Seed with the default values.
    ${handleShortPath} $IceWarpInstallFolder $SNFServerInstallDir
    ;StrCpy $localSERVDIR $SNFServerInstallDir   ; Seed with the default values.



    StrCpy $ContentXMLHeader '<FILTERS>$\r$\n' ; If nothing in file, when we need to write header and
    StrCpy $ContentXMLFooter "</FILTERS>$\r$\n"
                                                        ; footer.
; Filter looks like this:
;   <FILTER>
;      <FILENAME>&quot;C:/Program Files/clamAV/clamdscan.exe&quot;</FILENAME>
;      <PARAMETERS>-l &quot;C:/Program Files/clamAv/log/mylog.log&quot;</PARAMETERS>
;      <RETURNVALUES>1</RETURNVALUES>
;      <DELETECHECK>0</DELETECHECK>
;      <EXECTYPE>0</EXECTYPE>
;   </FILTER>


            StrCpy $SnifferAVXMLContent "" ; Clear buffer.
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent<FILTER>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent  <FILENAME>&quot;$localINSTDIR\SNFClient.exe&quot;</FILENAME>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent  <PARAMETERS></PARAMETERS>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent  <RETURNVALUES>20,21,22,23,2,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70</RETURNVALUES>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent  <DELETECHECK>0</DELETECHECK>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent  <EXECTYPE>0</EXECTYPE>$\r$\n"
            StrCpy $SnifferAVXMLContent "$SnifferAVXMLContent</FILTER>$\r$\n"

    ;Var /GLOBAL IceWarpContentFileHandle ; handle to hold open read file. ALREADY DECLARED in un. function.
    ;Var /GLOBAL IceWarpAdjustedFileHandle ; new file.
    ;Var /GLOBAL TempFilterXML ; this hold a filter paragraph until we're sure we want to commit it....
    ;Var /GLOBAL didWeOutput ; flag for if we exited normally with output of XML or if we ended file strangely and terminated with no output.
    ;Var /GLOBAL IceWarpContentXMLlinedata ; read data, line by line.

    StrCpy $didWeOutput "0"

    FileOpen  $IceWarpAdjustedFileHandle "$IceWarpInstallFolder\config\scanNEW.dat" w
    clearerrors
      IfFileExists "$IceWarpInstallFolder\config\scan.dat" 0 DoneReadingContentFile
        #MessageBox MB_OK "Unable to find IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat  Creating New File."
      FileOpen $IceWarpContentFileHandle "$IceWarpInstallFolder\config\scan.dat" r
        iferrors 0 ReadForProperyHeaderedFilterFile
          #MessageBox MB_OK "Unable to read IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat"
          Goto DoneReadingContentFile

      ; You can have an empty file.  With no headers... so first we either spin through without finding a valid header opener... and then
      ; open and enter our own filter at the end... or we'll find one, and enter into the valid filter sections.
      ReadForProperyHeaderedFilterFile:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingEmptyFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<FILTERS>" "E+1}" $WordFindResults
               ifErrors 0 ProperlyHeaderedFile ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a CLAMAV FILTER... so we write the line to the new file.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadForProperyHeaderedFilterFile ; go back and get a newline to test.
      ProperlyHeaderedFile:
        ; dump header line.
        FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
        ; Sniffer goes in front of the AV filters.... for speed.
        FileWrite $IceWarpAdjustedFileHandle $SnifferAVXMLContent ; and because this is a properly wrapped file, and there may be more filters after us.
        StrCpy $didWeOutput "1"                                 ; we continue through and write the rest till EOF.


      ;Ok, Next line SHOULD be FILTER object.... spin till we get one...
      ReadContentLine:
        FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
          ifErrors DoneReadingContentFile 0
            ${WordFind} $IceWarpContentXMLlinedata "<FILTER>" "E+1}" $WordFindResults
               ifErrors 0 FoundFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
               ; if were here and we're reading lines, then we're not in a SNIFFER FILTER... so we write the line to the new file.
                ; BUT we could be reading the last line, in which case, we need to output before we close the content filter tag...
                ${WordFind} $IceWarpContentXMLlinedata "</FILTERS>" "E+1}" $WordFindResults
                  ifErrors NotEndingYet 0 ; errors meant not in line...  If we found it, then drop through and handle trivial ending.  Otherwise drop through
                     FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; close the XML validily.
                     Goto DoneReadingContentFile
                  NotEndingYet:  ; ok if its not the trivial ending, then output line, and go back for more.
               FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump line to the new file.
            Goto ReadContentLine ; go back and get a newline to test.
        FoundFilterMarker:
          ; Ok, we're here at a filter header, so its either the SNIFFER FILTER, or its not... so we write to a temp var till we read the title...
          ; because the filter section has a couple lines ahead of the title tag... active y/n etc.... so we need to trap that till we get to
          ; something distinctive.

          StrCpy $TempFilterXML $IceWarpContentXMLlinedata
          LookForTitle:
            FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
            ifErrors DoneReadingContentFile 0
              ${WordFind} $IceWarpContentXMLlinedata "<FILENAME>" "E+1}" $WordFindResults
               ifErrors 0 FoundTitleMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                 StrCpy $TempFilterXML "$TempFilterXML$IceWarpContentXMLlinedata" ; not in line, add to temp buffer.
               Goto LookForTitle ; go back and get a newline to that might hold the title.
            FoundTitleMarker:
              ; Ok, if we popped out and we're here, then if we find the title and it IS clamdscan then we dont' write, and we loop to the next </FILTER>
              ; but if we're NOT sniffer.... then we write the temp string and pop out and continue looping at the top.
              ${WordFind} $IceWarpContentXMLlinedata "SNFClient.exe" "E+1}" $WordFindResults
                 ifErrors 0 FoundSnifferSection ; errors meant not in line...  If we found it, then go to found-handle.  Otherwise drop through
                   FileWrite $IceWarpAdjustedFileHandle $TempFilterXML ; Ok, we're not in a sniffer section, so dump the buffer
                   FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                  StrCpy $TempFilterXML "" ; clear the buffer.
                  Goto ReadContentLine ; pop out and look for the next filter tag.

            FoundSnifferSection: ; consume an existing sniffer section.
              ; if this is the case, we loop till we find the </FILTER> and then we insert the new sniffer code.
              LookForCloseFilter:
                FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata
                ifErrors DoneReadingContentFileWithErrors 0  ; if we exit here output is NOT done... and it probably means an error.
                  ${WordFind} $IceWarpContentXMLlinedata "</FILTER>" "E+1}" $WordFindResults
                  ifErrors 0 FoundCloseFilterMarker ; errors meant not in line...  If we found it, then go to handle.  Otherwise drop through
                  Goto LookForCloseFilter ; go back and get a newline to that might hold the title.
              FoundCloseFilterMarker:

            ; Dont output here cause we put it in front.
            
            ; Ok from here on, we dump it all to the file.
            ContinueDumpingFileLines:
              FileRead  $IceWarpContentFileHandle $IceWarpContentXMLlinedata  ;Grap new line.
              ifErrors DoneReadingContentFile 0                               ; if not EOF then exit with output true.  We're good and done.
                FileWrite $IceWarpAdjustedFileHandle $IceWarpContentXMLlinedata ; dump the current line...
                Goto ContinueDumpingFileLines                                 ; and go back for more.

    ; If were here then we called from the first loop section where we were checking for <CONTENTFILTER>
    DoneReadingEmptyFile:  ; this means we head, fill and footer the file ourselves.
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLHeader ; If nothing in file, when we need to write header and
        FileWrite $IceWarpAdjustedFileHandle $SnifferAVXMLContent
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLFooter ; and footer
        StrCpy $didWeOutput "1"                                            ; footer.
        ;   fall through and close files up.

    ; we could jump to here from anywere.  If we needed to write it out in the middle, we would have done it.
    DoneReadingContentFile:   ; only the trivial EOF early would trip with no output.... so if thats the case

      StrCmp $didWeOutput "0" 0 SkipOutputThisTime  ; we need to dump it all in, headers and footers too, and then close.

        FileWrite $IceWarpAdjustedFileHandle $ContentXMLHeader ; If nothing in file, when we need to write header and
        FileWrite $IceWarpAdjustedFileHandle $SnifferAVXMLContent
        FileWrite $IceWarpAdjustedFileHandle $ContentXMLFooter ; and footer ; if we didn't have a chance, then we output here.
        SkipOutputThisTime:
        ; potential for corrupted file if file ended with errors....

      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      StrCpy $IceWarpContentXMLlinedata "" ; Clear line data.

      ; Now swap out the files.
      #Var /GLOBAL  var1
      #Var /GLOBAL  var2
      #Var /GLOBAL  var3
      #Var /GLOBAL  var4
      #Var /GLOBAL  var5
      #Var /GLOBAL  var6
      #Var /GLOBAL  var7

      ${GetTime} "" "L" $var1 $var2 $var3 $var4 $var5 $var6 $var7
      ifFileExists "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml" 0 +2
        Delete "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scan.dat" "$IceWarpInstallFolder\config\scandat_InstallLOG_$var1-$var2-$var4.xml"
      Rename "$IceWarpInstallFolder\config\scanNEW.dat" "$IceWarpInstallFolder\config\scan.dat"
      Return

    DoneReadingContentFileWithErrors:
      FileClose $IceWarpContentFileHandle ; Close file.
      FileClose $IceWarpAdjustedFileHandle ; Close file.
      Delete "$IceWarpInstallFolder\config\scanNew.dat"
      MessageBox MB_OK "Attempting to edit XML in: $IceWarpInstallFolder\config\scan.dat resulted in finding a corrupted construction.  Please check the new file, scan.dat, manually."
      Return

    UnableToFindContentFileXML:
      MessageBox MB_OK "Unable to find IceWarps scan.dat file from: $IceWarpInstallFolder\config\scan.dat  You will have to tie-in manually with IceWarp."
      Return

FunctionEND  ; end IceWarp scan.dat file edit.





#############################
##  SNIFFER's Config file. ######################################################################################################
##  This function doubles as an editor for the MDaemon's config file editor as well. Since this editor doesn't concern itself  ##
## with most of the other features.
Function editXMLConfig

  ; Var /GLOBAL ShortPathTempVar ; Defined earier.  ; use this to hold the Short Windows Progr~1 path references...
  ;GetFullPathName /SHORT $ShortPathTempVar $INSTDIR
  ${handleShortPath} $ShortPathTempVar $INSTDIR
   
  ## MDaemon patch adjustment.  The snfmdplugin.xml file is the same file, except for some initial settings.  We can use the same edit code
  ## for both files.  Use the filename switch here.
  Var /GLOBAL ConfigFileName ; We're using a switch to double the snfengine edit code to handle the snfmdplugin.xml code as well.

  StrCpy $ConfigFileName "snf_engine.xml"
  ifFileExists "$INSTDIR\snfmdplugin.xml" 0 +2
    StrCpy $ConfigFileName "snfmdplugin.xml"
  ## End MDaemon filename switch.
  
          ${GetBetween} "<node identity='" "'>" "$INSTDIR\$ConfigFileName" "$R0"  ; This makes it not brittly dependant on the default value. i.e. It would
          !insertmacro ReplaceInFile "$INSTDIR\$ConfigFileName" "<node identity='$R0'>" "<node identity='$ShortPathTempVar\identity.xml'>"
            ClearErrors
                        
          ${GetBetween} "<log path='" "'/>" "$INSTDIR\$ConfigFileName" "$R0"  ; This makes it not brittly dependant on the default value.
          !insertmacro ReplaceInFile "$INSTDIR\$ConfigFileName" "<log path='$R0'/>" "<log path='$ShortPathTempVar\'/>"
            ClearErrors
          ${GetBetween} "<rulebase path='" "'/>" "$INSTDIR\$ConfigFileName" "$R0"  ; This makes it not brittly dependant on the default value.
          !insertmacro ReplaceInFile "$INSTDIR\$ConfigFileName" "<rulebase path='$R0'/>" "<rulebase path='$ShortPathTempVar\'/>"
            ClearErrors
          ${GetBetween} "<workspace path='" "'/>" "$INSTDIR\$ConfigFileName" "$R0"  ; This makes it not brittly dependant on the default value.
          !insertmacro ReplaceInFile "$INSTDIR\$ConfigFileName" "<workspace path='$R0'/>" "<workspace path='$ShortPathTempVar\'/>"
            ClearErrors
            
          ; Now we gotta cut this out to work with it in order to have referential integrity.  ( there are other tags named the same thing.... above the network block)
          ${GetBetween} "<network>" "</network>" "$INSTDIR\$ConfigFileName" "$R0"  ; This makes it not brittly dependant on the default value.
            FileOpen $R1 "tempNetworkFile.txt" w
            FileWrite $R1 $R0
            FileClose $R1
            
            ${GetBetween} "<update-script on-off='" "'" "$INSTDIR\tempNetworkFile.txt" "$R4"  ; This makes it not brittly dependant on the default value.
            StrCmp $R4 "" OutputEntireString 0 ; If $R0 returns empty in this instance, it means that the feature wasn't there in
                                               ; this file version.  So jump to the default and write the line.

            ; Ok we need to determine if we are keeping the older setting of the auto on-off flag. Or if we are installing it fresh as default on or default off.
            ; if you are using the update with existing settings, then the default for $AUTO_UPDATE_ONOFF_FLAG is off ( Set in the Section function prio to calling this sub )
            ; leaving an install that didn't have these features installed previously, left to use their own mechanisms.
            ; but if it was a fresh install, then it defaults to on.  So if the line doesn't exist, then we just write the default line, and its either
            ; fresh and on, or an update and off.  But if the line does exist, then we need to trap the value in $R4 and use that one.....
            
            ${GetBetween} "<update-script" "/>" "$INSTDIR\tempNetworkFile.txt" "$R0"  ; This makes it not brittly dependant on the default value.
            StrCmp $R0 "" OutputEntireString 0 ; If $R0 returns empty in this instance, it means that the feature wasn't there in
                                               ; this file version.  So jump to the default and write the line.

              StrCpy $R6 "<update-script on-off='$R4' call='$ShortPathTempVar\getRulebase.cmd' guard-time='180'/>" ; R6 holds the new PUT value....
              
              ; Typical update script looks like:
              ; <update-script on-off='on' call='/MDaemon/$FolderPrefix/getRulebase.cmd' guard-time='180'/>
              !insertmacro ReplaceInFile "$INSTDIR\$ConfigFileName" "<update-script$R0/>" "$R6"
              ClearErrors
              Delete  "$INSTDIR\tempNetworkFile.txt"
              Return
            OutputEntireString: ; This handles if there was an empty search returned from searching for updateScript.

              StrCpy $R6 "<update-script on-off='$AUTO_UPDATE_ONOFF_FLAG' call='$ShortPathTempVar\getRulebase.cmd' guard-time='180'/>"
              ; Typical update script looks like:
              ; <update-script on-off='on' call='/MDaemon/$FolderPrefix/getRulebase.cmd' guard-time='180'/>
                ; !insertmacro ReplaceInFile "$SNFServerInstallDir\$FolderPrefix\snfmdplugin.xml" "</network>" "$R6$\r$\n</network>"
                ; ClearErrors
                Push "</network>" #text to be replaced
                Push "$R6$\r$\n</network>" #replace with
                Push 0 #replace command
                Push 1 #replace but only one occurance.. not all close network references....
                Push "$INSTDIR\$ConfigFileName" #file to replace in
                Call AdvReplaceInFile ;; it reads the pushed variables as parameters.... ( Hey... I didn't design that interface... its confusing. )

              Delete  "$INSTDIR\tempNetworkFile.txt"
              Return
FunctionEnd





Function .onInit

  ############################ Semifor Code ###################
  # Ensure we only run one instance.
  System::Call 'kernel32::CreateMutexA(i 0, i 0, t "Message Sniffer") i .r1 ?e'
    Pop $R0
    StrCmp $R0 0 +3
    MessageBox MB_OK|MB_ICONEXCLAMATION "The Message Sniffer installer is already running."
    Abort
  ############################ Semifor Code ###################


  ; The master installer .exe should create a LocalRoot.txt file that indicates where the localroot of the mailserver is located.  
  ; To save us the trouble of finding it again.
  ; Now identify the folder that we're in and get the local root.....
  IfFileExists "$EXEDIR\LocalRoot.txt" 0 EndGracefully
    ${GetBetween} '<root>' '</root>' "$EXEDIR\LocalRoot.txt" $SNFServerInstallDir  ; if it was unpacked by the Installer than the file is there
    ${GetBetween} '<cd>' '</cd>' "$EXEDIR\LocalRoot.txt" $INSTDIR  ; if it was unpacked by the Installer than the file is there
    Goto ContinueInstall
       
    EndGracefully:
       MessageBox MB_OK "Unable to resolve the local root installation directory for the mail server.  Ending Installer."
       Quit

    ContinueInstall:
    
    ################################################ Variable Initialization Phase ########################################################
    ##
    ##
    #######################################################################################################################################

    ; If possible, retrieve the license info from an this folder, the rollback folder or an old archived path.  Not essential, but nice if we can.
    ; Read the most recent archived snapshot path

    IfFileExists "$INSTDIR\identity.xml" 0 TryAgain2
      ${GetBetween} "licenseid='" "'" "$INSTDIR\identity.xml" $LicenseID
      ${GetBetween} "authentication='" "'" "$INSTDIR\identity.xml" $Authentication
      Goto MakeNew
    TryAgain2:

    IfFileExists "$SNFServerInstallDir\SNFRollback\identity.xml" 0 MakeNew
      ${GetBetween} "licenseid='" "'" "$SNFServerInstallDir\SNFRollback\identity.xml" $LicenseID
      ${GetBetween} "authentication='" "'" "$SNFServerInstallDir\SNFRollback\identity.xml" $Authentication

   MakeNew:    ; The system did not detect an older install or we've moved the existing one or we've chosen to install in an entirely differnt place..
               ; So we will proceed with fresh folder creation.

     ## Variable initilization for some flags.
     StrCpy $UnpackedCURLStuff "0" ; set for first time.
     StrCpy $InstallerCompletedRestore "0" ; Initialize variables to default false.
     StrCpy $DownloadFailed "0"  ; $DownloadFailed This Variable declared in ONinit and defaulted to "0" for use in the RulebaseDownload screens.

     ################# Some Pre-Rollback housekeeping. #################################
     ## Grabbing copy of current settings, before forced rollback occurs.
     ## Remember, that if we CAN rollback, we must rollback to ground zero.  Hence the need to grab a copy of the existing files
     ## before rollback.
     
        ; This paragraph determines if we passed the FreshInstall flag (/F) to the installer to confirm
        ; the desire to ignore the existing configuration.
        ${GetOptions} $CommandLineParameters "-F" $R0
        
        IfErrors  RetainExistingConfig IgnoreExistingConfig
        	RetainExistingConfig:
                  StrCpy $RetainExistingSettings "1"
                  
                  ifFileExists "$INSTDIR\snfmdplugin.xml" 0 +2                             ; Both MDaemons xml, and SNFServer's xml files need to
                    CopyFiles /SILENT "$INSTDIR\snfmdplugin.xml" "$TEMP\snfmdplugin.xml"   ; be captured before we stomp them with an older install
                                                                                           ; if a previous install existed.
                  ifFileExists "$INSTDIR\snf_engine.xml" 0 Defaults                        ; If we need to do this, swap a copy over to temp
                    CopyFiles /SILENT "$INSTDIR\snf_engine.xml" "$TEMP\snf_engine.xml"     ; before we rollback, so we can restore it....
                  ;MessageBox MB_OK "Retaining"
        	Goto Defaults
        	
                IgnoreExistingConfig:
                StrCpy $RetainExistingSettings "0"

        Defaults:
        ;MessageBox MB_OK "Retaining settings:$RetainExistingSettings"


    #######################################################################################################################################
    ## We're installing.  Therefore if there is an existing rollback file, run it.
    #######################################################################################################################################

               ## BlockFullUninstall is the flag for determining if there was an existing manual install
               ## If we have this flag, then the uninstaller will never be allowed to
               ## remove the install completely.  
               
    Var /GLOBAL localSRS_RollbackPath
    ReadRegStr $localSRS_RollbackPath HKLM "Software\MessageSniffer" "SRS_RollbackPath"
               ifErrors 0 SkipBlocking  ; So only on teh condition that an installer hasn't run, do we consider blocking.
                 ifFileExists "$INSTDIR\snf2check.exe" 0 +2
                   WriteRegStr HKLM "Software\MessageSniffer" "BlockFullUninstall" "1"
                 ifFileExists "$INSTDIR\mingwm10.dll" 0 +2
                   WriteRegStr HKLM "Software\MessageSniffer" "BlockFullUninstall" "1"
                 ifFileExists "$INSTDIR\SNFClient.exe" 0 +2
                   WriteRegStr HKLM "Software\MessageSniffer" "BlockFullUninstall" "1" ; FULL Uninstall Prempted.
               SkipBlocking:

                ; We decided that we will always run an available rollback.
    ReadRegStr $1 HKLM "Software\MessageSniffer" "SRS_LogName"
    # If none of these trip, we'll presume safe.
    StrCmp $localSRS_RollbackPath "" NoPreRoll 0  ; so exit if no rollback file.
    StrCmp $1 "" NoPreRoll 0  ; and no log.....
    
    ## IF there are ANY valid rollback scenarios we are going to execute them prior to running a new install.
    ## Before we let the rollback put things back... presuming we have a service installed, we'll need to stop it....
    Call stopSNFServer ; if it there it will stop it.
    Call stopXYNTService ; if its there, stop it.
    
    ## IN the possible scenarior that we are uninstalling and rolling back a previous install when we are installing a seperate platform..
    ## Pull in the reg key from the old system:
    Var /GLOBAL OLD_INSTALL_DIR ; possible old , but if its the same (current) install folder, its ok.... it will still be functional.
    ReadRegStr $OLD_INSTALL_DIR HKLM "Software\MessageSniffer" "Install_Dir"
    ## Use that folder to trip the uninstall of XYNTService to enable the rollback.... ( The reason for this is that the NEW InstallDIR could be
    ## different because of the LocalRoot.txt file coming from the users selection of a different platform... i.e. The $INSTDIR is where its GOING
    ## not where the registry said it WAS......
    IfFileExists "$OLD_INSTALL_DIR\XYNTService.exe" 0 +2
      nsExec::Exec "$OLD_INSTALL_DIR\XYNTService -u" "" SH_HIDE ; uninstall it if it exists....
    ## Now we should be ready to fire... even if its over the bow, to an older platform...
    
      ## ADDING sensitivity to the functions being called to enable them to look up the proper path values in the event that the
      ## rollback sequence is not in the current INSTDIR and $SNFServerInstallDir locations.  i.e. Those parsing functions need to be able
      ## to find the correct file to be editing.  If its rolling back an older version cross platform, then it needs to redefine the file its
      ## targeting, not just assume that its in the INSTDIR or the $SNFServerInstallDir.  I added two registry keys to the EndRollbackSequence
      ## subroutine called SRS_INSTDIR and SRS_SERVDIR to cover the lookup during rollback....since by this point INSTDIR is defined,
      ## just having SRS_INSTDIR different from INSTDIR should be enough key to use the SRS_INSTDIR.... and if the SRS_INSTDIR doesnt' exist,
      ## ( because it wouldn't be entered until the end of the rollback sequence, then the functions will know they are in the new install, and
      ## will use the current INSTDIR as their paths.....

      ## Get this before its rolled back and gone.
      Var /GLOBAL localSRS_INSTDIR
      Var /GLOBAL localSRS_SERVDIR
      ReadRegStr $localSRS_INSTDIR HKLM "Software\MessageSniffer" "SRS_INSTDIR"
      ReadRegStr $localSRS_SERVDIR HKLM "Software\MessageSniffer" "localSRS_SERVDIR"

      ${RollBackTo} $localSRS_RollbackPath $1 ; Put all the files back the way they were. ; Both those values come from registry....
      RMDir /r $localSRS_RollbackPath

      ## Finish cleanup.
      ## IF there is no SNFServer.exe there should be nothing else
      ifFileExists "$localSRS_INSTDIR\SNFClient.exe" SkipNow 0 ; otherwise cleanup.
          ifFileExists "$localSRS_INSTDIR\Restorer.exe" 0 +2
            Delete "$localSRS_INSTDIR\Restorer.exe"
          ifFileExists "$localSRS_INSTDIR\oldsnifferversion.txt" 0 +2
            Delete "$localSRS_INSTDIR\oldsnifferversion.txt"
          ifFileExists "$localSRS_INSTDIR\getRulebase.cmd.old" 0 +2
            Delete "$localSRS_INSTDIR\getRulebase.cmd.old"
          ifFileExists "$localSRS_INSTDIR\shortcuts.xml" 0 +2
            Delete "$localSRS_INSTDIR\shortcuts.xml" ; if exists ; Find other location
          ifFileExists "$localSRS_INSTDIR\cfgstring.xml" 0 +2
            Delete "$localSRS_INSTDIR\cfgstring.xml" ; if exists ; Find other location
          ifFileExists "$localSRS_INSTDIR\XYNTService.ini" 0 +2
            Delete "$localSRS_INSTDIR\XYNTService.ini"
          ifFileExists "$localSRS_INSTDIR\LocalRoot.txt" 0 +2
            Delete "$localSRS_INSTDIR\LocalRoot.txt"
          ifFileExists "$localSRS_INSTDIR\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"  0 +2
            Delete "$localSRS_INSTDIR\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"
          ifFileExists "$localSRS_INSTDIR\UpdateReady.txt"  0 +2
            Delete "$localSRS_INSTDIR\UpdateReady.txt"
          ifFileExists "$localSRS_INSTDIR\mingwm10.dll"  0 +2
            Delete "$localSRS_INSTDIR\mingwm10.dll"
          Delete "$localSRS_INSTDIR\uninstall.exe"
          ; since we couldn't edit the registry, we don't need to worry abou tit. Now Kill attempt:
          
        ## For MINMI
           ifFileExists "$localSRS_SERVDIR\SNFIMailShimNEW.xml" 0 +2
              Delete "$localSRS_SERVDIR\SNFIMailShimNEW.xml"
           ifFileExists "$localSRS_SERVDIR\SNFIMailShim.xml" 0 +2
              Delete "$localSRS_SERVDIR\SNFIMailShim.xml"
            ifFileExists "$localSRS_SERVDIR\SNFIMailShim.exe" 0 +2
              Delete "$localSRS_SERVDIR\SNFIMailShim.exe"
            ifFileExists "$localSRS_SERVDIR\MIMIMIreadme.txt" 0 +2
              Delete "$localSRS_SERVDIR\MIMIMIreadme.txt"
            ifFileExists "$localSRS_SERVDIR\OLD_SNFIMailShim.exe" 0 +2
              Delete "$localSRS_SERVDIR\OLD_SNFIMailShim.exe"
            ifFileExists "$localSRS_SERVDIR\OLD_SNFIMailShim.xml" 0 +2
              Delete "$localSRS_SERVDIR\OLD_SNFIMailShim.xml"
          ## For MDaemon
            ifFileExists "$localSRS_SERVDIR\snfmdplugin.dll" 0 +2
              Delete "$localSRS_SERVDIR\snfmdplugin.dll"
            ifFileExists "$localSRS_SERVDIR\snfmdplugin.xml" 0 +2
              Delete "$localSRS_SERVDIR\snfmdplugin.xml"


          ;ifFileExists "$localSRS_SERVDIR\OLD_SNFIMailShim.xml" 0 +2 ; if we find the xml file, then we need to do checking...
          ;  Rename "$localSRS_SERVDIR\OLD_SNFIMailShim.xml" "$localSRS_SERVDIR\SNFIMailShim.xml"

          ;ifFileExists "$localSRS_SERVDIR\OLD_SNFIMailShim.exe" 0 +2 ; if we find the xml file, then we need to do checking...
          ;  Rename "$localSRS_SERVDIR\OLD_SNFIMailShim.exe" "$localSRS_SERVDIR\SNFIMailShim.exe"

              
      SkipNow:
      
      ;MessageBox MB_OK "Breaking"
      Goto NoPreRoll
      
    NoPreRoll:
;MessageBox MB_OK "Starting Rollback Transaction"
    ################################################ Start Rollback.nsh ###################################################################
    ## A Install requires a rollback build.
    ##
    ## First define the rollback folder:
    !insertmacro StartRollbackSession "$SNFServerInstallDir\SNFRollBack" "Archive_rllbck.log" "HKLM" "Software\MessageSniffer" ; _ArchivePath _LogName
    ## Registry USAGE:  $SetRegistry_with_RollbackControl "HKLM" "Software\MessageSniffer" "RollbackSequence" "0121"
    ##     File USAGE:  ${Install_with_RollbackControl} "License.txt" ""
    ##     !insertmacro StartRollbackSession     - Starts the rollback session to begin recording file and registry data.
    ##     !insertmacro EndRollbackSession        - closes the rollback session
    ##     ${SetRegistry_with_RollbackControl} _RootKey _RegistryKey _SubKey _Value   - Records a registry change for rollback.
    ##     ${Install_with_RollbackControl} _someFileName _onFailCommand               - Installs a file with archival of old file for rollback.
    ##     ${Copy_with_RollbackControl} _someFile _Path _onFailCommand                - Makes a copy of an existing file and records it in log for rollback.
    ##     ${RollBackTo} _rollbackLocalPath _rollbackLogName                          - Runs the parser through the rollback log and puts everything back.
    #################################################################################################################


  ; Set output path to the installation directory.
  SetOutPath $INSTDIR 
  
  ; Write the installation path into the registry
  ; WriteRegStr HKLM Software\MessageSniffer "Install_Dir" "$SNFServerInstallDir\$FolderPrefix"
  ${SetRegistry_with_RollbackControl} "HKLM" "Software\MessageSniffer" "Install_Dir" "$INSTDIR"
  ${SetRegistry_with_RollbackControl} "HKLM" "Software\MessageSniffer" "SNFMailServer_DIR" "$SNFServerInstallDir"


## Prime doesn't matter anymore because we will ALWAYS run an existing rollback file, thus ensuring that the only way a
## last working install is available is if the user had one installed manually.
;ReadRegStr $2 HKLM "Software\MessageSniffer" "Prime"
;${IF} $2 = "1"
;  ${SetRegistry_with_RollbackControl} "HKLM" "Software\MessageSniffer" "Prime" "0"
;${ELSE}
;  ${SetRegistry_with_RollbackControl} "HKLM" "Software\MessageSniffer" "Prime" "1"
;${ENDIF}

  ; Also... if the OLD install... ( if there was one.... ) had the shortcuts installed... and they didnt' call for them here....
  ; then we need to remove them... ( and if they want them, they'll be put back when that section fire.s
  ; but if they WERE installed... we need to put it back on a rollback....
  ifFileExists "$INSTDIR\shortcuts.xml" 0 SkipShortCutRollback
    ${Copy_with_RollbackControl} "shortcuts.xml" "$INSTDIR" "" "" ; Copy the old Server.exe
  SkipShortCutRollback:

  Call removeShortcuts ; This will be reinstalled with the shortcuts pointing at the newer files, in the Section reguarding shortcuts anyway...
  Return



  ###############################################################  ROLLBACK CODE ############################################################
  ## Handled by th $rollback macro in Rollback.nsh.
  PerformRollback:
    ;MessageBox MB_OK "Stubbed Code."
    return

    ; Before we let the rollback put things back... presuming we have a service installed, we'll need to stop it....
    Call stopSNFServer ; if it there it will stop it.
    Call stopXYNTService ; if its there, stop it.
    
    ; Since this is not being executed from the SNF directory, we are not put here by the master utility for a fresh
    ; install.  Instead, we are being called remotely ( or by a click...) from an archived directory.  It dosn't really mater
    ; where the archive is, but it ususally will be in [SomeMailInstalDirectory]\SNFArchive\[WheteverDirName]
    ; So the first thing is to empty the SNF Directory.
    ${RollBackTo} "$SNFServerInstallDir\SNFRollBack" "Archive_rllbck.log" ; Put all the files back the way they were.
    ; This simplified all the following code, because files that were NOT there on install are deleted, files that were are replaced to their original format
    ; and files that weren't touched remain there.....


    ## Won't need to do this cause we're not yanking the rulebase....
    ##; We'll need the LicenseID in order to search and save the rulebase file if it exists.
    ##${GetBetween} "licenseid='" "'" "$EXEDIR\identity.xml" $LicenseID ; This makes it not brittly dependant on the default value. i.e. It would
    ##${GetBetween} "authentication='" "'" "$EXEDIR\identity.xml" $Authentication

    ## INTENTIONALLY HARD TYPED.... reguardless of the target folder.
    ##IfFileExists "$SNFServerInstallDir\SNF\$LicenseID.snf" 0 +2
    ##  Rename "$SNFServerInstallDir\SNF\$LicenseID.snf" "$SNFServerInstallDir\$LicenseID.snf" ; Move the existing rulebase out of the SNF directory.
    ##IfFileExists "$SNFServerInstallDir\Sniffer\$LicenseID.snf" 0 +2
    ##  Rename "$SNFServerInstallDir\Sniffer\$LicenseID.snf" "$SNFServerInstallDir\$LicenseID.snf" ; Move the existing rulebase out of the SNF directory.

    # Reguardless of $FolderPrefix, kill these existing folders.
    ##IfFileExists "$SNFServerInstallDir\SNF\*.*" 0 DoSniffer
    ##  Delete "$SNFServerInstallDir\SNF\*.*" ; Kill all files in the SNF Dir.  INTENTIONALLY HARD TYPED.....
    ##  RMDir  "$SNFServerInstallDir\SNF"
    ##DoSniffer:
    ##  IfFileExists "$SNFServerInstallDir\Sniffer\*.*" 0 +3
    ##  Delete "$SNFServerInstallDir\Sniffer\*"  ; Kill all files in the sniffer Dir.  INTENTIONALLY HARD TYPED.....
    ##  RMDir  "$SNFServerInstallDir\Sniffer"

    ##CreateDirectory "$SNFServerInstallDir\$FolderPrefix"  ;Recreates target folder.  Sniffer and SNF safe...

    ##IfFileExists "$SNFServerInstallDir\$LicenseID.snf" 0 +2
    ##  Rename "$SNFServerInstallDir\$LicenseID.snf" "$SNFServerInstallDir\$FolderPrefix\$LicenseID.snf" ; Move the existing rulebase back into the SNF directory.

  ## This is handled by teh rollback function....
  ##; Now expressly copy all files to the SNF folder.
  ##;MessageBox MB_OK "Restoring"
  ##        CopyFiles /SILENT "$EXEDIR\About-Wget-and-Gzip.txt" "$SNFServerInstallDir\$FolderPrefix\About-Wget-and-Gzip.txt"
  ##        CopyFiles /SILENT "$EXEDIR\AuthenticationProtocol.swf" "$SNFServerInstallDir\$FolderPrefix\AuthenticationProtocol.swf"
  ##        CopyFiles /SILENT "$EXEDIR\Archiver.exe" "$SNFServerInstallDir\$FolderPrefix\Archiver.exe"
  ##        CopyFiles /SILENT "$EXEDIR\ChangeLog.txt" "$SNFServerInstallDir\$FolderPrefix\ChangeLog.txt"
  ##        CopyFiles /SILENT "$EXEDIR\exchndl.dll" "$SNFServerInstallDir\$FolderPrefix\exchndl.dll"
  ##        CopyFiles /SILENT "$EXEDIR\GBUdbIgnoreList.txt" "$SNFServerInstallDir\$FolderPrefix\GBUdbIgnoreList.txt"
  ##        CopyFiles /SILENT "$EXEDIR\getRulebase.cmd" "$SNFServerInstallDir\$FolderPrefix\getRulebase.cmd"
  ##        CopyFiles /SILENT "$EXEDIR\gzip.exe" "$SNFServerInstallDir\$FolderPrefix\gzip.exe"
  ##        CopyFiles /SILENT "$EXEDIR\identity.xml" "$SNFServerInstallDir\$FolderPrefix\identity.xml"
  ##        CopyFiles /SILENT "$EXEDIR\License.txt" "$SNFServerInstallDir\$FolderPrefix\License.txt"
  ##        CopyFiles /SILENT "$EXEDIR\LocalRoot.txt" "$SNFServerInstallDir\$FolderPrefix\LocalRoot.txt"
  ##        CopyFiles /SILENT "$EXEDIR\mingwm10.dll" "$SNFServerInstallDir\$FolderPrefix\mingwm10.dll"
  ##        CopyFiles /SILENT "$EXEDIR\Restorer.exe" "$SNFServerInstallDir\$FolderPrefix\Restorer.exe"
  ##        CopyFiles /SILENT "$EXEDIR\send_shutdown.cmd" "$SNFServerInstallDir\$FolderPrefix\send_shutdown.cmd"
  ##        CopyFiles /SILENT "$EXEDIR\snf2check.exe" "$SNFServerInstallDir\$FolderPrefix\snf2check.exe"
  ##        CopyFiles /SILENT "$EXEDIR\snf_engine.xml" "$SNFServerInstallDir\$FolderPrefix\snf_engine.xml"
  ##        CopyFiles /SILENT "$EXEDIR\snf_xci.xml" "$SNFServerInstallDir\$FolderPrefix\snf_xci.xml"
  ##        CopyFiles /SILENT "$EXEDIR\SNFClient.exe" "$SNFServerInstallDir\$FolderPrefix\SNFClient.exe"
  ##        CopyFiles /SILENT "$EXEDIR\SNFClient_readme.txt" "$SNFServerInstallDir\$FolderPrefix\SNFClient_readme.txt"
  ##        CopyFiles /SILENT "$EXEDIR\SNFServer_readme.txt" "$SNFServerInstallDir\$FolderPrefix\SNFServer_readme.txt"

  ##        IFFileExists "$EXEDIR\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe" 0 +2
  ##        CopyFiles /SILENT "$EXEDIR\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe" "$SNFServerInstallDir\$FolderPrefix\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"
  ##        IFFileExists "$EXEDIR\SNFServer.exe" 0 +2
  ##          CopyFiles /SILENT "$EXEDIR\SNFServer.exe" "$SNFServerInstallDir\$FolderPrefix\SNFServer.exe"
  ##        IFFileExists "$EXEDIR\$LicenseID.exe" 0 +2
  ##          CopyFiles /SILENT "$EXEDIR\$LicenseID.exe" "$SNFServerInstallDir\$FolderPrefix\$LicenseID.exe"

  ##        CopyFiles /SILENT "$EXEDIR\wget.exe" "$SNFServerInstallDir\$FolderPrefix\wget.exe"
  ##        CopyFiles /SILENT "$EXEDIR\XYNTService.exe" "$SNFServerInstallDir\$FolderPrefix\XYNTService.exe"
  ##        CopyFiles /SILENT "$EXEDIR\XYNTService.ini" "$SNFServerInstallDir\$FolderPrefix\XYNTService.ini"
  ##        CopyFiles /SILENT "$EXEDIR\XYNTServiceReadMe.txt" "$SNFServerInstallDir\$FolderPrefix\XYNTServiceReadMe.txt"
  ##        IFFileExists "$EXEDIR\uninstall.bckup" 0 +2
  ##          CopyFiles /SILENT "$EXEDIR\uninstall.bckup" "$SNFServerInstallDir\$FolderPrefix\uninstall.exe"
  ##        IfFileExists "$EXEDIR\cfgstring.xml" 0 +2 ; this is used to restore the global.cfg entry line.  it gets consumed as its mined.
  ##          CopyFiles /SILENT "$EXEDIR\cfgstring.xml" "$SNFServerInstallDir\$FolderPrefix\cfgstring.xml"

 ##########################
 ## ; Write the installation path into the registry
 ## WriteRegStr HKLM Software\MessageSniffer "Install_Dir" "$SNFServerInstallDir\$FolderPrefix"

 ##########################
 ##; Declude Special
 ##ifFileExists "$SNFServerInstallDir\global.cfg" 0 +2 ; replace line in existing cfg file with line from archived cfg command.
 ## call editglobalCFG


 ############################ MxGuard Special #####################
 ## ifFileExists "$SNFServerInstallDir\mxGuard.ini" 0 +2
 ##   call editMXGuardINI

 ##########################
 ##; MINIMI Special.  IF MINIMI was installed with this version then we need to restore from the archive....
 ##Var /GLOBAL MINIMISpecial_KeyHandle
 ##ifFileExists  "$EXEDIR\OLD_SNFIMailShim.xml" 0 SkipMINIMISpecial
 ##   ; ok, well the file exists, so we need to make sure that the registry entrys are there....
 ##   ClearErrors
 ##   ReadRegStr $MINIMISpecial_KeyHandle HKLM "SOFTWARE\Ipswitch\IMail\Global" "TopDir" ; get IMails value.
 ##     StrCmp $MINIMISpecial_KeyHandle "" SkipMINIMISpecial 0 ; test for valid TopDir for Imail.
 ##     ; so we can presume that Imail should exist, and this setting is ON....
 ##     WriteRegStr HKLM "Software\MessageSniffer" "isMINIMIInstalled" "1" ; Since we have the file in the folder, we're resetting it back...
 ##     WriteRegStr HKLM "Software\MessageSniffer" "MINIMIInstallFolder" "$MINIMISpecial_KeyHandle" ; Since we have the file in the folder, we're resetting it back...

 ##     IfFileExists "$MINIMISpecial_KeyHandle\SNFIMailShim.xml" 0 +2
 ##       Delete "$MINIMISpecial_KeyHandle\SNFIMailShim.xml"
 ##     IfFileExists "$MINIMISpecial_KeyHandle\SNFIMailShim.exe" 0 +2
 ##       Delete "$MINIMISpecial_KeyHandle\SNFIMailShim.exe"

 ##     CopyFiles "$EXEDIR\OLD_SNFIMailShim.xml" "$MINIMISpecial_KeyHandle\SNFIMailShim.xml"
 ##     CopyFiles "$EXEDIR\SNFIMailShim.exe" "$MINIMISpecial_KeyHandle\SNFIMailShim.exe"

      # Now you must re-tie-in IMail to the MINIMI Install.....
      # If you're restoring an image onto somehting ( say DECLUDE ) that stompted the SendName anyway, then you need a new install of MINIMI....
      # not a restored version of MINIMI.  If you restore it, it will stomp the Declude.
 ##     WriteRegStr HKLM "SOFTWARE\Ipswitch\IMail\Global" "SendName" "$MINIMISpecial_KeyHandle\SNFIMailShim.exe"
      ; We can presume its pointing at what it should have been pointing at.  If you're restoring a MINIMI install and its target is gone...
      ; oh well... not my problem....

      # Last, verify that the hold folder exists for the installation and create it if it doesn't.
 ##     ${GetBetween} "<hold path='" "\'/>$\r$\n" "$MINIMISpecial_KeyHandle\SNFIMailShim.xml" "$R0"  ; This makes it not brittly dependant on the default value. i.e. It would
 ##     IfFileExists "$R0\*.*" +2 0 ; if it exists then skip, otherwise, recreate the spam target directory
 ##       CreateDirectory "$R0\*.*"
 ##SkipMINIMISpecial:
 ################################################# End MINIMI INSTALL RESTORE ###########################################################

  MessageBox MB_OK "Stubbed Code. This should never run."
  ## Shortcuts only relevant for modern installed verions, not sniffy.....
  ## Handle shortcut exception.
  IfFileExists "$SNFServerInstallDir\SNFRollback\shortcuts.xml" 0 RemoveTheShortcuts
    ##CopyFiles /SILENT "$EXEDIR\shortcuts.xml" "$SNFServerInstallDir\$FolderPrefix\shortcuts.xml"
    ; But if it exists, it means that they were installed so put them back.
    SetShellVarContext all ; this makes it backward/forwrad compatible  Without it Vista will have problems removing shortcuts.
                           ; Essentially, we said put these shortcuts into the all-users profile of the machine
    CreateDirectory "$SMPROGRAMS\MessageSniffer"
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\InstallInstructions.lnk" "$INSTDIR\InstallInstructions.txt"
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\MessageSniffer.lnk" "http://kb.armresearch.com/index.php?title=Message_Sniffer"
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\GBUdbIgnoreList.lnk" "$INSTDIR\GBUdbIgnoreList.txt"
    Goto SkipShortcuts
  RemoveTheShortcuts:
    ; if the files exists... and the restore says that they didn't have them for the restored version.... then they need to go away.
    Call removeShortCuts
  SkipShortcuts:

    ;MessageBox MB_OK "Starting SNFService"
    ## These would have been handled by the ROllBACK if they existed, and removed if they didn't.
    ##SetOutPath $INSTDIR
    ##File "XYNTService.exe" ; Unpack the files.
    ##File "XYNTService.ini"
    MessageBox MB_OK "Stubbed Code. This should never run."
    call editXYNTServiceINI ; First properly handle the ini file.

    ## HERE we say, if the file still exists after the rollback.... THEN... we can reinstall the XYNTService.
    nsExec::Exec "XYNTService -u" "" SH_HIDE ; uninstall it if it exists....
    ; presumes that the .ini file is in the same location.
    nsExec::Exec "XYNTService -i" "" SH_HIDE ; install XYNTService
    nsExec::Exec "XYNTService -r" "" SH_HIDE ; restart XYNTService

    call startSNFServer     ;nsExec::Exec "NET START SNFService" "" SH_HIDE
    
    call onRestoreSuccess
    Quit   ; This will transfer control to the license page, which will determine if a restore was just completed
           ; prior to displaying the license.  If it IS we use the RelGotoPage function to move us to the restore-success screen and end.
FunctionEnd


; The stuff to install
Section "MessageSniffer (required)"
                       ; MessageBox MB_OK "Entering sniffer reuqired section. "
  SectionIN RO         ; Required Option express declaration.
                       ; Set output path to the installation directory.
  SetOutPath $INSTDIR  ; even the rollback scripts depend on having this properly assigned in the installer.  They'll put it where this is set.

                       ; presuming we have an existing service installed, we'll need to stop it.... ( doesn't hurt if its not there. )
  Call stopSNFServer   ; if its there it will stop it.
  Call stopXYNTService ; if its there, stop it.


 ## A lot of conditional branching needs to skip over things if this is an MDaemon install.  As opposed to all other installs.
 ## So its worth defining an MDaemon flag.
 
 Var /GLOBAL isMDaemonInstalled
 StrCpy $isMDaemonInstalled 0 ; default to no.
 ifFileExists "$SNFServerInstallDir\App\MDaemon.exe" 0 NoDetectableMDaemon  ; Would have to be there for MDaemon.
   ifFileExists "$SNFServerInstallDir\SpamAssassin\rules\*.*" 0 NoDetectableMDaemon  ; also dependant on the rules plugin.
      StrCpy $isMDaemonInstalled 1 ;ok, its here, so use conditional branching on MDaemon flag.
      
        ## The following calls to the CopyWithRollbackControl have the file, the location and the callback function name that needs to be defined
        ## somewere above.  Eventually, on restore, if a call back function is defined it will be called in order to trip a restore/strip function call.

        ## MDaemon Special ## Note the MDaemon snfmdplugins.xml file is handled specially, alongside the snfengine.xml file code further down.
        SetOutPath "$INSTDIR"
           ${Install_with_RollbackControl} "InstallInstructions_MDaemon.txt" "" "" ; Install and remove this file on rollback.
           ${Install_with_RollbackControl} "snfmdplugin.dll" "" "" ; Install and remove this file on rollback.
        SetOutPath "$SNFServerInstallDir\SpamAssassin\rules"
           ${Install_with_RollbackControl} "snf-groups.cf" "" "" ; Install and remove this file on rollback.

           ## Handle the MDaemon Plugins file.  If exists, copy old, if gone, insert new, then when done, call edit to validate/correct entries.
        SetOutPath "$SNFServerInstallDir\App"
           ifFileExists "$SNFServerInstallDir\App\Plugins.dat" 0 NewPluginsDatFile
             ;MessageBox MB_OK "MDAEMONDEBUG:Plugins exists.  Copying Rollback."
             ${Copy_with_RollbackControl} "Plugins.dat" "$SNFServerInstallDir\App" "restoreMDaemonDAT" ""  ; Copy the old PluginsFile if it exists file.
             Goto DoneWithPluginsDatFile
             NewPluginsDatFile:
             ;MessageBox MB_OK "MDAEMONDEBUG: Plugins doesn't exist  Install with Rollback."
             ${Install_with_RollbackControl} "Plugins.dat" "restoreMDaemonDAT" "" ; Install and remove this file on rollback.
           DoneWithPluginsDatFile:
        SetOutPath "$INSTDIR"

 NoDetectableMDaemon:
 SetOutPath "$INSTDIR" ; even the rollback scripts depend on having this properly assigned in the installer.  They'll put it where this is set.
  ; If we got to here then we're ok to commit the files.
  ; Put file there
 ${Install_with_RollbackControl} "CURLREADME.rtf" "" ""
 ${Install_with_RollbackControl} "CURLMANUAL.rtf" "" ""

 ${Install_with_RollbackControl} "AuthenticationProtocol.swf" "" ""
 #File /a "AuthenticationProtocol.swf"
 ${Install_with_RollbackControl} "ChangeLog.txt" "" ""
 #File /a "ChangeLog.txt"
 

 ; File /a "getRulebase.cmd" This is handled during the init of the download rulebase page.
 ; These files are handled during download of rulebase page also.
         #${Install_with_RollbackControl} "gzip.exe" ""
         #File /a "gzip.exe"
         #${Install_with_RollbackControl} "snf2check.exe" ""
         #File /a "snf2check.exe"
         #${Install_with_RollbackControl} "curl.exe" ""
         # File /a "curl.exe"

 ${Install_with_RollbackControl} "License.txt" "" ""
 #File /a "License.txt"
  ${Install_with_RollbackControl} "SNFClient.exe" "" ""
 #File /a "SNFClient.exe"
 ${Install_with_RollbackControl} "SNFClient_readme.txt" "" ""
 #File /a "SNFClient_readme.txt"
 ${Install_with_RollbackControl} "mingwm10.dll" "" ""
 #File /a "mingwm10.dll"

## These files do NOT need to be installed if the MDaemon install is being utilized.
StrCmp $isMDaemonInstalled 0 0 SkipForMDaemon1
SetOutPath "$INSTDIR"

 ${Install_with_RollbackControl} "exchndl.dll" "" ""
 #File /a "exchndl.dll"
 ${Install_with_RollbackControl} "send_shutdown.cmd" "" ""
 #File /a "send_shutdown.cmd"
 ${Install_with_RollbackControl} "snf_xci.xml" "" ""
 #File /a "snf_xci.xml"
 ${Install_with_RollbackControl} "SNFServer_readme.txt" "" ""
 #File /a "SNFServer_readme.txt"
 ${Install_with_RollbackControl} "SNFServer${SNIFFER_SERVER_SPECIFIER}.exe" "" "" ; Record and put the file name.
 #File /a "SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"
 ${Install_with_RollbackControl} "SNFServer.exe" "" "" ; Record and put the file name.

 ## InstallXYNTServiceFile
 ${Install_with_RollbackControl} "XYNTService.exe" "" ""
 #File /a "XYNTService.exe"
 ${Install_with_RollbackControl} "XYNTService.ini" "restoreXYNTini" ""
 #File /a "XYNTService.ini"
 ${Install_with_RollbackControl} "XYNTServiceReadMe.txt" "" ""
 #File /a "XYNTServiceReadMe.txt"
 ${Install_with_RollbackControl} "InstallInstructions.txt" "" "" ; Install and remove this file on rollback.

SkipForMDaemon1:
SetOutPath "$INSTDIR"
  ; THESE files are copied by default and then stomped if we find one in the archive if we are preserving settings.
  ${Install_with_RollbackControl} "GBUdbIgnoreList.txt" "" ""
  #File /a "GBUdbIgnoreList.txt"
  ${Install_with_RollbackControl} "identity.xml" "" ""
  #File /a "identity.xml"
  
  
## Because of the rollback its possible that the snf_engine.xml file was removed.  But if the user selected UPDATE ( retain settings ),
## Then we will have put a copy in the temp folder:  Copy it into the install directory and the new rollback engine will maintain it.
SetOutPath "$INSTDIR"
StrCmp $RetainExistingSettings "0" FreshSNFEngine HandleRetainingSNFENGINEFILE  # ( Or the MDaemonDLL.xml file )....

FreshSNFEngine:
  ;MessageBox MB_OK "Not retaining"
  ; This situation is trivial.  Just allow the files to be installed in the rollback log.  If an older file exists,
  ; keep a copy for rollback, but the new file goes in the new install spot.
  StrCmp $isMDaemonInstalled 0 DoWinService DoMDaemonFreshInstead
  DoWinService:
  ${Install_with_RollbackControl} "snf_engine.xml" "" ""
  Goto DoneWithSNFHandling

  DoMDaemonFreshInstead:
  ${Install_with_RollbackControl} "snfmdplugin.xml" "" "" ; Install and remove this file on rollback.
  Goto DoneWithSNFHandling
  
HandleRetainingSNFENGINEFILE:
    ; This is a little trickers.  We need to retain all the settings from the older install, but we need to be sure that all the paths are correct
    ; and that we're referencing the new file.  SO... we need to use a Copy _with_Rollback
    ; But there are issues.  First, we rollback EVERY time, if there's a rolback to be had.  So you need to look in .onInit BEFORE the rollback
    ; triggers to find where we copied the snfmdplugin.xml and the snf_engine.xml file, for retrieval.  ( TEMP folder ) Then we let teh rollback happen.
    ; That puts either an old file, or it deletes and removes the only one that was there.
    ; THEN we look for that file, below, and if we find it, we copy it in, and call the edit function to ensure path-compliance.
    ; If its not there, then we put jump to the new-install path, and complete.
    
    ; Because this behavior needs to be duplicated between the snfEngine file and the mdplugin.xml file... we effectively double it here.
    StrCmp $isMDaemonInstalled 0 DoWinServiceRetaining DoMDaemonRetainingInstead
      DoWinServiceRetaining:                                            
                                                                        ; Ok, so look for it where we stuffed the copy during onInit. ( Before rollback. )
        ifFileExists "$TEMP\snf_engine.xml" 0 NotInTempDir              ; If its there then we copy it back to the install directory.
          ;MessageBox MB_OK "Existed"
          CopyFiles "$TEMP\snf_engine.xml" "$INSTDIR\snf_engine.xml"    ; joy
        NotInTempDir:                                                   ; If it didn't exist, then somethings wierd, but recoverable.
        ifFileExists "$INSTDIR\snf_engine.xml" 0 FreshSNFEngine         ; Check to see if it exists IN the folder... if it does, then keep copy for rollback.
                                                                        ; Otherwise, jump to fresh install path and put a new copy in place.
          ${Copy_with_RollbackControl} "snf_engine.xml" $INSTDIR "" ""  ; Copy the old snf_engine.xml file.
          Delete "$TEMP\snf_engine.xml"                                 ; Remove the temp if it exists.
          Goto DoneWithSNFHandling                                      ; Done with the SNF Windows Service retain-settings path.

    DoMDaemonRetainingInstead:                                          ; Ok, we're handling the MDaemon version...
        ifFileExists "$TEMP\snfmdplugin.xml" 0 NotInTempDir2            ; Look for the MDaemon xml version in the Temp. ( Copied before onInit rolled back. )
            CopyFiles "$TEMP\snfmdplugin.xml" "$INSTDIR\snfmdplugin.xml" ; Move file back if found.
        NotInTempDir2:                                                  ; Nope, not in the temp.. look local just in case.
          ifFileExists "$INSTDIR\snfmdplugin.xml" 0 FreshSNFEngine      ; if Not in local, then call for fresh, and pump out new.
            ${Copy_with_RollbackControl} "snfmdplugin.xml" $INSTDIR "" ""  ; If it does exist, keep the backup in the rollback, who knows where it came from.

        Delete "$TEMP\snf_engine.xml"                                   ; Delete temp if exists.
        Goto DoneWithSNFHandling                                        ; done.



DoneWithSNFHandling:
  #File /a "snf_engine.xml"

StrCmp $RetainExistingSettings "1" 0 callEdits
        ifFileExists "$SNFServerInstallDir\SNFRollback\snfmdplugin.xml" 0 +2 ; Only if file exists.....
         CopyFiles /SILENT "$SNFServerInstallDir\SNFRollback\snfmdplugin.xml" "$INSTDIR\snfmdplugin.xml"

        ifFileExists "$SNFServerInstallDir\SNFRollback\getRulebase.cmd" 0 +2 ; Only if file exists.....
         CopyFiles /SILENT "$SNFServerInstallDir\SNFRollback\getRulebase.cmd" "$INSTDIR\getRulebase.cmd"
        ; no action fpr the getRulebase.cmd The Edit routine is called when the dialog page executes...
        ; and if we're restoring the archived version here, then we don't need to call it anyway.
         
        ifFileExists "$SNFServerInstallDir\SNFRollback\GBUdbIgnoreList.txt" 0 +2 ; Only if file exists.....
         CopyFiles /SILENT "$SNFServerInstallDir\SNFRollback\GBUdbIgnoreList.txt" "$INSTDIR\GBUdbIgnoreList.txt"
        ; no action fro the GBUdbIgnoreList.txt

        ifFileExists "$SNFServerInstallDir\SNFRollback\identity.xml" 0 +2 ; If exists... copy.
         CopyFiles /SILENT "$SNFServerInstallDir\SNFRollback\identity.xml" "$INSTDIR\identity.xml"


callEdits:
         #  snf_engine.xml and snfmdplugin.xml files handled further down;  HAS SPECIAL CASE DOWN BELOW BECAUSE OF on-off setting needing to be retained or defaulted.
         Call editGetRulebase ; ( Handle the paths )
         Call editLicenseFile ; Always call this... Finds, Opens and edits the License.xml File with the License ID and Authentication strings.

        ifFileExists "$SNFServerInstallDir\App\MDaemon.exe" 0 +2
           Call editMDPluginsFile

        ##########################
        ## The following calls to the CopyWithRollbackControl have the file, the location and the callback function name that needs to be defined
        ## somewere above.  Eventually, on restore, if a call back function is defined it will be called in order to trip a restore feature.

        ##########################
        ; Declude Special
        ifFileExists "$SNFServerInstallDir\global.cfg" 0 SkipDeclude_Special ; replace line in existing cfg file with line from archived cfg command.
          ;messageBox MB_OK "Calling the Declude special $SNFServerInstallDir\global.cfg"
          ${Copy_with_RollbackControl} "global.cfg" $SNFServerInstallDir "restoreGLOBALcfg" "" ; Copy the old Server.exe
          call editglobalCFG ; then edit the declude config file.
        SkipDeclude_Special:

        ############################ MxGuard Special #####################
        ifFileExists "$SNFServerInstallDir\mxGuard.ini" 0 SkipMXGuard_Special
           ;messageBox MB_OK "Calling the MXGuard special $SNFServerInstallDir\mxGuard.ini"
           ${Copy_with_RollbackControl} "mxGuard.ini" $SNFServerInstallDir "restoreMXGUARDini" ""  ; Copy the old MXGuard.ini file.
           call editMXGuardINI ; this should put the file pointing at SNF...
        SkipMXGuard_Special:

        ############################ Alligate Special #####################
        ifFileExists "$SNFServerInstallDir\SNF4Alligate.exe" 0 SkipAlligate_Special
          ; Nothing here right now.  The shims are installed at the Installer layer, not the Restorer layer, and hence aren't
          ; in the control of the rollback.
        SkipAlligate_Special:

        ############################ IceWarp Special #####################
        ifFileExists "$SNFServerInstallDir\config\content.xml" 0 SkipIceWarp_Special
          #${Copy_with_RollbackControl} "content.xml" "$SNFServerInstallDir\config\" "restoreContentXML" ""  ; Copy the old MXGuard.ini file. ; Removed Callback.. redundent.
          ; Why isn't this copied in rollback?  Nothing to change from the customers perspective?  Hmmmmmm.... they COULD edit it... this might be an error.
          call editContentXML
        SkipIceWarp_Special:

  ############################ SNFClient.exe and snfmdaemon.dll Special ############################
  #  snf_engine.xml and snfmdplugin.xml files
  #  There is a slight detail.
  #  If the install parameters were set to overwrite previous files if they existed... vs.. using their settings if they do...
  #
  #  NOTE: that editXMLConfig is smart enough to know if its editing the snfmddll.xml file, or the snf_engine.xml file.  Same rules apply.
  #
  StrCmp $RetainExistingSettings "1" 0 JustUseAllNewFiles  ; If we have a RETAIN flag set then use existing settings from file...
  ## Note:  If we retained settings, then we copied the old snfengine.xml/snfmddll.xml file to the temp and then back into the
  ##        INSTDIR, as well as storing it in the ROLLBACK.  So At this point there is the previous copy's ( manual or installer based ) SNFENGINE.xml file in all places.
  ##        and the flag $RetainExistingSettings to determine what we are to do.
  ##
  ## So check the mdaemon version if that exists, or the snfengine.xml if that one exists.
  ifFileExists "$INSTDIR\snfmdplugin.xml" UseMDaemonXMLFIle UseStdSNFEngineFile
                                                        ; So if this file exists then we mine it for the auto update flag, before calling the
    UseMDaemonXMLFIle:                                  ; editXMLConfig function.  ( Because that will set it ON by default unless told not to. )
    # So get the current value of whatever file is in place. ( If its old then fine, if its a new install it will be new file with the default set.  So no big deal. )
    ${GetBetween} "<update-script on-off='" "'" "$INSTDIR\snfmdplugin.xml" "$AUTO_UPDATE_ONOFF_FLAG"  ; This makes it not brittly dependant on the default value. i.e. It would
      ; if the setting is off, then its an old file.
      StrCmp $AUTO_UPDATE_ONOFF_FLAG "" 0 adjustFileNow ; if not expressly false, then use default of ON
        StrCpy $AUTO_UPDATE_ONOFF_FLAG "off"            ; flag is set off.
        goto adjustFileNow                              ; break out and run edit script.
    UseStdSNFEngineFile:                                ; Ok, the snf_engine file is what were mining, not the mdaemon.
      ${GetBetween} "<update-script on-off='" "'" "$INSTDIR\snf_engine.xml" "$AUTO_UPDATE_ONOFF_FLAG"  ; This makes it not brittly dependant on the default value. i.e. It would
      StrCmp $AUTO_UPDATE_ONOFF_FLAG "" 0 adjustFileNow ; if not expressly false, then use default of ON
        StrCpy $AUTO_UPDATE_ONOFF_FLAG "off"
        ; fall through now.
        
    adjustFileNow:
    Call editXMLConfig ; patching this function to hand off to use the snfmdplugin.xml file as source if necessary.
    Goto DoneWithFiles
    
    JustUseAllNewFiles:
     ; Prior to calling editXMLConfig we need to set the flag that determines if we're using the AutoUpdate feature.
     StrCpy $AUTO_UPDATE_ONOFF_FLAG "on" ; Defaults to yes.
     Call editXMLConfig ; Handles altering the log and executible paths as well as the network instrument. ( If it exists. )
       ; Don't need to parse it if we have it....

DoneWithFiles:

  ; A similar command will be used to open the GUIEdit file with a notepad.exe
  ${IF} $OpenGBUIgnoreFileOnClose == 1
    ExecWait '"notepad.exe" "$INSTDIR\GBUdbIgnoreList.txt"'
  ${ENDIF}


  ; Write the uninstall keys for Windows For NSIS not SNF Install relevant
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MessageSniffer" "DisplayName" "Message Sniffer"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MessageSniffer" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MessageSniffer" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MessageSniffer" "NoRepair" 1
  SetOutPath $INSTDIR
  ifFileExists "$INSTDIR\uninstall.exe" 0 +2
    ${Copy_with_RollbackControl} "uninstall.exe" "$INSTDIR" "" "" ; Copy the old Uninstaller.exe
  WriteUninstaller "uninstall.exe"


  ## These calls aren't required for the MDaemon installation.
  ## Skipp for MDaemon, the files won't be there, the service isn't going to be installed.
  ifFileExists "$INSTDIR\snfmdplugin.xml" SkipAllServiceRelatedCalls RunServiceWrapperInstallMethods

    RunServiceWrapperInstallMethods:
            call editXYNTServiceINI ; First properly handle the ini file.
            ## HERE we say, if the file still exists after the rollback.... THEN... we can uninstall and reinstall the XYNTService.
            nsExec::Exec "$INSTDIR\XYNTService -u" "" SH_HIDE ; uninstall it if it exists....
            ; presumes that the .ini file is in the same location.
            nsExec::Exec "$INSTDIR\XYNTService -i" "" SH_HIDE ; install XYNTService
            nsExec::Exec "$INSTDIR\XYNTService -r" "" SH_HIDE ; restart XYNTService
            call startSNFServer     ;nsExec::Exec "NET START SNFService" "" SH_HIDE

    SkipAllServiceRelatedCalls:
    ; Looks like were done.

  ## Close rollback macro.
  ${EndRollbackSession} "HKLM" "Software\MessageSniffer"  ; Close this file, and end the rollback session. Provide strings for the resgistry handle.


SectionEnd




; Optional section (can be disabled by the user)
Section "Start Menu Shortcuts"
  SetOutPath $INSTDIR
  VAR /GLOBAL FileHandle

  ; NOTE we need to track if these were installed, for putting back on archive/restore.
  FileOpen  $FileHandle "$INSTDIR\shortcuts.xml" w
  FileWrite $FileHandle "<snf><shortcuts>1</shortcuts></snf>"
  FileClose $FileHandle
  
  SetShellVarContext all ; this makes it backward/forwrad compatible  Without it Vista will have problems removing shortcuts.
                         ; Essentially, we said put these shortcuts into the all-users profile of the machine
  CreateDirectory "$SMPROGRAMS\MessageSniffer"
  ifFileExists "$INSTDIR\snfmdplugin.dll" 0 InstallNormalInstructions
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\InstallInstructions.lnk" "$INSTDIR\InstallInstructions_MDaemon.txt"
    Goto AddSiteLink
   InstallNormalInstructions:
    CreateShortCut  "$SMPROGRAMS\MessageSniffer\InstallInstructions.lnk" "$INSTDIR\InstallInstructions.txt"
  AddSiteLink:
  CreateShortCut  "$SMPROGRAMS\MessageSniffer\MessageSniffer.lnk" "http://www.armresearch.com/"
  CreateShortCut  "$SMPROGRAMS\MessageSniffer\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  CreateShortCut  "$SMPROGRAMS\MessageSniffer\GBUdbIgnoreList.lnk" "$INSTDIR\GBUdbIgnoreList.txt"
SectionEnd

;--------------------------------

; Uninstaller





Function un.Restore
       !insertmacro BIMAGE "SnifferStop.bmp" ""  ; change banner image.

        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Uninstall Message Sniffer Server 3.0:"

        ; Page formation
	nsDialogs::Create /NOUNLOAD 1018
	Pop $0

        ; now check restore options:
        VAR /GLOBAL DeleteArchives ; flag to indicate yes/no
        StrCpy $DeleteArchives "0" ; default to no.

        ${NSD_CreateLabel} 0 10% 100% 40u "You are now going to uninstall the current working version of Message Sniffer.  You may use the Message Sniffer Install Utility to Restore from a previous archived version, if you choose to not remove all archived folders.  If you choose to remove all archives, this operation cannot be undone."
	Pop $0
	;${NSD_CreateLabel} 30 50% 100% 20u ""
	;Pop $0
        ${NSD_CreateCheckbox} 0 50% 100% 20 "Check this if you want to remove all archived Message Sniffer folders."
        Pop $CHECKBOX
	GetFunctionAddress $0 un.ToggleRestore
	nsDialogs::OnClick /NOUNLOAD $CHECKBOX $0
        nsDialogs::Show
FunctionEnd

Function un.BeSure
  StrCpy $5 "This operation will remove the current restore/rollback of Message Sniffer from the Server 3.0 install."
  StrCmp $DeleteArchives "1" 0 +2
    StrCpy $5 "You have chosen to destroy your rollback files as well  THE ROLLBACK ARCHIVE WILL BE DELETED.  This operation cannot be undone."
  MessageBox MB_YESNO "Are you sure? $5" IDYES true IDNO false
true:
  Return
false:
  Abort
FunctionEnd

Function un.ToggleRestore

	Pop $0 # HWND
	StrCmp $DeleteArchives "1" 0 ToggleStuff
          StrCpy $DeleteArchives "0";

          Push $0
	  GetTempFileName $0
	  File /oname=$0 "SnifferStop.bmp"
	  SetBrandingImage "" $0
	  Delete $0
	  Pop $0

          Return
          
    ToggleStuff:
	  StrCpy $DeleteArchives "1";
	  Push $0
	  GetTempFileName $0
	  File /oname=$0 "SnifferStop2.bmp"
	  SetBrandingImage "" $0
	  Delete $0
	  Pop $0
FunctionEnd

Function un.RemoveSNF4Alligate

          ######################################################################### SNF4ALLIGATE UNINSTALL SECTION ############################################
          ; If SNF4Alligate exists then we remove it.
          Var /GLOBAL uninstallAlligate
          ReadRegStr $uninstallAlligate HKLM "Software\MessageSniffer" "isSNF4AlligateInstalled"  ; read the install folder for MINIMI.
          StrCmp $uninstallAlligate "1" 0 NoAlligateHere

            ; If we DO have SNF4Alligate installed we drop in here....

          Var /GLOBAL UninstallAlligateFolder ; holds if and where MINIMI was installed.
          Var /GLOBAL AlligateDelivery_Setting
          Var /GLOBAL currentAlligateTarget
          ReadRegStr $currentAlligateTarget HKLM "Software\SolidOak\Aligate\Settings" "FilterEXE"  ; read alligates AGFILTSVC target....
          StrCmp $currentAlligateTarget "SNF4Alligate.exe" 0 SkipFilterExeAdustment
             ; Then we'll clear it, or set it to the next in the chain.

             ; So we'll need to know if we're the ones in Alligates prime spot... otherwise we don't clear/or clean it.
             ReadRegStr $UninstallAlligateFolder HKLM "Software\MessageSniffer" "SNF4AlligateInstallFolder"  ; read the install folder for MINIMI.
             ; Now we know where the files are:


             ; So read out the delivery program setting:
             ifFileExists "$UninstallAlligateFolder\SNF4Alligate.xml" 0 NoXMLFile ; if we find the xml file, then we need to do checking...
                        ; IF this is valid, then we read from OLD....
                        ; and if its anything other than the inert tag values, we put it back in.
                        ${un.GetBetween} "<delivery program='" "'/>$\r$\n" "$UninstallAlligateFolder\SNF4Alligate.xml" "$AlligateDelivery_Setting"
                        ${Switch} $AlligateDelivery_Setting
                            ${Case} ""
                                ExecWait 'net stop AGFILTSVC'
                                ExecWait '$UninstallAlligateFolder\AGFiltSvc.exe /uninstall'
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "DropDir" "\Spool"
                                goto doneResolvingAlligateDeliverySetting
                            ${Case} "none"
                                ExecWait 'net stop AGFILTSVC'
                                ExecWait '$UninstallAlligateFolder\AGFiltSvc.exe /uninstall'
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "DropDir" "\Spool"
                                goto doneResolvingAlligateDeliverySetting
                            ${Case} "NONE"
                                ExecWait 'net stop AGFILTSVC'
                                ExecWait '$UninstallAlligateFolder\AGFiltSvc.exe /uninstall'
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "DropDir" "\Spool"
                                goto doneResolvingAlligateDeliverySetting
                            ${Case} "None"
                                ExecWait 'net stop AGFILTSVC'
                                ExecWait '$UninstallAlligateFolder\AGFiltSvc.exe /uninstall'
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "DropDir" "\Spool"
                                goto doneResolvingAlligateDeliverySetting
                            ${Case} "SNF4Aligate"
                                ExecWait 'net stop AGFILTSVC'
                                ExecWait '$UninstallAlligateFolder\AGFiltSvc.exe /uninstall'
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
                                WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "DropDir" "Spool\"
                                goto doneResolvingAlligateDeliverySetting
                            ${Default}
                              ExecWait 'net stop AGFILTSVC'    ; this will stop it and release the SNF4Alligate.exe file.
                              MessageBox MB_OK "SNF4Alligate was set to hand messages downstream to $AlligateDelivery_Setting.  The Uninstaller will try to restore the FilterEXE registry value to maintain the rest of the filter-call chain.  Please confirm and test this before you're done with your settings."
                              WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" "$AlligateDelivery_Setting."
                              ExecWait 'net start AGFILTSVC'   ; this will stop it and reset the new filter target.

                              goto doneResolvingAlligateDeliverySetting
                        ${EndSwitch}

              NoXMLFile:
                  ;something was wrong here.....
                  ; but if there isn't anything to go buy, then if the FiltEXE is pointing at us, then we clear it.
                  WriteRegStr HKLM "SOFTWARE\SolidOak\Alligate\Settings" "FilterEXE" ""
              doneResolvingAlligateDeliverySetting:
          SkipFilterExeAdustment:

          DeleteRegKey HKLM SOFTWARE\SolidOak\Alligate\Settings\Addins\MsgSniffer\ProcessDirHint  ; this holds the verbage for the Alligate Inteface clue.
          DeleteRegKey HKLM SOFTWARE\SolidOak\Alligate\Settings\Addins\MsgSniffer\ProcessDir      ; This flags the directory.
          DeleteRegKey HKLM SOFTWARE\SolidOak\Alligate\Settings\Addins\MsgSniffer\ProcessDirLabel ; This is "Sniffer"

          ; In either case we need to remove isSNF4AlligateInstalled,SNF4AlligateInstallFolder,SNFMailServer_DIR from the MessageSniffer registry key.
          ; and
          DeleteRegKey HKLM HKEY_LOCAL_MACHINE\SOFTWARE\MessageSniffer\isSNF4AlligateInstalled
          DeleteRegKey HKLM HKEY_LOCAL_MACHINE\SOFTWARE\MessageSniffer\SNF4AlligateInstallFolder
          DeleteRegKey HKLM HKEY_LOCAL_MACHINE\SOFTWARE\MessageSniffer\SNFMailServer_DIR

          ifFileExists "$UninstallAlligateFolder\SNF4Alligate.xml" 0 +2
            Delete "$UninstallAlligateFolder\SNF4Alligate.xml"
          ifFileExists "$UninstallAlligateFolder\SNF4Alligate.exe" 0 +2
            Delete "$UninstallAlligateFolder\SNF4Alligate.exe"

          ExecWait "net stop AgSMTPSvc"     ; Now bounce the Alligate SMTP Server.
          ExecWait "net start AgSMTPSvc"

          NoAlligateHere:
          ######################################################################### END Alligate UNINSTALL SECTION ############################################
  return
FunctionEnd

Section "Uninstall"

  ; Now we have two situations.  The first is that this Uninstaller was called legitimately, in which case, this file
  ; will be being run from the existing Message Sniffer install directory.
  ; and $EXEDIR will be that directory..... or $EXEDIR will be in a directory inside the SnifferArchive directory, and be
  ; an illigitimate version running..... SOLVED THIS BY CHANGING THE FILE EXTENSION to bck.. and then back to exe when its appropriate.
  ; So read the registry key:
  Call un.stopSNFServer
  Call un.UninstallXYNTService

  Var /GLOBAL localFileDirectory
  Var /GLOBAL uninstallRollbackPath
  Var /GLOBAL uninstallRollbackLogName
  Call un.removeShortcuts               ; if your uninstalling, then you're taking the installers work out.  Shortcuts will always go away.
                                        ; only manual installs might be left behind. Manual installs don't have shortcuts.
  
  ReadRegStr $localFileDirectory HKLM "Software\MessageSniffer" "Install_Dir"
  ReadRegStr $uninstallRollbackPath HKLM "Software\MessageSniffer" "SRS_RollbackPath"
  ReadRegStr $uninstallRollbackLogName HKLM "Software\MessageSniffer" "SRS_LogName"
  ReadRegStr $SNFServerInstallDir HKLM "Software\MessageSniffer" "SNFMailServer_DIR"


  ## ROLLBACK WILL ALWAYS OCCUR ON UNINSTALL... mostly it will be on a fresh install... but if it has an existing install.... it will only remove
  ## Files it inserted.

  ${un.GetParent} $localFileDirectory $SNFServerInstallDir
    #######################################################################################################################################
    ## We're un-installing.  Therefore if there is an existing rollback file, run it.
    #######################################################################################################################################
    StrCmp $uninstallRollbackPath "" NoPreRoll 0
    StrCmp $uninstallRollbackLogName "" NoPreRoll 0
    StrCmp $uninstallRollbackPath "$SNFServerInstallDir\SNFRollBack" 0 NoPreRoll  ; Only roll this back if its the same folder as the source. i.e. Don't rollback an
                                                                                  ; Imail install ontop of a smartermail install.
    ${un.RollBackTo} $uninstallRollbackPath $uninstallRollbackLogName  ; Put all the files back the way they were.

    # Do we end here?
    NoPreRoll:
    
          ######################################################################### MINIMI UNINSTALL SECTION ############################################
          ; If MINIMI exists then we should roll it back, but first we need to replace the IMAIL SendName Registry Key with the target value in
          ; the MINIMI xml config file.
          Var /GLOBAL UninstallMINIMIFolder ; holds if and where MINIMI was installed.
          Var /GLOBAL Delivery_Setting
          Var /GLOBAL Current_Send_setting ; current IMAIL send target for the mail delivery.
          Var /GLOBAL Current_UninstallTopDir ; Imail top directory
          ReadRegStr $0 HKLM "Software\MessageSniffer" "isMINIMIInstalled"
          StrCmp $0 "1" 0 ContinueWithRollback  ; if it is, then drop in and handle the tests.....
            ReadRegStr $UninstallMINIMIFolder HKLM "Software\MessageSniffer" "MINIMIInstallFolder"  ; read the install folder for MINIMI.
                # EXPLANATION:  MINIMI might have been made irrelevant, so we first need to test if it was being used before we roll it back.
                #               then if this MINIMI was being used, but we'rerolling back to the OLD minimi version, then we're going to
                #               put the OLD MINIMI's target back as IMAILs send name target.  If there is no OLD_SNIFIMailShim.xml, that means
                #               that the rollback is deleteing MINIMI and we should put the current MINIMI's target back as Imails sendName Target....
                #  Make sense?  Good.  All bets are off, if current MINIMI is not tied into IMAIL.
                # Test for current xml file.  Test for Imail's SendName and TopDir
                  ifFileExists "$UninstallMINIMIFolder\SNFIMailShim.xml" 0 ContinueWithRollback ; if we find the xml file, then we need to do checking...
                    ; if this file exists, then MINIMI was installed at some point.  Check to see what IMAIL is pointing at:
                    ReadRegStr $Current_Send_setting HKLM "SOFTWARE\Ipswitch\IMail\Global" "SendName" ; this is what it was calling....
                    ReadRegStr $Current_UninstallTopDir HKLM "SOFTWARE\Ipswitch\IMail\Global" "TopDir"   ; this is where MINIMI would be installed.
                    StrCmp "$Current_UninstallTopDir\SNFIMailShim.exe" $Current_Send_setting 0 IgnoreSendNameRollback

                      ## Dropping into here means that the IMAIL target is the same as the MINIMI executable.
                      ## So we're rolling back.  Test to see if there is an OLD_SNIFI.xml file, or not.
                      ifFileExists "$UninstallMINIMIFolder\OLD_SNFIMailShim.xml" 0 ResetImail_WithCurrentMINIMIVALUE ; if we find the xml file, then we need to do checking...
                        ## IF this is valid, then we read from OLD....
                        ${un.GetBetween} "<delivery program='" "'/>$\r$\n" "$UninstallMINIMIFolder\OLD_SNFIMailShim.xml" "$Delivery_Setting"
                        Goto ResetImail
                        
                      ResetImail_WithCurrentMINIMIVALUE:
                        ## IF THIS gets executed it means there was no OLD but we're still removing MINIMI from the chain....
                        ${un.GetBetween} "<delivery program='" "'/>$\r$\n" "$UninstallMINIMIFolder\SNFIMailShim.xml" "$Delivery_Setting"
                        Goto ResetImail
                        
                     ResetImail:
                     ## Finally, reset the Imail setting to the target of MINIMI and take it out of the chain.
                     ClearErrors
                     WriteRegStr HKLM "SOFTWARE\Ipswitch\IMail\Global" "SendName" "$Delivery_Setting"
                       iferrors 0 IgnoreSendNameRollback
                         MessageBox MB_OK "MINIMI was set to hand cleared messages downstream.  The Uninstaller tried to restore the SendName registry value for IMail to: '$Delivery_Setting' but the write was rejected.  Please save this value and manually reset the SendName parameter."

          IgnoreSendNameRollback:
          # Not changing the target for Imail, but we're rolling back MINIMI's files.... ( theoretically, somethings pointing at it???? )
          # Test for xml file.  Test for Imail's SendName and TopDir
          ifFileExists "$UninstallMINIMIFolder\OLD_SNFIMailShim.xml" 0 ContinueWithRollback ; if we find the xml file, then we need to do checking...
            ifFileExists "$UninstallMINIMIFolder\SNFIMailShim.xml" 0 +2
              Delete "$UninstallMINIMIFolder\SNFIMailShim.xml"
            CopyFiles /SILENT "$UninstallMINIMIFolder\OLD_SNFIMailShim.xml" "$UninstallMINIMIFolder\SNFIMailShim.xml"

          ifFileExists "$UninstallMINIMIFolder\OLD_SNFIMailShim.exe" 0 ContinueWithRollback ; if we find the xml file, then we need to do checking...
            ifFileExists "$UninstallMINIMIFolder\SNFIMailShim.exe" 0 +2
              Delete "$UninstallMINIMIFolder\SNFIMailShim.exe"
            CopyFiles /SILENT "$UninstallMINIMIFolder\OLD_SNFIMailShim.exe" "$UninstallMINIMIFolder\SNFIMailShim.exe"
          ContinueWithRollback:
          ######################################################################### END MINIMI UNINSTALL SECTION ############################################

       ######################################################################### Alligate UNINSTALL SECTION
       Call un.RemoveSNF4Alligate ; remove SNF4Alligate if its installed.
       
       ######################################################################### IceWarp UNINSTALL SECTION
       ifFileExists "$SNFServerInstallDir\config\content.xml" 0 +2
       Call un.editContentXML     ; remove IceWarp if its installed.

       ######################################################################### IceWarp UNINSTALL SECTION
       ; Don't need this here cause it gets called on the Rollback.  Twice will remove the rolled back references if there were any.
       ; ifFileExists "$SNFServerInstallDir\App\Plugins.dat" 0 +2
       ;   Call un.editMDPluginsFile     ; remove MDaemon SNF Call if its installed.

       ## IF there is no SNFClient.exe there should be no uninstaller.exe or anything else.
       ifFileExists "$localFileDirectory\SNFClient.exe" LeaveNow 0 ; otherwise cleanup.
          ifFileExists "$localFileDirectory\Restorer.exe" 0 +2
            Delete "$localFileDirectory\Restorer.exe"
          ifFileExists "$localFileDirectory\oldsnifferversion.txt" 0 +2
            Delete "$localFileDirectory\oldsnifferversion.txt"
          ifFileExists "$localFileDirectory\getRulebase.cmd.old" 0 +2
            Delete "$localFileDirectory\getRulebase.cmd.old"
          ifFileExists "$localFileDirectory\shortcuts.xml" 0 +2
            Delete "$localFileDirectory\shortcuts.xml" ; if exists ; Find other location
          ifFileExists "$localFileDirectory\cfgstring.xml" 0 +2
            Delete "$localFileDirectory\cfgstring.xml" ; if exists ; Find other location
          ifFileExists "$localFileDirectory\XYNTService.ini" 0 +2
            Delete "$localFileDirectory\XYNTService.ini"
          ifFileExists "$localFileDirectory\LocalRoot.txt" 0 +2
            Delete "$localFileDirectory\LocalRoot.txt"
          ifFileExists "$localFileDirectory\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"  0 +2
            Delete "$localFileDirectory\SNFServer${SNIFFER_SERVER_SPECIFIER}.exe"
          ifFileExists "$localFileDirectory\UpdateReady.txt"  0 +2
            Delete "$localFileDirectory\UpdateReady.txt"
          ifFileExists "$localFileDirectory\mingwm10.dll"  0 +2
            Delete "$localFileDirectory\mingwm10.dll"
          Delete "$localFileDirectory\uninstall.exe"
          ifFileExists "$localFileDirectory\snfmdplugin.xml"  0 +2
            Delete "$localFileDirectory\snfmdplugin.xml"
          ifFileExists "$localFileDirectory\snfmdplugin.dll"  0 +2
            Delete "$localFileDirectory\snfmdplugin.dll"
          ifFileExists "$localFileDirectory\Plugins.dat"  0 +2
            Delete "$localFileDirectory\Plugins.dat"
          ifFileExists "$SNFServerInstallDir\SpamAssassin\rules\snf-groups.cf" 0 +2
            Delete "$SNFServerInstallDir\SpamAssassin\rules\snf-groups.cf"
            
    LeaveNow:
       ##################
       ; Ok, lastly wipe all the registry keys because if the uninstaller has run, it isn't available anmore..
       DeleteRegKey HKLM SOFTWARE\MessageSniffer

       ifFileExists "$SNFServerInstallDir\SNFRollBack\*.*" 0 +2
         RMDir /r "$SNFServerInstallDir\SNFRollBack"

       Delete "$uninstallRollbackPath\$uninstallRollbackLogName"
       
       ; Remove registry keys
       DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MessageSniffer"
       ; don't delete the master RegKey Folder until the end.  We might need to reference the archive path.

    Return
    ## END ROLLBACK
    

  ########################################################### PRIME is 1 and No FULLUNNSTALLBLOCKER EXISTS ########################################
  ## Massive chunk of uninstaller code was removed on Mar 02.  Rollback should be handling all of these items.  Need full test to confirm that.
  
SectionEnd

;Function that calls a messagebox when installation finished correctly
Function .onInstSuccess
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  ;  Modal banner sample: show
    File "SuccessInstall.bmp"
    newadvsplash::show 5000 100 500 0x04025C  "$PLUGINSDIR\SuccessInstall.bmp" ;/NOCANCEL
    Delete "$PLUGINSDIR\SuccessInstall.bmp"

FunctionEnd

;Function that calls a messagebox when installation finished correctly
Function onRestoreSuccess

  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  ;  Modal banner sample: show
    File "SuccessRestore.bmp"
    newadvsplash::show 5000 100 500 0x04025C "$PLUGINSDIR\SuccessRestore.bmp" ; /NOCANCEL
    Delete "$PLUGINSDIR\SuccessRestore.bmp"

FunctionEnd

Function un.onUninstSuccess
  SetOutPath $SNFServerInstallDir ; To release any holds on folders.
  ; SetOutPath "C:"
    ; ifFileExists "C:\MessageSniffer\StandAlone" 0 +2
    ;  RmDir  /r "C:\MessageSniffer\StandAlone"
    ; ifFileExists "C:\MessageSniffer\MXGuard" 0 +2
     ; RmDir  /r "C:\MessageSniffer\MXGuard"
    ; ifFileExists "C:\MessageSniffer" 0 +2
    ;  RmDir  /r "C:\MessageSniffer"
    ;ifFileExists "$INSTDIR\*.*" 0 +2
    ;  RmDir  /r $INSTDIR
    ;ifFileExists "$SNFServerInstallDir\Sniffer" 0 +2
    ;  RmDir  /r "$SNFServerInstallDir\Sniffer"
     ; And if the user said to delete ALL of the Archive folders, then we kill them all.
    ;StrCmp $DeleteArchives "1" 0 SkippingDeleteOfArchives
    ;  Delete "$SNFServerInstallDir\SNFRollback\*.*"
    ;  RmDir  /r "$SNFServerInstallDir\SNFRollback"
  ;SkippingDeleteOfArchives:
    ;MessageBox MB_OK "You have successfully uninstalled Message Sniffer."
    InitPluginsDir
    SetOutPath "$PLUGINSDIR"
    ;  Modal banner sample: show
    File "SuccessUnInstall.bmp"
    newadvsplash::show 5000 100 500 0x04025C /NOCANCEL "$PLUGINSDIR\SuccessUnInstall.bmp"
    Delete "$PLUGINSDIR\SuccessUnInstall.bmp"
    
    MessageBox MB_OK "                          Uninstall Complete!$\r$\nThe uninstaller has rolled back any changes made during the last installation.$\r$\nThe uninstaller does not delete files that it did not create (such as log files).$\r$\nIf you want to delete these files you will probably find them in your install$\r$\nfolder located here: $SNFServerInstallDir"

    ;call un.restartMDaemon
FunctionEnd

