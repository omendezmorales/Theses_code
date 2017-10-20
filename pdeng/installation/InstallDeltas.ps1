#####################################################
#install the MSPs (upgrade version)
#this script takes as inputs:
# A) the directory where the patches (MSP files) are
# B) the BOM_MSP file that prescribes the installation order of patches 
# C) the execution mode: -i for patching, and -u for  patching removal
# example of use:
# InstallDeltas.ps1 <MSP_Files_Directory> <BOM_MSP_file> <execution_mode>
#####################################################

#####################################################
# function to write to a pre/post patching log 
#####################################################
function WriteVerifyLog ($message, $logFile) {
          [string]$m=$message;
               if ($m.contains('Unable') -or $m.contains('should be')) {
                 Add-Content -Value $message -Path $LogFile;
                 return $false
                 }
    else{

            return $true;
         }   
         
}

#####################################################
# logging variables
####################################################
$logDirectory= '..\Log\';
if ((Test-Path $logDirectory -PathType container) -eq $false){
    New-Item $logDirectory -type directory;
}
$logPreInstall= $logDirectory + 'logPreInstall.txt';
$LogInstall= $logDirectory + 'LogInstall.txt'; #store return codes from msiexec.
$logPostInstall= $logDirectory + 'logPostInstall.txt';

#####################################################
# function to verify the system is in a known working 
# state from the cofiguration point of view.
# this function verifies the following:
# a) the MSP files to install have not been tampered
# b) the system to be updated contains the right configuration
# not only subsystem level, but even file level. For this verication
# we assume the xml files are in the same directory where the MSP 
# files are
#####################################################
function verifyPreInstall{
   $targetSuffix= '*target*.xml';
   $success= $true;
   $tempSuccess= $success;
    write-host "performing pre-install verification...";
    #verify the MSP files
    cd $MSPsPath;
    write-host `t 'Validating MSP files...' -nonewline;
    $result = cmd /c $installPath\fciv.exe -v -xml  $XMLPath\MSPs.xml
    $success= WriteVerifyLog $result $logPreInstall
    if ($success -eq $false){
        write-host -ForegroundColor Red "MSPs corrupted; validation failed. Exiting the installation script";
        exit;
    }
    else {
         write-host -ForegroundColor Green "MSP files ok";
    }
    
    cd $installPath; 
    #read from the XML directory all target XML files
    $targetList= Get-ChildItem $XMLPath\$targetSuffix
 	write-host 'verifying subsystems: ' 
    foreach($item in $targetList){
        write-host `t $item.Name.TRimEnd(".xml") '...' -nonewline;
        Add-Content -Value ('verifying subsystem ' + $item.Name.TRimEnd(".xml")) -Path $logPreInstall;
       $result= cmd /c .\fciv.exe -v -xml $item
       $tempSuccess = WriteVerifyLog $result $logPreInstall;
       if($tempSuccess -eq $false) {
            $success = $tempSuccess;
            write-host  -ForegroundColor Red  'failed';
            }
       else{
            write-host  -ForegroundColor Green 'OK';
       }     
   }
    return $success;
}

#####################################################
# function to verify system after update
#####################################################
function verifyPostInstall{
   $UpgradeSuffix= '*upgrade*.xml';
   $success= $true;
   $beginDate= (Get-Date);
   write-host 'validating installation of MSPs...' $beginDate.ToLongTimeString();
   #read from the XML directory all upgrade XML files
    $targetList= Get-ChildItem $XMLPath\$UpgradeSuffix
    foreach($item in $targetList){
        write-host `t $item.Name.TRimEnd(".xml") '...'  -NoNewline;
        Add-Content -Value ('verifying subsystem ' + $item.Name.TRimEnd(".xml")) -Path $logPostInstall;
       $result= cmd /c .\fciv.exe -v -xml $item
       $tempSuccess = WriteVerifyLog $result $logPostInstall;
       if($tempSuccess -eq $false) {
            $success = $tempSuccess;
            write-host  -ForegroundColor Red 'failed';
            }
         else{
            write-host  -ForegroundColor Green 'ok'; 
       }          
   }
    return $success;
}

#####################################################
# function to retrieve the Data for MSP removal
#####################################################
function getRemovalData($FileFound){
    [System.Array] $AllProps, $properties;
    $AllProps = MsiInfo.Exe $FileFound;
    $i=0;
    if ($AllProps -ne $null){
        foreach($p in $AllProps){
            if ($p.contains('/p') -or $p.contains('/v')){
                write-host 'to be done'
            }
        }
    }
}

#####################################################
#function to rollback the installation
#this function is responsible for removing the patches previously installed.
#it uses as reference the BOM_SMP.txt file used for installation, but read in
#inverse order
#####################################################
function rollback{
    write-host rollbacking...
    for($i=$bom_msp.length -1; $i -ge 0; $i--){
                if ($bom_msp[$i].toString().Equals('')){continue;}
                   $fileName= $bom_msp[$i];
                   $filename= $filename.split(':');
                   $FileFound= Get-ChildItem -path $MSPsPath $filename[$filename.length-1].Trim();
    if ($FileFound.length -ne $null ){
        #$retCode= Msiexec /package <> /uninstall $FileFounf.FullName /passive
	   write-host 'removing patch...'
       $MSIData = getRemovalData $FileFound;
       $retoCode =  Msiexec /I $MSIData[0] MSIPATCHREMOVE=$MSIData[1] /qb /l*v ($logDirectory + $result.Name.trimEnd(".msp") + "_removal.log");

    }
     if  ($retCode -eq 0) { continue } #successful removal
    else {
            # something went wrong during removal; log
            set-content -path $LogInstall -value $retCode
            return 1; #return to Questra
			#rollback
        }
   }
}

#####################################################
# this function installs the set of msp files in the 
# order indicated by the BOM_MSP.txt file
#####################################################
function install
{
    [string]$fileName;
    [bool]$result;
    for($i=0;$i -le $bom_msp.length -1; $i++){
        if ($bom_msp[$i].toString().Equals('')){continue;}
        $fileName= $bom_msp[$i];
        $filename= $filename.split(':');
        $result= Get-ChildItem -path $MSPsPath $filename[$filename.length-1].Trim();
        if ($result.length -ge 0 ){
            $retCode= cmd /c msiexec /p $result.FullName REINSTALL=ALL REINSTALLMODE=amus /qb /l*v ($logDirectory + $result.Name.trimEnd(".msp") + "_install.log"); #$filename[$filename.length-1]
        }
        if  ($retCode -eq $null) { #patching succeeded.
            set-content -path $LogInstall -value ('patching of ' + $result.Name + ' succeeded');
            continue;
        } 
        else {
            write-host $retCode;
            set-content -path $LogInstall -value ('patching of ' +  $result.Name + ' failed; error code: ' + $retCode);
			rollback
        }
   }#foreach
}

########################################################
# starting point of execution 
########################################################
clear;
write-host 'installation of delta packages begins at' (Get-Date).ToLongTimeString();

#evaluate input arguments
if ($args[0] -eq $null -or $args[1] -eq $null -or $args[2] -eq $null){
    write-host 'missing arguments; example:';
    write-host 'InstallDeltas.ps1 <MSP_Files_Directory> <BOM_MSP_file> <execution_mode>';
    write-host 'execution mode is either "-i" for install, or "-r" for rollback'
    break;
   }
   
$MSPsPath=  $args[0]; #Read-Host 'input the directory containing the MSPs'
$installPath= (Get-Location);
$XMLPath= '..\XML';

[string]$p=$args[0];

########################################################
#testing parameters
########################################################
if((Test-Path -path $p) -eq $false) {
    write-host "MSP directory not found: " $args[0];
    break;
}

$p=$args[1];
if((Test-Path -path $p) -eq $false) {
    write-host "BOM_MSP file not found: " $args[1];
    break;
}

$bom_MSP= get-content -path $args[1] #FileName to read the installation order

[string]$command= $args[2];


$list= Get-ChildItem $MSPsPath -recurse -include pms*.msp

switch ($command) { 
  #install  MPS
   -i {  #verify pre-requirements
        #unrebase the rebased files, so that 
        # verify pre-install passes MD5 checking
	   write-host 'unrebasing files...' (Get-Date).ToLongTimeString(); 
       Set-Content -Value ("unrebasing files begins..." +  (Get-Date).ToLongTimeString()) -Path $LogPreInstall;
        .\unrebase.ps1 'C:\Program Files\PMS\Fusion' >$logDirectory\Unrebase.log;
       Add-Content -Value ("unrebasing files ends..." +  (Get-Date).ToLongTimeString()) -Path $LogPreInstall; 
       # get-history -count 1|fl @{l="duration of unrebasing: "; e={$_.endexecutiontime - $_.startexecutiontime}};
        $beginDate= (get-date);
        write-host 'pre-patch verification begins at ' $beginDate.ToLongTimeString();
        $PreInstallVal= verifyPreInstall;
        $timediff= (Get-Date).Subtract($beginDate);
        write-host 'pre-patch verification ends at ' (Get-Date).ToLongTimeString();
        write-host `t 'Duration of pre-patch verification: ' $timediff.Minutes ' minutes, ' $timediff.Seconds ' seconds';
        if ($PreInstallVal -eq $true){
            write-host 'pre install validation succeeded!';
            $beginDate= (get-date);
            write-host 'installation begins at ' $beginDate.ToLongTimeString();
            install
            $timediff= (Get-Date).Subtract($beginDate);
            write-host 'installation ends at ' (Get-Date).ToLongTimeString();    
            write-host `t 'Duration of installation: ' $timediff.Minutes ' minutes, ' $timediff.Seconds ' seconds' -ForegroundColor Cyan;
        }
        
        else { #prepatching failed
            write-host "Pre-install verification failed.";
            #exit;
            $beginDate= (get-date);
            write-host 'installation begins at ' $beginDate.ToLongTimeString();
            install
            $timediff= (Get-Date).Subtract($beginDate);
            write-host 'installation ends at ' (Get-Date).ToLongTimeString();    
            write-host `t 'Duration of installation: ' $timediff.Minutes ' minutes, ' $timediff.Seconds ' seconds' -ForegroundColor Cyan;
            }

        #verify after installation
       $beginDate= (get-date);
       write-host 'post-patch verification begins at ' $beginDate.ToLongTimeString();
	   $postPatchVerification= verifyPostInstall;
	   $timediff= (Get-Date).Subtract($beginDate);
       write-host 'installation ends at ' (Get-Date).ToLongTimeString();    
       write-host `t 'Duration of post-patch verification: ' $timediff.Minutes ' minutes, ' $timediff.Seconds ' seconds' -ForegroundColor Cyan;
       if ($postPatchVerification -eq $true){
            write-host 'installation succeded';
            return 0; #return to Questra
        }

        else {
            rollback;
            return 2; #return to Questra
        };
    } #-i
    
   #remove MSPs
   -u {
        rollback;
    }
} 

write-host 'installation of delta packages ends at' (Get-Date).ToLongTimeString();