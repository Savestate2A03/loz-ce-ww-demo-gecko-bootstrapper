$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot

# box drawing function
function Format-Box {
    param([string[]]$Lines)

    [int]$width = ($Lines | Measure-Object -Property Length -Maximum).Maximum

    # need to encode as [char] because powershell explodes if you
    # actually try to assign the character as a string lol
    $topLeft     = [char]0x250C
    $topRight    = [char]0x2510
    $bottomLeft  = [char]0x2514
    $bottomRight = [char]0x2518
    $vertical    = [char]0x2502
    $border      = ([string][char]0x2500) * ($width + 2)

    "$topLeft$border$topRight"
    foreach ($line in $Lines) {
        "$vertical $(([string]$line).PadRight($width)) $vertical"
    }
    "$bottomLeft$border$bottomRight"
}

try {
    # create build directory
    $outputDir = Join-Path $PSScriptRoot 'build'
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $regions = [ordered]@{ usa = 'PZLE01'; jp = 'PZLJ01'; pal = 'PZLP01' }
    foreach ($region in $regions.Keys) {
        # prepare assembly output files
        $stem = "restore-menus-$region"
        $objectPath = Join-Path $outputDir "$stem.o"
        $binaryPath = Join-Path $outputDir "$stem.bin"
        $codePath = Join-Path $outputDir "$stem.gecko.txt"

        # assemble time
        $regionSymbol = 'REGION_{0}=1' -f $region.ToUpper()
        & "$PSScriptRoot\powerpc-gekko-as.exe" -mregnames --defsym $regionSymbol lozce_persistent.asm -o $objectPath
        if ($LASTEXITCODE -ne 0) { throw 'powerpc-gekko-as error!' }

        # grab the binary data from the object output
        & "$PSScriptRoot\powerpc-eabi-objcopy.exe" -O binary $objectPath $binaryPath
        if ($LASTEXITCODE -ne 0) { throw 'powerpc-eabi-objcopy error!' }

        # read all words from the binary and iterate through them
        $bytes = [IO.File]::ReadAllBytes($binaryPath)
        $words = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $bytes.Length; $i += 4) {
            $words.Add(('{0:X2}{1:X2}{2:X2}{3:X2}' -f $bytes[$i], $bytes[$i+1], $bytes[$i+2], $bytes[$i+3]))
        }
        if ($words.Count % 2 -eq 1) { $words.Add('00000000') } # add extra word of 0s if odd number of words
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(('C0000000 {0:X8}' -f ($words.Count / 2))) # start crafting the gecko code based on word size
        for ($i = 0; $i -lt $words.Count; $i += 2) {
            $lines.Add(('{0} {1}' -f $words[$i], $words[$i+1]))
        }

        # gecko code wrapper
        $lines = (
            @("`$Timer Disable/Menu Restoration [Savestate, SuperDude88]") +
            $lines +
            @(
                ("*Collector's Edition {0} ({1})." -f $region.ToUpper(), $regions[$region]),
                "*Disables the timer, and restores the menus/saving in the TWW demo.",
                "*The project can be found at:",
                "*https://github.com/Savestate2A03/loz-ce-ww-demo-gecko-bootstrapper"
            )
        )

        # write the final gecko code
        [IO.File]::WriteAllLines($codePath, $lines, [Text.Encoding]::ASCII)

        # output the final results of assembler in a box using box-drawing characters
        $outputLines = @(
            ("Built gecko code {0}!" -f (Resolve-Path -Path $codePath -Relative)),
            ("Size: {0} bytes/{1} lines." -f $bytes.Length, $lines.Count)
        )
        Format-Box -Lines $outputLines
    }

} finally {
    Pop-Location
}