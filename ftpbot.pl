#!/usr/bin/perl -w
############################################################################
#
# Perl source file for project deleteme 
# Purpose: Encapsulate FTP functionality into scripts in a standardized way.
# Method:  
#
# FTP file or files from one place to another using standardized methodology.
#    Copyright (C) 2016  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Created: Wed Jan 27 12:16:55 MST 2016
# Rev: 
#          0.1 - Production. 
#          0.0 - Dev. 
#
#############################################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;
use Net::FTP;

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'}  = qq{:/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/usr/bin:/usr/sbin};
$ENV{'UPATH'} = qq{/s/sirsi/Unicorn/Config/upath};
###############################################
my $VERSION            = qq{0.1};
my @FILE_LIST          = ();
my $USER               = '';
my $LOCAL_DIR          = '.'; # Default '.'
my $REMOTE_DIR         = '.';
my $SERVER             = '';
my $PASSWORD           = '';
my $PASSIVE            = 1;
my $TIMEOUT            = 100;

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-Dtx][-c<config>][-l<local_dir>][-r<remote_dir>][-s<server>]
	       [-u<user>][-p<password>]
Usage notes for ftpbot.pl.

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

example:
  ftpbot.pl -cconfig.file
 This will read all the configuration requirements and FTP to the specified site.
  ftpbot.pl -cftp.cfg -l'/s/sirsi/Unicorn/ftp_stuff'
 Use configs in ftp.cfg, but the local directory is specified on command line. If the 'local dir'
 is set in the config file it will override the command line option.
Version: $VERSION
EOF
    exit;
}

# Trim function to remove white space from the start and end of the string.
# This version also will normalize the string if '-n' flag is selected.
# param:  string to trim.
# return: string without leading or trailing spaces.
sub trim( $ )
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Reads the config file, sets the settings. Saves on hard-coding passwords and 
# looking up details every time. File can be named anything and have any extension you like.
# The file has the format '#' to add comment to file, 'config setting: setting_value\n'
# param:  name of the config file.
# return: count of settings successfully set.
sub read_config_file( $ )
{
	my $config_file           = shift;
	my $config_settings_count = 0;
	my $line_no               = 0;
	if ( not -s $config_file )
	{
		printf STDERR "** error reading configuration file '%s'. File not found, or file is empty.\n", $config_file;
		return $config_settings_count;
	}
	open CFH, "<$config_file" or die "** error while opening the configuration file '$!'\n";
	while ( <CFH> )
	{
		my $line = $_;
		$line_no++;
		next if ( $line =~ m/(\s+)?#/ );
		$line = trim( $line );
		# Break appart the name value pair.
		my ( $name, $value ) = split( ':', $line );
		$value = trim( $value );
		if ( not $name or not $value )
		{
			printf STDERR "** error invalid setting on line %d '%s', ignoring.\n", $line_no, $line;
			next;
		}
		if ( $name eq 'local dir' )
		{
			$LOCAL_DIR = $value;
		}
		elsif ( $name eq 'user' )
		{
			$USER = $value;
		}
		elsif ( $name eq 'remote dir' )
		{
			$REMOTE_DIR = $value;
		}
		elsif ( $name eq 'server' )
		{
			$SERVER = $value;
		}
		elsif ( $name eq 'password' )
		{
			$PASSWORD = $value;
		}
		else
		{
			printf STDERR "* warning invalid option on line %d '%s', ignoring.\n", $line_no, $name;
			next;
		}
		printf STDERR "CONFIG:> setting '%s' = '%s' on line %d.\n", $name, $value, $line_no if ( $opt{'D'} );
		$config_settings_count++;
	}
	close CFH;
	return $config_settings_count;
}

# FTPs files.
# pamam:  user login name.
# pamam:  Server name or IP.
# pamam:  Password.
# pamam:  Remote directory to send files.
# pamam:  Passive mode (1) by default for pasv=yes.
# pamam:  Timeout 100ms by default.
# pamam:  List reference of the file names to send.
# return: count of files, and files sent.
sub ftp_files( $$$$$$$ )
{
	my ( $user, $server, $password, $remote_dir, $passive, $timeout, $file_list ) = @_;
	printf STDERR "SETTING> user '%s'.\n", $user if ( $opt{'D'} );
	printf STDERR "SETTING> server '%s'.\n", $server if ( $opt{'D'} );
	printf STDERR "SETTING> password '%s'.\n", $password if ( $opt{'D'} );
	printf STDERR "SETTING> remote_dir '%s'.\n", $remote_dir if ( $opt{'D'} );
	printf STDERR "SETTING> passive '%s'.\n", $passive if ( $opt{'D'} );
	printf STDERR "SETTING> timeout '%s'.\n", $timeout if ( $opt{'D'} );
	printf STDERR "SETTING> file_list '%s'.\n", @{$file_list} if ( $opt{'D'} );
	my $count = 0;
	my $ftp = Net::FTP->new( $server, Passive => $passive, Timeout => $timeout );
	if ( ! $ftp )
	{
		printf STDERR "** error unable to connect to FTP server '%s'.\n", $server;
		exit( 0 );
	}
	# login to server.
	if ( ! $ftp->login( "$user","$password" ) ) 
	{
		printf STDERR "** error unable to login to FTP server '%s' as '%s'. Are the name and password correct?\n", $server, $user;
		exit( 1 );
	}
	$ftp->pasv();
	printf STDERR "setting pasv %d.\n", $passive if ( $opt{'D'} );
	$ftp->ascii();
	printf STDERR "setting ASCII.\n" if ( $opt{'D'} );
	$ftp->cwd( $remote_dir );
	printf STDERR "setting remote directory '%s'.\n", $remote_dir if ( $opt{'D'} );
	my $sent = 0;
	foreach my $file ( @{ $file_list } ) 
	{
		$count++;
		if ( $opt{'t'} )
		{
			printf STDERR "status=pretending to send '%s'.\n", $file;
			$sent++;
			next;
		}
		if ( $ftp->put( "$file" ) ) 
		{
			printf STDERR "status=DONE %s.\n", $file if ( $opt{'D'} );
			$sent++;
		}
		else 
		{
			printf STDERR "status=ERROR %s.\n", $file;
		}
	}
	$ftp->quit;
	return ( $count, $sent );
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'c:Dl:r:s:tu:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	$USER       = $opt{'u'} if ( $opt{'u'} );
	$REMOTE_DIR = $opt{'r'} if ( $opt{'r'} );
	$LOCAL_DIR  = $opt{'l'} if ( $opt{'l'} );
	$SERVER     = $opt{'s'} if ( $opt{'s'} );
}

init();
### code starts
# Config file settings take precedence over command line settings.
if ( $opt{'c'} )
{
	printf STDERR "reading configuration file '%s'\n", $opt{'c'} if ( $opt{'D'} );
	my $settings_set = read_config_file( $opt{'c'} );
	printf STDERR "read %d settings from file '%s'\n", $settings_set, $opt{'c'};
}
# Check if the local directory is a directory and get the files from it.
if ( $LOCAL_DIR ) 
{
	if ( -d $LOCAL_DIR )
	{
		@FILE_LIST = <$LOCAL_DIR/*>;
		printf STDERR " '%d' files selected.\n", scalar( @FILE_LIST ) if ( $opt{'D'} );
	}
	else
	{
		printf STDERR "** error, '-l' flag selected, but '%s' doesn't look like a directory.\n", $LOCAL_DIR;
		usage();
	}
}
else
{
	printf STDERR "** error, '-l', 'local dir' not set which could choose '/'!\n";
	usage();
}

my ( $count, $sent ) = ftp_files( $USER, $SERVER, $PASSWORD, $REMOTE_DIR, $PASSIVE, $TIMEOUT, \@FILE_LIST );

printf STDERR "status %d file(s) selected, %d file(s) FTP'ed.\n", $count, $sent if ( $opt{'D'} );
printf STDERR "*WARNING: only %d file(s) got FTP'ed.\n", $sent if ( $count != $sent );

### end FTP ends
# EOF
