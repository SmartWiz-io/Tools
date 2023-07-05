<#
.SYNOPSIS
  Tools to Populate Unit Test Files for an exsisting directory

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023
#>

<#
    Create Some Constants to use for error messages
#>
Set-Variable -Name MODULEERRORS -Option Constant -Value @{
    1='Input path not found';
    2='Expected A File, but found a container';
    3='Item path not contained in base path';
    4='Ensure-Path does not expect a path to an exsisting non-directory item';
    5='Very Unexpected.  Item from Wrapper of GCI returned a object outside of a viable path';
}

<#
.SYNOPSIS
  Throw an Error (Terminate or Trap externally)

.DESCRIPTION
  Throw a terminating error that the consumer can handle if wanted
  So really this is here for a place to do error logging

.PARAMETER Message
    [string] [Mandatory] The Human Readable Error Message
.PARAMETER Number
    [int] [Mandatory] The Error Number as an integer 
.PARAMETER Data
    [string] [optional] Extra data to help describe the error if present

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  Throw-ToolError -Message "Failed to find Type" -Number 52 -Data "System.IO.NoType"
  Throw-ToolError -Message "Failed to access a thing" -Number 5

#>
function Throw-ToolError
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [int] $Number,
        
        [string] $Data
    )
 

    # Construct an Error Message on Required Info
    $errorMessage = [string]::format("{0}:{1}",$Number,$Message);

    # If more Data was passed in add it
    if($Data)
    {
        $errorMessage = [string]::Format("{0}:{1}", $errorMessage, $Data);
    }

    throw $errorMessage;
}

<#
.SYNOPSIS
  Return the delta of two paths

.PARAMETER Item
    [System.IO.FileSystemInfo] [Mandatory] [ValueFromPipeline] Full Path to File or Directory of which we want to take off the base
.PARAMETER RootDirectory
    [System.IO.DirectoryInfo] [Mandatory] Base DirectoryInfo (Object) to remove


.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  Get-PathPortion -RootDirectory (Get-Item "C:\Temp") -Item (Get-Item "C:\Temp\Folder\File.cs")
    Returns: Folder\File.cs

#>
function Get-PathPortion
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]    
        [System.IO.FileSystemInfo] $Item,
        [Parameter(Mandatory)]    
        [System.IO.DirectoryInfo] $RootDirectory

    )

    $basePath = ($RootDirectory.FullName).ToLower();
    $itemPath = ($Item.FullName).ToLower();

    # Validate we have the same base path
    if(-not ($itemPath.Contains($basePath)))
    {
        # If the base path is not contained in the item path... Throw
        Throw-ToolError `
            -Message 3 `
            -Number $MODULEERROR[3] `
            -Data ([string]::Format("Base {0} - Item {1}", $basePath, $itemPath))
    }

    # Remove the base path and return remainder
    # example RootDirectory: c:\taxes\data\ Item: c:\taxes\data\subdir\myfile.cs -> 
    $relativePathItem = $itemPath.Replace($basePath, '');

    #remove a leading '\' if present (use single quotes or we need to escape the backslash
    return $relativePathItem.TrimStart('\');
}

<#
.SYNOPSIS
    Return a new name if matching file filter

.DESCRIPTION
    Not the best approach as it is brittle and could be better with full regex later

.PARAMETER ItemRelativePath
    [string] [Mandatory] [ValueFromPipeline] The relative portion of the path and the file name example: home\project-one\controllers\serviceController.cs

.PARAMETER FilteTypes
    [string] [Optional] File Extension to Match.  Defaults to .cs if not supplied

.PARAMETER NewPathPortion
    [string] [Optional] A part of the file name that is put prior to the file extension
    Defaults to .Test if not supplied 

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  Get-PathPortion -RootDirectory (Get-Item "C:\Temp") -Item (Get-Item "C:\Temp\Folder\File.cs")
    Returns: Folder\File.cs

#>
function Get-NewItemName
{
    param(
        [Parameter(Mandatory, ValueFromPipeline)]    
        [string] $ItemRelativePath,

        [string[]] $FileTypes = @('.cs'),

        [string] $NewPathPortion = '.Tests'
    )

    #normalize to lowercase
    $ItemRelativePath = $ItemRelativePath.ToLower();

    foreach($fileType in $FileTypes)
    {
        if($ItemRelativePath.EndsWith($FileTypes))
        {
            # Add the path portion before the file type
            $newEndPortion = $NewPathPortion + $fileType;

            # remove the filetype match off the end and add the new end portion
            return $ItemRelativePath.TrimEnd($FileType) + $newEndPortion;
        }
    }
}

<#
.SYNOPSIS
  Get a list of items exluding top level subfolders

.DESCRIPTION
  Get a list of recursive child items exluding an array of strings that are
  root or top level of the base search folders

    C:\Temp\Test\
    |
    ├╴bin\
    |  |
    |  └╴netcore3.1\
    |    |
    |    └╴something.exe
    |
    └╴MyApplication\
      |
      ├╴BinFile.txt
      ├╴FileA.txt
      ├╴FileB.txt
      |
      └╴bin\
        |
        └╴Debug\
          |
          └╴SomeFile.txt

Would Result in:

    C:\Temp\Test\
    |
    └╴MyApplication\
      |
      ├╴BinFile.txt
      ├╴FileA.txt
      └╴FileB.txt
      └╴bin\
        |
        └╴Debug\
          |
          └╴SomeFile.txt
  
.PARAMETER Directory
    [System.IO.DirectoryInfo] [Mandatory] [ValueFromPipeline] Path to get recursive items from
    example: C:\Temp\Test

.PARAMETER ExcludedDirectories
    [string[]] Array of strings that are root / top  level folders to exclude
    example: 'bin','obj'

.PARAMETER IncludedFileTypes
    [string[]] Array of file extensions to work with
    example: '.cs'

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  # See description (all items in the project not including stuff in c:\temp\test\bin\* or c:\temp\test\obj\*)
  Get-ChildItemExludeRootSubFolders -Directory 'C:\Temp\Test'
  
  # See description (all items in the project not including stuff in c:\temp\test\MyApplication\*)
  Get-ChildItemExludeRootSubFolders -Directory 'C:\Temp\Test' -ExcludedDirectories 'MyApplication'
#>

# should ensure path here while iterating the directories 
function Get-ChildItemExcludeRootSubFolders
{
    param(
        [Parameter(Mandatory, ValueFromPipeline)] 
        [System.IO.DirectoryInfo] $Directory,

        [string[]] $ExcludedDirectories = @('bin','obj'),
        [string[]] $IncludedFileTypes = @('.cs')
    )

    $rootDirectories = Get-ChildItem -Path $Directory -Exclude $ExcludedDirectories -Directory
   
    # Get the files in all the directories that match the included file type filter
    return Get-ChildItem -Path $rootDirectories -Recurse -File | Where-Object {$_.Extension -in $IncludedFileTypes}

    # Have a fringe case here.  Empty folder would not move over
    # might want exclude at root, exclude as like, exclude starts with.  or have it be a list of types of exclusions or a switch
}

<#
.SYNOPSIS
  Take a path and make sure it exsists

.DESCRIPTION
  Given a string path, check it to ensure it isn't a file and then create it fully on the file system

.PARAMETER Path
    [string] [Mandatory] [ValueFromPipeline] Path of some directory

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  'C:\Temp\Test' | Ensure-Path
  
  Ensure-Path -Path 'C:\Temp\Test'
#>
function Ensure-Path
{
    param(
        [Parameter(Mandatory, ValueFromPipeline)]   
        [string] $Path
    )
    # Changed this to only get called via a new path for a file...  so don't need many validations

    <#--- Currently Unused, but interesting code
    # This path may not exist (we can't cast directly to a filesysteminfo object)
    # Test to see if exists


    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_enum?view=powershell-7.3
    #if(($Directory -band [System.IO.FileAttributes]::Directory) -ne [System.IO.FileAttributes]::Directory)
    #{
    #    # If It is not already a directory get the container path
    #    $castDirectory = [System.IO.FileInfo]$Directory;
    #
    #    $pathToEnsure = $castDirectory.Directory
    #}
    --#>
    # Shouldn't be able to get here, but if we get a path that is a file throw
    if(Test-Path $Path -PathType Leaf)
    {
        Throw-ToolError `
            -Message $MODULEERROR[4] `
            -Number 4 `
            -Data ([string]::Format("Base {0} - Item {1}", $basePath, $itemPath))        
    }

    # if the contaier path is already created we do not need to do anything
    if(-not(Test-Path $Path -PathType Container))
    {
        # We are using Force here in case more than one portion of the path isn't created.
        New-Item -Path $Path -ItemType Directory -Force| Out-Null
    }
}

<#
.SYNOPSIS
  Copy File Structure and make Unit Test files for CS files

.DESCRIPTION
  Copy Files and File structure to make Unit Test Files.  We should have matching folders and files with Unit Test Files in the associated project.
  So if we have a project: MyStuff
  With a folder \Controllers\
  and a file inside taxController.cs
  the Unit Test project: MyStuff.Tests
  should have a folder \Controllers\
  with a file inside to match taxController.Tests.cs
  
.PARAMETER RootDirectory
    [System.IO.DirectoryInfo][Mandatory] Path to project to clone for unit testing.
    example: C:\Source\Repo\SmartWiz\MainProject\

.PARAMETER DestinationDirectory
    [System.IO.DirectoryInf]o[Mandatory] "DD] Path to Unit Test Project to get cloned from root project directory
    example: C:\Source\Repo\SmartWiz\MainProject.Tests\

.PARAMETER TemplateFileName
    [System.IO.FileInfo][Mandatory] File Name of Template File including Path
    example Unit

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023
#>
function Copy-DirectoryForUnitTests
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]   
        [System.IO.DirectoryInfo] $RootDirectory,

        [Parameter(Mandatory)]   
        [System.IO.DirectoryInfo] $DestinationDirectory,

        [Parameter(Mandatory)]   
        [System.IO.FileInfo] $TemplateFileName
    )

    # --- Collect Needed Data ---
    # Get all items in a root path (we don't want bin or obj directories (these are build folders))
    $itemsToCopy = $RootDirectory | Get-ChildItemExcludeRootSubFolders

    # --- Main Working Loop ---
    # Iterate and copy items with new settings and names.
    Foreach($item in $itemsToCopy)
    {


        # Compare to see if it is a type we can use
        Switch ($item)
        {
            # Case is Directory
            {$_ -is [System.IO.DirectoryInfo]}
            {
                # Do nothing here will get done with files
                # now order isn't important
                break;
            }

            # Case is File
            {$_ -is [System.IO.FileInfo]}
            {
                # Get the relative portion of the path to create and then get a new name for it (using pipelining)
                $newRelativeName =  $item | Get-PathPortion -RootDirectory $RootDirectory | Get-NewItemName;

                # Join the dest root with the relative path to the new item and return as string path.  It may not yet exsist.
                $newFullName = Join-Path $DestinationDirectory $newRelativeName;

                # Drop the file portion off the path [string] (remove last leaf which is a file or we expect it to be)
                $parentContainer = $newFullName | Split-Path

                # Ensure the directory is created
                $parentContainer | Ensure-Path
                
                # If the object already exsists then leave it:
                if(-not (Test-Path -Path $newFullName -PathType Leaf))
                {
                    # Copy the template object to the new name and path
                    $TemplateFileName.CopyTo($newFullName) | Out-Null;
                }
                break;
            }
            
            # Case Else
            Default 
            {
                # Encountered a fatal type outside of acceptable types
                # We may want to eat this and log later.
                Throw-ToolError `
                    -Message $MODULEERROR[5] `
                    -Number 5 `
                    -Data ($item.GetType().Name)
            }
        }
    }
}

Export-ModuleMember -Function Copy-DirectoryForUnitTests