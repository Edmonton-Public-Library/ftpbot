Project Notes
-------------
Initialized: Wed Nov 18 09:55:09 MST 2015.

Instructions for Running:
```
ftpbot.pl -x
```

Product Description:
--------------------
Perl script written by Andrew Nisbet for Edmonton Public Library, distributable by the enclosed license.
Script handles FTP of files. It has some handy features like test mode to do everything but actually 'put'
the file. It has a debug mode to see what you are setting. The applicaiton does not remove the local files
on completion.

Configuration file composition
------------------------------
You can specify a configuration file with -c. The configuration file has name value pairs separated by ':'
White space is allowed between words and between the comma delimiter, but be careful not to have a password 
that starts or ends with a space.

All settings from the config file take precedence over those from the command line so if you want to over
ride settings on command line, comment that setting out from the config file. You may put any number of 
settings, including 0 in the config file, and specify any, upto all, on the command line. If the setting 
is made from the command line, and the config file, the setting in the config file wins.

The following is a well-formed configuration file. Trailing spaces on 'local dir' and 'remote dir' are optional.
```
# This line should be ignored.
     # so should this
  local dir: ./FTP_test
server: 198.161.203.76
user:ilsxml
# remote dir: DLA Export/Pull/


Flags
-----
```
 -c<file>:       Use the configuration file which can contain login id, password, and URL
                 in the following format:
                 # Comment
                 password: 123456
                 Valid values are 'local dir', 'user', 'remote dir', 'server', 'password'.
                 NOTE: config settngs take precedence over command line settings.
 -D:             Output debug information.
 -l<local_dir>:  FTP all the files in a given local directory directory.
 -p<password>:   Password for the remote server.
 -u<user>:       FTP user id at login.
 -r<remote_dir>: Target directory on the remote server.
 -s<server>:     Remote server name, like 'ftp.server.epl.ca'.
 -t:             Test mode, all functions performed except 'put' to the remote FTP site.
 -x:             This (help) message.
```


password:xxxxxxxxxx
```

Examples
--------
Read all the configuration requirements and FTP to the specified site.
```
ftpbot.pl -cconfig.file
```

Use configs in ftp.cfg, but the local directory is specified on command line. If the 'local dir'
```
  ftpbot.pl -cftp.cfg -l'/s/sirsi/Unicorn/ftp_stuff' is set in the config file it will override the command line option.
```


Repository Information:
-----------------------
This product is under version control using Git.
[Visit GitHub](https://github.com/Edmonton-Public-Library)

Dependencies:
-------------
None

Known Issues:
-------------
None
