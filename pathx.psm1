# Pathx
# Utility for altering the PATH (envar and registry) from the command-line.
# PowerShell version.
# Created 2011-2017 Kody Brown.
# Released under the MIT License.

Set-Alias path Show-Path
Set-Alias pathx Show-Path
Set-Alias edpath Edit-Path

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
        if ($_.StartsWith("-") -or $_.StartsWith("/")) {
            while ($_.StartsWith("-") -or $_.StartsWith("/")) {
                $_ = $_.Substring(1)
            }
            $a = $_.ToLower()

            if ($a -eq "quiet") {
                $quiet = $true

            } elseif ($a -eq "force") {
                $force = $true

            } elseif ($a -eq "add" -or $a -eq "append" -or $a -eq "a") {
                $cmd = "append"
            } elseif ($a -eq "insert" -or $a -eq "i") {
                $cmd = "insert"
            } elseif ($a -eq "rm" -or $a -eq "remove") {
                $cmd = "remove"
            } elseif ($a -eq "disable") {
                $cmd = "disable"
            } elseif ($a -eq "enable") {
                $cmd = "enable"
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
        disablePaths $files $scope $quiet $force
    } elseif ($cmd -eq "enable") {
        enablePaths $files $scope $quiet $force
    } elseif ($cmd -eq "reset") {
        resetPath $scope $quiet $force
    } else {
        Show-Path $files[0]
    }
}

function Show-Path( [string]$dir, [string]$scope = "" ) {
    $dir = $dir.TrimEnd("\").ToLower()

    $showIndex = $false
    $count = 0

    # total lazy hack..
    if ($dir -eq "--count") {
        $dir = ""
        $showIndex = $true
    } elseif ($scope -eq "--count") {
        $showIndex = $true
    }

    Write-Host ""
    if ($showIndex) {
        Write-Host " Idx  FullName"
        Write-Host " ---  --------"
    } else {
        Write-Host " FullName"
        Write-Host " --------"
    }

    foreach ($p in $env:PATH.Split(";")) {
        if ($p -ne "") {
            $count++
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
            if ($showIndex) {
                $tmp = $count.ToString().PadLeft(3, ' ')
                Write-Host " $tmp  $p" -ForegroundColor $color
            } else {
                Write-Host " $p" -ForegroundColor $color
            }
        }
    }

    Write-Host ""
}

function replacePathItem( [string]$newPath, [string]$dir, [string]$replwith, [bool]$quiet = $false, [bool]$force = $false ) {
    $newPath = $newPath.Trim()
    $dir = $dir.Trim().TrimEnd("\")
    $replwith = $replwith.Trim().TrimEnd("\")

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
            $ar += $replwith
            if ($quiet -eq $false) {
                Write-Host "    $p"
            }
        }
    }

    $newPath = [string]::Join(";", $ar).Replace(";;", ";").Trim(";")
    return $newPath
}

function findDirectoryIndex( [string]$paths, [string]$dir ) {
    $paths = $paths.Trim().Trim(";").TrimEnd("\")
    $dir = $dir.Trim().TrimEnd("\")

    $dirf = [System.IO.Path]::GetFullPath($dir)
    if ([string]::IsNullOrEmpty($dirf)) {
        # The directory doesn't actually exist
        $dirf = ""
    } else {
        $dirf = $dirf.ToLower()
    }
    $dir = $dir.ToLower()

    [int]$count = -1
    [int]$index = -1

    foreach ($p in $paths.Split(";")) {
        $count++
        $pl = $p.ToLower()
        if ($pl -ne "" -and ($pl -eq $dir -or $pl -eq $dirf)) {
            $index = $count
            break
        }
    }

    return $index
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
        Write-Host "  from environment"
    }

    if ($dir.ToLower() -eq "c:\bin" -or $dir.ToLower() -eq "c:\windows" -or $dir.ToLower() -eq "c:\windows\system32") {
        if ($force -eq $false) {
            Write-Host "    You must use --force to remove '$dir'." -ForegroundColor "Red"
            return
        }
    }

    # Update the PATH in the current environment.
    $env:PATH = replacePathItem $env:PATH $dir "" $quiet $force

    # Update the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  from hkcu"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = replacePathItem $newpath $dir "" $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  from hklm"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = replacePathItem $newpath $dir "" $quiet $force
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
        Write-Host "  into environment"
    }

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

    # Update the PATH in the current environment.
    $env:PATH = "$dirf;" + $env:PATH.Replace(";;", ";").Trim(";")

    # Update the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  into hkcu"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = "$dirf;" + $newpath.Replace(";;", ";").Trim(";")
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  into hklm"
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
        Write-Host "  into environment"
    }

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

    # Update the PATH in the current environment.
    $env:PATH = $env:PATH.Replace(";;", ";").Trim(";") + ";$dirf"

    # Update the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  into hkcu"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = $newpath.Replace(";;", ";").Trim(";") + ";$dirf"
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  into hklm"
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

function enablePaths( [array]$files, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $files | ForEach-Object -Process {
        enablePath $_ $scope $quiet $force
    }
}

function enablePath( [string]$dir, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $dir = $dir.TrimEnd("\")
    if ($dir.Contains("\DISABLED") -and $dir.Substring(2, 9) -eq "\DISABLED") {
        $disabled = $dir
        $dir = ($dir.Substring(0, 2) + $dir.Substring(11)).Replace("\\", "\").Trim("\")
    } else {
        $disabled = ($dir.Substring(0, 2) + "\DISABLED\" + $dir.Substring(2)).Replace("\\", "\").Trim("\")
    }

    # Write-Host "dir=$dir"
    # Write-Host "disabled=$disabled"

    if ($quiet -eq $false) {
        Write-Host "Enabling $dir" -ForegroundColor "Cyan"
        Write-Host "  in environment"
    }

    # Update the PATH in the current environment.
    if ($env:PATH.ToLower().IndexOf($disabled.ToLower()) -gt -1) {
        $env:PATH = replacePathItem $env:PATH $disabled $dir $quiet $force
    }

    # Update the PATH in the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  in hkcu"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = replacePathItem $newpath $disabled $dir $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  in hklm"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = replacePathItem $newpath $disabled $dir $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "Machine")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'User' or 'Machine'." -ForegroundColor "Red"
            }
        }
    }
}

function disablePaths( [array]$files, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $files | ForEach-Object -Process {
        disablePath $_ $scope $quiet $force
    }
}

function disablePath( [string]$dir, [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    $dir = $dir.TrimEnd("\")
    $disabled = ($dir.Substring(0, 2) + "\DISABLED\" + $dir.Substring(2)).Replace("\\", "\").Trim("\")

    # Write-Host "dir=$dir"
    # Write-Host "disabled=$disabled"

    if ($quiet -eq $false) {
        Write-Host "Disabling $dir" -ForegroundColor "Cyan"
        Write-Host "  in environment"
    }

    # Update the PATH in the current environment.
    if ($env:PATH.ToLower().IndexOf($dir.ToLower()) -gt -1) {
        $env:PATH = replacePathItem $env:PATH $dir $disabled $quiet $force
    }

    # Update the PATH in the registry.
    if ($scope -ne "") {
        # replaceInRegistry $dir $disable $scope $quiet $force
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  in hkcu"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $newpath = replacePathItem $newpath $dir $disabled $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "User")
            }
            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  in hklm"
                }
                $newpath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $newpath = replacePathItem $newpath $dir $disabled $quiet $force
                [Environment]::SetEnvironmentVariable("PATH", $newpath, "Machine")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'User' or 'Machine'." -ForegroundColor "Red"
            }
        }
    }
}

function resetPath( [string]$scope = "", [bool]$quiet = $false, [bool]$force = $false ) {
    # Update the local PATH from the registry.
    if ($scope -ne "") {
        $scope = $scope.ToUpper()
        if ($scope -eq "*" -or $scope -eq "USER" -or $scope -eq "MACHINE") {
            if ($quiet -eq $false) {
                Write-Host "Reseting PATH" -ForegroundColor "Cyan"
                Write-Host "  in environment"
            }

            if ($scope -ne "*" -and $force -eq $false) {
                Write-Host "**** You must specify `--force` to reset from only one of the Registry hives." -ForegroundColor "Red"
                return
            }

            $env:PATH = ""

            if ($scope -eq "*" -or $scope -eq "MACHINE") {
                if ($quiet -eq $false) {
                    Write-Host "  from hklm"
                }
                $env:PATH += ";" + [Environment]::GetEnvironmentVariable("PATH", "Machine")
            }
            if ($scope -eq "*" -or $scope -eq "USER") {
                if ($quiet -eq $false) {
                    Write-Host "  from hkcu"
                }
                $env:PATH += [Environment]::GetEnvironmentVariable("PATH", "User")
            }
        } else {
            if ($quiet -eq $false) {
                Write-Host "**** ERROR: Invalid scope specified ('$scope'). Must be '*', 'User' or 'Machine'." -ForegroundColor "Red"
            }
        }
    }
}
