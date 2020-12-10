#Connect to NSX-T Manager and vCenter
Connect-NsxtServer -Server "NSX-T Manager URL or IP" -User admin -Password "Password here"

Connect-VIServer -Server "vCenter URL or IP" -User "administrator@vsphere.local" -Password "Password here"

# Set to VM Network portgroup. Used to quickly change portgroup setting to "VM Network" when I was testing.
Get-VM "nsxt_lab01_mgmt-esxi01",
       "nsxt_lab01_mgmt-esxi02",
       "nsxt_lab01_mgmt-esxi03",
       "nsxt_lab01_mgmt-esxi04",
       "nsxt_lab01_comp-esxi01",
       "nsxt_lab01_comp-esxi02",
       "nsxt_lab01_comp-esxi03" |  Get-NetworkAdapter | Set-NetworkAdapter -NetworkName "VM Network" -Confirm:$false

# Set to nsxt backed portgroup. Used to quickly change portgroup setting to "NSX-T Backed Portgroup i.e. nsxt_lab01_mgmt_vmk0_subnet_100" when I was testing.
Get-VM "nsxt_lab01_mgmt-esxi01",
       "nsxt_lab01_mgmt-esxi02",
       "nsxt_lab01_mgmt-esxi03",
       "nsxt_lab01_mgmt-esxi04",
       "nsxt_lab01_comp-esxi01",
       "nsxt_lab01_comp-esxi02",
       "nsxt_lab01_comp-esxi03" | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName "nsxt_lab01_mgmt_vmk0_subnet_100" -Confirm:$false

# Quickly set Network to VM Network to reset and test script against hosts again.
Get-VM | Get-NetworkAdapter  | Where-Object {$_.NetworkName -eq "nsxt_lab01_mgmt_vmk0_subnet_100"} | Set-NetworkAdapter -NetworkName "VM Network" -Confirm:$false

# Dot Sourcing the NSX-T Functions 
. ./'NSX-T_Parent-Child_Functions'.ps1

# Create Parent and Child Ports. 
# Make sure to change below parameters that are relevant to your environment. The information below was used in the youtube video. 
# Youtube Video - https://www.youtube.com/watch?v=rLEVcm5A-rg
New-NsxtParentPort -VmName  "nsxt_lab01_mgmt-esxi01",
                            "nsxt_lab01_mgmt-esxi02",
                            "nsxt_lab01_mgmt-esxi03",
                            "nsxt_lab01_mgmt-esxi04",
                            "nsxt_lab01_comp-esxi01",
                            "nsxt_lab01_comp-esxi02",
                            "nsxt_lab01_comp-esxi03"  | 
New-NsxtChildPort -Name "workload1",
                        "workload2",
                        "host-overlay",
                        "edge-overly",
                        "mgmt",
                        "vmotion",
                        "vsan",
                        "nfs" `
                  -VLAN "80",
                        "81",
                        "90",
                        "91",
                        "0",
                        "101",
                        "102",
                        "103" `
                  -LogicalSwitchName "nsxt_lab01_workload1_vmk0_subnet_80",
                                     "nsxt_lab01_workload2_vmk0_subnet_81",
                                     "nsxt_lab01_host-overlay_vmk0_subnet_90",
                                     "nsxt_lab01_edge-overlay_vmk0_subnet_91",
                                     "nsxt_lab01_mgmt_vmk0_subnet_100",
                                     "nsxt_lab01_vmotion_vmk0_subnet_101",
                                     "nsxt_lab01_vsan_vmk0_subnet_102",
                                     "nsxt_lab01_nfs_vmk0_subnet_103" 