# data-to-mysql-powershell


```
    ___      _          _____                     __    ____  __  
   /   \__ _| |_ __ _  /__   \___     /\/\  _   _/ _\  /___ \/ /  
  / /\ / _` | __/ _` |   / /\/ _ \   /    \| | | \ \  //  / / /   
 / /_// (_| | || (_| |  / / | (_) | / /\/\ \ |_| |\ \/ \_/ / /___ 
/___/  \__,_|\__\__,_|  \/   \___/  \/    \/\__, \__/\___,_\____/ 
                                            |___/                 
```

**PowerShell tools to get generic data into MySQL servers.**

The purpose of these tools is to assist in getting generic data into a format suitable to load into a MySQL server. 

As a data science student, I need to be able to download seemingly random datasets and analyse them. The column names are always a challenge, and it can be difficult to guestimate at the appropriate field lengths.

These tools allow me to do automate this process. If you find them useful, let me know! 

## Workflow

The fully automated workflow is as follows:

1) Import some data into PowerShell using Get-Content and ConvertFrom-[Format].

 ```PS> $RawData = Get-Content -Path some_data_file.csv | ConvertFrom-CSV```

2) Convert this to a MySQL friendly data array. Table and column names are made suitable for import.

```PS> $MySQLData = (ConvertTo-MySqlFormat -Data $RawData)```

3) Use the New-MySqlImportable to output a text string containing a Create Table and multiple Insert queries. Export this to a file for later import into MySQL.

```PS> New-MySqlImportable -TableName "My Data Table" -Data $MySqlData | Set-Content -Path ./my_table_import.sql```

4) I tend to use a local Docker container with MySQL, so this works to pour the data in to the server, assuming that I've already created the database 'my_database':

```docker exec -i mysql-container mysql -u root --password=PASSWORD my_database < ./my_table_import.sql```

(I am already writing code to directly upload the output into MySQL.)

## Functions

* ConvertTo-MySqlFormat - Convert to MySQL friendly data array
* Measure-ColumnMax - Find the longest line in each data file, reported per column
* New-QueryCreateTable - Generate a Create Table query from data.
* New-QueryInsert - Generate an Insert query from one line of data.
* New-MySqlImportable - Automated process to convert a data array into a file for import into a MySQL server.


