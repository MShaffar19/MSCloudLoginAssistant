function Connect-MSCloudLoginPnP
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [System.String]
        $ConnectionUrl
    )
    $clientid = "9bc3ab49-b65d-410a-85ad-de819febfddc"
    $RedirectURI = "https://oauth.spops.microsoft.com/"

    if ($null -eq $Global:o365Credential)
    {
        $Global:o365Credential = Get-Credential -Message "Cloud Credential"
    }

    if ([string]::IsNullOrEmpty($ConnectionUrl))
    {
        if (-not [string]::IsNullOrEmpty($Global:SPOAdminUrl))
        {
            $Global:SPOConnectionUrl = $Global:SPOAdminUrl
        }
        else
        {
            $Global:SPOAdminUrl = Get-SPOAdminUrl -CloudCredential $Global:o365Credential
        }
        $Global:SPOConnectionUrl = $Global:SPOAdminUrl
    }
    else
    {
        $Global:SPOConnectionUrl = $ConnectionUrl
    }
    Write-Verbose -Message "`$Global:SPOConnectionUrl is $Global:SPOConnectionUrl."
    # Explicitly import the required module(s) in case there is cmdlet ambiguity with other modules e.g. SharePointPnPPowerShell2013
    Import-Module -Name SharePointPnPPowerShellOnline -DisableNameChecking -Force

    try
    {
        Connect-PnPOnline -Url $Global:SPOConnectionUrl -Credentials $Global:o365Credential
        Write-Verbose "Connected to PnP {$($Global:SPOConnectionUrl) using regular authentication"
        $Global:IsMFAAuth = $false
    }
    catch
    {
        if ($_.Exception -like '*Microsoft.SharePoint.Client.ServerUnauthorizedAccessException*' -or `
                $_.Exception -like '*The remote server returned an error: (401) Unauthorized.*')
        {
            try
            {
                Connect-PnPOnline -Url $Global:SPOConnectionUrl -UseWebLogin
                $Global:IsMFAAuth = $true
                $Global:MSCloudLoginAzurePnPConnected = $true
            }
            catch
            {
                $Global:MSCloudLoginAzurePnPConnected = $false
                throw $_
            }
        }
        elseif ($_.Exception -like "*The remote name could not be resolved:*" -and ($Global:CloudEnvironment -eq 'USGovernment' -or `
                    $Global:CloudEnvironment -eq 'GCCHigh') -and !$Global:IsMFAAuth)
        {
            # We are most likely dealing with a GCC High environment, we need to change the connection url to *.us
            $Global:SPOConnectionUrl = $Global:SPOConnectionUrl.Replace('.com', '.us')
            Connect-PnPOnline -Url $Global:SPOConnectionUrl -Credentials $Global:o365Credential
            $Global:IsMFAAuth = $false
            $Global:CloudEnvironment = 'GCCHigh'
        }
        elseif ($_.Exception -like '*The sign-in name or password does not match one in the Microsoft account system*')
        {
            # This error means that the account was trying to connect using MFA.
            try
            {
                if ($null -eq $Global:SPOAdminUrl)
                {
                    $Global:SPOAdminUrl = Get-SPOAdminUrl -CloudCredential $Global:o365Credential
                }
                Write-Verbose "Trying to acquire AccessToken"
                $AuthHeader = Get-AuthHeader -UserPrincipalName $Global:o365Credential.UserName `
                    -ResourceURI $Global:SPOAdminUrl -clientID $clientID -RedirectURI $RedirectURI
                $AccessToken = $AuthHeader.split(" ")[1]
                Write-Verbose "Access Token = $AccessToken"
                if ($null -ne $AccessToken)
                {
                    Connect-PnPOnline -Url $Global:SPOConnectionUrl -AccessToken $AccessToken
                }
                else
                {
                    Connect-PnPOnline -Url $Global:SPOConnectionUrl -UseWebLogin
                }
                $Global:IsMFAAuth = $true
                $Global:MSCloudLoginAzurePnPConnected = $true
            }
            catch
            {
                Write-Verbose "Error acquiring AccessToken: $_.Exception"
                try
                {
                    Connect-PnPOnline -Url $Global:SPOConnectionUrl -UseWebLogin
                    $Global:IsMFAAuth = $true
                    $Global:MSCloudLoginAzurePnPConnected = $true
                }
                catch
                {
                    $Global:MSCloudLoginAzurePnPConnected = $false
                    throw $_
                }
            }
        }
    }
    return
}
