#!/bin/bash
#
# Copyright 2013-2014 
# Développé par : Stéphane HACQUARD
# Date : 02-01-2014
# Version 1.0
# Pour plus de renseignements : stephane.hacquard@sargasses.fr



#############################################################################
# Variables d'environnement
#############################################################################


DIALOG=${DIALOG=dialog}

REPERTOIRE_CONFIG=/usr/local/scripts/config
FICHIER_CONFIG=config_centralisation_sauvegarde

DATE_HEURE=`date +%d.%m.%y`-`date +%H`h`date +%M`

NagiosLockFile=/usr/local/nagios/var/nagios.lock
Ndo2dbPidFile=/var/run/ndo2db/ndo2db.pid
NrpePidFile=/var/run/nrpe/nrpe.pid

CentenginePidFile=/var/run/centengine.pid
CbdbrokerPidFile=/var/run/cbd_central-broker.pid
CbdrrdPidFile=/var/run/cbd_central-rrd.pid
CentcorePidFile=/var/run/centreon/centcore.pid
CentstoragePidFile=/var/run/centreon/centstorage.pid


#############################################################################
# Fonction Verification installation de dialog
#############################################################################


if [ ! -f /usr/bin/dialog ] ; then
	echo "Le programme dialog n'est pas installé!"
	apt-get install dialog
else
	echo "Le programme dialog est déjà installé!"
fi


#############################################################################
# Fonction Activation De La Banner Pour SSH
#############################################################################


if grep "^#Banner" /etc/ssh/sshd_config > /dev/null ; then
	echo "Configuration de Banner en cours!"
	sed -i "s/#Banner/Banner/g" /etc/ssh/sshd_config 
	/etc/init.d/ssh reload
else 
	echo "Banner déjà activée!"
fi


#############################################################################
# Fonction Lecture Fichier Configuration Gestion Centraliser
#############################################################################

lecture_config_centraliser()
{

if test -e $REPERTOIRE_CONFIG/$FICHIER_CONFIG ; then

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VAR$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CONFIG | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

else 

mkdir -p $REPERTOIRE_CONFIG

num=10
while [ "$num" -le 15 ] 
	do
	echo "VAR$num=" >> $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	num=`expr $num + 1`
	done

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VALFIC$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CONFIG | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

fi

if [ "$VAR10" = "" ] ; then
	REF10=`uname -n`
else
	REF10=$VAR10
fi

if [ "$VAR11" = "" ] ; then
	REF11=3306
else
	REF11=$VAR11
fi

if [ "$VAR12" = "" ] ; then
	REF12=sauvegarde
else
	REF12=$VAR12
fi

if [ "$VAR13" = "" ] ; then
	REF13=root
else
	REF13=$VAR13
fi

if [ "$VAR14" = "" ] ; then
	REF14=directory
else
	REF14=$VAR14
fi

}


#############################################################################
# Fonction Lecture Des Valeurs Dans La Base de Donnée
#############################################################################

lecture_valeurs_base_donnees()
{

lecture_config_centraliser

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


cat <<- EOF > $fichtemp
select user
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-user.txt

lecture_user=$(sed '$!d' /tmp/lecture-user.txt)
rm -f /tmp/lecture-user.txt
rm -f $fichtemp

cat <<- EOF > $fichtemp
select password
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-password.txt

lecture_password=$(sed '$!d' /tmp/lecture-password.txt)
rm -f /tmp/lecture-password.txt
rm -f $fichtemp


cat <<- EOF > $fichtemp
select base
from sauvegarde_bases
where uname='`uname -n`' and application='centreon' ;

EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/lecture-bases.txt

sed -i '1d' /tmp/lecture-bases.txt

lecture_bases_no1=$(sed -n '1p' /tmp/lecture-bases.txt)
lecture_bases_no2=$(sed -n '2p' /tmp/lecture-bases.txt)
lecture_bases_no3=$(sed -n '3p' /tmp/lecture-bases.txt)
rm -f /tmp/lecture-bases.txt
rm -f $fichtemp


cat <<- EOF > $fichtemp
select nombre_bases
from information
where uname='`uname -n`' and application='centreon' ;
EOF

mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nombre-bases-lister.txt

nombre_bases_lister=$(sed '$!d' /tmp/nombre-bases-lister.txt)
rm -f /tmp/nombre-bases-lister.txt
rm -f $fichtemp


if [ "$nombre_bases_lister" = "" ] ; then
nombre_bases_lister=0
fi

if [ "$lecture_user" = "" ] ; then
	REF20=root
else
	REF20=$lecture_user
fi

if [ "$lecture_password" = "" ] ; then
	REF21=directory
else
	REF21=$lecture_password
fi

if [ "$lecture_bases_no1" = "" ] ; then
	REF22=centreon
else
	REF22=$lecture_bases_no1
fi

if [ "$lecture_bases_no2" = "" ] ; then
	REF23=centstorage
else
	REF23=$lecture_bases_no2
fi

if [ "$lecture_bases_no3" = "" ] ; then
	REF24=centstatus
else
	REF24=$lecture_bases_no3
fi


}


#############################################################################
# Fonction Message d'erreur
#############################################################################

message_erreur()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que les parametres saisie
                sont correcte
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Parametrage Serveur Centreon" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 52 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Verification Couleur
#############################################################################

verification_couleur()
{


# 0=noir, 1=rouge, 2=vert, 3=jaune, 4=bleu, 5=magenta, 6=cyan 7=blanc

if ! grep -w "OUI" $REPERTOIRE_CONFIG/$FICHIER_CONFIG > /dev/null ; then
	choix1="\Z1Gestion Centraliser des Taches\Zn" 
else
	choix1="\Z2Gestion Centraliser des Taches\Zn" 
fi

if [ "$nombre_bases_lister" = "0" ] ; then
	choix2="\Z1Configuration Bases A Sauvegarder\Zn" 
else
	choix2="\Z2Configuration Bases A Sauvegarder\Zn" 
fi


}

#############################################################################
# Fonction Menu 
#############################################################################

menu()
{

lecture_config_centraliser
verification_couleur

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Configuration Restauration Centreon" \
	  --title "Configuration Restauration Centreon" \
	  --clear \
	  --colors \
	  --default-item "3" \
	  --menu "Quel est votre choix" 12 56 4 \
	  "1" "$choix1" \
	  "2" "Configuration Restauration Centreon" \
	  "3" "Quitter" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Taches
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
              menu_gestion_centraliser_taches
	fi

	# Configuration Restauration Centreon
	if [ "$choix" = "2" ]
	then
		if [ "$VAR15" = "OUI" ] ; then
			rm -f $fichtemp
			menu_configuration_restauration_centreon
		else
			rm -f $fichtemp
			message_erreur
			menu
		fi
	fi
	
	# Quitter
	if [ "$choix" = "3" ]
	then
		clear
	fi

	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

exit

}

#############################################################################
# Fonction Menu Gestion Centraliser des Taches
#############################################################################

menu_gestion_centraliser_taches()
{

lecture_config_centraliser

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Configuration Restauration Centreon" \
	  --insecure \
	  --title "Gestion Centraliser des Taches" \
	  --mixedform "Quel est votre choix" 11 60 0 \
	  "Nom Serveur:"     1 1  "$REF10"  1 24  28 26 0  \
	  "Port Serveur:"    2 1  "$REF11"  2 24  28 26 0  \
	  "Base de Donnees:" 3 1  "$REF12"  3 24  28 26 0  \
	  "Compte Root:"     4 1  "$REF13"  4 24  28 26 0  \
	  "Password Root:"   5 1  "$REF14"  5 24  28 26 1  2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Taches
	VARSAISI10=$(sed -n 1p $fichtemp)
	VARSAISI11=$(sed -n 2p $fichtemp)
	VARSAISI12=$(sed -n 3p $fichtemp)
	VARSAISI13=$(sed -n 4p $fichtemp)
	VARSAISI14=$(sed -n 5p $fichtemp)
	

	sed -i "s/VAR10=$VAR10/VAR10=$VARSAISI10/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR11=$VAR11/VAR11=$VARSAISI11/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR12=$VAR12/VAR12=$VARSAISI12/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR13=$VAR13/VAR13=$VARSAISI13/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR14=$VAR14/VAR14=$VARSAISI14/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG

      
	cat <<- EOF > /tmp/databases.txt
	SHOW DATABASES;
	EOF

	mysql -h $VARSAISI10 -P $VARSAISI11 -u $VARSAISI13 -p$VARSAISI14 < /tmp/databases.txt &>/tmp/resultat.txt

	if grep -w "^$VARSAISI12" /tmp/resultat.txt > /dev/null ; then
	sed -i "s/VAR15=$VAR15/VAR15=OUI/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG

	else
	sed -i "s/VAR15=$VAR15/VAR15=NON/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	message_erreur
	fi

	rm -f /tmp/databases.txt
	rm -f /tmp/resultat.txt
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}

#############################################################################
# Fonction Menu Configuration Restauration Centreon
#############################################################################

menu_configuration_restauration_centreon()
{

lecture_valeurs_base_donnees

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Configuration Restauration Centreon" \
	  --insecure \
	  --title "Configuration Restauration Centreon" \
	  --mixedform "Quel est votre choix" 12 62 0 \
	  "Fichier de Sauvegarde:"   1 1  "centreon-$DATE_HEURE.tgz" 1 25  28 28 0  \
	  "Utilisateur de la Base:"  2 1  "$REF20"                   2 25  28 28 0  \
	  "Password de la Base:"     3 1  "$REF21"                   3 25  28 28 1  \
	  "Nom de la Base:"          4 1  "$REF22"                   4 25  28 28 0  \
	  "Nom de la Base:"          5 1  "$REF23"                   5 25  28 28 0  \
	  "Nom de la Base:"          6 1  "$REF24"                   6 25  28 28 0  2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Configuration Restauration Centreon
	VARSAISI10=$(sed -n 1p $fichtemp)
	VARSAISI11=$(sed -n 2p $fichtemp)
	VARSAISI12=$(sed -n 3p $fichtemp)
	VARSAISI13=$(sed -n 4p $fichtemp)
	VARSAISI14=$(sed -n 5p $fichtemp)
	VARSAISI14=$(sed -n 6p $fichtemp)

	if [ -f $VARSAISI10 ] ; then


	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	if [ -f $Ndo2dbPidFile ] ; then
	/etc/init.d/ndo2db stop &> /dev/null
	fi

	if [ -f $CentenginePidFile ] ; then
	/etc/init.d/centengine stop &> /dev/null
	fi

	if [ -f $CbdbrokerPidFile ] || [ -f $CbdrrdPidFile ] ; then	
	/etc/init.d/cbd stop &> /dev/null
	fi

	if [ -f $CentcorePidFile ] ; then
	/etc/init.d/centcore stop &> /dev/null
	fi

	if [ -f $CentstoragePidFile ] ; then
	/etc/init.d/centstorage stop &> /dev/null
	fi

	tar xvzf $VARSAISI10

	rm -rf /etc/centreon/
	rm -rf /usr/local/centreon/www/img/media/
	rm -rf /var/lib/centreon

	cp -R etc/centreon/ /etc/
	cp -R usr/local/centreon/www/img/media/ /usr/local/centreon/www/img/
	cp -R var/lib/centreon/ /var/lib/

	rm -rf etc/
	rm -rf usr/
	rm -rf var/
	
	else
		rm -f $fichtemp
		message_erreur
		menu
	fi

	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}


#############################################################################
# Demarrage du programme
#############################################################################

menu