Get-Module Tasks | Remove-Module -Force
Import-Module $PSScriptRoot\Tasks.psm1 -Force

InModuleScope Tasks {
    # Helper functions
    function maketasks {
        param(
            [int]$num,
            [validateset('open','closed','both')]
            [string]$type
        )
        $return = @()
        foreach($line in 1..$num){
            switch($type){
                'open'  {
                            $open = "($((65..90) | Get-Random | %{[char]$_})) 2017-01-01 Subject, ETR:1 Complete:1% Folder:`"C:\temp`" +Project @context"
                            $return += $open
                        }
                'closed'{
                            $close = "x pri:$((65..90) | Get-Random | %{[char]$_}) 2017-01-01 Subject, ETR:1 Complete:1% Folder:`"C:\temp`" +Project @context"
                            $return += $close
                        }
                default {
                            $open = "($((65..90) | Get-Random | %{[char]$_})) 2017-01-01 Subject, ETR:1 Complete:1% Folder:`"C:\temp`" +Project @context"
                            $return += $open
                            $close = "x pri:$((65..90) | Get-Random | %{[char]$_}) 2017-01-01 Subject, ETR:1 Complete:1% Folder:`"C:\temp`" +Project @context"
                            $return += $close
                        }
            }
        }
        $return
    }

    Describe 'Get-Task' {
        it 'knows if a task is complete' {
            mock Get-Content { maketasks -num 1 -type both }
            (get-task -all)[0].completed | should be $false
            (get-task -all)[1].completed | should be $true
        }
        it 'Parses open priorities correctly with one line' {
            mock Get-Content { maketasks -num 1 -type 'open' }
            (get-task).Priority | should matchexactly '[A-Z]'
        }
        it 'Parses closed priorities correctly with one line' {
            mock Get-Content { maketasks -num 1 -type 'closed' }
            (Get-Task -all).priority | Should matchexactly 'x\s[A-Z]'
        }
        it 'Parses open priorities correctly with multiple lines' {
            mock Get-Content { maketasks -num 5 -type 'open' }
            (Get-Task) -is [array] | should be $true
            (Get-Task).Priority | should matchexactly '\([A-Z]\)'
        }
        it 'Parses closed priorities correctly with multiple lines' {
            mock Get-Content { maketasks -num 5 -type 'closed' }
            (Get-Task -all) -is [array] | should be $true
            (Get-Task -all).Priority | should matchexactly 'x\s[A-Z]'
        }
        it 'Parses mixed priorities correctly' {
            mock Get-Content { maketasks -num 1 -type both }
            (get-Task -all)[0].Priority | should matchexactly '\([A-Z]\)'
            (Get-Task -all)[1].Priority | should matchexactly 'x\s[A-Z]'
        }
        it 'Parses created date correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all)[0].created | should matchexactly '\d{4}-\d{2}-\d{2}'
            (get-task -all)[1].created | should matchexactly '\d{4}-\d{2}-\d{2}'
        }
        it 'Parses subjects correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).Subject | should matchexactly 'Subject'
        }
        it 'Parses time remaining correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).EstTimeRemaining | should matchexactly '[0-9]'
        }
        it 'Parses complete % correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).CompletePercentage | should matchexactly '[0-9]%'
        }
        it 'Parses folder correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).Folder | should be $true
        }
        it 'Parses contexts correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).Context | should matchexactly 'context'
        }
        it 'Parses projects correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).Project | should matchexactly 'Project'
        }
        it 'Stores the task properly' {
            mock Get-Content { maketasks -num 5 -type both }
            (get-task -all).Task | should be $true
        }
        it 'Returns projects correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (Get-Task -all -Project 'Project').project | should be 'Project'
        }
        it 'Returns contexts correctly' {
            mock Get-Content { maketasks -num 5 -type both }
            (Get-Task -All -Context 'context').context | should be 'context'
        }
        it 'stores the TaskFile correctly' {
            (Get-Task -All).TaskFile -notlike $null | should be $true 
        }
    }

    Describe 'New-Task' {
        New-Task -TaskFile TestDrive:\tasks.txt -Priority A -Subject Test -EstTimeRemaining 1 -CompletePercentage 50 `
            -Folder C:\temp -Project Project -Context Context

        it 'Sets priority correctly' {
           (Get-Task -TaskFile TestDrive:\tasks.txt).priority | should be '(A)'
        }
        it 'Sets created date correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).Created | should be $(get-date -Format yyyy-MM-dd)
        }
        it 'Sets subject correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).subject | should be 'Test'
        }
        it 'Sets time remaining correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).EstTimeRemaining | should be '1'
        }
        it 'Sets complete % correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).CompletePercentage | should be '50%'
        }
        it 'Sets folder correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).Folder | should be 'C:\temp'
        }
        it 'Sets project correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).Project | should be 'Project'
        }
        it 'Sets context correctly' {
            (Get-Task -TaskFile TestDrive:\tasks.txt).Context | should be 'Context'
        }
    }

    Describe 'Set-Task' {
        New-Task -TaskFile 'TestDrive:\tasks.txt' -Priority A -Subject one -EstTimeRemaining 1 -CompletePercentage 50 `
            -Folder C:\temp

        New-Task -TaskFile 'TestDrive:\tasks.txt' -Priority A -Subject Two -EstTimeRemaining 1 -CompletePercentage 50 `
            -Folder C:\temp -Project Project -Context Context

        it 'Sets completed correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'Two' -Completed 
            (Get-Task -TaskFile TestDrive:\tasks.txt -All)[1].Completed | should be 'True'
        }
        it 'Sets created date correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Created '2017-01-01'
            (Get-Task -TaskFile TestDrive:\tasks.txt).Created | should be '2017-01-01'

        }
        it 'Sets open priority correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Priority 'C'
            (Get-Task -TaskFile TestDrive:\tasks.txt).Priority | should be '(C)'
           
        }
        it 'Sets closed priority correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'Two'  -Completed -Priority 'B'
           (Get-Task -TaskFile TestDrive:\tasks.txt -all)[1].Priority | should be 'x B'
        }
        it 'Sets subject correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Subject 'Done'
            (Get-Task -TaskFile TestDrive:\tasks.txt).Subject | should be 'Done'
        }
        it 'Sets time remaining correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -EstTimeRemaining '0'  
            (Get-Task -TaskFile TestDrive:\tasks.txt).EstTimeRemaining | should be '0'
        }
        it 'Sets complete % correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -CompletePercentage 100
            (Get-Task -TaskFile TestDrive:\tasks.txt).CompletePercentage | should be '100%'
        }
        it 'Sets folder correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Folder 'c:\temp\done'
            (Get-Task -TaskFile TestDrive:\tasks.txt).Folder | should be 'c:\temp\done'
        }
        it 'Sets project correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Project '+PDone'
            (Get-Task -TaskFile TestDrive:\tasks.txt).project | should be 'PDone'
        }
        it 'Removes a project correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Project '-PDone'
            (Get-Task -TaskFile TestDrive:\tasks.txt).Project | should not be 'PDone'
        }
        it 'Sets context correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Context '+CDone'
            (Get-Task -TaskFile TestDrive:\tasks.txt).context | should be 'CDone'
        }
        it 'Removes a context correctly' {
            Set-Task -TaskFile TestDrive:\tasks.txt -task 'one' -Context '-CDone'
            (Get-Task -TaskFile TestDrive:\tasks.txt).context | should not be 'CDone'
        }
    }
    describe 'New-TaskReport' {
        New-Task -TaskFile 'TestDrive:\tasks.txt' -Priority A -Subject 'Title' -EstTimeRemaining 1 -CompletePercentage 50 `
            -Folder C:\temp
        New-TaskReport -taskfile 'TestDrive:\tasks.txt' | Out-File 'TestDrive:\Report.txt'
        it 'Sets Project Title' {
            'TestDrive:\Report.txt' | should contain "Title"
        }
        it 'Sets the time remaining' {
            'TestDrive:\Report.txt' | should contain "time remaining: 1"
        }
        it 'Sets the percent complete' {
            'TestDrive:\Report.txt' | should contain "Percent Complete: 50%"
        }
        it 'includes notes' {
            'TestDrive:\Report.txt' | should contain "Notes:"
        }
    }
}