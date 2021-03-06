﻿[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
#compute MD5 values for the MSP files
#example of use:
# MD5s4MSPs.ps1 <valid_path_with_MSPs>

clear;
[string]$OutputDir= '..\XML\';
echo (Get-Date).DateTime
$MSPsPath= $args[0];
if ($args[0] -eq $null) {
    $MSPsPath= Read-Host 'input the directory containing the generated MSPs ';
}

if ($MSPsPath -ne $null -and (Test-Path -Path $MSPsPath)){
    $MSPs= Get-ChildItem -Path $MSPsPath -Include *.msp;
     echo 'creating xml database';
     if((Test-Path -path .\fciv.err) -eq $true) {
        del .\fciv.err;
     }
     cmd /c .\fciv.exe -wp $MSPsPath -wp -type *.msp -MD5 -xml ($OutputDir  + 'MSPs.xml')
     echo 'checking if there are errors...'
      if((Test-Path -path .\fciv.err) -eq $true) {
        $errors =cmd /c findstr.exe /n "Error msg" fciv.err;
      }  
     if ($errors -ne $null){
        echo $errors
     }
     else{
        echo 'computation of MD5 values for MSPs succeeded';
     }

}
else{
    [System.Windows.Forms.MessageBox]::Show("Path does not exist", "InvalidPath");
}
echo 'computation ended at ' (Get-Date).DateTime
