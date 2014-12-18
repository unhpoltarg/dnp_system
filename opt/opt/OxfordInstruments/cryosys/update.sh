#!/bin/sh
# To update the system it
# If no update or old directory do nothing
#
# Copies relevent files from cryosys -> backup; update -> cryosys
# OR
# Copies relevent files from cryosys -> update; old -> cryosys
#
# This assumes the we are starting one directory above
# the (potentialy) three directories. BASE_DIR 
# cryosys_update, cryosys and cryosys_old.


#------------------------------------------------------------------------------
# In this function.
# If the 'cyosys_update' directory does not exist then the program exits.
# If a file exists in 'cryosys_update' it will transfer the equivelent file in 'cryosys' to 'cryosys_old'.
# The file in 'cryosys_update' will then get copied into 'cryosys'.
# Finaly 'cryosys_update' will be deleted.
do_update()
{
 OLD=$1
 CRYOSYS=$2
 UPDATE=$3
   
 if [ ! -d $CRYOSYS ]; then
  echo "$CRYOSYS does not exist in this directory locate one above and re run"
  exit 2
 fi
 
 # create a empty old directory
 if [ -d $OLD ]; then
  rm -R $OLD
 fi
 mkdir $OLD 

 # if cryosys_update exists
 if [ -d $UPDATE ]; then
 
  cd $UPDATE
 
  # Loop through the files in the current directory
  ls
  for file in *; 
  do
   if [ ! -d $BASE_DIR/$UPDATE/$file ]; then
    # copy the files down
    #echo "copy this file $BASE_DIR/$CRYOSYS/$file to $BASE_DIR/$OLD"
    cp -fv $BASE_DIR/$CRYOSYS/$file $BASE_DIR/$OLD/
    #echo "copy this file $BASE_DIR/$UPDATE/$file to $BASE_DIR/$CRYOSYS"
    cp -fv $BASE_DIR/$UPDATE/$file  $BASE_DIR/$CRYOSYS/
    else
		# copy the directory
		cp -rf $BASE_DIR/$CRYOSYS/$file $BASE_DIR/$OLD/		
		# when reverting one should delete first the directory to restore only the original files from before updates		
		if [ $OLD = "cryosys_update" ]; then
			rm -r $BASE_DIR/$CRYOSYS/$file 
		fi
		cp -Rf $BASE_DIR/$UPDATE/$file  $BASE_DIR/$CRYOSYS/
   fi
  done
 fi

 # Put back to starting directory
 cd $BASE_DIR
 #cd ../

 chmod -R 777 $OLD
  
 # Remove the update directory
 #echo "Removing the directory $UPDATE"
 rm -Rv $UPDATE
}
#------------------------------------------------------------------------------


cd ../
BASE_DIR=$(pwd)
RES_DRV=0

# If no update or old directory do nothing
#
# The update directory takes precedence.
# If update directory is there then use it to update the system.
# It will be deleted at end of function call.
if [ -d cryosys_update ]; then
 	if [ -d cryosys_update/lib ]; then 
		RES_DRV=1
 	fi
 	
	echo  "Applying New Updates. Please wait . . . "
 	do_update cryosys_old cryosys cryosys_update
 	
	if [ RES_DRV==1 ]; then 
		sh /etc/init.d/S50oidbDrivers restart
	fi
else
 	# Update director does not exist so now look for the old directory.
 	# If old directory exists then undo the update.
 	# The old directory will be delete at the end of function call.
	if [ -d cryosys_old ]; then
		if [ -d cryosys_old/lib ]; then  
			RES_DRV=1
		fi
	
		echo  "Reverting Updates. Please wait . . . "
		
		do_update cryosys_update cryosys cryosys_old
		rm -r cryosys_update

		if [ RES_DRV==1 ]; then 
			sh /etc/init.d/S50oidbDrivers restart
		fi
	fi
fi

cd cryosys

exit 0

