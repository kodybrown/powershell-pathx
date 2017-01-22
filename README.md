# powershell-pathx

Utility for manipulating the PATH (envar and registry) from the command-line.


Windows-Only
------------

This only works on Windows. Sorry, I haven't tried any PowerShell on Linux nor OSX yet!


Installation:
-------------

Put the `pathx` directory in `%UserProfile%\Documents\WindowsPowerShell\Modules`.

    PS> cd "%UserProfile%\Documents\WindowsPowerShell\Modules"
    PS> git clone https://github.com/kodybrown/powershell-pathx pathx

Import the pathx module in your `Profile.ps1` file:

    PS> echo Import-Module pathx>> $PROFILE

Reload your Profile (or restart your console):

    PS> . $PROFILE


Command-line Usage:
-------------------

    PS> Show-Path [SearchExpr]
    PS> Edit-Path [--insert|--add|--remove|--enable|--disable] [--force] "C:\NewDir" ... [--user|--machine|--both]


Commands:
---------

*Show-Path*: Shows the current path envar, one directory per line. Directories that do not exist are highlighted in red. (alias: pathx)

*Edit-Path*: Allows you to add, insert, and remove paths from the environment and also make the changes permanent via the registry. (alias: edpath)

Notes:

Multiple directories can be specified.

    PS> edit-path --insert "C:\NewDir" "C:\Additional\Dir" ...


Flags:
------

*-q*|*--quiet*: Reduces the console output.

*-a*|*--add*|*--append*: Append the specified directory (or directories) to the end of the PATH.

*-i*|*--insert*: Insert the specified directory (or directories) to the beginning of the PATH.

*-rm*|*--remove*: Removes the specified directory (or directories) from the PATH.

*--disable*: Disables the specified directory (or directories) in the PATH.

*--enable*: Enables the specified directory (or directories) in the PATH.

*--force*: Allows removing a protected directory (see notes below in 'Adding and Removing' section). Also, used to allow adding (or inserting) a directory that does not exist.

*-u*|*--user*: also make the change to the HKCU Registry hive.

*-m*|*--machine*: also make the change to the HKLM Registry hive.

*--both*: also make the change to both the HKCU and HKLM Registry hives.

>Note: The `-` and `/` are (mostly) interchangeable. As are using `-` or `--`. 


Adding and Removing
-------------------

If the directory being added or inserted does not exist a warning will be displayed; use `--force` to override it.

Also, in order to remove the `C:\Bin`, `C:\Windows`, or `C:\Windows\System32` directories, you must also specify the `--force` flag.


## Examples

Show the current environment path:

>Assume every example uses this set of directories, before each command is executed.

    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common

    PS> pathx bin

     FullName
     --------
     C:\Bin
     C:\Go\bin
     C:\ProjectBin

    PS> pathx \bin

     FullName
     --------
     C:\Bin
     C:\Go\bin

Add directories:

    PS> edit-path --append C:\NewDir
    Appending C:\NewDir
      into environment
    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common
     C:\NewDir

    PS> edit-path --append C:\Go\bin
    Appending C:\Go\bin
      into environment
    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common
     C:\Go\bin          <-- Notice `C:\Go\bin` moved from the fourth position to the last..

Insert directories:

    PS> edit-path --insert C:\NewDir
    Inserting C:\NewDir
      into environment
    PS> pathx

     FullName
     --------
     C:\NewDir
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common

    PS> edit-path --insert C:\Go\bin
    Inserting C:\Go\bin
      into environment
    PS> pathx

     FullName
     --------
     C:\Go\bin          <-- Notice `C:\Go\bin` moved from the fourth position to the first..
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common

Remove directories:

    PS> edit-path --remove "C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common"
    Removing C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common
      from environment
    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin

Disable directories:

>Note: Directories are disabled by inserting `DISABLED` at the beginning of the directory.

    PS> edit-path --disable "C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common"
    Disabling C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common"
      in environment
    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\DISABLED\Program Files (x86)\NVIDIA Corporation\PhysX\Common

Enable directories:

>Note: Directories are enabled by removing `DISABLED` from the beginning of the directory.

    PS> edit-path --enable "C:[\DISABLED]\Program Files (x86)\NVIDIA Corporation\PhysX\Common"
    Disabling C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common"
      in environment
    PS> pathx

     FullName
     --------
     C:\Bin
     C:\WINDOWS\System32
     C:\WINDOWS
     C:\Go\bin
     C:\WINDOWS\System32\Wbem
     C:\WINDOWS\System32\WindowsPowerShell\v1.0
     C:\ProjectBin
     C:\Program Files (x86)\NVIDIA Corporation\PhysX\Common

