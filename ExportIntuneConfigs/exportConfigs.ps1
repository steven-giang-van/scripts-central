#requires -Version 7.0

param(
    [string]$OutputPath = ".\IntunePolicyExport"
)

$ErrorActionPreference = "Stop"

Import-Module Microsoft.Graph.Authentication

$requiredScopes = @(
    "DeviceManagementConfiguration.Read.All",
    "DeviceManagementApps.Read.All",
    "DeviceManagementServiceConfig.Read.All"
)

Connect-MgGraph -Scopes $requiredScopes -NoWelcome

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$exportRoot = Join-Path $OutputPath $timestamp
New-Item -Path $exportRoot -ItemType Directory -Force | Out-Null

function ConvertTo-SafeFileName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $invalidChars = [IO.Path]::GetInvalidFileNameChars()
    $escapedChars = [Regex]::Escape((-join $invalidChars))

    $safeName = $Name -replace "[$escapedChars]", "_"
    $safeName = $safeName.Trim()

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        return "Unnamed"
    }

    return $safeName
}

function Invoke-GraphCollection {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while ($nextLink) {
        Write-Host "GET $nextLink"

        $response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $nextLink `
            -OutputType PSObject

        if ($null -ne $response.value) {
            foreach ($item in $response.value) {
                $results.Add($item)
            }
        }
        else {
            # Some endpoints can return a single object rather than a collection.
            $results.Add($response)
        }

        $nextLink = $response.'@odata.nextLink'
    }

    return $results
}

function Invoke-GraphOptionalCollection {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    try {
        return @(Invoke-GraphCollection -Uri $Uri)
    }
    catch {
        Write-Warning "Could not retrieve $Uri"
        Write-Warning $_.Exception.Message
        return @()
    }
}

function Export-JsonFile {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $InputObject |
        ConvertTo-Json -Depth 100 |
        Set-Content -Path $Path -Encoding utf8
}

function Export-PolicyFamily {
    param(
        [Parameter(Mandatory)]
        [string]$FamilyName,

        [Parameter(Mandatory)]
        [string]$CollectionUri,

        [string]$SettingsUriTemplate,

        [string]$AssignmentsUriTemplate
    )

    $familyPath = Join-Path $exportRoot $FamilyName
    New-Item -Path $familyPath -ItemType Directory -Force | Out-Null

    $policies = @(Invoke-GraphOptionalCollection -Uri $CollectionUri)

    Write-Host "${FamilyName}: $($policies.Count) object(s)" -ForegroundColor Cyan

    Export-JsonFile `
        -InputObject $policies `
        -Path (Join-Path $familyPath "_AllObjects.json")

    foreach ($policy in $policies) {
        $policyName = if ($policy.name) {
            $policy.name
        }
        elseif ($policy.displayName) {
            $policy.displayName
        }
        else {
            $policy.id
        }

        $safeName = ConvertTo-SafeFileName -Name $policyName
        $policyFolderName = "$safeName--$($policy.id)"
        $policyPath = Join-Path $familyPath $policyFolderName

        New-Item -Path $policyPath -ItemType Directory -Force | Out-Null

        Export-JsonFile `
            -InputObject $policy `
            -Path (Join-Path $policyPath "Policy.json")

        if ($SettingsUriTemplate) {
            $settingsUri = $SettingsUriTemplate.Replace("{id}", $policy.id)
            $settings = @(Invoke-GraphOptionalCollection -Uri $settingsUri)

            Export-JsonFile `
                -InputObject $settings `
                -Path (Join-Path $policyPath "Settings.json")
        }

        if ($AssignmentsUriTemplate) {
            $assignmentsUri = $AssignmentsUriTemplate.Replace("{id}", $policy.id)
            $assignments = @(Invoke-GraphOptionalCollection -Uri $assignmentsUri)

            Export-JsonFile `
                -InputObject $assignments `
                -Path (Join-Path $policyPath "Assignments.json")
        }
    }

    return $policies
}

$exportDefinitions = @(
    @{
        FamilyName             = "SettingsCatalog"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
        SettingsUriTemplate    = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/{id}/settings"
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/{id}/assignments"
    },
    @{
        FamilyName             = "DeviceConfigurations"
        CollectionUri          = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/{id}/assignments"
    },
    @{
        FamilyName             = "CompliancePolicies"
        CollectionUri          = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/{id}/assignments"
    },
    @{
        FamilyName             = "EndpointSecurityIntents"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/intents"
        SettingsUriTemplate    = "https://graph.microsoft.com/beta/deviceManagement/intents/{id}/settings"
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/intents/{id}/assignments"
    },
    @{
        FamilyName             = "AdministrativeTemplates"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations"
        SettingsUriTemplate    = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/{id}/definitionValues?`$expand=definition,presentationValues"
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/{id}/assignments"
    },
    @{
        FamilyName             = "PowerShellScripts"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/{id}/assignments"
    },
    @{
        FamilyName             = "Remediations"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/{id}/assignments"
    },
    @{
        FamilyName             = "EnrollmentConfigurations"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/{id}/assignments"
    },
    @{
        FamilyName             = "AutopilotProfiles"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles/{id}/assignments"
    },
    @{
        FamilyName             = "AppConfigurations"
        CollectionUri          = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations"
        SettingsUriTemplate    = $null
        AssignmentsUriTemplate = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations/{id}/assignments"
    }
)

$summary = [System.Collections.Generic.List[object]]::new()

foreach ($definition in $exportDefinitions) {
    try {
        $objects = Export-PolicyFamily @definition

        $summary.Add([pscustomobject]@{
            PolicyFamily = $definition.FamilyName
            Count        = $objects.Count
            Status       = "Exported"
            Endpoint     = $definition.CollectionUri
        })
    }
    catch {
        Write-Warning "Family failed: $($definition.FamilyName)"
        Write-Warning $_.Exception.Message

        $summary.Add([pscustomobject]@{
            PolicyFamily = $definition.FamilyName
            Count        = 0
            Status       = "Failed: $($_.Exception.Message)"
            Endpoint     = $definition.CollectionUri
        })
    }
}

$summary |
    Export-Csv `
        -Path (Join-Path $exportRoot "ExportSummary.csv") `
        -NoTypeInformation `
        -Encoding utf8

Export-JsonFile `
    -InputObject $summary `
    -Path (Join-Path $exportRoot "ExportSummary.json")

$context = Get-MgContext

$metadata = [ordered]@{
    ExportedAt    = (Get-Date).ToString("o")
    TenantId      = $context.TenantId
    Account       = $context.Account
    GraphEnvironment = $context.Environment
    Scopes        = $context.Scopes
}

Export-JsonFile `
    -InputObject $metadata `
    -Path (Join-Path $exportRoot "ExportMetadata.json")

Write-Host ""
Write-Host "Export completed:" -ForegroundColor Green
Write-Host $exportRoot
