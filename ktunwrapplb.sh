#!/bin/bash
IF=${1:-"/dev/stdin"}
OF=${2:-"/dev/stdout"}
exec 3<&0 4>&1 <$IF >$OF
awk '
BEGIN {
  A=0
  KTU="./ktunwrap.sh"
}
{
  if (/^[[:blank:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:blank:]]+(([Oo][Rr])*[[:blank:]]*[Rr][Ee][Pp][Ll][Aa][Cc][Ee][[:blank:]]*)*(FUNCTION|PROCEDURE|PACKAGE|PACKAGE BODY|TYPE|TYPE BODY|LIBRARY)[ ]+.*[ ]+wrapped[ ]*$/) {
    A=1
    match($0,/(^[[:blank:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:blank:]]+(([Oo][Rr])*[[:blank:]]*[Rr][Ee][Pp][Ll][Aa][Cc][Ee][[:blank:]]*)*)(FUNCTION|PROCEDURE|PACKAGE|PACKAGE BODY|TYPE|TYPE BODY|LIBRARY)/,arr)
    printf arr[1]
  }
  else if (A==1 && /^[[:blank:]]*$/)
    A=2
  if (A==1)
    print | KTU
  else if (A==2) {
    print | KTU
    close(KTU)
    A=0
  }
  else print
}
'|cat
exec 0<&3 3<&- 1>&4 4>&-
