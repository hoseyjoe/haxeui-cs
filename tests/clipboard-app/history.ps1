# Whether texts are in Windows' clipboard history (Win+V), for clipboard-app. Windows PowerShell 5.1
# (`powershell.exe`, which projects WinRT): `history.ps1 -Present <text> -Absent <text>` exits 0 when
# the first is in the history and the second is not, 1 when not, 2 when history is off or unreadable.
# It prints only what it found about those two texts, never what else the history holds.
param([Parameter(Mandatory)] [string]$Present, [Parameter(Mandatory)] [string]$Absent)

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.ApplicationModel.DataTransfer.Clipboard, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    function Await($operation, [Type]$type) {
        $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
        if (-not $task.Wait(5000)) { throw "timed out" }
        $task.Result
    }

    if (-not [Windows.ApplicationModel.DataTransfer.Clipboard]::IsHistoryEnabled()) {
        Write-Output "history.ps1: clipboard history is off"
        exit 2
    }
    $result = Await ([Windows.ApplicationModel.DataTransfer.Clipboard]::GetHistoryItemsAsync()) ([Windows.ApplicationModel.DataTransfer.ClipboardHistoryItemsResult])
    if ($result.Status -ne [Windows.ApplicationModel.DataTransfer.ClipboardHistoryItemsResultStatus]::Success) {
        Write-Output "history.ps1: history not readable ($($result.Status))"
        exit 2
    }
    $texts = foreach ($item in $result.Items) {
        if ($item.Content.Contains([Windows.ApplicationModel.DataTransfer.StandardDataFormats]::Text)) {
            Await ($item.Content.GetTextAsync()) ([string])
        }
    }
} catch {
    Write-Output "history.ps1: history not readable ($_)"
    exit 2
}

$hasPresent = @($texts) -contains $Present
$hasAbsent = @($texts) -contains $Absent
Write-Output "history.ps1: ""$Present"" in history: $hasPresent; ""$Absent"" in history: $hasAbsent"
if ($hasPresent -and -not $hasAbsent) { exit 0 }
exit 1
