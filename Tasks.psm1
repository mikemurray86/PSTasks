<# This module contains functions that implement a powershell version of the todo.txt task management
#  model to help keep track of projects. It imposes additional structure above the standards expected
#  by todo.txt and therefore is not a true implementation. 
#>

$TaskFile = $Env:HOMEDRIVE+'\Projects\Current Projects.txt'

function Get-Task{
<# 
.SYNOPSIS
	Displays pending tasks
.DESCRIPTION
	This reads from a text file and displays all current tasks in the file. 
.PARAMETER TaskFile
    The fully qualified path to the file that contains your tasks. this must be a text file.
.PARAMETER All
    Return all tasks. if this switch is not specified completed tasks are not shown
.PARAMETER Project
    Accepts a comma seperated list of project names and returns only tasks in those projects
.PARAMETER Context
    Accepts a comma seperated list of context names and returns only tasks in those contexts
.EXAMPLE
    get-task -all

    Returns all projects
.EXAMPLE
    get-task -project 'test','info'

    Returns all projects that have +test or +info specified.
.Notes 
    Script: Tasks.psm1  
    Author: Mike Murray 
    Comments: 

.Link 
     
#Requires -Version 3.0 
#> 

[CmdletBinding()]

param(
    [string]$TaskFile = $TaskFile,
    [switch]$All,
    [string[]]$Project,
    [string[]]$Context
)

    if(Test-Path $TaskFile){
        $File = Get-Content -Path $TaskFile
        Write-Verbose "Verified that $TaskFile exists."
    }
    else{
        Write-Error 'Error opening the specified file.'
    }

    $TaskCol = @()
    Remove-TypeData -TypeName 'PSCustomTask' -ErrorAction SilentlyContinue
    Update-TypeData -TypeName 'PSCustomTask' -DefaultDisplayPropertySet 'Priority','Subject','CompletePercentage','Folder'
    Write-Verbose 'Reloaded Type data for PSCustomTask'

    foreach($Line in $File){
        Write-Verbose 'Parsing task'
        # Open Ticket parsing rules
        $Priority = (Select-String -Pattern '^\([A-Z]\)' -InputObject $Line).Matches.Value
        $Created = (Select-String -Pattern "(^\d{4}-\d{2}-\d{2}|(?<=$([regex]::Escape($Priority))\s)\d{4}-\d{2}-\d{2})" `
            -InputObject $Line).Matches.Value
        if($Created){
            $Subject = (Select-String -Pattern "(?<=$([regex]::Escape($Priority))\s\d{4}-\d{2}-\d{2}\s)[^,]+" `
            -InputObject $Line).Matches.Value
        }
        else{
            $Subject = (Select-String -Pattern "(?<=$([regex]::Escape($Priority))\s)[^,]+" `
            -InputObject $Line).Matches.Value
        }
        $ETR = (Select-String -Pattern '(?<=(ETR|etr):)\d+' -InputObject $Line).Matches.Value
        $PercentComplete = (Select-String -Pattern '(?<=(c|C)omplete:)\d{1,3}%' -InputObject $Line).Matches.Value
        $folder = (Select-String -Pattern '(?<=(f|F)older:")([^"'']+)' -InputObject $Line).Matches.Value
        $TProject = (Select-String -Pattern '(?<=\s\+)[^\s]+' -InputObject $Line -AllMatches).Matches.Value
        $TContext = (Select-String -Pattern '(?<=\s@)[^\s]+' -InputObject $Line -AllMatches).Matches.Value
        
        # Closed ticket parsing rules
        # These also inherit all the open rules plus a few special ones. 
        if((Select-String -Pattern '^x' -InputObject $Line).Matches.Value){
            $Complete = $True
            $Priority = "x " + (Select-String -Pattern '(?<=pri:)[A-Z]' -InputObject $Line).Matches.Value
            $created = (Select-String -Pattern `
                "(?<=pri:[A-Z]\s)\d{4}-\d{2}-\d{2}" -InputObject $Line).Matches.Value
            $Subject = (Select-String -Pattern '(?<=pri:[A-Z]\s)[^,]+' -InputObject $Line).Matches.Value
        }
        else{
            $Complete = $False
        }


        Write-Verbose 'Creating task object'
        $Task = [PSCustomObject]@{
                                  PSTypeName='PSCustomTask'
                                  Completed = $Complete
                                  Priority = $Priority
                                  Created = $Created
                                  Subject = $subject
                                  EstTimeRemaining = $ETR
                                  CompletePercentage = $PercentComplete
                                  Folder = $folder
                                  Project = $TProject
                                  Context = $TContext
                                  Task = $Line
                                  TaskFile = $TaskFile
                                 }

        if($Project){
            Write-Verbose 'Checking for projects in task'
            foreach($proj in $Project){
                if( $Task.Project -eq $proj){
                    if($All){
                        Write-Verbose "Found $proj in task"
                        $TaskCol += $Task
                    }
                    else{
                        if( -Not $Task.Completed){
                            Write-Verbose "Found $proj in task"
                            $TaskCol += $Task
                        }
                    }
                }
            }
        }
        if($Context){
            Write-Verbose 'Checking for Contexts in task'
            foreach($cont in $Context){
                if( $Task.Context -eq $cont){
                    if($All){
                        Write-Verbose "Found $cont in task"
                        $TaskCol += $Task
                    }
                    else{
                        if( -Not $Task.Completed){
                            Write-Verbose "Found $cont in task"
                            $TaskCol += $Task
                        }
                    }
                }
            }
        }
        if( (-Not $Context) -and (-Not $Project) ){
            if($All){
                Write-Verbose 'Storing task'
                $TaskCol += $Task
            }
            else{
                if( -Not $Task.Completed){
                    Write-Verbose 'Storing task'
                    $TaskCol += $Task
                }
            }
        }
        $Completed = $null #This is done so that the value is not carried to later tasks
    }

    $TaskCol | Sort-Object -Property Priority, Subject
}

function New-Task {
<# 
.SYNOPSIS
	This creates a new task and adds it to a task file
.DESCRIPTION
	This creates a task based on the format todo.txt uses and saves it into a task file.
.PARAMETER TaskFile
    This is the file that will have the new task appended to it. 
.PARAMETER Priority
    Sets the priority of the new task using single uppercase letter value ex- A
.PARAMETER Subject
    Sets what the task is about.
.PARAMETER ETR
    Sets the Estimate Time Remaining for this task in hours
.PARAMETER CompletePercentage
    Sets the percent a task is complete using a 1-3 digit number. ex-15
.PARAMETER Folder
    Sets where additional information about the task is stored.
.PARAMETER Project
    Sets what project this task is associated with.
.PARAMETER Context
    Sets the context that this task can be completed in.
.EXAMPLE
	New-Task -Priority A -Subject 'Go Home' -ETR 1 -CompletePercentage 95 -Folder C:\temp -Project Home -Context Walk

    this sets a high priority to go home with an hour to go that is 95% complete. Additional information is in the C:\temp folder
    The project for this task is 'Home' and it can be completed in the context of a walk.
.Notes 
    Script: New-Task  
    Author: Mike Murray 
    Last Edit: 02/06/2017 15:54:01 
    Comments: 

.Link 
     
#Requires -Version 3.0 
#>
 
[CmdletBinding()]

param(
    [string]$TaskFile = $TaskFile,
    [string]$Priority,
    [string]$Subject,
    [string]$EstTimeRemaining,
    [string]$CompletePercentage,
    [string]$Folder,
    [string[]]$Project,
    [string[]]$Context
)

$tasks = @()
if(Test-Path $TaskFile){
    $tasks += (Get-Task -TaskFile $TaskFile -All).Task
}

Write-Verbose 'creating new task'
$task = "($Priority) $(get-date -Format yyyy-MM-dd) $Subject, ETR:$EstTimeRemaining Complete:$CompletePercentage% Folder:`"$Folder`" "

if($PSBoundParameters.ContainsKey('Project')){
    foreach($proj in $Project){ $task += "+$proj "}
}
if($PSBoundParameters.ContainsKey('Context')){
    foreach($con in $Context){ $task += "@$Con "}
}

Write-Verbose 'exporting new task'
$tasks += $task
Out-File -FilePath $TaskFile -InputObject $tasks
}

function Set-Task{
<#
.Synopsis
   This modifies an existing task
.DESCRIPTION
   Takes an existing task from the specified taskfile and updates the information.
.PARAMETER Taskfile
    The file to read tasks from.
.PARAMETER Completed
    Set if this task is complete or not.
.PARAMETER Created
    Sets the date this task was created.
.PARAMETER Priority
    Sets the priority of this task.
.PARAMETER Subject
    sets what the subject is.
.PARAMETER ETR
    Sets the estimated time remaining.
.PARAMETER CompletePercentage
    Sets how complete this task is.
.PARAMETER Folder
    Sets the the path to the folder with additional details.
.PARAMETER Project
    Sets what project this is for.
.PARAMETER Context
    Sets what context this is about.
.EXAMPLE
   Set-Task -taskfile C:\temp\tasks.txt -task "Check Stuff" -Subject "Send Stuff"

   This loads a task from the C:\temp\tasks.txt file with a subject of "Check Stuff" and changes the subject to "Send Stuff"
#>

    [CmdletBinding()]
    [Alias()]
    Param(   
        [string]$TaskFile = $TaskFile,
        [string]$task,
        [switch]$Completed,
        [string]$Created,
        [string]$Priority,
        [string]$Subject,
        [string]$EstTimeRemaining,
        [string]$CompletePercentage,
        [string]$Folder,
        [string]$Project,
        [string]$Context
    )

    Process{
        $File = Get-Task -TaskFile $TaskFile -All

        foreach($Line in $File){
            if($Line.Subject -match $task){
                switch($PSBoundParameters.Keys){
                    'Completed'          { $Line.Completed = $Completed
                                           $Line.Priority = $Line.priority.trim("()")
                                           $Line.Priority = "x pri:$($Line.Priority.ToUpper())"
                                         }
                    'Created'            { $Line.Created = $Created }
                    'Priority'           { if($Line.Completed){
                                                $Line.Priority = $Line.priority.trim("()")
                                                $Line.Priority = "x pri:$($Priority.ToUpper())"
                                           }
                                           else{
                                                $Line.Priority = "($($Priority.ToUpper()))"
                                           }
                                         }
                    'Subject'            { $Line.Subject = $Subject }
                    'EstTimeRemaining'   { $Line.EstTimeRemaining = $EstTimeRemaining }
                    'CompletePercentage' { $Line.CompletePercentage = "$CompletePercentage%" }
                    'Folder'             { $Line.Folder = $Folder }
                    'Project'            { if($Project -match '^\+'){ 
                                                $Line.Project += " $Project"
                                            }
                                            if($Project -match '^-'){
                                                $Line.Project = $Line.Project | Where-Object { $_ -ne $Project.TrimStart('-') }
                                            }
                                         }
                    'Context'            { if($Context -match '^\+'){
                                                $Line.Context += " @$($Context.TrimStart('+'))"
                                           }
                                           if($Context -match '^-'){
                                                $Line.Context = $Line.Context | Where-Object { $_ -ne $Context.TrimStart('-') }
                                           }
                                         }
                }
                
                $Line.task = "$($Line.priority) $($Line.created) $($Line.Subject), ETR:$($Line.EstTimeRemaining) Complete:$($Line.CompletePercentage) Folder:`"$($Line.Folder)`" "
                
                foreach($Proj in $Line.Project){
                    $Line.Task += "+$Proj "
                }
                foreach($Con in $Line.Context){
                    $Line.Task += "@$Con "
                }
            }
        }

        Out-File -FilePath $TaskFile -InputObject $File.task 

    }
}

function New-TaskReport {
    param (
        [string]$taskfile = $taskfile
    )
    $report = ""

    $tasks = Get-Task -TaskFile $taskfile

    foreach ($task in $tasks){
        $report += $task.Subject + "`r`n"
        $report += "Time Remaining: " + $task.EstTimeRemaining + "`r`n"
        $report += "Percent Complete: " + $task.CompletePercentage + "`r`n`r`n"
        $report += "Notes:`r`n" + (Get-Content -Path ($task.folder.TrimEnd('\') + '/notes.txt') -Raw -ErrorAction SilentlyContinue) + "`r`n`r`n"
    }

    return $report
}
Export-ModuleMember -Function Get-Task, New-Task, Set-Task, New-TaskReport -Variable TaskFile
