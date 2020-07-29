# Author: Dave Davis
# Website: www.virtualizestuff.com

#===================================================#
#   Modify Perennially Reserved for Phsyical RDMs   #
#===================================================#

# Global variable
$vcenter = "vcsa-a.homelab.virtualizestuff.com"
$Cluster1 = "compute"
$rdmPRreportLocation = "RDM-PR-report.csv"

# vCenter
Connect-VIServer -Server $vcenter

#=============#
#   Phase 1   #
#=============#

# ESXi Hosts Info. Since my environemnt is in linked mode I filter for specific vCenter
$vmhosts = Get-Cluster | Where-Object {$_.Name -eq $Cluster1} | Get-VMHost | 
Where-Object {$_.Uid -match "vcsa-a"} | Sort-Object

# RDMs Info
$RDMinfo = $vmHosts | Get-VM | Get-HardDisk -Disktype "rawPhysical" | `
Select ScsiCanonicalName, @{Name = "VM" ; Expression = {$_.parent}}, `
@{Name = "ESXiHost" ; Expression = {$_.parent.vmhost}}, `
@{Name = "Datastore" ; Expression = {$_.Filename.split("]")[0].trim("[")}}

Write-host "Informational: pRDMs shared between VMs" -ForegroundColor Yellow
# Identify duplicate SCSICanonicalNames
$RDMinfo | Group -Property ScsiCanonicalName | Where count -gt 1 | Select -ExpandProperty Group | Format-Table -AutoSize

# Create emptry array for report
$rdmPRreport = @()

#--------------------execute---------------------#
Write-host "Informational: Begin Perennially Reserved modification of pRDMs" -ForegroundColor Yellow
Write-Host "Format: [ host ] [ datastore ] [ naa id ] [ perennially reserved status ]" -ForegroundColor Darkblue
foreach ( $vmhost in $vmHosts.name) {
    $myesxcli = Get-EsxCli -VMhost $vmHost 
    foreach ($naa in $RDMInfo | ? VM -match "c-sql-node01"){
        $Result = New-Object PSObject
        $diskinfo = $myesxcli.storage.core.device.list($naa.SCSICanonicalName)
        if($diskinfo.IsPerenniallyReserved -eq "false"){
            #=============#
            #   Phase 2   # --> to set perennially reserved status remove the # below and modify the last $false to $true
            #=============#
            #$myesxcli.storage.core.device.setconfig($false,$naa.SCSICanonicalName,$true)
            $diskinfo = $myesxcli.storage.core.device.list($naa.SCSICanonicalName)
            $vmhost + " " + $naa.Datastore + " " + $naa.SCSICanonicalName + " " + `
            "PerenniallyReserved = " + $diskinfo.IsPerenniallyReserved
            $Result | add-member -membertype NoteProperty -name "Host" -Value $vmhost
            $Result | add-member -membertype NoteProperty -name "Datastore" -Value $naa.Datastore
            $Result | add-member -membertype NoteProperty -name "Disk Name" -Value $naa.SCSICanonicalName
            $Result | add-member -membertype NoteProperty -name "PR enabled?" -Value $diskinfo.IsPerenniallyReserved
            $rdmPRreport += $Result
        }
    }
}

Write-host "Informational: Completed Perennially Reserved modification of pRDMs" -ForegroundColor Yellow

# Export RDMs to CSV

Write-host "Exporting Datastore Report to: $rdmPRreportLocation" -ForegroundColor Green
$rdmPRreport | Export-Csv -Path $rdmPRreportLocation -NoClobber:$false