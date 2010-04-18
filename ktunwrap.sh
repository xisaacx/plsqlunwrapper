#!/bin/bash
##
# PL/SQL Unwrapper
# Usage: $0 inputfile outputfile
IF=${1:-"/dev/stdin"}
OF=${2:-"/dev/stdout"}
declare -r F8=$(for f in {0..255};do printf '\%03o' $f;done)
declare -r T8=$(echo "3D6585B318DBE287F152AB634BB5A05F7D687B9B24C228678ADEA4261E03EB17
6F343E7A3FD2A96A0FE935561FB14D1078D975F6BC4104816106F9ADD6D5297E
869E79E505BA84CC6E278EB05DA8F39FD0A271B858DD2C38994C480755E4538C
46B62DA5AF322240DC50C3A1258B9C16605CCFFD0C981CD4376D3C3A30E86C31
47F533DA43C8E35E1994ECE6A39514E09D64FA5915C52FCABB0BDFF297BF0A76
B449445A1DF0009621807F1A82394FC1A7D70DD1D8FF139370EE5BEFBE09B977
72E7B254B72AC7739066200E51EDF87C8F2EF412C62B83CDACCB3BC44EC06936
6202AE88FCAA4208A64557D39ABDE1238D924A1189746B91FBFEC901EA1BF7CE"| \
while read -n2 f;do [ -n "$f" ] && printf '\%03o' "0x$f";done)
exec 3<&0 4>&1 <$IF >$OF
sed -n -e '/ wrapped[ ]*$/,/^[[:blank:]]*$/p'| \
sed -n -e '21,$p'| \
base64 -d -i| \
dd bs=1 skip=20 status=noxfer 2>/dev/null| \
tr "$F8" "$T8"| \
perl -e '
use strict;
use warnings;
use Compress::Zlib;
my $x = inflateInit()
  or die "Cannot create a inflation stream\n";
my $input = "";
binmode STDIN;
binmode STDOUT;
my ($output, $status);
while (read(STDIN, $input, 4096))
{
  ($output, $status) = $x->inflate(\$input);
  print $output
    if $status == Z_OK or $status == Z_STREAM_END;
  last if $status != Z_OK;
}
die "inflation failed\n"
  unless $status == Z_STREAM_END;
'| \
sed '$s/\x0$//g'
echo
exec 0<&3 3<&- 1>&4 4>&-
