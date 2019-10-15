<#
.SYNOPSIS
  Connects to Azure and check VM nic for ASG assignment

.DESCRIPTION
  This runbooks check for all VM Nic assigned to an Application Security Group and returns the list of VMs.

.PARAMETER SubscriptionName
   Optional with default of "1-Prod".
   The name of an Azure Subscription stored in Automation Variables. To use an subscription with a different name you can pass the subscription name as a runbook input parameter or change
   the default value for this input parameter.
   
   To reduce error, create automation account variables called "Prod Subscription Name" and "DevTest Subscription Name"

.PARAMETER Location
   Optional with default of "australiasoutheast".
   The name of an Azure location to check the Application Security Groups Virtual Machine lists.

.NOTES
	Created By: Eric Yew - OLIKKA
	LAST EDIT: Oct 14, 2019
	By: Eric Yew
	SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/Get-AppSecGrp_VMList.ps1
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $SubscriptionName = "1-Prod, 2-Dev/Test *Defaults to Prod*",

    [Parameter(Mandatory=$false)] 
    [String] $Location = "australiasoutheast"
)

# Error Checking: Trim white space from both ends of string enter.
$SubscriptionName = $SubscriptionName.trim()	

# Retrieve subscription name from variable asset if not specified
    if($SubscriptionName -eq "1" -Or $SubscriptionName -eq "1-Prod, 2-Dev/Test *Defaults to Prod*")
    {
        $SubscriptionName = Get-AutomationVariable -Name 'Prod Subscription Name'
        $SubscriptionID = Get-AutomationVariable -Name 'Prod Subscription ID'
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name: [$SubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'Prod Subscription Name' was found. Either specify an Azure subscription name or define the 'Prod Subscription Name' variable setting"
        }
    }
    elseIf($SubscriptionName -eq "2")
    {
        $SubscriptionName = Get-AutomationVariable -Name 'DevTest Subscription Name'
        $SubscriptionID = Get-AutomationVariable -Name 'DevTest Subscription ID'
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name: [$SubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'DevTest Subscription Name' was found. Either specify an Azure subscription name or define the 'DevTest Subscription Name' variable setting"
        }
    }
    else
    {
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$SubscriptionName]"
        }
    }

#Connect to Azure
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name AzureRunAsConnection         

        "Logging in to Azure..."
        Connect-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection AzureRunAsConnection not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

#Use Subscription ID if Prod or DevTest subscription to avoid errors should Subscription be renamed
    if($SubscriptionName -eq "1" -Or $SubscriptionName -eq "1-Prod, 2-Dev/Test *Defaults to Prod*" -Or $SubscriptionName -eq "2")
    {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    }
    else
    {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName
    }

#Gets App Sec Group and all nics in region
    $ASGs = Get-AzureRmApplicationSecurityGroup
    $nics = Get-AzureRmNetworkInterface

#Compare ASG and VM Nic assigned with ASG and add to hashtable
    $ASGVMList = @{}

    foreach($ASG in $ASGs){
        if($ASG.Location -eq $location){
            $VMlist = @()
            foreach($nic in $nics){
                $asgIDs = $nic.IpConfigurations.ApplicationSecurityGroups.id  
                foreach($asgID in $asgIDs){                      
                    if($ASG.Id -like $asgID){
                        $Vm = get-azurermresource -ResourceId $nic.VirtualMachine.Id
                        #$Vm
                        $VMlist += ,$Vm.Name
                        #$VMlist += ,$nic.Name
                    }
                }
            }
            $ASGVMList.Add($ASG.Name, $VMList)
        }
    }

#Return ASG VM List
write-output $ASGVMList | fl
foreach($key in $ASGVMList.keys)
{
    $ASGVMList[$key]
}

