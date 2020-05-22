function Connect-MSCloudLoginSharePointOnline
{
    [CmdletBinding()]
    param()

    # Explicitly import the required module(s) in case there is cmdlet ambiguity with other modules e.g. SharePointPnPPowerShell2013
    Import-Module -Name Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -Force

    try
    {
        if ($null -ne $Global:o365Credential)
        {
            if ([string]::IsNullOrEmpty($Global:SPOAdminUrl))
            {
                $Global:spoAdminUrl = Get-SPOAdminUrl -CloudCredential $Global:o365Credential
            }
            if ($Global:IsMFAAuth)
            {
                Connect-MSCloudLoginSharePointOnlineMFA
                return
            }
            Connect-SPOService -Credential $Global:o365Credential -Url $Global:spoAdminUrl
            $Global:MSCloudLoginSharePointOnlineConnected = $true
            $Global:IsMFAAuth = $false
        }
        else
        {
            $Global:spoAdminUrl = Get-SPOAdminUrl
            Connect-SPOService -Url $Global:spoAdminUrl
            $Global:MSCloudLoginSharePointOnlineConnected = $true
        }
    }
    catch
    {
        if ($_.Exception -like '*The sign-in name or password does not match one in the Microsoft account system*')
        {
            Connect-MSCloudLoginSharePointOnlineMFA
            return
        }
        else
        {
            $Global:MSCloudLoginSharePointOnlineConnected = $false
            throw $_
        }
    }
    return
}

function Connect-MSCloudLoginSharePointOnlineMFA
{
    [CmdletBinding()]
    param()

    try
    {
        $EnvironmentName = 'Default'
        if ($Global:o365Credential.UserName.Split('@')[1] -like '*.de')
        {
            $Global:CloudEnvironment = 'Germany'
            $EnvironmentName = 'Germany'
        }
        elseif ($Global:CloudEnvironment -eq 'GCCHigh')
        {
            $EnvironmentName = 'ITAR'
        }
        Connect-SPOService -Url $Global:spoAdminUrl -Region $EnvironmentName
        $Global:MSCloudLoginSharePointOnlineConnected = $true
        $Global:IsMFAAuth = $true
    }
    catch
    {
        $Global:MSCloudLoginSharePointOnlineConnected = $false
        throw $_
    }
    return
}
