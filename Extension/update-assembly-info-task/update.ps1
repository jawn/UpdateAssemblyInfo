[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

$script:errors = 0

function Use-Parameter {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Use-Parameter: $parameterName"

    Block-InvalidVariable $displayName $parameterName $value
    $value = Expand-Variables $displayName $parameterName $value
    $value = Set-NullIfEmpty $parameterName $value

    return $value
}

function Use-Version {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Use-Version: $parameterName"

    if ([string]::IsNullOrEmpty($value)) {
        Write-VstsTaskDebug -Message "$parameterName`: `$(current)"
        return "`$(current)"
    }
    else {
        Block-InvalidVariable $displayName $parameterName $value
        $value = Expand-Variables $displayName $parameterName $value
        Block-NonNumericParameter $displayName $parameterName $value
        return $value
    }
}

function Expand-Variables {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Expand-Variables: $parameterName"

    Write-VstsTaskDebug -Message "value: $value"

    $value = $value.Replace("`$(DayOfYear)", (Get-Date -UFormat %j))

    $value = $value.Replace("`$(Assembly.Company)", $script:company)

    $value = $value.Replace("`$(Assembly.Product)", $script:product)

    $value = $value.Replace("`$(Assembly.FileVersion)", "`$(fileversion)")
    $value = $value.Replace("`$(Assembly.FileVersionMajor)", $script:fileVersionMajor)
    $value = $value.Replace("`$(Assembly.FileVersionMinor)", $script:fileVersionMinor)
    $value = $value.Replace("`$(Assembly.FileVersionBuild)", $script:fileVersionBuild)
    $value = $value.Replace("`$(Assembly.FileVersionRevision)", $script:fileVersionRevision)

    $value = $value.Replace("`$(Assembly.AssemblyVersion)", "`$(version)")
    $value = $value.Replace("`$(Assembly.AssemblyVersionMajor)", $script:assemblyVersionMajor)
    $value = $value.Replace("`$(Assembly.AssemblyVersionMinor)", $script:assemblyVersionMinor)
    $value = $value.Replace("`$(Assembly.AssemblyVersionBuild)", $script:assemblyVersionBuild)
    $value = $value.Replace("`$(Assembly.AssemblyVersionRevision)", $script:assemblyVersionRevision)

    $value = Expand-DateVariables $displayName $parameterName $value

    # Leave in for legacy functionality
    $value = $value.Replace("`$(Assembly.Year)", (Get-Date).Year)
    $value = $value.Replace("`$(Year)", (Get-Date).Year)

    Write-VstsTaskDebug -Message "value after all variable expansions: $value"

    return $value
}

function Expand-DateVariables {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Expand-DateVariables: $parameterName"

    Write-VstsTaskDebug -Message "value: $value"

    $variableFormat = '(\$\(Date:([^\)]*)\))'

    $matches = [regex]::Matches($value, $variableFormat)

    $matches | ForEach-Object {
        if ($_.Success) {
            Write-VstsTaskDebug -Message "variable: $($_.Groups[1].Value)"
            Write-VstsTaskDebug -Message "date format: $($_.Groups[2].Value)"

            $date = Get-Date -Format "$($_.Groups[2].Value)"
            Write-VstsTaskDebug -Message "date: $date"

            #$value = $value.Replace([regex]::Escape($_.Groups[1].Value), $date)
            $value = $value.Replace($_.Groups[1].Value, $date)
            Write-VstsTaskDebug -Message "value after date variable expansion: $value"
        }
    }

    Write-VstsTaskDebug -Message "value after all date variable expansions: $value"

    return $value
}

function Block-InvalidVariable {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Block-InvalidVariable: $parameterName"

    if (![string]::IsNullOrEmpty($value)) {
        if ($value.Contains("`$(Invalid)")) {
            Write-VstsTaskError -Message "$displayName contains the variable `$(Invalid). Most likely this is because the default value must be changed to something meaningful."
            $script:errors += 1
        }
    }
}

function Block-NonNumericParameter {
    param(
        [string]
        $displayName,
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Block-NonNumericParameter: $parameterName"

    if (![string]::IsNullOrEmpty($value)) {
        if (!($value -match "^[\d\.]+$")) {
            Write-VstsTaskError -Message "Invalid value for `'$displayName`'. `'$value`' is not a numerical value."
            $script:errors += 1
        }
    }	
}

function Set-NullIfEmpty {
    param(
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Set-NullIfEmpty`: $parameterName"

    if ([string]::IsNullOrEmpty($value)) {
        Write-VstsTaskDebug -Message "$parameterName`: `$null"
        return $null
    }

    return $value
}

function Get-DisplayValue {
    param(
        [string]
        $parameterName,
        [string]
        $value
    )

    Write-VstsTaskDebug -Message "Get-DisplayValue: $parameterName"
    Write-VstsTaskDebug -Message "value: $value"

    $value = $value.Replace("`$(fileversion)", $script:fileVersion)
    $value = $value.Replace("`$(version)", $script:assemblyVersion)

    Write-VstsTaskDebug -Message "value: $value"

    return $value
}

try {
    $assemblyInfoFiles = Get-VstsInput -Name assemblyInfoFiles -Require
    $description = Get-VstsInput -Name description
    $configuration = Get-VstsInput -Name configuration
    $script:company = Get-VstsInput -Name company
    $script:product = Get-VstsInput -Name product
    $copyright = Get-VstsInput -Name copyright
    $trademark = Get-VstsInput -Name trademark
    $script:fileVersionMajor = Get-VstsInput -Name fileVersionMajor
    $script:fileVersionMinor = Get-VstsInput -Name fileVersionMinor
    $script:fileVersionBuild = Get-VstsInput -Name fileVersionBuild
    $script:fileVersionRevision = Get-VstsInput -Name fileVersionRevision
    $script:assemblyVersionMajor = Get-VstsInput -Name assemblyVersionMajor
    $script:assemblyVersionMinor = Get-VstsInput -Name assemblyVersionMinor
    $script:assemblyVersionBuild = Get-VstsInput -Name assemblyVersionBuild
    $script:assemblyVersionRevision = Get-VstsInput -Name assemblyVersionRevision
    $informationalVersion = Get-VstsInput -Name informationalVersion
    $comVisible = Get-VstsInput -Name comVisible -AsBool
    $ensureAttribute = Get-VstsInput -Name ensureAttribute -AsBool  

    $script:fileVersionMajor = Use-Version "File Version Major" "fileVersionMajor" $script:fileVersionMajor
    
    $script:fileVersionMinor = Use-Version "File Version Minor" "fileVersionMinor" $script:fileVersionMinor

    $script:fileVersionBuild = Use-Version "File Version Build" "fileVersionBuild" $script:fileVersionBuild

    $script:fileVersionRevision = Use-Version "File Version Revision" "fileVersionRevision" $script:fileVersionRevision

    $script:assemblyVersionMajor = Use-Version "Assembly Version Major" "assemblyVersionMajor" $script:assemblyVersionMajor

    $script:assemblyVersionMinor = Use-Version "Assembly Version Minor" "assemblyVersionMinor" $script:assemblyVersionMinor

    $script:assemblyVersionBuild = Use-Version "Assembly Version Build" "assemblyVersionBuild" $script:assemblyVersionBuild

    $script:assemblyVersionRevision = Use-Version "Assembly Version Revision" "assemblyVersionRevision" $script:assemblyVersionRevision

    Write-VstsTaskDebug -Message "formatting file version"
    $fileVersion = "$script:fileVersionMajor.$script:fileVersionMinor.$script:fileVersionBuild.$script:fileVersionRevision"
    Write-VstsTaskDebug -Message "fileVersion: $fileVersion"
    $script:fileVersion = $fileVersion

    Write-VstsTaskDebug -Message "formatting assembly version"
    $assemblyVersion = "$script:assemblyVersionMajor.$script:assemblyVersionMinor.$script:assemblyVersionBuild.$script:assemblyVersionRevision"
    Write-VstsTaskDebug -Message "assmeblyVersion: $assemblyVersion"
    $script:assemblyVersion = $assemblyVersion

    $description = Use-Parameter "Description" "description" $description
    
    $configuration = Use-Parameter "Configuration" "configuration" $configuration

    $script:company = Use-Parameter "Company" "company" $script:company

    $script:product = Use-Parameter "Product" "product" $script:product

    $copyright = Use-Parameter "Copyright" "copyright" $copyright

    $trademark = Use-Parameter "Trademark" "trademark" $trademark

    $informationalVersion = Use-Parameter "Informational Version" "informationalVersion" $informationalVersion

    if ($global:errors) {
        throw [System.Exception] "Failed with $script:errors error(s)"
    }

    # Print parameters
    $parameters = @()
    $parameters += New-Object PSObject -Property @{Parameter = "Add Missing Attriutes"; Value = $ensureAttribute}
    $parameters += New-Object PSObject -Property @{Parameter = "Description"; Value = (Get-DisplayValue "description" $description)}
    $parameters += New-Object PSObject -Property @{Parameter = "Configuration"; Value = (Get-DisplayValue "configuration" $configuration)}
    $parameters += New-Object PSObject -Property @{Parameter = "Company"; Value = (Get-DisplayValue "company" $script:company)}
    $parameters += New-Object PSObject -Property @{Parameter = "Product"; Value = (Get-DisplayValue "product" $script:product)}
    $parameters += New-Object PSObject -Property @{Parameter = "Copyright"; Value = (Get-DisplayValue "copyright" $copyright)}
    $parameters += New-Object PSObject -Property @{Parameter = "Trademark"; Value = (Get-DisplayValue "trademark" $trademark)}
    $parameters += New-Object PSObject -Property @{Parameter = "Informational Version"; Value = (Get-DisplayValue "informationalVersion" $informationalVersion)}
    $parameters += New-Object PSObject -Property @{Parameter = "Com Visible"; Value = $comVisible}
    $parameters += New-Object PSObject -Property @{Parameter = "File Version"; Value = $fileVersion}
    $parameters += New-Object PSObject -Property @{Parameter = "Assembly Version"; Value = $assemblyVersion}
    $parameters | format-table -property Parameter, Value

    # Update files
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "Bool.PowerShell.UpdateAssemblyInfo.dll")

    $files = @()

    Write-VstsTaskDebug -Message "testing assembly info files path"
    if (Test-Path -LiteralPath $assemblyInfoFiles) {
        Write-VstsTaskDebug -Message "assembly info file path is absolute"
        $files += (Resolve-Path $assemblyInfoFiles).Path
    }
    else {
        Write-VstsTaskDebug -Message "getting assembly info files based on minimatch"
        $files = Get-ChildItem $assemblyInfoFiles -Recurse | ForEach-Object {$_.FullName}
    }

    if ($files) {
        Write-VstsTaskDebug -Message "files:"
        Write-VstsTaskDebug -Message "$files"
        Write-Output "Updating..."
        $updateResult = Update-AssemblyInfo -Files $files -AssemblyDescription $description -AssemblyConfiguration $configuration -AssemblyCompany $script:company -AssemblyProduct $script:product -AssemblyCopyright $copyright -AssemblyTrademark $trademark -AssemblyFileVersion $fileVersion -AssemblyInformationalVersion $informationalVersion -AssemblyVersion $assemblyVersion -ComVisible $comVisible -EnsureAttribute $ensureAttribute

        Write-Output "Updated:"
        $result += $updateResult | ForEach-Object { New-Object PSObject -Property @{File = $_.File; FileVersion = $_.FileVersion; AssemblyVersion = $_.AssemblyVersion } }
        $result | format-table -property File, FileVersion, AssemblyVersion
		
        Write-VstsTaskDebug -Message "exporting variables"
        $firstResult = $result[0]
        Write-VstsTaskDebug -Message "firstResult: $firstResult"
        Write-VstsSetVariable -Name 'Assembly.FileVersion' -Value $firstResult.FileVersion
        Write-VstsSetVariable -Name 'Assembly.AssemblyVersion' -Value $firstResult.AssemblyVersion
    }
    else {
        throw [System.Exception] "AssemblyInfo.* file not found using search pattern `'$assemblyInfoFiles`'."
    }
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    Write-VstsSetResult -Result "Failed" -Message $_.Exception.Message
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
