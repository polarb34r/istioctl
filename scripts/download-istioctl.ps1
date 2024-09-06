# Define the executable name
$filename = "istioctl"

function Get-ExecutableExtension {
    if ($IsWindows) {
        return ".exe"
    }
    return ""
}

function Get-DownloadUrl {
    param(
        [string]$version
    )

    if ($IsWindows) {
        return "https://github.com/istio/istio/releases/download/$version/istioctl-$version-win.zip"
    } elseif ($IsMacOS) {
        return "https://github.com/istio/istio/releases/download/$version/istioctl-$version-osx.tar.gz"
    } else {
        return "https://github.com/istio/istio/releases/download/$version/istioctl-$version-linux-amd64.tar.gz"
    }
}

function Download-File {
    param(
        [string]$version
    )

    $url = Get-DownloadUrl -version $version
    $outputFile = Join-Path -Path $env:TEMP -ChildPath "$filename-$version$(Get-ExecutableExtension)"

    try {
        Write-Output "Downloading istioctl version $version from $url..."
        Invoke-WebRequest -Uri $url -OutFile $outputFile -ErrorAction Stop
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            throw "Istioctl version '$version' not found."
        } else {
            throw "Failed to download Istioctl: $($_.Exception.Message)"
        }
    }

    return $outputFile
}

function Extract-File {
    param(
        [string]$file
    )

    $extractPath = Join-Path -Path $env:TEMP -ChildPath "$filename-extracted"
    
    if (Test-Path $extractPath) {
        Remove-Item -Recurse -Force $extractPath
    }

    if ($IsWindows) {
        Expand-Archive -Path $file -DestinationPath $extractPath -Force
    } else {
        # Ensure tar command exists for Linux/macOS
        if (Get-Command tar -ErrorAction SilentlyContinue) {
            tar -xf $file -C $extractPath
        } else {
            throw "tar is not installed on this system. Install tar to extract the file."
        }
    }

    return Join-Path -Path $extractPath -ChildPath $filename
}

function Cache-File {
    param(
        [string]$file,
        [string]$version
    )

    $cacheDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "istioctl-cache"
    if (-not (Test-Path $cacheDir)) {
        New-Item -Path $cacheDir -ItemType Directory | Out-Null
    }

    $cachedFile = Join-Path -Path $cacheDir -ChildPath "$filename-$version$(Get-ExecutableExtension)"
    Copy-Item -Path $file -Destination $cachedFile -Force
    icacls $cachedFile /grant Everyone:F | Out-Null

    return $cachedFile
}

function Execute-Istioctl {
    param(
        [string]$version
    )

    $downloadedFile = Download-File -version $version
    $extractedFile = Extract-File -file $downloadedFile
    $cachedFile = Cache-File -file $extractedFile -version $version

    # Add the directory containing istioctl to the PATH
    $pathDir = Split-Path -Path $cachedFile
    [System.Environment]::SetEnvironmentVariable('PATH', "$($env:PATH);$pathDir", [System.EnvironmentVariableTarget]::Process)

    return $cachedFile
}

function Run-Istioctl {
    param(
        [string]$version
    )

    try {
        $istioctlPath = Execute-Istioctl -version $version
        Write-Output "Istioctl version '$version' has been cached at $istioctlPath"
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
        exit 1
    }
}

# Check the OS
$IsWindows = $PSVersionTable.OS -match "Windows"
$IsMacOS = $PSVersionTable.OS -match "Darwin"

# Run the script
$version = Read-Host "Enter the version of Istioctl"
Run-Istioctl -version $version
