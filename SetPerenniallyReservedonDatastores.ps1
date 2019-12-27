#===============================================#
#   Modify Perennially Reserved on Datastores   #
#===============================================#

# Global variable
$vcenter = "vcsa-a.homelab.virtualizestuff.com"
$Cluster1 = "compute"
$datastorePRreportLocation = "Datastore-PR-report.csv"

# vCenter
Connect-VIServer -Server $vcenter

#=============#
#   Phase 1   #
#=============#

#--------------------execute---------------------#

# ESXi Hosts Info
$vmhosts = Get-Cluster | Where-Object {$_.Name -eq $Cluster1} | Get-VMHost |
Where-Object {$_.Uid -match "vcsa-a"} | Sort-Object

# Return everything
foreach ($vmhost in $vmhosts) {
    (Get-Log -VMHost $vmhost vmkernel).Entries
}

# Filtered but contains duplicates
foreach ($vmhost in $vmhosts) {
    Write-Host $vmhost.name.split(".")[0] "filtered but contains duplicates:" -ForegroundColor Yellow
    (Get-Log -VMHost $vmhost vmkernel).Entries | 
    Where-Object {$_ -like “*marked perennially reserved*“} |
    ForEach-Object {$_.split(')')[1]} 
}

# Filter VMkernel Logs per host selecting only the unique values
foreach ($vmhost in $vmhosts) {
    Write-Host $vmhost.name.split(".")[0] "filtered vmkernel log:" -ForegroundColor Yellow
    (Get-Log -VMHost $vmhost vmkernel).Entries | 
    Where-Object {$_ -like “*marked perennially reserved*“} |
    ForEach-Object {$_.split(')')[1]} |
    Select-Object -Unique
}

# Below is the formating for what will be displayed. Datastores can be backed by a single LUN [s] or multiple LUNs [m]
Write-Host "Format: [ [s]ingle or [m]ultiple LUNs ] [ host ] [ datastore ] [ naa id ] [ perennially reserved status ]" -ForegroundColor Darkblue
Write-host "Informational: Begin Perennially Reserved modification of Datastores" -ForegroundColor Yellow
$datastorePRreport = @()
foreach ($vmhost in $vmhosts) {
    $myesxcli = Get-EsxCli -VMHost $vmhost
    foreach ($DS in (Get-Datastore -VMHost $vmhost | Where-Object {$_.type -eq "vmfs" -and $_.name -ne "SQLOSDS" })){
        $Result = New-Object PSObject
        # Runs if Datastore is backed by multiple LUNs iterate through them
        $DSlistnaa = $DS.ExtensionData.INfo.Vmfs | Select-Object Name, @{Name = "naa" ; Expression = {$_.extent.diskname}}
        $naaCount = $DSlistnaa.naa.count
        if ($naaCount -gt 1){
            foreach ($na in $DSlistnaa.naa){
                $Result = New-Object PSObject
                $diskinfo = $myesxcli.storage.core.device.list("$na") | Select-Object Device, IsPerenniallyReserved
                                                     # change me #
                                                     #     ↓↓    #
                if (($diskinfo.IsPerenniallyReserved -eq "true")){
                    $Result | add-member -membertype NoteProperty -name "Host" -Value $vmhost
                    $Result | add-member -membertype NoteProperty -name "Datastore" -Value $DS
                    $Result | add-member -membertype NoteProperty -name "Disk Name" -Value $na
                    $Result | add-member -membertype NoteProperty -name "PR enabled?" -Value $diskinfo.IsPerenniallyReserved
                    $datastorePRreport += $Result

                    #=============#
                    #   Phase 2   # --> to set perennially reserved status remove the # below and modify the last $false to $true
                    #=============#
                                                                    # change me #
                                                                    #     ↓↓    #
                    #$myesxcli.storage.core.device.setconfig($false,$na,$false)
                    $diskinfo = $myesxcli.storage.core.device.list("$na") | Select-Object Device, IsPerenniallyReserved
                    Write-Host "[m]" $vmhost, $DS, $na, $diskinfo.IsPerenniallyReserved
                }
            }
        }
        # Runs if the above statement is false
        Else{
            $naa = $DS.ExtensionData.Info.vmfs.extent[0].diskname
            $diskinfo = $myesxcli.storage.core.device.list("$naa") | Select-Object IsPerenniallyReserved
                                                 # change me #
                                                 #     ↓↓    #
            if (($diskinfo.IsPerenniallyReserved -eq "true")){
                $Result | add-member -membertype NoteProperty -name "Host" -Value $vmhost
                $Result | add-member -membertype NoteProperty -name "Datastore" -Value $DS
                $Result | add-member -membertype NoteProperty -name "Disk Name" -Value $DS.ExtensionData.Info.vmfs.extent[0].diskname
                $Result | add-member -membertype NoteProperty -name "Is PR'd?" -Value $diskinfo.IsPerenniallyReserved
                $datastorePRreport +=  $Result

                #=============#
                #   Phase 2   # --> to set perennially reserved status remove the # below and modify the last $false to $true
                #=============#
                                                                 # change me #
                                                                 #     ↓↓    #
                #$myesxcli.storage.core.device.setconfig($false,$naa,$false)
                $diskinfo = $myesxcli.storage.core.device.list("$naa") | Select-Object IsPerenniallyReserved
                Write-Host "[s]" $vmhost, $DS, $DS.ExtensionData.Info.vmfs.extent[0].diskname, $diskinfo.IsPerenniallyReserved
            }
        }
    }
}

Write-host "Informational: Completed Perennially Reserved modification of Datastores" -ForegroundColor Yellow

Write-host "Exporting Datastore Report to: $datastorePRreportLocation" -ForegroundColor Green
$datastorePRreport | Export-Csv -Path $datastorePRreportLocation


#--------------------verify---------------------#

# Delete vmkernel log on datastore
$datastore = Get-Datastore "nfs01-a"
New-PSDrive -Name "vsphere" -Root \ -PSProvider VimDatastore -Location $datastore 
foreach($vmhost in $vmhosts.name.Replace('.homelab.virtualizestuff.com','')){
    Remove-Item vsphere:/Scratch/$vmhost/vmkernel.log
}
Remove-PSDrive -Name "vsphere" -Confirm:$false

# Restart Syslog Service to recreate the vmkernel logs
Get-VMHost $vmhosts | Foreach-Object { Restart-VMHostService -Confirm:$false -HostService ($_ | Get-VMHostService | Where-Object { $_.Key -eq "vmsyslogd"} )} 

# Rescan VMFS 
$vmhosts | Get-VMHostStorage -RescanVmfs

# Filter VMkernel Logs per host selecting only the unique values
foreach ($vmhost in $vmhosts) {
    Write-Host $vmhost.name.split(".")[0] "filtered vmkernel log:" -ForegroundColor Yellow
    (Get-Log -VMHost $vmhost vmkernel).Entries | 
    Where-Object {$_ -like “*marked perennially reserved*“} |
    ForEach-Object {$_.split(')')[1]} |
    Select-Object -Unique
}