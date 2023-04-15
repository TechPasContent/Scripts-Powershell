# Utilisation 
Prérequis : 1VM, un disque secondaire sur la VM
1. Lancer playstation1.ps1, redémarrer
2. Lancer playstation2.ps1, redémarrer
3. lancer playstation3.ps1, redémarrer



# Description

- <b> playstation1.ps1 </b> 
	- Change le nom du PC 
	- Redémarrage nécessaire

- <b> playstation2.ps1 </b>
	- Config de l'interface (IP, DNS, Gateway...)
	- Installation du serveur DHCP
	- Installation du serveur AD et de la Forêt
	- Redémarrage nécessaire

- <b> playstation3.ps1 </b>
	- Autorise DHCP sur le DC
	- Config users/grps/OU de l'AD
	- Configuration du dossier pour les profils itinérants
	- Configuration du dossier partage commun
