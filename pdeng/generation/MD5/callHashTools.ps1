########################################################
#script to compute MD5 values for a set of files administratively installed 
# using msiexec.exe the computation done is Allura-system wide.
# This script assumes there are two MAIN 'root' directories:
#a target directory which contains all the subsystem directories
#that belong to the base version, and
#an upgrade dir containing all the subsystem directories 
#that belong to the upgrade version
#examples of usage are:
#callHashtools c:\temp\target c:\temp\upgrade 
########################################################
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
clear; 
echo (Get-Date).DateTime
#evaluate input arguments
if ($args[0] -eq $null -or $args[1] -eq $null){
    echo 'missing arguments; example:';
    echo 'callHashTools.ps1 <Target_Root_Directory> <Upgrade_Root_Directory>';
    break;
   }

#compute MD5 values for the MSP files
$option= Read-Host 'compute MD5 values for MSP files? (y/n):'
if($option -eq 'y' -or $option -eq 'Y'){
    .\MD5s4MSPs.ps1
}

$dirsTarget = dir $args[0] | Where {$_.psIsContainer -eq $true} | sort;
$dirsUpgrade = dir $args[1] | Where {$_.psIsContainer -eq $true} | sort;
if ($dirsTarget.length -ne $dirsUpgrade.Length){
    [System.Windows.Forms.MessageBox]::Show("Both Target and Upgrade directories must have = number of directories")
    break;
}

$index=0;
foreach ($item in $dirsTarget){
    #here $item represents the sub-directory where the admin install subsystem is
    #.\ComputeMD5s.ps1 $item.FullName $dirsUpgrade[$index].FullName;
    
    $msi= Get-ChildItem $item.FullName *.msi;
    if ($msi -ne $null){ 
        .\MD5PerFeature.ps1 $msi.FullName $item.FullName -t
        $msi= Get-ChildItem $dirsUpgrade[$index].FullName *.msi;
        .\MD5PerFeature.ps1 $msi.FullName  $dirsUpgrade[$index].FullName -u
        $index++;
        }
    }


#get-history -count 1 | fl @{l="Duration of computation: "; e={$_.EndExecutionTime - $_.StartExecutionTime}}
echo  'computation ended at ' (Get-Date).DateTime