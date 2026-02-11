param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,
    
    [string]$Args = "",
    
    [string]$InstallDir = "",
    
    [string]$AssetPattern = ".*\.exe$",
    
    [string]$DownloadDir = "",
    
    [string]$Version = "",
    
    [switch]$ForceAdmin = $false,
    
    [switch]$Wait = $true
)

# Desktop-Sandbox PowerShell Script
# Downloads and installs Windows applications from GitHub releases

$ErrorActionPreference = "Stop"

# Logging utility
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Check if file exists
function Test-PathSafe {
    param([string]$Path)
    try {
        if ([string]::IsNullOrEmpty($Path)) { return $false }
        Test-Path -Path $Path -PathType Leaf
    } catch {
        Write-Log -Message "Path check failed: $Path - $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Resolve path to absolute
function Resolve-PathSafe {
    param([string]$Path)
    try {
        if ([string]::IsNullOrEmpty($Path)) { return $null }
        $resolved = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
        if ($resolved) { return $resolved.Path }
        
        $expanded = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if (Test-Path -Path $expanded -PathType Leaf) {
            return (Get-Item $expanded).FullName
        }
        return $null
    } catch {
        Write-Log -Message "Failed to resolve path: $Path - $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Generate unique temp path
function Get-TempPath {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $random = Get-Random -Minimum 1000 -Maximum 9999
    return Join-Path -Path $env:TEMP -ChildPath "desktop-sandbox_$timestamp_$random"
}

# Check if running as administrator
function Test-AdminRights {
    $currentUser = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList (
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Download installer from GitHub
function Invoke-GitHubDownload {
    param(
        [string]$Repo,
        [string]$Pattern = ".*\.exe$",
        [string]$DownloadTo = "",
        [string]$SpecificVersion = ""
    )
    
    Write-Log -Message "Starting GitHub download for: $Repo" -Level "INFO"
    
    # Parse repository format
    if ($Repo -match "github\.com/(.+)/(.+)") {
        $owner = $matches[1]
        $repoName = $matches[2] -replace '\.git$', ''
    } elseif ($Repo -match "^([^/]+)/([^/]+)$") {
        $owner = $matches[1]
        $repoName = $matches[2]
    } else {
        throw "Invalid repository format: $Repo. Use 'owner/repo' or full URL"
    }
    
    Write-Log -Message "Owner: $owner, Repo: $repoName" -Level "INFO"
    
    # Determine API URL based on version
    $apiUrl = if ([string]::IsNullOrEmpty($SpecificVersion)) {
        "https://api.github.com/repos/$owner/$repoName/releases/latest"
    } else {
        "https://api.github.com/repos/$owner/$repoName/releases/tags/$SpecificVersion"
    }
    
    Write-Log -Message "Fetching from: $apiUrl" -Level "INFO"
    
    # Fetch release information
    try {
        $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "Desktop-Sandbox/1.0"
        } -ErrorAction Stop
    } catch {
        throw "Failed to fetch release info: $($_.Exception.Message)"
    }
    
    $tagName = $releaseInfo.tag_name
    Write-Log -Message "Release version: $tagName" -Level "INFO"
    
    # Find matching Windows executable
    $asset = $releaseInfo.assets | Where-Object { 
        $_.name -match $Pattern -and $_.name -match "(?i)win|windows|\.exe$"
    } | Select-Object -First 1
    
    if (-not $asset) {
        throw "No matching Windows .exe asset found in release"
    }
    
    Write-Log -Message "Found asset: $($asset.name)" -Level "INFO"
    Write-Log -Message "Download URL: $($asset.browser_download_url)" -Level "INFO"
    
    # Determine download path
    if ([string]::IsNullOrEmpty($DownloadTo)) {
        $DownloadTo = Get-TempPath
    }
    
    if (-not (Test-Path -Path $DownloadTo -PathType Container)) {
        New-Item -Path $DownloadTo -ItemType Directory -Force | Out-Null
    }
    
    $downloadPath = Join-Path -Path $DownloadTo -ChildPath $asset.name
    
    # Download file
    Write-Log -Message "Downloading to: $downloadPath" -Level "INFO"
    
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -Headers @{
            "Accept" = "application/octet-stream"
            "User-Agent" = "Desktop-Sandbox/1.0"
        } -ErrorAction Stop
    } catch {
        throw "Failed to download file: $($_.Exception.Message)"
    }
    
    # Verify download
    if (-not (Test-PathSafe -Path $downloadPath)) {
        throw "Downloaded file not found: $downloadPath"
    }
    
    $fileSize = (Get-Item $downloadPath).Length
    Write-Log -Message "Downloaded file size: $fileSize bytes" -Level "INFO"
    
    return @{
        Path = $downloadPath
        Name = $asset.name
        Version = $tagName
    }
}

# Execute installer
function Invoke-Installer {
    param(
        [string]$ExePath,
        [string]$Args,
        [string]$InstallDir,
        [bool]$ForceAdmin
    )
    
    Write-Log -Message "Starting installer execution" -Level "INFO"
    Write-Log -Message "EXE Path: $ExePath" -Level "INFO"
    
    # Validate installer file
    if (-not (Test-PathSafe -Path $ExePath)) {
        throw "Installer file not found: $ExePath"
    }
    
    $resolvedExe = Resolve-PathSafe -Path $ExePath
    if (-not $resolvedExe) {
        throw "Could not resolve installer path: $ExePath"
    }
    
    Write-Log -Message "Resolved EXE: $resolvedExe" -Level "INFO"
    
    # Check if admin rights are needed
    $needsAdmin = $false
    
    if ($ForceAdmin) {
        $needsAdmin = $true
        Write-Log -Message "Admin rights forced by parameter" -Level "INFO"
    }
    elseif ($InstallDir -match ':\\Program Files') {
        $needsAdmin = $true
        Write-Log -Message "Target directory requires admin rights: $InstallDir" -Level "INFO"
    }
    
    # Check current permissions
    $hasAdmin = Test-AdminRights
    Write-Log -Message "Current user admin status: $hasAdmin" -Level "INFO"
    
    # Request elevation if needed
    if ($needsAdmin -and -not $hasAdmin) {
        Write-Log -Message "Elevation required but not requested" -Level "WARNING"
        return @{
            Success = $false
            ExitCode = -1
            NeedsElevation = $true
            Message = "Installation requires administrator rights. Re-run with -ForceAdmin or run as administrator."
        }
    }
    
    # Build process arguments
    $processArgs = @{
        FilePath = $resolvedExe
        Wait = $true
        PassThru = $true
        NoNewWindow = $true
    }
    
    # Build argument string
    $fullArgs = ""
    
    # Handle installation directory
    if (-not [string]::IsNullOrEmpty($InstallDir)) {
        try {
            $parentDir = Split-Path -Path $InstallDir -Parent
            if (-not (Test-Path -Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            Write-Log -Message "Install directory: $InstallDir" -Level "INFO"
        } catch {
            Write-Log -Message "Failed to create install directory: $($_.Exception.Message)" -Level "WARNING"
        }
        
        # Common directory flags
        if ($Args -match '/D=') {
            # Already has directory argument
        } elseif ($Args -match '/D\s*=') {
            $Args = $Args -replace '/D\s*=', "/D=`"$InstallDir`" "
        } else {
            $fullArgs = "/D=`"$InstallDir`" "
        }
    }
    
    $fullArgs += $Args.Trim()
    
    # Set arguments
    if (-not [string]::IsNullOrEmpty($fullArgs)) {
        $processArgs.ArgumentList = $fullArgs
        Write-Log -Message "Arguments: $fullArgs" -Level "INFO"
    }
    
    # Run as administrator if needed
    if ($needsAdmin) {
        $processArgs.Verb = "RunAs"
        Write-Log -Message "Executing with administrator privileges" -Level "INFO"
    }
    
    # Execute installer
    $startTime = Get-Date
    Write-Log -Message "Starting installer..." -Level "INFO"
    
    try {
        $process = Start-Process @processArgs
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Log -Message "Installer completed" -Level "INFO"
        Write-Log -Message "Exit code: $($process.ExitCode)" -Level "INFO"
        Write-Log -Message "Duration: $duration seconds" -Level "INFO"
        
        # Interpret exit code
        $success = $process.ExitCode -eq 0
        $exitCode = $process.ExitCode
        $needsReboot = $false
        $message = ""
        
        switch ($process.ExitCode) {
            0 { $message = "Installation completed successfully" }
            1603 { 
                $message = "Fatal error during installation"
                $success = $false
            }
            1641 {
                $message = "Installation completed successfully, reboot initiated"
                $needsReboot = $true
            }
            3010 {
                $message = "Installation completed successfully, reboot required"
                $needsReboot = $true
            }
            default {
                $message = "Installation completed with exit code: $($process.ExitCode)"
                if ($process.ExitCode -gt 0) { $success = $false }
            }
        }
        
        return @{
            Success = $success
            ExitCode = $exitCode
            NeedsReboot = $needsReboot
            Message = $message
            Duration = $duration
        }
        
    } catch {
        Write-Log -Message "Installer execution failed: $($_.Exception.Message)" -Level "ERROR"
        
        return @{
            Success = $false
            ExitCode = -1
            Message = "Installer execution failed: $($_.Exception.Message)"
            Error = $_.Exception.Message
        }
    }
}

# Cleanup temporary files
function Remove-TempFile {
    param([string]$Path)
    try {
        if (Test-Path -Path $Path -PathType Leaf) {
            Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Cleaned up temporary file: $Path" -Level "INFO"
        }
    } catch {
        Write-Log -Message "Failed to cleanup: $Path - $($_.Exception.Message)" -Level "WARNING"
    }
}

# Main execution
try {
    Write-Log -Message "=== Desktop-Sandbox Started ===" -Level "INFO"
    Write-Log -Message "GitHub Repo: $GitHubRepo" -Level "INFO"
    Write-Log -Message "Arguments: $Args" -Level "INFO"
    Write-Log -Message "Install Dir: $InstallDir" -Level "INFO"
    Write-Log -Message "Force Admin: $ForceAdmin" -Level "INFO"
    
    $tempFile = $null
    $shouldCleanup = $false
    
    # Download from GitHub
    Write-Log -Message "Processing GitHub download request..." -Level "INFO"
    
    $downloadResult = Invoke-GitHubDownload -Repo $GitHubRepo -Pattern $AssetPattern -DownloadTo $DownloadDir -SpecificVersion $Version
    
    $ExePath = $downloadResult.Path
    $tempFile = $downloadResult.Path
    $shouldCleanup = $true
    
    Write-Log -Message "Downloaded: $($downloadResult.Name) v$($downloadResult.Version)" -Level "INFO"
    
    # Execute installer
    $result = Invoke-Installer -ExePath $ExePath -Args $Args -InstallDir $InstallDir -ForceAdmin $ForceAdmin
    
    # Cleanup downloaded file
    if ($shouldCleanup -and $tempFile) {
        Start-Sleep -Seconds 5
        Remove-TempFile -Path $tempFile
    }
    
    Write-Log -Message "=== Desktop-Sandbox Completed ===" -Level "INFO"
    
    # Output result as JSON
    $result | ConvertTo-Json -Compress
    
    # Exit with appropriate code
    if ($result.Success) {
        exit 0
    } elseif ($result.NeedsElevation) {
        exit 2
    } else {
        exit 1
    }
    
} catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level "ERROR"
    exit 999
}
