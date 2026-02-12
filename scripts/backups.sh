#!/bin/bash

# Backup directory
if [[ ! -d "$Backups_folder" ]]; then
    echo "[`date`] ERROR: Backup folder '$Backups_folder' does not exist!" | tee ~/.backups.log
    exit 1
fi

# ESO
if [[ ! -d "$ESO_AddOns_folder" ]]; then 

    echo "[`date`] WARNING: ESO AddOns folder '$ESO_AddOns_folder' does not exist! Aborting" | tee -a ~/.backups.log
    
else

    if [[ ! -d "$Backups_folder/ESO" ]]; then

        mkdir "$Backups_folder/ESO"

    fi

    cd "$ESO_AddOns_folder"
    
    if [[ -f AddOns.zip ]]; then
    
	    echo "[ `date` ] Backing up AddOns from ESO ... " | tee -a ~/.backups.log
    
		zip -r AddOns AddOns > ~/.backups.log 2>&1
		cp AddOns.zip  "$Backups_folder/ESO/."
	
    else
    	echo "[ `date` ] Restoring AddOns from ESO ... " | tee -a ~/.backups.log
    
   		rm -rf AddOns/
		cp "$Backups_folder/ESO/AddOns.zip" .
		unzip -o AddOns.zip
        	    
    fi
    
    if [[ -f SavedVariables.zip ]]; then
    
	    echo "[ `date` ] Backing up SavedVariables from ESO ... " | tee -a ~/.backups.log
    	
		zip -r SavedVariables SavedVariables > ~/.backups.log 2>&1
		cp SavedVariables.zip  "$Backups_folder/ESO/."
	
    else
    
    	echo "[ `date` ] Restoring SavedVariables from ESO ... " | tee -a ~/.backups.log 
    
	    rm -rf SavedVariables/
		cp "$Backups_folder/ESO/SavedVariables.zip" . 		
		unzip -o SavedVariables.zip
        	    
    fi    
           
fi

# DDO
if [[ ! -d "$DDO_folder" ]]; then 

    echo "WARNING: DDO folder '$DDO_folder' does not exist!" | tee -a ~/.backups.log

else

    if [[ ! -d "$Backups_folder/DDO" ]]; then

        mkdir "$Backups_folder/DDO"

    fi

    cd "$DDO_folder"
    
    if [[ -f DDO.zip ]]; then 
    
	    echo "[ `date` ] Backing up DDO ... " | tee -a ~/.backups.log
       
		zip -r DDO . > ~/.backups.log 2>&1
	    cp DDO.zip "$Backups_folder/DDO/."
	    
	else
	
		echo "[ `date` ] Restoring DDO ... " | tee -a ~/.backups.log
	
		cp "$Backups_folder/DDO/DDO.zip" .
		rm -rf DDO/
		unzip -o DDO.zip
	
	fi	    

fi
