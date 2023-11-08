# EtherDFS-3
Fork of EtherDFS - The Ethernet DOS File System v0.8.2 by Mateusz Viste (https://etherdfs.sourceforge.net/).


EtherDFS is an 'installable filesystem' TSR for DOS. It maps a drive from a remote computer (typically Linux-based) to a local drive letter, using raw ethernet frames to communicate.

EtherDFS-3 is a very special version of the DOS etherdfs client, for use with DOS 3.20 - 3.30 only.

The original version is for DOS 5+; however, I wanted a client for playing with older DOS versions.


Here you find the DOS client only; not the ethersrv (server) files.


INSTCHK.EXE is a simple EtherDFS install check.

I use this small tool in some batch files - it's not needed to run EtherDFS.
INSTCHK has just one (optional) argument: '-b' for batch mode (quiet mode), i.e. errorlevel only (no output to screen).
Errorlevel is 1, if the client is not loaded, 0 if loaded.

