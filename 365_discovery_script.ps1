#powershell script that will pull excel sheets of migration reports needed for tenant discovery when migrating

#install module for exchange online if needed
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser

#Import-Module ExchangeOnlineManagement
Import-Module ExchangeOnlineManagement

#connect to exchange online
$UserCredential = Get-Credential
Connect-ExchangeOnline -UserPrincipalName $UserCredential.UserName -ShowProgress $true

#retrieve shared mailboxes 
Get-Mailbox -RecipientTypeDetails SharedMailbox

#Change directory path to somewhere local on computer

Get-Mailbox -RecipientTypeDetails SharedMailbox | ForEach-Object {
    $mbx = $_
    $stats = Get-MailboxStatistics -Identity $mbx.Identity
    $sizeString = ($stats.TotalItemSize -split '\(')[0].Trim()

    if ($sizeString -like "*GB*") {
        $sizeInMB = [math]::Round([double]$sizeString.Replace(' GB','').Trim() * 1024, 2)
    } elseif ($sizeString -like "*MB*") {
        $sizeInMB = [math]::Round([double]$sizeString.Replace(' MB','').Trim(), 2)
    } else {
        $sizeInMB = 0
    }

    [PSCustomObject]@{
        DisplayName       = $mbx.DisplayName
        PrimarySmtpAddress = $mbx.PrimarySmtpAddress
        ItemCount         = $stats.ItemCount
        "MailboxSize(MB)" = $sizeInMB
    }
} | Export-Csv -Path "C:\Users\Ksalcedo\Desktop\SharedMailboxes.csv" -NoTypeInformation

#####################et security groups in csv listed as cloud vs on prem#######################################################
#Install the AzureAD module if you haven't already
Install-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Retrieve all groups
$groups = Get-AzureADMSGroup -Filter "groupTypes/any(c:c eq 'Unified') or securityEnabled eq true"

# Retrieve shared mailboxes
$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox | Select-Object -ExpandProperty Alias

# Retrieve distribution lists
$distributionLists = Get-DistributionGroup | Select-Object -ExpandProperty Alias

# Create an array to store the results
$results = @()

foreach ($group in $groups) {
    if ($group.OnPremisesSyncEnabled -eq $true) {
        $source = "OnPremises"
    } else {
        $source = "Cloud"
    }

    # Determine if the group is a shared mailbox, distribution list, or security group
    if ($sharedMailboxes -contains $group.MailNickname) {
        $groupType = "Shared Mailbox"
    } elseif ($distributionLists -contains $group.MailNickname) {
        $groupType = "Distribution List"
    } else {
        $groupType = "Security Group"
    }
    
    # Create a custom object with the group details
    $results += [PSCustomObject]@{
        DisplayName     = $group.DisplayName
        EmailAddress    = $group.Mail
        GroupSource     = $source
        GroupType       = $groupType
    }
}

# Sort the results alphabetically by DisplayName
$sortedResults = $results | Sort-Object DisplayName

# Export the sorted results to a CSV file
$sortedResults | Export-Csv -Path "C:\Users\Ksalcedo\Desktop\SecurityGroups.csv" -NoTypeInformation



##############################List of SharePoint sites and the associated members with permission to access###############

# Connect to SharePoint Online
$SPOAdminUrl = "https://csincus-admin.sharepoint.com" # Update with your admin URL
Connect-SPOService -Url $SPOAdminUrl

# Retrieve all SharePoint sites
$sites = Get-SPOSite -Limit All

# Create an array to store the results
$results = @()

foreach ($site in $sites) {
    # Get the site members and their roles
    $members = Get-SPOUser -Site $site.Url
    
    # Process each member
    foreach ($member in $members) {
        $results += [PSCustomObject]@{
            SiteTitle       = $site.Title
            SiteUrl         = $site.Url
            UserDisplayName = $member.DisplayName
            UserEmail       = $member.Email
            Role            = if ($member.IsSiteAdmin) { "Site Admin" } else { "Member" }
        }
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "C:\Users\Ksalcedo\Desktop\SharePointSitesAndMembers.csv" -NoTypeInformation




####Team sites and the associated members with permission to access#######