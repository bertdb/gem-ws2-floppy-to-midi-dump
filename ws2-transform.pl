#!/usr/bin/perl
#
# This script transforms a GEM WS1/WS2/WS400 floppy memory dump (.ALL file) into a MIDI SysEx memory dump. 
# Usage:   ./sysextransform.pl INPUTFILE [OUTPUTFILE]
# If no outputfile is given, the inputfilename is used with the .syx extension
# 
# known sysex header:
#  240: SysEx start
#  47: GeneralMusic ID
#  0
#  p packet type: 1= start packet, name of filename follows aaaaaaa(32)ALL, then 19 more bytes | 2=: data packet, length max 128 bytes including begin/end
#  x packet counter. starts from 0
#  15
#
# The memory bytes from the .ALL file are stored in the SysEx dump packets in groups of 7, each byte with the LSB chopped. 
#  Byte number eight contains the 7 chopped LSB of the previous bytes.
# Every data packet has one last extra byte before 247: total data packet checksum
# Last data packet adds 2 trailing 255 bytes as padding because there are only 5 bytes left in the memory dump, and the conversion requires a group of 7 bytes.

# A memory dump contains Voices, Globals, and Sequencer data (Styles and Songs). Also some system settings are stored (e.g. main volume, the current voice selected by the "alpha dial" button. )
# VOICES:
# one voice takes up 30 8bit bytes. First 7 bytes: name. byte nr 8: 32/space. 
# first voice starts at byte 13
# GLOBALS:
# one global takes 95 8bit bytes.
# first global starts at byte 5068

use warnings;

my $allfilename = $ARGV[0];
my $syxfilename = $allfilename; 
$syxfilename =~ s/ALL$/syx/i;
if (defined($ARGV[1])) { $syxfilename = $ARGV[1] }; #override default output filename with second argument
if ($allfilename eq $syxfilename) { $syxfilename = $allfilename . ".syx" }; #if input filename didn't end in ALL, output filename may be identical to input. Add .syx 
my $byte;
my $counter=0;
my @sevenbytes;

open(ALL,"<$allfilename") or die "Couldn't open $allfilename for reading";
binmode(ALL);
open(SYX,">$syxfilename") or die "Couldn't open $syxfilename for writing";
binmode(SYX);

# generate/write header packet to SYX
#  we use aaaaaaa.ALL as the indicated filename. It would be possible to take the first seven characters of the actual filename and encode it, but that is not implemented here.

@packetdata=(240,47,0,1,97,97,97,97,97,97,97,32,65,76,76,0,1,8,11,23,0,0,117,79,127,1,0,0,2,0,0,111,0,18,247);
syswrite(SYX,pack("C"x@packetdata,@packetdata));

$packetcounter=0; #will count packets modulo 64
# until EOF
until(eof(ALL)){
        #  write header for data packet to prep array @packetdata
        $packetcounter %= 64;
        $checksum=0;
        @packetdata=("240","47","0","2",$packetcounter,"length"); #value 5 needs to be replaced at the end
        # construct data packet contents
        $length=0;
        until(($length==15) or eof(ALL)) {#  until 15 data blocks or EOF
                @bytelist=(0,0,0,0,0,0,0,0);
                for $nr (0,1,2,3,4,5,6) {
                        #   read 7 bytes from ALL
                        #   if EOF: pad with two 255 bytes
                        read(ALL,$byte,1) or do { $byte=pack("C","255"); }; # at EOF, read fails
                        @number=unpack("C",$byte);
                        $n=$number[0];
                        #   convert into 8x7bit
                        $bytelist[$nr]=$n >> 1;
                        $lsb=$n%2;
                        if ($lsb == 1) { $bytelist[7]+=2**($nr); };
                };
                # write 8 7bitdata bytes to prep array
                push(@packetdata,@bytelist);
                for $nr (0,1,2,3,4,5,6,7) {
                        #   and keep sum for checksum
                        $checksum^=$bytelist[$nr];
#debug#                 print "CHECKSUM: $checksum BYTE:$bytelist[$nr]   LENGTH: $length  PACKETCOUNTER: $packetcounter\n";
                };
                $length++; #increment current packet length counter
        }; # until $length==15 or eof(ALL);
        # insert actual length into sixth field
        $packetdata[5]=$length;
        # calculate checksum
        $checksum ^= 47; # first 5 data bytes were not yet added to checksum value
        $checksum ^= 2; # first 5 data bytes were not yet added to checksum value
        $checksum ^= $packetcounter; # first 5 data bytes were not yet added to checksum value
        $checksum ^= $length; # first 5 data bytes were not yet added to checksum value
        $checksum %= 128;
#debug# print "FINAL CHECKSUM: $checksum  LENGTH: $length  PACKETCOUNTER: $packetcounter\n";
        # push checksum and SysEx end onto @packetdata
        push(@packetdata,$checksum,"247");
        # write 
        syswrite(SYX,pack("C"x@packetdata,@packetdata));
        # increment packet counter
        $packetcounter++;
#  end packet
};
