# Introduction to the Big Data Archive System Service - BDASS

In modern research, large data sets are the norm. Either original data or results created by extensive computational effort. Often this data is to be archived as the project winds down, to free resources for other projects.

The BDASS system is tailor made to work in heterogenous environments. Its plugin architecture allows BDASS to be adapted to different system architectures, providing a unified management interface. 

Users can select data to be archived, search for archived filenames and restore archived data if they have to access it again.

Administrators get 'approve' archive requests and thus get control over what gets into the archives. Allowing them to keep tabs on system resources.

## Architecture

BDASS is constructed to make minimal assumptions about the systems involved, delegating the actual system interfacing to plugins which can be easily adapted. The BDASS system consists of two parts:

A web interface for:

* creating archiving requests (users)
* approving archiving requests (admins)
* searching the archive index
* restoring archived data

A data-mover-daemon which is responsible for running the archival jobs. It uses plugins to:

* get a list of archivable folders from a remote system
* create an archive (zip/tar) of a remote folder
* transfer the archive to an archival system
* retrieve the archive
* unpack the archive to make it accessible again (restore function)

Both the web interface as well as the datamover are implemented asynchronously, so that they can perform multiple tasks in parallel without forking. This is especially important in a 'slow' scenario like this one where the central system will spend most of its time, waiting, since the heavy lifting with reading and writing to physical media is performed by attached servers where the data actually resides.

## Security and Authentication

Often not all systems involved with data live under a unified namespace as far as usernames are concerned. The system architecture assumes that BDASS itself is able to access all relevant data in connected systems, BUT that does not solve the problem if a particular user is entitled to request archiving of a particular folder or, even to see that the folder exists in the first place.

To solve this problem BDASS provides each users with a *token string* (for example `zut8aeleekungaeS`). The user now has to create a file called `BDASS.token` containing this string in the folder s*he wants to get archived. Being able to create this file is proof that the user has control over the project data directory.

When adding a system to BDASS, the sysadmin defines which folders could *potentially* be archived. When a user then looks at the system through the BDASS web interface, s\*he will only see the folders that contain a `BDASS.token` file with the appropriate *token string*.

The BDASS user database allows to assign users to groups. When a user creates an archiving request and the user is assigned to multiple groups, the user can chose which group the archive should be assigned to.

Tobias Oetiker  
2018-05-24

