# Pathx
# Utility for altering the PATH (envar and registry) from the command-line.
# PowerShell version.
# Created 2011 Kody Brown.
# Released under the MIT License.

Set-Alias path Show-Path
Set-Alias pathx Show-Path
Set-Alias edpath Edit-Path

# Tests:
# edit-path --remove "C:\DISABLED\Program Files (x86)\NVIDIA Corporation\PhysX\Common" *
# edit-path --rm "C:\Users\kodyb\scoop\apps\go\current\bin" User
# edit-path --rm "C:\Users\kodyb\scoop\apps\go\current\bin" *

# function Edit-Path( [string]$cmd, [string]$dir, [string]$scope = "", [bool]$force = $false) {
function Edit-Path() {
    $cmd = ""
    $quiet = $false
    $force = $false
    $files = @()
    $scope = ""

    # Parse the arguments
    $args | ForEach-Object -Process {
        # Write-Host "$_"
        if ($_.StartsWith("-")) {
            while ($_.StartsWith("-")) {
                $_ = $_.Substring(1)
            }
            $a = $_.ToLower()

            if ($a -eq "quiet") {
                $quiet = $true

            } elseif ($a -eq "force") {
                $force = $true

            } elseif ($a -eq "add" -or $a -eq "append") {
                $cmd = "append"
            } elseif ($a -eq "insert") {
                $cmd = "insert"
            } elseif ($a -eq "rm" -or $a -eq "remove") {
                $cmd = "remove"
            } elseif ($a -eq "disable") {
                $cmd = "disable"
            } elseif ($a -eq "reset") {
                $cmd = "reset"

            } elseif ($a -eq "user" -or $a -eq "u") {
                $scope = "USER"
            } elseif ($a -eq "machine" -or $a -eq "m") {
                $scope = "MACHINE"
            } elseif ($a -eq "*" -or $a -eq "both") {
                $scope = "*"

            } elseif ($a -ne "") { 
                Write-Host "**** ERROR: Unknown command '$_'" -ForegroundColor "Red"
                return
            }
        } else {
            $a = $_.ToLower()
            if ($a -eq "user") {
                $scope = "USER"
            } elseif ($a -eq "machine") {
                $scope = "MACHINE"
            } elseif ($a -eq "*") {
                $scope = "*"
            } else {
                $files += $_
            }
        }
    }

    if ($cmd -eq "append") {
        appendPaths $files $scope $quiet $force
    } elseif ($cmd -eq "insert") {
        insertPaths $files $scope $quiet $force
    } elseif ($cmd -eq "remove") {
        removePaths $files $scope $quiet $force
    } elseif ($cmd -eq "disable") {
        # Disable-Paths $files $scope $quiet $force
    } elseif ($cmd -eq "reset") {
        # Reset-Paths $files $scope $quiet $force
    } else {
        Show-Path $files[0]
    }
}

function Show-Path( [string]$dir, [string]$scope = "" ) {
    $dir = $dir.TrimEnd("\").ToLower()

    $dirList = @()

    Write-Host ""
    Write-Host " FullName"
    Write-Host " --------"

    foreach ($p in $env:PATH.Split(";")) {
        if ($p -ne "") {
            $p = $p.Trim("\")
            if ($dir -ne "") {
                # filtering..
                if ($p.ToLower().IndexOf($dir) -eq -1) {
                    continue
                }
            }
            if (Test-Path -Path $p) {
                $color = "Cyan"
            } else {
                $color = "DarkRed"
            }
            Write-Host " $p" -ForegroundColor $color
        }
    }

    Write-Host ""
}

function removePathItem( [string]$newPath, [string]$dir, [bool]$quiet = $false, [bool]$force = $false ) {
    $newPath = $newPath.Trim()
    $dir = $dir.Trim().TrimEnd("\")

    if ($dir.ToLower() -eq "c:\bin" -or $dir.ToLower() -eq "c:\windows" -or $dir.ToLower() -eq "c:\windows\system32") {
        if ($force -eq $false) {
            Write-Host "    You must use --force to remove '$dir'." -ForegroundColor "Red"
            return
        }
    }

    $dirf = [System.IO.Path]::GetFullPath($dir)
    if ([string]::IsNullOrEmpty($dirf)) {
        # The directory doesn't actually exist
        $dirf = ""
    } else {
        $dirf = $dirf.ToLower()
    }
    $dir = $dir.ToLower()

    # Remove the directory from the PATH.
    $ar = @()
    foreach ($p in $newPath.Split(";")) {
        $pl = $p.ToLower()
        if ($pl -ne "" -and $pl -ne $dir -and $pl -ne $dirf) {
            $ar += $p
        } else {
            if ($quiet -eq $false) {
                Write-Host "    $p"
            }
        }
    }

    $newPath = [string]::Join(";", $ar).Replace(";;", ";").Trim(";")
    return $newPath
}

function removePaths( [array]$files, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $files | ForEach-Object -Process {
        removePath $_ $scope $quiet $force
    }
}

function removePath( [string]$dir, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $dir = $dir.Trim().TrimEnd("\")
    if ($dir.Length -eq 2 -and $dir.Substring(1,1) -eq ":") {
        $dir = $dir + "\"
    }
    $scope = $scope.Trim()

    if ($quiet -eq $false) {
        Write-Host "Removing '$dir'" -ForegroundColor "Cyan"
        Write-Host "  from environment:"
    }

    if ($dir.ToLower() -eq "c:\bin" -or $dir.ToLower() -eq "c:\windows" -or $dir.ToLower() -eq "c:\windows\system32") {
        if ($force -eq $false) {
            Write-Host "    You must use --force to remove '$dir'." -ForegroundColor "Red"
            return
        }
    }

    # Remove from the PATH in the current environment.
    $env:PATH = removePathItem $env:PATH $dir $quiet $force

    # Remove from the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  from hkcu:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = removePathItem $newpath $dir $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  from hklm:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = removePathItem $newpath $dir $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "Machine")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'USER' or 'MACHINE'." -ForegroundColor "Red"
            }
        }
    }
}

function insertPaths( [array]$files, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $files | ForEach-Object -Process {
        insertPath $_ $scope $quiet $force
    }
}

function insertPath( [string]$dir, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $dir = $dir.TrimEnd("\")

    if ($quiet -eq $false) {
        Write-Host "Inserting $dir" -ForegroundColor "Cyan"
        Write-Host "  into environment:"
    }

    # Remove $dir from the current PATH envar.
    removePath $dir $scope $true $force

    $dirf = [System.IO.Path]::GetFullPath($dir)
    if ([string]::IsNullOrEmpty($dirf)) {
        # The directory doesn't actually exist
        if ($force -eq $false) {
            Write-Host "**** WARNING: The specified directory doesn't exist. Use --force to force it." -ForegroundColor "Red"
            return
        } else {
            $dirf = $dir
        }
    }

    # Insert the PATH in the current environment.
    $env:PATH = "$dirf;" + $env:PATH.Replace(";;", ";").Trim(";")

    # Insert the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  into hkcu:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = "$dirf;" + $newpath.Replace(";;", ";").Trim(";")
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  into hklm:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = "$dirf;" + $newpath.Replace(";;", ";").Trim(";")
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "Machine")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'User' or 'Machine'." -ForegroundColor "Red"
            }
        }
    }
}

function appendPaths( [array]$files, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $files | ForEach-Object -Process {
        appendPath $_ $scope $quiet $force
    }
}

function appendPath( [string]$dir, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $dir = $dir.TrimEnd("\")

    if ($quiet -eq $false) {
        Write-Host "Appending $dir" -ForegroundColor "Cyan"
        Write-Host "  into environment:"
    }

    # Append the PATH in the current environment.
    removePath $dir $scope $true $force

    # Append the PATH in the registry.
    $dirf = [System.IO.Path]::GetFullPath($dir)
    if ([string]::IsNullOrEmpty($dirf)) {
        # The directory doesn't actually exist
        if ($force -eq $false) {
            Write-Host "**** WARNING: The specified directory doesn't exist. Use --force to force it." -ForegroundColor "Red"
            return
        } else {
            $dirf = $dir
        }
    }

    $env:PATH = $env:PATH.Replace(";;", ";").Trim(";") + ";$dirf"

    # Update the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  into hkcu:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = $newpath.Replace(";;", ";").Trim(";") + ";$dirf"
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  into hklm:"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = $newpath.Replace(";;", ";").Trim(";") + ";$dirf"
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "Machine")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'User' or 'Machine'." -ForegroundColor "Red"
            }
        }
    }
}
