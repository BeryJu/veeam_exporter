Import-Module PrometheusExporter
Import-Module Veeam.Backup.PowerShell -DisableNameChecking

$VBRVersion = New-MetricDescriptor -Name "veeam_br_version" -Type counter -Help "Veeam VBR version" -Labels "version"
$VBRJob = New-MetricDescriptor -Name "veeam_br_jobs" -Type gauge -Help "Veeam VBR Jobs" -Labels @(
    "job_name",
    "state",
    "type",
    "vm_count"
)
$VBRVMs = New-MetricDescriptor -Name "veeam_br_vms" -Type gauge -Help "Veeam VBR VM metrics" -Labels @(
    "job_name",
    "vm_name",
    "type",
    "state"
)
$VBRJobThroughput = New-MetricDescriptor -Name "veeam_br_jobs_throughput" -Type histogram -Help "Veeam VBR Jobs Throughput" -Labels @(
    "job_name",
    "state",
    "type",
    "vm_count"
)


function Get-VBRVersion {
    $Path = "C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Core.dll"
    $Item = Get-Item -Path $Path
    New-Metric -MetricDesc $VBRVersion -Value 1 -Labels (
        $Item.VersionInfo.ProductVersion
    )
}

function Get-BackupJobs {
    $jobs = Get-VBRJob
    $metrics = @()
    foreach ($job in $jobs) {
        if ($job.IsBackupJob -eq $true) {
            $finish = $job.GetLastBackup().MetaUpdateTime | Get-Date -UFormat %s
        }
        $finish = $job.LatestRunLocal | Get-Date -UFormat %s
        $metrics += New-Metric -MetricDesc $VBRJob -Value $finish -Labels @(
            $job.Name,
            $job.GetLastResult().ToString().ToLower(),
            $job.Info.JobType.ToString().ToLower(),
            $job.GetLastBackup().VmCount
        )
        $speed = 0
        if ($job.GetLastState().ToString().ToLower() -eq "working") {
            Get-VBRSession -Job $job  | Get-VBRTaskSession
            $sess = $job.FindLastSession()
            $speed = $sess.Info.Progress.AvgSpeed
        }
        $metrics += New-Metric -MetricDesc $VBRJobThroughput -Value $speed -Labels @(
            $job.Name,
            $job.GetLastResult().ToString().ToLower(),
            $job.Info.JobType.ToString().ToLower(),
            $job.GetLastBackup().VmCount
        )
        foreach ($vm in $job | Get-VBRJobObject) {
            $metrics += New-Metric -MetricDesc $VBRVMs -Value 1 -Labels @(
                $job.Name,
                $vm.Name,
                $job.Info.JobType.ToString().ToLower(),
                $job.GetLastResult().ToString().ToLower()
            )
        }
    }
    $metrics
}

function collector () {
    @(
        Get-VBRVersion
        Get-BackupJobs
    )
}

$exp = New-PrometheusExporter -Port 9700
Register-Collector -Exporter $exp -Collector $Function:collector
$exp.Start()
