#

$Logo = '
    ___      _          _____                     __    ____  __  
   /   \__ _| |_ __ _  /__   \___     /\/\  _   _/ _\  /___ \/ /  
  / /\ / _` | __/ _` |   / /\/ _ \   /    \| | | \ \  //  / / /   
 / /_// (_| | || (_| |  / / | (_) | / /\/\ \ |_| |\ \/ \_/ / /___ 
/___/  \__,_|\__\__,_|  \/   \___/  \/    \/\__, \__/\___,_\____/ 
                                            |___/                 
'
#   Convert-Data-Into-Mysql.ps1
#   - PowerShell Tools to Get Data into MySQL Servers
#
#   Author: Daemonchild / Tom Rowan
#

# Public Functions
Function ConvertTo-MySqlFormat () {
#
# Convert data array to MySQL Safe data array
#

    param (
        [Parameter(Mandatory=$True)]
        [System.Array] $Data
    )

    Write-BoxMessage -Title "Running" -Message ((Get-PSCallStack)[0].FunctionName | Out-String) -BoxColour DarkCyan -MsgColour Yellow

    If ($Data.Count -le 0) {
        # Empty dataset
        Write-ErrorMsg -Message "[ERROR] Please supply some data. :)"

    } Else {
        # Process the data
        $Keys = Get-Keys -Object $Data[0]

        Write-OKMsg -Message ("[OK] Working on "+($Data.Count)+" records, with "+($Keys.Count)+" columns.")

        # Create Empty Data Structure
        $NewData = @()
        $NewData = New-Object System.Collections.ArrayList($Data.Count)

        # Show Progress
        $ProgCounter = 1
        $ProgDivisor = [Math]::Round($Data.Count / 10)

        # Iterate through the data records
        $Timer = Measure-Command -Expression {

            Foreach ($Record in $Data) {

                If ($ProgCounter % $ProgDivisor -eq 0) {
                    $PercentageComplete = [Math]::Round(($ProgCounter / $Data.Count) * 100)
                    Write-Host $PercentageComplete"% " -NoNewline -ForegroundColor DarkCyan
                }

                # Dictionary
                $NewRecord = @{}

                Foreach ($KeyPair in $Keys) {
                    $NewRecord.($KeyPair.mysql) = $Record.($KeyPair.original)
                }

                $NewData.Add($NewRecord)

                $ProgCounter ++

            }
        } # End Timed Section

        $TimeTaken = [math]::Round($Timer.Seconds)

        Write-Host
        Write-OKMsg -Message ("Returning "+($NewData.Count)+" records in "+$TimeTaken+" seconds.")

        Write-Output -NoEnumerate $NewData

    }

}


Function Measure-ColumnMax () {
    #
    #
    # Returns: String
    param (
        [Parameter(Mandatory=$True)]
        [System.Array] $Data,
        [Parameter(Mandatory=$False)]
        [Int16] $Padding = 4
    )

    Write-BoxMessage -Title "Running" -Message ((Get-PSCallStack)[0].FunctionName | Out-String) -BoxColour DarkCyan -MsgColour Yellow

    If ($Data.Count -le 0) {
        # Empty dataset
        Write-ErrorMsg -Message "[ERROR] Please supply some data. :)"

    } Else {
        # Process the data
        $Keys = $Data[0].Keys

        Write-OKMsg -Message ("Working on "+($Data.Count)+" records, with "+($Keys.Count)+" columns.")
        Write-BoxMessage -Title "Note" -Message ("Adding "+$Padding+" to each value.") -BoxColour DarkCyan

        # Create Empty Data Structure
        $MaxCount = @{}
    
        # Setup Empty Records
        Foreach ($Key in $Keys) {        
            $MaxCount.$Key = 0
        }

        $Timer = Measure-Command -Expression {

            Foreach ($Record in $Data) {
        
                # Clone the data structure to allow editing
                $MaxCountEditable = $MaxCount.Clone()

                #Write-Host $Record -ForegroundColor DarkCyan

                Foreach ($Key in $MaxCount.Keys) {
                    If (($Record.$Key).Length -gt $MaxCount.$Key ){
                        $MaxCountEditable.$Key = ($Record.$Key).Length + $Padding

                        If ($MaxCountEditable.$Key -gt 255) {
                            $MMaxCountEditable.$Key = 255
                            Write-WarningMsg -Message ("Line length exceeds 255 characters")
                        }
                    }
                }

                # Clone the editied version back to the original
                $MaxCount = $MaxCountEditable.Clone()

            }

        } # End Timed Section

        $TimeTaken = [math]::Round($Timer.Seconds)

        Write-OKMsg -Message ("Processed "+($Data.Count)+" records in "+$TimeTaken+" seconds.")

        Return $MaxCount

    }
}


Function New-QueryCreateTable () {
    #
    #
    # Returns: String
        param (
            [Parameter(Mandatory=$True)]
            [String] $TableName,
            [Parameter(Mandatory=$True)]
            [Hashtable] $FieldsWithCount
        )

        #Write-BoxMessage -Title "Running" -Message ((Get-PSCallStack)[0].FunctionName | Out-String) -BoxColour DarkCyan -MsgColour Yellow
    
        $SQLTemplateHeader = "CREATE TABLE table_name ("
        $SQLTemplateLine   = "`tcolumn_name data_type"
        $SQLTemplateFooter = ");"
    
        $SQLText = ""
        $NL = "`r`n"
    
        $Counter = 1
    
        # Add Header
    
        $TableName = (ConvertTo-MySqlFriendly -Value $TableName)
    
        $SQLText = $SQLText + $SQLTemplateHeader.Replace('table_name',$TableName) + $NL
    
        # Process Fields List
        Foreach ($Field in $FieldsWithCount.Keys) {
    
            $MysqlFriendlyField = (ConvertTo-MySqlFriendly -Value $Field)
    
            $DataType = "varchar("+$FieldsWithCount.$Field+"),"
            $FieldDef = ($SQLTemplateLine.Replace('column_name',$MysqlFriendlyField).Replace('data_type', $DataType))
    
            # Remove Last Comma
            If ($Counter -eq $FieldsWithCount.Count) {
                $FieldDef = $FieldDef.Trim(",")
            }
    
            $SQLText = $SQLText+ $FieldDef + $NL
            $Counter ++
        }
    
        # Add Footer
        $SQLText = $SQLText + $SQLTemplateFooter + $NL
    
        Return $SQLText
    
    
} # End Function

Function New-QueryInsert () {

    param (
        [Parameter(Mandatory=$True)]
        [String] $TableName,
        [Parameter(Mandatory=$True)]
        [PSCustomObject] $Object
    )

    #Write-BoxMessage -Title "Running" -Message ((Get-PSCallStack)[0].FunctionName | Out-String) -BoxColour DarkCyan -MsgColour Yellow

    $QueryText = ""
    $SQLTemplateLine   = "INSERT INTO table_name (fields) VALUES (values);"

    $TableName = (ConvertTo-MySqlFriendly -Value $TableName)
    $QueryText = $SQLTemplateLine.Replace('table_name',$TableName)

    $Keys = $Object.Keys
    $InsertFields = ($Object.Keys) -Join ","

    $InsertValues = ""
    Foreach ($Key in $Object.Keys) {

        $Value = $Object.$Key.Replace("'", "``")
        $InsertValues += ("'"+$Value+"'" + ",")

    }

    $InsertValues = $InsertValues.Trim(",")

    $QueryText = ($QueryText.Replace('fields', $InsertFields)).Replace('values',$InsertValues)

    Return $QueryText

}

Function New-MySqlImportable () {

    #
    #
    # Returns: String
    param (
        [Parameter(Mandatory=$True)]
        [String] $TableName,
        [Parameter(Mandatory=$True)]
        [System.Array] $Data
    )

    Write-BoxMessage -Title "Running" -Message ((Get-PSCallStack)[0].FunctionName | Out-String) -BoxColour DarkCyan -MsgColour Yellow

    $NL = "`r`n"

    If ($Data.Count -le 0) {
        # Empty dataset
        Write-ErrorMsg -Message "[ERROR] Please supply some data. :)"

    } Else {
        # Process the data

        $TableName = (ConvertTo-MySqlFriendly -Value $TableName)

        # Create Table Query
        $FieldsWithCount = Measure-ColumnMax -Data $Data -Padding 2
        $QueryCreateTable = New-QueryCreateTable -Table $TableName -FieldsWithCount $FieldsWithCount

        # Show Progress
        $ProgCounter = 1
        $ProgDivisor = [Math]::Round($Data.Count / 10)

        $InsertQuiries = ""
        Foreach ($Record in $Data) {
            $InsertQuery = (New-QueryInsert -TableName $TableName -Object $Record) + $NL
            $InsertQuiries + $InsertQuery

            If ($ProgCounter % $ProgDivisor -eq 0) {
                $PercentageComplete = [Math]::Round(($ProgCounter / $Data.Count) * 100)
                Write-Host $PercentageComplete"% " -NoNewline -ForegroundColor DarkCyan
            }

            $ProgCounter ++
        }

    }

    Write-Host
    Write-OKMsg -Message "Finished"
    Write-Output ($QueryCreateTable + $NL + $InsertQuiries)

}

# Private Functions


Function Get-Keys () {

    param (
        [Parameter(Mandatory=$True)]
        [PSCustomObject] $Object
    )

    $Keys = @()
    Foreach ($Property in $Object.PSObject.Members | ?{ $_.MemberType -eq 'NoteProperty'}) {

        $Key = @{}

        $KeyOrgi = $Property.Name
        $KeyMysql = (ConvertTo-MySqlFriendly -Value $Property.Name)

        $Key.original = $KeyOrgi
        $Key.mysql = $KeyMysql 

        $Keys += $Key

    }

    Return $Keys

}

Function ConvertTo-MySqlFriendly () {
    #
    #
    # Returns: String
    
        param (
            [Parameter(Mandatory=$True)]
            [String] $Value
        )
    
        $NewValue = $Value.Replace(' ','_').ToLower()
        $NewValue  = $NewValue  -Replace "[^a-zA-Z0-9_]"
    
        # What is the max length for a column or table name?
    
        Return $NewValue
    
    }


    Function Write-BoxMessage () {

        param (
            [Parameter(Mandatory=$True)]
            [String] $Title,
            [Parameter(Mandatory=$True)]
            [String] $Message,
            [Parameter(Mandatory=$False)]
            [String] $BoxColour = "White",
            [Parameter(Mandatory=$False)]
            [String] $MsgColour = "Gray"
        )

        $BoxString = "[" + $Title + "]"
        Write-Host $BoxString" " -ForegroundColor $BoxColour -NoNewline
        Write-Host $Message" " -ForegroundColor $MsgColour

    }

    Function Write-OKMsg () {

        param (
            [Parameter(Mandatory=$True)]
            [String] $Message
        )
        Write-BoxMessage -Title "OK" -Message $Message -BoxColour Green
    }

    Function Write-ErrorMsg () {

        param (
            [Parameter(Mandatory=$True)]
            [String] $Message
        )
        Write-BoxMessage -Title "Error" -Message $Message -BoxColour DarkRed
    }

    Function Write-ErrorMsg () {

        param (
            [Parameter(Mandatory=$True)]
            [String] $Message
        )
        Write-BoxMessage -Title "Warning" -Message $Message -BoxColour Yellow
    }

Write-Host "Importing:"
Write-Host $Logo -ForegroundColor DarkCyan
Write-Host "Functions:" -ForegroundColor DarkYellow
Write-Host "`tConvertTo-MySqlFormat"
Write-Host "`tMeasure-ColumnMax"
Write-Host "`tNew-QueryCreateTable"
Write-Host "`tNew-QueryInsert"
Write-Host "`tNew-MySqlImportable"
Write-Host
