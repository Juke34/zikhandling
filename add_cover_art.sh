#!/bin/bash

#################################
# Dainat 2016
# jacques.dainat@gmail.com
#################################


# /!\ The script deal only with Id3 tag
#
#
#

nb=0 #counter number picture added
nbL=0 #counter number picture corrected


function get_picture(){
	array="$1"
	picture=()

	for i in  "${array[@]}";do
		if echo $i  | grep -iq cover;then
			picture+=("$i")
		fi
	done

	for i in  "${array[@]}";do
		if echo $i  | grep -iq folder;then
			picture+=("$i")
		fi
	done

		for i in  "${array[@]}";do
		if echo $i  | grep -iq front;then
			picture+=("$i")
		fi
	done

	for i in  "${array[@]}";do
		if echo $i  | grep -iq recto;then
			picture+=("$i")
		fi
	done					

	#Nothing found take the biggest
	sizeP=0
	bigestPicture=""
	for i in  "${array[@]}";do
		pictureSize=$(du -k "$i" | cut -f 1)
		if (( $pictureSize > $sizeP ));then
			bigestPicture=$i
			sizeP=$pictureSize
		fi
	done
	if [[ bigestPicture != "" ]];then
		picture+=("$bigestPicture")
	fi
}

#####################
# PARAMETER AND HELP
#####################
folder=''
silence=''
startFrom=''
resize_size="1200x1200" #1mo ~ 1400*1400
picture_size=1000 # kiloctet 1000 ~ 1 mo
help_message="""This tool allowws to add cover art to albums\n
	options:\n
	-h              => show brief help\n
	-d name         => specify the directory\n
	"""

#check if no option
if (( $# == 0 )); then
	echo -e $help_message
	exit 0
fi
# When option, handle them correctly
while getopts 'hd:f:s' opt; do
	case "${opt}" in
    	h)
			echo -e $help_message
		    exit 0
	   		;;
	    d) 
			folder="${OPTARG}" ;;
		f)
			startFrom="${OPTARG}" ;;
	    s) 
			silence='true' ;;
	    *) 
			echo error "Unexpected option ${opt}" ;;
  esac
done

echo "Lets work on the folder <$folder>";

IFS=$'\n';
letsgo=""
for i in $(find $folder -type d | sort); do #list tous les repertoires

	if [[ $i == "." ]];then
		continue
	fi

	#Check if we skip according to the parameter startFrom
	folderName=${i##*/}
	if [[ $startFrom == "" ]];then
		letsgo="yes"
	elif [[ $folderName =~ ^[${startFrom,,}-z${startFrom^^}-Z] ]];then
		letsgo="yes"
	fi

	if [[ $letsgo == "yes" ]];then 
		echo -e "\nlook into $i"
		#list all picture available into the folder
		array=(`find $i -maxdepth 1 -type f -regex ".*/.*\.\(jpg\|jpeg\|png\|gif\|JPG\|JPEG\|PNG\|GIF\)"`)
		
		#if we have a picture we continue
		if [ ${#array[@]} -gt 0 ];then

			arrayZik=(`find $i -maxdepth 1 -type f -regex ".*/.*\.\(ogg\|mpg\|mp3\|aac\|ac3\|wav\|MP3\|wma\|AAC\|Ogg\|WMA\|WAV\)"`)
			if [ ${#arrayZik[@]} -gt 0 ];then
				echo "I have a ${#arrayZik[@]} songs and ${#array[@]} picture(s)"

				#iterate over songs
				bestPic=""
				modif=0
				choice=''
				for song in "${arrayZik[@]}";do
					
					# if the song does not have picture
					if ! [  $(id3v2 -l $song | awk '{print $1}' | grep "APIC") ];then
						#song whitout tag
						echo "The song <${song##*/}> does not have cover art !!"
						
						# Get best picture to add to this song if not yet chosen
						if [[ $bestPic == "" ]];then

							get_picture $array #return a picture array
							#Manage picture
							bestPic="${picture[0]}"
							pictureSize=$(du $bestPic | cut -f 1) #size in byte
							size=$(echo "scale=2; $pictureSize*1024/1000000" | bc -l)
							
							if [ $pictureSize -ge 1000 ];then
								#I have to reencode it because is to big (over 1Mb)
								
								echo "picture $bestPic too big ($size mo) => Resize it"
								path=$(dirname $bestPic)
								#echo "we resize $bestPic"
								##echo "convert $bestPic -resize 600*600 ${path}/resized.jpg"
								convert $bestPic -resize $resize_size ${path}/resized.jpg

								pictureSize=$(du ${path}/resized.jpg | cut -f 1) #size in byte
								newsize=$(echo "scale=2; $pictureSize*1024/1000000" | bc -l)
								echo "New picture size: $newsize mo"
								#extension="${bestPic##*.}"
								#filename=$(basename $bestPic .$extension)

								##echo "mv $bestPic ${filename}_original.${extension}"
								#mv ${picture[0]} ${path}/${filename}_original.${extension}
								#mv ${path}/resized.jpg ${path}/${filename}.jpg
								#bestPic=${path}/${filename}.jpg
							fi
						fi

						#ASK IF WE LOAD THE COVERT ART
						if [[ $choice == '' ]];then
							addpic=false
							if [[ $silent == true ]];then
								addpic=true
							else
								echo "Do you wish to add the picture <${bestPic##*/}> (size=$size mo) to the song <${song##*/}> (y/n)?"
								read answer
		    					if echo "$answer" | grep -iq "^y" ;then
								    addpic=true ;
								fi
							fi
							choice=$addpic
						fi

						# Add the picture to the song
						if [[ $addpic == true ]];then
							echo "command=  $song $bestPic"
							fancy_audio $song $bestPic
							((nb=nb+1))
							#echo "We included the pic $bestPic to $song!"
						fi
					#The song has a picture
					#elif [[ "${array[@]}" =~ "_original." ]];then

					#		if [[ $bestPic == "" ]];then
					#			path=$(dirname ${array[0]})
					#			tt=$(echo $path | sed 's/\[/\\[/g')
					#			tt=$(echo $path | sed 's/\]/\\]/g')
					#			total=$(echo ${tt}/*_original.*)
					#			echo "quoi $total"
					#			filenameAll=$(basename $total)
					#			extension="${filenameAll##*.}"
					#			filename=$(basename $total _original.$extension)
					#			rm ${path}/${filename}.jpg 

					#			bestPic=${total}
					#			pictureSize=$(du $bestPic | cut -f 1)
								
					#			if [ $pictureSize -ge 1000 ];then 
					#				#I have to reencode it because is to big (over 1Mb)
					#				echo "picture too big => Resize it"
									#echo "convert $bestPic -resize 600*600 ${path}/resized.jpg"
					#				convert $bestPic -resize 600x600 ${path}/${filename}.jpg
					#				bestPic=${path}/${filename}.jpg
					#			else
					#				modif=1
					#			fi
					#		fi
					#	fancy_audio $song $bestPic
					#   ((nbL=nbL+1))
					#   echo "We changed the pic $bestPic to $song!"

					fi
				done

				if [[ $modif == 1 ]];then
					mv $total ${path}/${filename}.${extension}
					bestPic=${path}/${filename}.${extension}
				fi
			fi
		fi
	fi
done

echo "We included $nb pic !"
#echo "correct previous one : $nbL"