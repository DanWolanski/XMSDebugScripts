#!/bin/sh
#
# Take a core dump and create a tarball of all of the binaries and libraries
# that are needed to debug it.
#
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
OFFSET='\033[60G'
echo_success(){
  echo -en \\033
  echo -en "${OFFSET}${GREEN}[OK]${NC}";
  echo "$STEP - OK" >> $LOG
}
echo_failure(){
echo -en "${OFFSET}${RED}[FAIL]${NC}";
  echo "$STEP - FAILED" >>$LOG
}
step() {
    echo -n -e "$@"
    echo "$@" >> $LOG
    STEP="$@"
    STEP_OK=0
}
next() {
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo
    echo "################################################################" >> $LOG
    return $STEP_OK
}
stepfail(){
  STEP_OK=1;
}
###########################################################################
#######                Start of script                             ########
###########################################################################
include_core=1
keep_workdir=0

WDPATH="/var/tmp/"
LOG="/dev/null"
usage()
{
        argv0="$1"
        retval="$2"
        errmsg="$3"
        if [ ! -z "$errmsg" ] ; then
                echo "ERROR: $errmsg" 1>&2
        fi
        cat <<EOF
Usage: $argv0 [-k] [-x] <corefile>
        Parse a core dump and create a tarball with all binaries and libraries
        needed to be able to debug the core dump.
        Creates <corefile>.tgz

        -k - Keep temporary working directory
        -x - Exclude the core dump from the generated tarball
EOF
        exit $retval
}

while [ $# -gt 0 ] ; do
        case "$1" in
        -k)
                keep_workdir=1
                ;;
        -x)
                include_core=0
                ;;
        -h|--help)
                usage "$0" 0
                ;;
        -*)
                usage "$0" 1 "Unknown command line arguments: $*"
                ;;
        *)
                break
                ;;
        esac
        shift
done

COREFILE="$1"
step "Stating core file"
if [ ! -e "$COREFILE" ] ; then
        usage "$0" 1 "core dump '$COREFILE' doesn't exist."
fi
case "$(file "$COREFILE")" in
        *"core file"*)
                break
                ;;
        *)
                usage "$0" 1 "per the 'file' command, core dump '$COREFILE' is not a core dump."
                ;;
esac
next

step "Gathering Command name from core"
cmdname=$(file "$COREFILE" | grep -oP "(?<=from ')(.*?)(?=',)")
next
echo "     $cmdname"
step "Converting command name to path"
fullpath=$(which "$cmdname")
if [ ! -x "$fullpath" ] ; then
        usage "$0" 1 "unable to find command '$cmdname'"
fi
next
echo "     $fullpath"

step "Creating tmp working wirectory"
mkdir "${WDPATH}${COREFILE}.pack" &>> $LOG
next

step "Gathering shared library dependency"
filelist=$(gdb -ex="info sharedlibrary" -ex="quit" "${fullpath}" ${COREFILE}  2>&1 | \
  grep -oP "((?<=Core was generated by .)\/.*?(?='\.))|(\/.*\.so($|\.[0-9]))")
next

echo "Coping dependencies to working directory:"
for file in $filelist ;
do
  step "   $file"
  cp -R "$file" "${WDPATH}${COREFILE}.pack" &>> $LOG
  next 
done

if [ $include_core -eq 1 ] ; then
        step "Copying core file"
        cp "${COREFILE}" "${WDPATH}${COREFILE}.pack" &>> $LOG
	next
fi
step "Copying Dialogic and system logs"
mkdir "${WDPATH}${COREFILE}.pack/logs" &>> $LOG
cp -r /var/log/xms "${WDPATH}${COREFILE}.pack/logs" &>> $LOG
cp -r /var/log/dialogic "${WDPATH}${COREFILE}.pack/logs" &>> $LOG
cp /var/log/messages* "${WDPATH}${COREFILE}.pack/logs" &>> $LOG
next

step "Saving other Dialogic/XMS binaries"
mkdir "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
cp /usr/dialogic/bin/ssp* "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
cp /usr/dialogic/data/ssp* "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
cp /usr/bin/xmserver "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
#cp /usr/bin/msmlserver "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
#cp /usr/bin/vxmlinterpreter "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
#cp /usr/bin/xmsrest "${WDPATH}${COREFILE}.pack/binaries" &>> $LOG
next
step "Saving OS release and RPM packagelist"
cat /etc/redhat-release >  "${WDPATH}${COREFILE}.pack/redhat-release"
rpm -qa 2>&1 >  "${WDPATH}${COREFILE}.pack/rpmlist" 
next

step "Gathering BT from core"
bt=$(gdb --batch --quiet -ex "bt " -ex "quit" -core ${COREFILE} ${fullpath} 2>&1)
echo ${bt} > "${WDPATH}${COREFILE}.pack/backtrace"
fullbt=$(gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" -core ${COREFILE} ${fullpath} 2>&1)
echo ${fullbt} >> "${WDPATH}${COREFILE}.pack/backtrace"
next

step "Compressing core package (may take a long time)"
tar czf "${WDPATH}${COREFILE}.pack.tgz" "${WDPATH}${COREFILE}.pack" &>> $LOG
next

if [ $keep_workdir -eq 0 ] ; then
        step "Removing pack working directory"
        rm -r "${WDPATH}${COREFILE}.pack"
	next
fi
echo
echo "Done, created ${WDPATH}${COREFILE}.path.tgz"
