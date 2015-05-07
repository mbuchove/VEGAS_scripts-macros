#!/bin/bash

runMode=print

mode=dt
DistanceUpper=1.38

array=ua
atm=22
simulation=CORSIKA

azimuths="0,45,90,135,180,225,270,315"
noiseLevels="100,150,200,250,300,350,400,490,605,730,870"
zeniths="50,55,60,65"
offset=all

spectrum=medium

workDir=$GC
scratchDir=/scratch/mbuchove

#offset=0.75
#fileList=$HOME/work/SgrA_dt_simlist.txt

#add environment option
args=`getopt -o qr -l offsets:,atm:,fileList:,array:,mode:,distance:,testname:,zeniths:,spectrum: -- $*`
eval set -- $args
for i; do 
    case "$i" in 
	-r) 
	    runMode=run ; shift ;;
	-q) 
	    runMode=qsub ; shift ;;
	--mode) # lt, dt, ea
	    mode="$2" ; shift 2 ;;
	--offsets) 
	    offset="$2" ; shift 2 ;;
	--atm) 
	    atm="$2" ; shift 2 ;;
	--fileList) 
	    fileList="$2" ; shift 2 ;;
	--array) 
	    array="$2" ; shift 2 ;;
	--distance)
	    DistanceUpper="$2" ; shift 2 ;;
	--zeniths)
	    zeniths="$2" ; shift 2 ;; 
	--spectrum)
	    spectrum="$2" ; shift 2 ;; 
	--testname) 
	    testnameflag="_${2}" ; shift 2 ;; 
	--) 
	    shift ; break ;;
#	*)
#	    echo "argument $1 is not valid!"
#	    exit 1
    esac # argument cases
done # loop over i in args
if [ $1 ]; then
    mode="$1"
fi

if [ ! -d $workDir/log/tables ]; then
    echo "Must create table $workDir/log/tables !!!"
    #mkdir $workDir/log/tables
    exit 1
fi

tableList=$workDir/config/tableList_${mode}_${array}_ATM${atm}.txt
test $runMode != print && test -f $tableList && mv $tableList ${tableList}.backup
cuts="-SizeLower=0/0 -DistanceUpper=0/${DistanceUpper} -NTubesMin=0/5"

case "$array" in
    oa) #V4 
	noise="3.62,4.45,5.13,5.71,6.21,6.66,7.10,7.83,8.66,9.49,10.34"
	model=MDL8OA_V4_OldArray ;;
    na) #V5 
	noise="4.29,5.28,6.08,6.76,7.37,7.92,8.44,9.32,10.33,11.32,12.33"
	model=MDL15NA_V5_T1Move ;;
    ua) #V6 
	noise="4.24,5.21,6.00,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17" 
	model=MDL10UA_V6_PMTUpgrade ;;
    *) 
	echo "Array $array not recognized! Choose either oa, na, or ua!!"
	exit 1
        ;;
esac

test "$offset" == all && offsets="0.00,0.25,0.50,0.75,1.00,1.25,1.50,1.75,2.00" || offsets="$offset"
# more compact than if then else logic, read about == behavior vs single / double brackets 

for z in ${zeniths//,/ }; do 
    for o in ${offsets//,/ }; do 
	for n in ${noiseLevels//,/ }; do 

	    if [ "$mode" == "dt" ]; then # disp table
		flags="$cuts -DTM_Azimuth ${azimuths}"
#		flags="$flags -DTM_Noise $noise -DTM_Zenith ${zeniths}"
		flags="$flags -Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7" #WindowSizeForNoise 7 by default 
		flags="$flags -DTM_Width 0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
		flags="$flags -DTM_Length 0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"
		# don't use TelID or AbsoluteOffset 
		cmd=produceDispTables
		#buildDispTree -G_SimulationMode=1 -DTM_TelID=0,1,2,3 -DTM_Azimuth=0,45,90,135,180,225,270,315 -DTM_Noise=100,150,200,250,300,350,400,490,605,730,870 -DTM_Width 0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35 -DTM_Length 0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8 -DTM_WindowSizeForNoise=7 dt_MDL10UA_V6_PMTUpgrade_ATM22_CORSIKA_vegas254_7sam_000wobb_Z50_std_1p38_100noise.root
	    fi # disp table

	    # if [[ "$mode" =~ "dt" ]] # lt

	    if [[ "$mode" == "lt" ]]; then
		flags="$cuts -Azimuth=${azimuths}" 
		#flags="$flags -AbsoluteOffset=${offset} -Zenith=${zeniths} -Noise=${noise}"
		flags="$flags -LTM_WindowSizeForNoise=7"
		flags="$flags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
		flags="$flags -Log10SizePerBin=0.07 -ImpDistUpperLimit=800 -MetersPerBin=5.5"
		flags="$flags -TelID=0,1,2,3"
		flags="$flags -G_SimulationMode=1"		

		cmd=produce_lookuptables
		
	    fi # lookup 

	    if [ "$mode" == EA ]; then
		flags="-EA_RealSpectralIndex=-2.4" # -2.1
		flags="$flags -Azimuth=${azimuths}"
		#flags="$flags -Zenith=$zeniths -Noise=${noise}" # same as lookup table
		flags="$flags -cuts=$HOME/cuts/stage5_ea_${spectrum}_cuts.txt"


		cmd="makeEA $flags "
		
	    fi
#	    outputFile=$TABLEDIR/${fileBase}.root
#	    outputLog=$workDir/log/tables/${fileBase}.txt

	    fileBase=${mode}_${model}_ATM${atm}_${simulation}_vegas254_7sam_${o/./}wobb_Z${z}_std_${DistanceUpper/./p}_${n}noise #modify zeniths, offsets
	    smallTableFile=$workDir/processed/tables/${fileBase}.root
	    outputLog=$workDir/log/tables/${fileBase}.txt

	    simFileBase=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${z}deg_${o/./}wobb_${n}noise
	    simFile=/veritas/upload/OAWG/stage2/vegas2.5/Oct2012_${array}_ATM${atm}/${z}_deg/$simFileBase.root
	    simFileList=$workDir/config/simFileList_${array}_ATM${atm}_Z${z}_${o/./}wobb_${n}noise.txt
	    if [ "$runMode" != print ]; then
		test -f $simFileList || echo $simFile > $simFileList
		echo $smallTableFile >> $tableList
	    fi
	    # maybe make separate for lt and dt, remake every time? 
	    # make and append list files but don't actually run if the table piece already exists 

	    if [ -f $smallTableFile ] || [[ "`qstat -f`" =~ "$fileBase" ]]; then
		continue
	    fi
	    cmd="$cmd $flags $simFileList $smallTableFile"
	    echo "$cmd" 

	    if [ "$runMode" == run ]; then
		$cmd | tee $outputLog
		exitCode=${PIPESTATUS[0]}
		echo "$cmd" >> $outputLog

	    elif [ "$runMode" == qsub ]; then 
		qsub <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=4gb
#PBS -j oe
#PBS -V 
#PBS -N $fileBase
#PBS -o $outputLog

while [[ "\`ps cax\`" =~ "bbcp" ]]; do sleep \$((RANDOM%10+10)); done
test -f $scratchDir/$simFileBase.root || bbcp -e -E md5= $simFile $scratchDir/
#exitCode=\$?
#test \$exitCode -eq 0 || exit \$exitCode 

timeStart=\`date +%s\`
$cmd
timeEnd=\`date +%s\`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

exitCode=\$?
echo "$cmd"
if [ \$exitCode -ne 0 ]; then
mv $outputLog $workDir/rejected/
exit \$exitCode
fi

exit 0
EOF
		exitCode=$?
	    fi # runMode options

	    if (( exitCode != 0 )); then
		echo "FAILED!"
		if [ -f $outputLog ]; then
		    mv $outputLog $workDir/rejected/
		fi
		exit 1
	    fi 

	done # noise levels
    done # offsets 
done # zeniths 

exit 0 # great job 
