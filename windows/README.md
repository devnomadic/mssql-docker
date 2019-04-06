## Windows Containers
This includes samples for setting up mssql-server in Windows Containers. Currently it includes the following:
- __[mssql-server-windows-developer](mssql-server-windows-developer/)__
- __[mssql-server-windows-express](mssql-server-windows-express/)__
- __[mssql-server-windows](mssql-server-windows/)__

## Forked Updates:
[![Build status](https://ci.appveyor.com/api/projects/status/ty31wdostar0vok0?svg=true)](https://ci.appveyor.com/project/devnomadic/mssql-docker)  
  
Fixed for issue [Issue-#357 Cannot create database snapshots on microsoft/mssql-server-windows-developer](https://github.com/Microsoft/mssql-docker/issues/357)
- Updated Developer & Express docker builds to mount external volume & and move system databases to mount. This will make system DB snapshots & DBCC work successfully
- Updated appveyor.yaml image to 'Visual Studio 2017'
