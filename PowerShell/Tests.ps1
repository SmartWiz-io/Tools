function Test-Geoff
{
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $dir
    )

    return $dir

}