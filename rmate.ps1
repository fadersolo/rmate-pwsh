#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell rmate - Matches aurora/rmate bash protocol exactly
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true, ValueFromPipeline=$true)]
    [string[]]$Path,

    [string]$HostName = "127.0.0.1",
    [int]$Port = 52698,
    [switch]$Wait = $true,
    [int]$Line,
    [string]$Name,
    [string]$Type,
    [switch]$Force
)

begin {
    # --- Configuration ---
    if ($env:RMATE_HOST) { $HostName = $env:RMATE_HOST }
    if ($env:RMATE_PORT) { $Port = [int]$env:RMATE_PORT }

    # Check .rmate.rc
    $RcPaths = @("$HOME/.rmate.rc", "/etc/rmate.rc")
    foreach ($RcFile in $RcPaths) {
        if (Test-Path $RcFile) {
            Get-Content $RcFile | ForEach-Object {
                if ($_ -match "^\s*host:\s*(.+)\s*$") { $HostName = $Matches[1] }
                if ($_ -match "^\s*port:\s*(\d+)\s*$") { $Port = [int]$Matches[1] }
            }
        }
    }

    # Helper: Convert "C:\Users\..." to "/c/Users/..."
    function ConvertTo-UnixPath {
        param([string]$InputPath)
        $p = $InputPath -replace '\\', '/'
        if ($p -match "^([a-zA-Z]):(.*)") {
            return "/" + $Matches[1].ToLower() + $Matches[2]
        }
        return $p
    }

    # Helper: Read line (non-blocking safe)
    function Read-LineWithTimeout {
        param($Stream)
        $Bytes = New-Object System.Collections.Generic.List[byte]
        while ($true) {
            try { $Byte = $Stream.ReadByte() }
            catch [System.IO.IOException] { continue }
            if ($Byte -eq -1) { return $null }
            if ($Byte -eq 10) { break }
            if ($Byte -ne 13) { $Bytes.Add($Byte) }
        }
        return [System.Text.Encoding]::UTF8.GetString($Bytes.ToArray())
    }

    # Helper: Read N bytes
    function Read-BytesWithTimeout {
        param($Stream, [int]$Count)
        $Buffer = New-Object byte[] $Count
        $Offset = 0
        while ($Offset -lt $Count) {
            try {
                $Read = $Stream.Read($Buffer, $Offset, $Count - $Offset)
                if ($Read -eq 0) { throw "Connection closed unexpectedly." }
                $Offset += $Read
            }
            catch [System.IO.IOException] { continue }
        }
        return $Buffer
    }
}

process {
    foreach ($FilePath in $Path) {
        Write-Verbose "Processing $FilePath..."

        # 1. Prepare File Content
        try {
            if (-not (Test-Path $FilePath)) {
                if ($Force -or $true) {
                    $FullPath = $FilePath
                    if (-not [System.IO.Path]::IsPathRooted($FilePath)) {
                        $FullPath = Join-Path (Get-Location) $FilePath
                    }
                    $FileContentBytes = [byte[]]@()
                } else { Write-Error "File not found."; continue }
            } else {
                $RealFile = Get-Item $FilePath
                $FullPath = $RealFile.FullName
                $FileContentBytes = [System.IO.File]::ReadAllBytes($FullPath)
            }
        }
        catch { Write-Error "Error reading file: $_"; continue }

        # 2. Connect
        $Client = $null
        try {
            Write-Verbose "Connecting to $HostName`:$Port..."
            $Client = New-Object System.Net.Sockets.TcpClient($HostName, $Port)
            $Client.NoDelay = $true
            $Client.ReceiveTimeout = 500
            $Stream = $Client.GetStream()
        }
        catch { Write-Error "Connection failed. Check SSH tunnel."; continue }

        try {
            # 2.1 Read Greeting (Must consume this first!)
            $Greeting = Read-LineWithTimeout $Stream
            Write-Verbose "Server Handshake: $Greeting"

            # 3. Build & Send Command Block
            $UnixPath = ConvertTo-UnixPath $FullPath
            $DisplayName = if ($Name) { $Name } else { Split-Path $FilePath -Leaf }

            $Headers = [System.Text.StringBuilder]::new()
            [void]$Headers.Append("open`n")
            [void]$Headers.Append("display-name: $DisplayName`n")
            [void]$Headers.Append("real-path: $UnixPath`n")
            if ($Line) { [void]$Headers.Append("selection: $Line`n") }
            if ($Type) { [void]$Headers.Append("file-type: $Type`n") }
            if ($Wait) {
                [void]$Headers.Append("data-on-save: yes`n")
                [void]$Headers.Append("re-activate: yes`n")
            }
            [void]$Headers.Append("token: $UnixPath`n")
            [void]$Headers.Append("data: $($FileContentBytes.Length)`n")

            $HeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($Headers.ToString())

            Write-Verbose "Sending Open Command..."
            # Send Headers
            $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
            # Send Data
            if ($FileContentBytes.Length -gt 0) {
                $Stream.Write($FileContentBytes, 0, $FileContentBytes.Length)
            }
            # Send Newline (Terminates the 'open' command)
            $Stream.WriteByte(10)

            # CRITICAL: Send Dot (Terminates the batch/session init)
            # This corresponds to `echo "."` in the bash script
            $DotBytes = [System.Text.Encoding]::UTF8.GetBytes(".`n")
            $Stream.Write($DotBytes, 0, $DotBytes.Length)

            $Stream.Flush()

            # 4. Event Loop
            if ($Wait) {
                Write-Host "Editing '$DisplayName' (Ctrl+C to stop)..."
                while ($Client.Connected) {
                    $CmdLine = Read-LineWithTimeout $Stream
                    if ([string]::IsNullOrEmpty($CmdLine)) { break }
                    if ($CmdLine.StartsWith("220")) { continue }

                    Write-Verbose "Received: $CmdLine"

                    switch ($CmdLine.Trim()) {
                        "save" {
                            Write-Host "Saving... " -NoNewline
                            $DataLength = 0
                            while ($true) {
                                $Header = Read-LineWithTimeout $Stream
                                if ($Header -match "^token:") { continue }
                                if ($Header -match "^data:\s*(\d+)$") {
                                    $DataLength = [int]$Matches[1]
                                    break
                                }
                            }

                            if ($DataLength -gt 0) {
                                $NewContent = Read-BytesWithTimeout $Stream $DataLength
                                [System.IO.File]::WriteAllBytes($FullPath, $NewContent)
                                Write-Host "Done."
                            }
                        }
                        "close" {
                            Write-Host "Closed."
                            $Client.Close()
                            break
                        }
                    }
                }
            } else {
                Write-Host "Sent $FilePath to editor."
            }
        }
        catch { Write-Error "Error: $_" }
        finally { if ($Client) { $Client.Close() } }
    }
}