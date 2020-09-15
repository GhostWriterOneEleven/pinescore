#!/bin/sh

#remember you're working in SHELL SCRIPTING HERE, not BASH ++_+_+_+__+_+_+++_+__+

if [ -z "$1" ] #parameter not passed after interface
then
        echo
        echo
        echo "Please pass the interface, i.e. ./ns_speedtest_v3.sh eth1"
        echo "script exiting..."
        echo
        exit 1
fi

touch speedtest.log
tail speedtest.log -f -n0 &

i="1"
sleepseconds="1"
if [ -z "$2" ] #parameter not passed after interface
then
	echo "+++++++++++++++++   To run every hour, for 24 hours, pass 'cron' after interface. i.e. ./ns_speedtest_v3.sh eth1 cron"
else
	i="24"
	sleepseconds="3600"
fi
while [ $i -gt 0 ]
do

	touch /tmp/111.tmp
	temp_file=/tmp/111.tmp

	#CTRL-C protection, still make sure background task killed
	trap trapint 2
	trapint() {
	    killall -q -s 9 wget
	    killall -q -s 9 curl
	    killall -q -s 9 tail
	    rm ${temp_file}
	}



	#when running on XG, it was getting bytes correct. but then when running on debian, the return from ifconfig was different, and so
	#the byytes field was in a different place, hence the if check below
	get_ispeed() {
	    if [ "$1" = "upload" ]
	    then
		field=f3
		direction=TX
	    else
		field=f2
		direction=RX
	    fi

	    bytes=$(/sbin/ifconfig $external_interface | grep bytes | grep $direction | cut -d ':' -$field | cut -d ' ' -f1);
	    if [ -z "$bytes" ]
	    then
		bytes=$(/sbin/ifconfig $external_interface | grep bytes | grep $direction | cut -d ':' -$field | cut -d ' ' -f14);
	    fi
	    echo $bytes;
	}

	write_output() {
		#don't lower this below 16, as it takes 15 seconds for curl to fail on a upload test and output error message
		secs=8
		endTime=$(( $(date +%s) + secs )) # Calculate end time.

		if [ "$1" = "upload" ]
		then
			interface="get_ispeed upload"
			killprocess=curl
			wgetrunning="yes"
		else
			interface=get_ispeed
			killprocess=wget
			wgetrunning="yes"
		fi
			sleep 1

			while [ $(date +%s) -lt $endTime ] && [ -f ${temp_file} ] && [ ! -z "$wgetrunning" ]
			do :
			    s1=`$interface`;
			    sleep 1s;
			    s2=`$interface`;
			    d=$(($s2-$s1));
			    d2=$(($d*8));
			    echo "        " $(($d / 1048576))" MB/s ("$(($d2 / 1048576))"Mb/s)   | " $(date);
			    wgetrunning="$(pgrep $killprocess)"
			#echo "${wgetrunning}"
			done
			sleep 1
			killall -q -s 9 $killprocess
	}

	testserver=$2
	external_interface=$1
	###########################################################################
	echo
	echo
	echo 3x simultaneous downloads from thinkbroadband, pinescore and apple cdn, measuring the total aggregated throuput of the external interface
        write_output download >> speedtest.log &
	wget http://updates-http.cdn-apple.com/2018FallFCS/fullrestores/091-62921/11701D1E-AC8E-11E8-A4EB-C9640A3A3D87/iPad_Pro_HFR_12.0_16A366_Restore.ipsw -o /dev/null &
	wget https://pinescore.com/111/ns_1GB.zip -o /dev/null &
        wget http://ipv4.download.thinkbroadband.com/1GB.zip -o /dev/null

	sleep 2
#	echo
#	echo
#	echo Aggregated download test from pinescore.com
#	write_output download >> speedtest.log &
#	wget https://pinescore.com/111/ns_1GB.zip -o /dev/null
#
#	sleep 2
#	echo
#	echo
#	echo Aggregated download test from apple cdn
#	write_output download >> speedtest.log &
#	wget http://updates-http.cdn-apple.com/2018FallFCS/fullrestores/091-62921/11701D1E-AC8E-11E8-A4EB-C9640A3A3D87/iPad_Pro_HFR_12.0_16A366_Restore.ipsw -o /dev/null
#
#	sleep 2
#	echo
#	echo
#	echo Aggregated download test from speedtest.virtuetechnologies.co.uk
#        write_output download >> speedtest.log &
#        wget http://speedtest.virtuetechnologies.co.uk/ns_1GB.zip -o /dev/null
#
#	sleep 2
#	echo
#	echo
#	echo Aggregated download test from thinkbroadband
#        write_output download >> speedtest.log &
#        wget http://ipv4.download.thinkbroadband.com/1GB.zip -o /dev/null
#	sleep 2

	echo
	echo

	echo Aggregated upload test to pinescore.com
	write_output upload >> speedtest.log &
	sleep 1
	curl -T ns_1GB.zip ftp://pinescore.com --user ftp_speedtest.pinescore:ftp_speedtest.pinescore 2>/dev/null

	rm ns_1GB.zi*
	#dev/null output because if we CTL-C, it removes the file once as part of the trap, then tries again here and throws error
	rm ${temp_file} 2> /dev/null

	#sleep solves a race condition on debian causing scipt to hang a third of the time otherwise. think it's because
	#the commands finish the background tasks have yet not complete
	sleep 2
	i=$((i-1))
#	echo
#	echo
#	echo
#	echo "+++++++++++++++++   none aggreagated pinescore:"
#	wget -q --show-progress -O /dev/null https://pinescore.com/111/ns_1GB.zip &
#	sleep 10
#	killall -q -s 9 wget
#	echo
#	echo
#	echo
#	echo "+++++++++++++++++   none aggregated apple cdn:"
#	wget -q --show-progress -O /dev/null http://updates-http.cdn-apple.com/2018FallFCS/fullrestores/091-62921/11701D1E-AC8E-11E8-A4EB-C9640A3A3D87/iPad_Pro_HFR_12.0_16A366_Restore.ipsw &
#	sleep 10
#	killall -q -s 9 wget
#	echo
#	echo "sleeping for $sleepseconds second(s), $((i-1)) iterations left"
#	sleep $sleepseconds
done
killall -q -s 9 tail
echo
echo " +++++++++++++++++   deleting script, if you'd like to run again, please pull the latest version from https://pinescore.com/111/ns_speedtest_v3.sh"
echo " +++++++++++++++++   example one liner: wget https://pinescore.com/111/ns_speedtest_v3.sh --no-check-certificate && chmod +x ns_speedtest_v3.sh && ./ns_speedtest_v3.sh eth1"
rm ns_speedtest_v3.s*
rm iPad_Pro_HFR* > /dev/null 2>&1
rm ns_1GB.zip* > /dev/null 2>&1
rm 1GB.zip* > /dev/null 2>&l