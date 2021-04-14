# gem-ws2-floppy-to-midi-dump
This repository contains tools to convert GEM WS2 or WS400 keyboard memory dumps from floppy format (.ALL) to MIDI System Exclusive format.

This convertor can be used for using collections of WS2 floppies on WS2 devices with broken floppy drives.

Usage: 

./ws2-transform.pl floppyfile.ALL

ls -l floppyfile.syx


Finally, put your WS1/WS2/WS3/WS400 in MIDI dump receive mode, then use your favorite SysEx librarian program to send the .syx file via MIDI to your WS1/WS2/WS3/WS400.

