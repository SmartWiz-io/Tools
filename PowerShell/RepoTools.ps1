<#
.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

# --- Some Global Constants ---
Set-Variable PathErrorNum -Option Constant -Value 1
Set-Variable PathErrorMessage -Option Constant -Value "Input Path is Not Found."
Set-Variable InvalidTypeErrorNum -Option Constant -Value 2
Set-Variable InvalidTypeErrorMessage -Option Constant -Value "Invalid Type for operation."
Set-Variable BasePathNotContainedErrorNum -Option Constant -Value 3
Set-Variable BasePathNotContainedErrorMessage -Option Constant -Value "The base path was not found in the item path and the operation is invalid."


<#
.SYNOPSIS
  Throw an Error (Terminate or Trap externally)

.DESCRIPTION
  Throw a terminating error that the consumer can handle if wanted

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

    throw [System.Exception] $errorMessage;
}


<#
.SYNOPSIS
  Throw and Error if input Path doesn't exist or can't be reached

.DESCRIPTION
  Throw a terminating error that the consumer can handle if wanted specific to a missing or bad path

.PARAMETER Path
    [string] [Mandatory] [pipeline-able] Path to something (can include a filename or may be a directory etc)

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  "C:\Temp" | Test-PathAndThrow
  # If C:\Temp exists will return nothing - If c:\temp does not exist will throw System.Exception "Input Path not found" Number 1

  Test-PathAndThrow "C:\NotAThing"
  # Will throw a System.Exception with data Message "Input Path not found" Number 1
  # if the path exists will return to caller (no return value(s))
#>
function Test-PathAndThrow
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]  
        [string] $Path
    )

    if(-not(Test-Path -Path $Path))
    {
        Throw-ToolError 
            -Number $PathErrorNum 
            -Message $PathErrorMessage 
            -Data $Path
    }
    # Construct and return a filesysteminfo object 
    return Get-Item -Path $Path
}

<#
.SYNOPSIS
  Return the delta of two paths

.PARAMETER RootDirectory
    [System.IO.DirectoryInfo] [Mandatory] Base DirectoryInfo (Object) to remove
.PARAMETER Item
    [System.IO.FileSystemInfo] [Mandatory] Full Path to File or Directory of which we want to take off the base

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
        [Parameter(Mandatory)]    
        [System.IO.DirectoryInfo] $RootDirectory,
        [Parameter(Mandatory)]    
        [System.IO.FileSystemInfo] $Item
    )

    $basePath = $RootDirectory.FullName;
    $itemPath = $Item.FullName;

    # Validate we have the same base path
    if(-not ($itemPath.Contains($basePath)))
    {
        # If the base path is not contained in the item path... Throw
        Throw-ToolError 
            -Message BasePathNotContainedErrorMessage 
            -Number BasePathNotContainedErrorNum 
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
    [string] [Mandatory] The relative portion of the path and the file name example: home\project-one\controllers\serviceController.cs

.PARAMETER FilteTypeFilter
    [string] [Optional] File Extension to Match.  Defaults to .cs if not supplied

.PARAMETER NewFileType
    [string] [Optional] Sort of like a new file type, but really just appending .Tests after the file name and before the file extension.  
    Defaults to .Test.cs if not supplied 

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
        [Parameter(Mandatory)]    
        [string] $ItemRelativePath,

        [string] $FileTypeFilter = '.cs',

        [string] $NewFileType = '.Tests.cs'
    )

    return $ItemRelativePath -replace $FileTypeFilter, $NewFileType

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
    [string] [Mandatory] [Aliases "RD"] Path to project to clone for unit testing.
    example: C:\Source\Repo\SmartWiz\MainProject\

.PARAMETER DestinationDirectory
    [string] [Mandatory] [Aliases "DD] Path to Unit Test Project to get cloned from root project directory
    example: C:\Source\Repo\SmartWiz\MainProject.Tests\

.PARAMETER TemplateFileName
    [string] [Mandatory] File Name of Template File at root of destination project to copy as basis for unit test files
    example Unit

.NOTES
  Version:        1.0
  Author:         Geoffrey DeFilippi (gdefilippi@smartwiz.io)
  Creation Date:  7/1/2023

  
.EXAMPLE
  "C:\Temp" | Test-PathAndThrow
  # If C:\Temp exists will return nothing - If c:\temp does not exist will throw System.Exception "Input Path not found" Number 1

  Test-PathAndThrow "C:\NotAThing"
  # Will throw a System.Exception with data Message "Input Path not found" Number 1
  # if the path exists will return to caller (no return value(s))
#>
function Copy-DirectoryForUnitTests
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] 
        [Alias("RD")]    
        [string] $RootDirectory,

        [Parameter(Mandatory)]
        [Alias("DD")]
        [string] $DestinationDirectory,

        [Alias("TFN")]
        [string] $TemplateFileName

    )
    # Get a path to our TemplateFile
    $templateFile = Join-Path $DestinationDirectory $TemplateFileName;

    # --- Validate input --
    # Test Path(s)
    $rootObj = Test-PathAndThrow -Path $RootDirectory;
    $destObj = Test-PathAndThrow -Path $DestinationDirectory;
    $tplObj = Test-PathAndThrow -Path $templateFile;

    # --- Collect Needed Data ---
    # Get all items in a root path
    $itemsToCopy = Get-ChildItem $RootDirectory -Recurse;

    # --- Main Working Loop ---
    # Iterate and copy items with new settings and names.
    Foreach($item in $itemsToCopy)
    {
        # Get the relative portion of the path to create
        $itemRelativePath = Get-PathPortion -RootDirectory $rootObj -Item $item;

        # Compare to see if it is a type we can use
        Switch ($item)
        {
            # Case is Directory
            {$_ -is [System.IO.DirectoryInfo]}
            {
                # Combine the base path with the relative path
                $newDir = Join-Path $destObj $itemRelativePath;

                # Check to see if the directory / path exists.  Using force would work, but for safety we will only create missing items.
                # Testing new-item -force doesn't remove things in the path if it exists, but that could change.
                if(-not (Test-Path -Path $newDir -PathType Container))
                {
                    # Directory is not there.  Create it (no rename needed here is not a file)
                    New-Item -Path $newDir -ItemType Directory;
                }

                break;
            }

            # Case is File
            {$_ -is [System.IO.FileInfo]}
            {
                # Create the file name for the unit test file...  
                $newRelativeName = Get-NewItemName -ItemRelativePath $itemRelativePath;

                # Join the dest root with the relative path to the new item
                $newFullName = Join-Path $destObj $newRelativeName;
                
                # Copy the template object to the new name and path
                $tplObj.CopyTo($newFullName);
                break;
            }
            
            # Case Else
            Default 
            {
                # Encountered a fatal type outside of acceptable types
                # We may want to eat this and log later.
                Throw-ToolError -Message $InvalidTypeErrorMessage -Number $InvalidTypeErrorNum -Data ($item.GetType().Name)
            }
        }
    }
}