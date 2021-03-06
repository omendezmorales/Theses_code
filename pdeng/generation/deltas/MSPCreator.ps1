[System.Reflection.Assembly]::LoadWithPartialName(“System”) # load at the beginning of the file.
########################################################
#script to create PCP and MSP files
########################################################
$script:PatchName -as [string];
function getLargestSeq
{
    $SQLCommand= 'Select `Media`.`LastSequence` from `Media`';
    $SeqTarget = cscript /nologo .\WiRunSQL.vbs  $TargetFile $SQLCommand; 	
    $SeqUpgrade = cscript /nologo .\WiRunSQL.vbs  $UpgradeFile $SQLCommand;
    [int]$t= $SeqTarget[0]; 
    [int]$u= $SeqUpgrade[0];
    if ($u -gt $t)
        {return $u}
    else {return $t}    
}

function ModifyVersion
{
    param ($FileName)
    $SQLCommand= "select `Value` from `Property` where `Property`.`Property` = 'ProductVersion'";
    $productVersion -as [string] 
    $tmp -as [string] 
    $productVersion=cscript /nologo .\WiRunSQL.vbs  $FileName $SQLCommand;
    $shortversion = $productVersion[0].split('.')
    $SQLCommand= "update `Property` set `Value` = '" + $shortversion[0]+ "."+ $shortversion[1] + "."+ $shortversion[2] +
            "' where `Property`.`Property` = 'ProductVersion'";
	#echo "-->Running SQL on $FileName : $SQLCommand"
    cscript /nologo .\WiRunSQL.vbs  $FileName $SQLCommand; 
    
    #assemble patch file name
    if ($PatchName.Equals("")) {
        if ($FileName.GetType().name -eq 'String') {
             $FileName=$FileName.split("\");
                         $PatchName=$FileName[$fileName.length -1].TRimEnd(".msi") + "_"+ $shortversion[0]+  
                        $shortversion[1] + $shortversion[2] ;
        }
        else {
            $PatchName=$FileName.name.TrimEnd(".msi") + "_"+ $shortversion[0]+
          $shortversion[1] + $shortversion[2] ;}
        return $PatchName;
    }
    elseif ($PatchName.length -gt 0){ #second part of the patch name 
        $tmp = "_"+ $shortversion[0]+  $shortversion[1] + $shortversion[2] + ".msp";
        return $PatchName.Trim() + $tmp.Trim();
    }
    else {$PatchName='MyPatch.msp'}
}
#input parameters: Target filename and Upgrade filename 
echo  "entering " $MyInvocation.ScriptName  " with Args" $args[0]  " and "  $args[1] 
$TargetFile=$args[0];
$UpgradeFile= $args[1];
$SQLCommand='';
[string]$script:PatchName='';
#if($TargetFile.Name -ne $UpgradeFile.Name){
 #   echo 'Target and Upgrade files have different names!' `n  'generation skipped'
  #  continue 
#}


#verify ProductVersion property; if both are = then skip rest of process
$SQLCommand= "select `Value` from `Property` where `Property`.`Property` = 'ProductVersion'";
[string]$productVersionTarget =  cscript /nologo .\WiRunSQL.vbs  $TargetFile $SQLCommand;
[string]$productVersionUpgrade =  cscript /nologo .\WiRunSQL.vbs  $UpgradeFile $SQLCommand;
if ($productVersionTarget.equals($productVersionUpgrade)){
    echo "both target and upgrade MSIs have the same version, there's nothing to update";
    continue;
}


# the script does the following:
########################################################
#Prepare a temp working folder
########################################################
if (test-path temp)
{
	del -recurse -force temp
}
mkdir temp
mkdir temp\target
mkdir temp\upgrade

########################################################
#Prepare input MSIs
########################################################

#make productCode the same for target and upgrade files
$SQLCommand= "select `Value` from `Property` where `Property`.`Property` = 'ProductCode'";
$productCode -as [string] 
$productCode =  cscript /nologo .\WiRunSQL.vbs  $TargetFile $SQLCommand;
$SQLCommand= "update `Property` set `Value` = '" + $productCode[0].Trim() + "' where `Property`.`Property` = 'ProductCode'";
#echo "-->Running SQL on $UpgradeFile : $SQLCommand"
cscript /nologo .\WiRunSQL.vbs  $UpgradeFile $SQLCommand;

#Assert that ProductVersions contain only 3 fields. 
$PatchName=ModifyVersion $TargetFile
$PatchName=ModifyVersion $UpgradeFile    

########################################################
#Unpack MSIs
########################################################
[string]$CD = $env:TEMP;
echo "Current dir ==== $CD"
if ($TargetFile.gettype().Name.Equals("String")) {
    $tmp= $TargetFile.split("\");
    $tmp= $tmp[$tmp.length -1].TRimEnd(".msi");
}
else{
    $tmp= $TargetFile.Name;
    $tmp= $tmp.TRimEnd(".msi");
}
 
#echo $location2;

[string]$Installpath=  $env:TEMP + "\Target\" + $tmp; #(Get-Location).Path 
cmd /c msiexec /a $TargetFile  /qb TARGETDIR=$Installpath; # $env:TEMP\Target$TargetFile.Name.TRim(".MSI")

#now target file becomes unpacked msi
$TargetFile = Split-Path -leaf -path $TargetFile
$TargetFile = $CD + "\target\" + $tmp + "\" + $TargetFile #$TargetFile

if ($UpgradeFile.gettype().Name.Equals("String")) {
    $tmp= $UpgradeFile.split("\");
    $tmp= $tmp[$tmp.length -1].TRimEnd(".msi");
}
else{
    $tmp= $UpgradeFile.Name;
    $tmp= $tmp.TRimEnd(".msi");
}
$Installpath= $env:TEMP  + "\Upgrade\" + $tmp;
cmd /c msiexec /a $UpgradeFile /qb TARGETDIR=$Installpath ; #$env:TEMP\Upgrade$UpgradeFile.Name.TRim(".MSI")
#now upgrade file becomes unpacked msi
$UpgradeFile = split-path -leaf -path $UpgradeFile
$UpgradeFile = $CD + "\upgrade\" + $tmp + "\" + $UpgradeFile; #$UpgradeFile
   
########################################################
#Fill  the PCP file
########################################################
#copies an empty pcp file from the sample from SDK
$pcpFile =    $env:SystemDrive.ToString() +
        '\Program Files\Windows Installer 4.5 SDK\patching\template.pcp';
Copy-Item  -path $pcpFile -Destination (Get-Location)
$pcpFile = 'template.pcp'
#Modify Properties Table 

$SQLCommand= "update Properties set Properties.Value ='"+ $PatchName.TRim() +"' " +
            " where Properties.Name= 'PatchOutputPath'";
#echo "-->Running SQL on $pcpFile : $SQLCommand"
cscript /nologo .\WiRunSQL.vbs  $pcpFile  $SQLCommand; 

[string]$guid= "{" +  [system.Guid]::NewGuid().ToString() + "}";
$GUID= $guid.Trim();
$SQLCommand= "update Properties set Properties.Value ='"+ $guid.ToUpper() +"'" +
             " where Properties.Name= 'PatchGUID'";
cscript /nologo .\WiRunSQL.vbs  $pcpFile  $SQLCommand;
$SQLCommand= "insert into Properties(Value, Name) values('1', 'OptimizePatchSizeForLargeFiles')";
cscript /nologo .\WiRunSQL.vbs  $pcpFile  $SQLCommand;

#Modify TargetImages Table
$SQLCommand= "insert into TargetImages (`TargetImages`.``Order`` , `TargetImages`.`Target`,`TargetImages`.`MsiPath`," +  
         "`TargetImages`.`Upgraded`,`TargetImages`.`IgnoreMissingSrcFiles`, `TargetImages`.`ProductValidateFlags`) " +
           "values(1,'previous','" + $TargetFile + "','newer', 0, '0x00000922')";

#echo "-->Running SQL on $pcpFile : $SQLCommand"
cscript /nologo .\WiRunSQL.vbs $pcpFile $SQLCommand;

$fam='family1'
if ($TargetFile.Name.Length -ge 1) {
    $fam= $TargetFile.Name
    $fam= $fam.TrimEnd(".msi");
    $fam= $fam.TrimsTART("pms_");
    if ($Fam.length -gt 8) {$fam= $fam.substring(0,8)}
}
#Modify ImageFamilies Table 
#$LastSequence = getLargestSeq($TargetFile, $UpgradeFile);
[int]$SeqNum= getLargestSeq($TargetFile, $UpgradeFile); #$lastSequence[0];
$SeqNum= $SeqNum + 1;
$SQLCommand= "insert into `ImageFamilies` (`Family`,`MediaSrcPropName`,`MediaDiskId`, `FileSequenceStart` ) VALUES ('" +
             $fam + "', '"+ $fam +"_MediaSrcPropName', 2," + $SeqNum +")"; #" + $LastSequence + "
echo "-->Running SQL on $pcpFile : $SQLCommand"
cscript /nologo .\WiRunSQL.vbs $pcpFile  $SQLCommand

#Modify UpgradedImages Table 
$SQLCommand= "insert into UpgradedImages (`Upgraded`,`MsiPath`,`PatchMsiPath`,`SymbolPaths`,`Family`) " `
            + " values ('newer','" + $UpgradeFile +"','',' ', '" + $fam + "')"; #" + (Get-Location) +"
echo "-->Running SQL on $pcpFile : $SQLCommand"            
cscript /nologo .\WiRunSQL.vbs $pcpFile $SQLCommand

#Modify PatchSequence Table 
$SQLCommand= "insert into ``PatchSequence`` (``PatchFamily``, ``Target``, ``Sequence``, ``Supersede``)" + 
              " Values('"+ $fam +"',NULL,NULL,1)";
cscript /nologo .\WiRunSQL.vbs $pcpFile $SQLCommand

########################################################
#create a MSP file 
########################################################
echo 'creating patch...'
[string]$OutputDir= '..\MSP\';
   if ((Test-Path $OutputDir) -eq $false) { mkdir $OutputDir;}
   
$logFile= (Get-Date).Year.ToString() + 
          (Get-Date).Month.ToString() + 
          (Get-Date).Day.ToString() + 
          '_' +(Get-Date).hour.ToString() + 
          (Get-Date).minute.ToString() +'.log'; 
$retval -as [string] 
$retval = Msimsp.exe -s $pcpFile -p ($OutputDir + $PatchName.Trim()) -l Allura.log
#Allura.log #$logFile $PatchName

if ( $retval.length -gt 0){ 
   #$retval = $retval.split(':')
            echo 'generation failed; check log';
            cmd /c findstr.exe /n ERROR Allura.log
      #  type  Allura.log; #works
    }
 else {echo 'done!'} 
 