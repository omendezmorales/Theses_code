#script to compute MD5 values based on features.
#this script is called from callHashTools.ps1
# it receives the path of a given MSi administratively installed
# it also creates a file to store the files (to be installed) + their timestamp

#############################################################################
# known issues:
# if the filename is > 260 characters the gci cmdlet will fail; example:
# FSCGeoCVLArcBeamLongitudinalPotentiometerAdjustmentParamDic.xml
# Get-ChildItem : The specified path, file name, or both are too long. The fully
# qualified file name must be less than 260 characters, and the directory name mu
# st be less than 248 characters.
# At D:\Final Project\Code\Validation\MD5PerFeature.ps1:76 char:30
#############################################################################

###############################################################################
# validate args
###############################################################################
if($args[0] -eq $null -or $args[1] -eq $null -or $args[2] -eq $null)
{
    echo 'missing arguments; example of use:'
    echo 'MD5PerFeature.ps1 <fileName.msi> <path_Admin_install> <suffix: -t or -u>'
    break;
}

function GetVersion($MSIName){
    $SQLCommand= "select `Value` from `Property` where `Property`.`Property` = 'ProductVersion'";
    $productVersion -as [string] 
    return cscript /nologo .\WiRunSQL.vbs  $MSIName $SQLCommand;
   }
   
function Replace-String($find, $replace, $path)
      {
        echo "Replacing string `"$find`" with string `"$replace`" in file contents and file names of path: $path"
        ls $path | select-string $find -list |% { echo "Processing contents of $($_.Path)"; (get-content $_.Path) |% { $_ -replace $find, $replace } | set-content $_.Path -Force }
        #ls $path\*$find* |% { echo "Renaming $($_.FullName) to $($_.FullName.Replace($find, $replace))";mv $_.FullName $_.FullName.Replace($find, $replace) }
      }

function ReassemblePath($path){
    $newPath='';
    if ($path.length -ge 1)
    {
        foreach ($item in $path)
        {
            $newPath= $newpath + $item +  "\\";
        }
        return $newPath;
    }
}      

function getPath($component){
     $SQLcommand= "Select Directory_Parent from Directory, Component "  +
                " where Component.Directory_ = Directory.Directory "  +
                " and Component.Component ='" + $component.Trim() + "'";
    return cscript.exe /nologo .\WiRunSQL.vbs $db $SQLCommand;
}

function getUnique($found, $filePath){
    foreach ($item in $found){
        $tmp= $item.directoryName.Tolower();
        if ($tmp.Contains($filePath[0].ToLower()) -eq $true){
            return $item;
            }
        }
}

 function getGacPath ($found)
 {
    $actualPath= $env:windir + '\assembly\GAC';
    #find version, name and public key token
    $info = [System.Reflection.Assembly]::LoadFrom($found.FullName);
    $Assemblyname= $info.GetName().Name;
    $version = $info.GetName().Version.ToString();
    $PKT = $info.GetName().GetPublicKeyToken(); #public key token
    #iterate to convert PKT from hexa to decimal
    $decimalPKT= '';
    foreach ($byte in $PKT){
        $decimalPKT = $decimalPKT  + [Convert]::ToString($byte, 16)
     }
     #assemble path
     $actualPath = $actualPath + '\' `
                        + $Assemblyname + '\' `
                        + $version + '\' `
                        + $decimalPKT ; # + '\' 
                        #+ $found.Name;
    return $actualPath;                    
 }
 
function ComputeMD5($files)
{
    [string]$values ='';
    $defaultAdd= 10000000;
    #find the file
    foreach ($file in $files){
    #separate file and component
    $file = $file.split(" ");
    $component= $file[$file.length -1];
    $file= $file[0];
    #remove the piping stuff
    if ($file.Contains('|')) {
        $tmp= $file.split('|');
        $file = $tmp[$tmp.length -1].Trim();
        #echo 'after removing |:' $file
    }
        echo $file;
        $found = $null;
        if ($file -eq $null -or $file.Length -le 0) {continue;}
        $found= get-childitem -Path $path $file -recurse
        
        if ($found.GetType().BaseType.Name.Equals('Array') -and ($found -ne $null)){
        # more than 1 file Found with the same name, 
        # we just want the one that matches the component
            #echo $found.GetType();
            $component = getPath($component);
            $found = getUnique $found $component;
        }
        echo 'computing MD5 for' $found.fullname #`t $tmp[$tmp.length -1].Trim();
         # rebase files to default address and timestamp
        if ($found -ne $null -and $found.Length -gt 0){ 
            $tmp= $found.Extension.ToUpper();
           # only files located in 'program files\pms\fusion' directory are (un)rebased
            if (($tmp.Contains(".SDM") -or $tmp.Contains(".OCX") -or $tmp.Contains(".DLL")) -and 
                    ($found.DirectoryName.Contains('Windows') -eq $false) -and
                    ($found.DirectoryName.Contains('Fusion') -eq $true))
                    {
             #Add-Content  -Value $values -Path $timeStampsFile;
                .\RebaseDLL $found.fullName $defaultAdd;
            }
         
            #compute its MD5 value
            .\fciv.exe -add $found.FullName -xml $XMLfile;
            
            if ($found.Directory.FullName.Contains('GlobalAssemblyCache') -eq $true){
                # replace globalassemblycache in the path, for the actual path
                $tmp= getGacPath $found;         
                Replace-String "c:\\GlobalAssemblyCache" $tmp $XMLfile;
           }
        }
    
    }
   
}


$tmp=$args[2];
$XML_suffix= '_Target';
switch ($tmp) { 
  
   -t {
        $XML_suffix= '_Target';
    }
   
   -u {
       $XML_suffix= '_Upgrade';
    }
   }
   
[string]$OutputDir= '..\XML\';
   if ((Test-Path $OutputDir) -eq $false) { mkdir $OutputDir;}
$DB = $args[0];
$path = $args[1];
$NameSuffix= 
$tmp= $db.split('\');
[string]$version= GetVersion $db;
$version= "_" + $version.Trim();
$XMLfile= $OutputDir + ($tmp[$tmp.length-1].trim('.msi') + $version + $XML_suffix + '.xml');

#create the .csv file that contains timestamps for rebasable files.
$timeStampsFile= $OutputDir +  ($tmp[$tmp.length-1].trim('.msi') + $version + '_ts.csv'); #use comma delimited files; later decide to use another format
$tmp = "file,second,minute,hour,day,month,year";
#set-Content  -Value $tmp -Path $timeStampsFile;

#select features from the MSI
$SQLCommand = 'select `Feature` FROM `Feature` order by `Feature`';
$Features= cscript.exe  /nologo .\WiRunSQL.vbs $db $SQLCommand
#echo $Features.length;
#echo $db.gettype();

foreach($feat in $features){
    IF ($feat.Contains('_PROD')){#echo $feat
        $SQLCommand = "select `File`.`FileName`, `File`.`Component_` from `File`," + #`File`.`File`, 
                      "`Component`,`FeatureComponents` where `File`.`Component_` " + 
                      "= `Component`.`Component` and "  +
                      "`FeatureComponents`.`Component_` = `Component`.`Component` "  + 
                      "and `FeatureComponents`.`Feature_`= '" + $feat + 
                      "' order by `File`.`FileName` ";  
        $Files= cscript.exe  /nologo .\WiRunSQL.vbs $db $SQLCommand;  
        echo $files.Length;                    
        ComputeMD5 $files;
        }
}
# remove the files base path; this path won't be used when verifying the files 
# in the actual system
$chopped= $path.split('\');
$tmp= ReassemblePath $chopped;
Replace-String $tmp.toLower() "c:\" $XMLfile;
Replace-String "c:\\winroot" "c:" $XMLfile;