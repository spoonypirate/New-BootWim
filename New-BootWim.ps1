#arch choices 
$arch = "amd64"

$smsts = @"
[Logging] 
LOGLEVEL=0 
LOGMAXSIZE=16000000 
LOGMAXHISTORY=1 
DEBUGLOGGING=0
"@
$unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Description>Lite Touch PE</Description>
                    <Order>1</Order>
                    <Path>wscript.exe X:\Scripts\WaitForNetwork.vbs</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
"@

$features = @("WMI","Scripting","WDS-Tools","SecureStartup","NetFX","PowerShell","DismCmdlets","EnhancedStorage")

#These are under the assumption that you ran copype.cmd to the below directories
if ($arch -eq "amd64" ) {
    $pedir = "C:\WinPEMount"
    $arch2 = "x64"
    $pemount = "$pedir\$arch2\mount"

    $driverstore = "\\fileserver\software`$\Drivers\Sources\DellCatalog_SCCM\WinPE 10\$arch2\network"
    $drivers = @(
        "$driverstore\CFXPV_A00-00\Windows10-x64\rtux64w10.inf",
        "$driverstore\6CC2C_A00-00\Windows10-x64\net7500-x64-n630f.inf",
        "$driverstore\N6RY0_A00-00\E1Q\E1Q63x64.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x64\E1C65x64.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x64\E1D65x64.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x64\E1R65x64.inf",
        "$driverstore\RJFNY_A00-00\NETAX88772.inf"
    )
    } else { 
    $pedir = "C:\WinPEMount"
    $arch2 = "x86"
    $pemount = "$pedir\$arch2\mount"

    $driverstore = "\\fileserver\software`$\Drivers\Sources\DellCatalog_SCCM\WinPE 10\$arch2\network"
    $drivers = @(
        "$driverstore\CFXPV_A00-00\Windows10-x86\rtux86w10.inf",
        #"$driverstore\6CC2C_A00-00\Windows10-x64\net7500-x64-n630f.inf",
        #"$driverstore\N6RY0_A00-00\E1Q\E1Q63x64.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x86\E1C6532.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x86\E1D6532.inf",
        "$driverstore\KJTXR_A00-00\Windows10-x86\E1R6532.inf"
        #"$driverstore\RJFNY_A00-00\NETAX88772.inf"
    )
    }


$subdirs = @("fwfiles","media","media\sources","mount")
$fwfiles = @("efisys.bin","etfsboot.com","oscdimg.exe")

if (Test-Path $pemount) { dism.exe /unmount-wim /mountdir:$pemount /discard }
if (Test-Path $pedir) { Remove-Item -Path $pedir -Recurse }
if (!(Test-Path -Path $pedir)) { New-Item -Path $pedir -ItemType Directory }

foreach ($subdir in $subdirs) { New-Item -Path $pedir -Name $subdir -ItemType Directory }
copy-item -path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$arch\Media" -Container -Destination "$pedir" -Force -Recurse
copy-item -path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$arch\en-us\winpe.wim" -Destination "$pedir\media\sources\boot.wim"
foreach ( $fwfile in $fwfiles) { Copy-Item -Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$arch\Oscdimg\$fwfile" -Destination "$pedir\fwfiles\$fwfile" }
$peOCs = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$arch\WinPE_OCs"

dism.exe /mount-wim /wimfile:$pedir\media\sources\boot.wim /index:1 /mountdir:$pemount

foreach ( $feature in $features ) {
    dism.exe /image:$pemount /add-package /packagepath:"$peOCs\WinPE-$feature.cab"
    dism.exe /image:$pemount /add-package /packagepath:"$peOCs\en-us\WinPE-${feature}_en-us.cab"
    }
foreach ( $driver in $drivers ) {
    dism.exe /image:$pemount /add-driver /driver:"$driver"
    }

if (!(Test-Path -Path "$pemount\Windows\smsts.ini")) {  New-Item -Path "$pemount\Windows" -Name "smsts.ini" -ItemType File }
Set-Content -Path "$pemount\Windows\smsts.ini" -Value $smsts
if (!(Test-Path -Path "$pemount\unattend.xml")) { New-Item -Path $pemount -Name "unattend.xml" -ItemType File }
Set-Content -Path "$pemount\unattend.xml" -Value $unattend
if (!(Test-Path -Path "$pemount\Scripts")) { New-Item -Path $pemount -Name "Scripts" -ItemType Directory }
if (!(Test-Path -Path "$pemount\Scripts\WaitForNetwork.vbs")) { New-Item -Path "$pemount\Scripts\WaitForNetwork.vbs" -ItemType File }
Set-Content -Path "$pemount\Scripts\WaitForNetwork.vbs" -Value "wscript.sleep 10000" 
Copy-Item -Path ".\cmtrace.exe" -Destination "$pemount\Windows\system32\cmtrace.exe"

dism.exe /unmount-wim /mountdir:$pemount /commit
dism.exe /export-image /sourceimagefile:$pedir\media\sources\boot.wim /sourceindex:1 /destinationimagefile:$pedir\winpe_${arch}.wim
Copy-Item -Path "$pedir\winpe_$arch.wim" -Destination "$pedir\media\sources\boot.wim" -Force 
cmd /c "$pedir\fwfiles\oscdimg" -b"$pedir\fwfiles\etfsboot.com" -n $pedir\media $pedir\winpe_${arch}_bios.iso
cmd /c "$pedir\fwfiles\oscdimg" -b"$pedir\fwfiles\efisys.bin" -n $pedir\media $pedir\winpe_${arch}_efi.iso