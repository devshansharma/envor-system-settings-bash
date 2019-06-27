#! /bin/bash

# variables
PROGRAM_NAME="Envor"
LOG_FILE="/var/log/messages"


# array to maintain commands to be installed
Commands_Needed_Array=(ifconfig iptables mogrify ssh scp macchanger traceroute exiftool)
Commands_Package_Array=(net-tools iptables imagemagick ssh ssh macchanger traceroute libimage-exiftool-perl)
Commands_To_Install_Array=()


# function to show alert message
notify_send () {
	#notify-send $1 "${PROGRAM_NAME}: $2"
	echo $1 "${PROGRAM_NAME}: $2"
}


# function to create logs in file
create_logs () {
	local date=$(date '+%F %T')
	local starting="$date [${USER} - ${PROGRAM_NAME}]: "
	echo "${starting} $1" | sudo tee --append ${LOG_FILE}
}

# creating alias and reloading bash
create_alias () {
	# will return 1 when nothing found
: '
	if [ ! -f ~/.bash_aliases ]
	then
		echo ".bash_aliases file created!"
		touch ~/.bash_aliases
	fi
'
	echo "Creating alias in .bash_aliases file ..."
	cat <<EOF > ~/.bash_aliases
# alias created by user
# using ${PROGRAM_NAME}
alias c='clear'
alias e='exit'
alias desk='cd Desktop'
alias suspend='sudo systemctl suspend'
alias firewall='watch -n 1 sudo iptables --list --verbose'
alias shutdown='sudo shutdown -h -P now'
alias reboot='sudo shutdown -r now'
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias rm='rm --preserve-root'
EOF
#	exec bash
	notify_send "Success!" "Alias created successfully!"
}


# check if ufw enabled/disabled and make firewall rules
create_firewall_rules () {
	notify_send "Information" "Creating firewall rules!"
	echo "Creating firewall rules..."
	# make sure the rules survive a reboot
	#apt install iptables-persistent
	# https://www.digitalocean.com/community/tutorials/how-to-list-and-delete-iptables-firewall-rules
	# https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands

	# to delete a specific rule
	# sudo iptables -L --line-numbers
	# sudo iptables -D INPUT 3

	# new rules
	iptables --flush
	iptables --policy INPUT DROP
	iptables --policy FORWARD DROP
	iptables --policy OUTPUT DROP

	iptables --append INPUT --in-interface lo --jump ACCEPT
	iptables --append OUTPUT --out-interface lo --jump ACCEPT
	iptables --append INPUT --match conntrack --ctstate INVALID --jump DROP

	# allowing promod to access mysql
	iptables --append INPUT --protocol tcp --source 192.168.0.27 --dport 3306 --jump ACCEPT
	iptables --append OUTPUT --protocol tcp --destination 192.168.0.27 --sport 3306 --jump ACCEPT

	iptables --append INPUT --protocol tcp --match multiport --sports 22,53,80,443 --match conntrack --ctstate ESTABLISHED,RELATED --jump ACCEPT
	iptables --append OUTPUT --protocol tcp --match multiport --dports 22,53,80,443 --match conntrack --ctstate NEW,ESTABLISHED --jump ACCEPT

	iptables --append OUTPUT --protocol udp --match multiport --dports 53 --jump ACCEPT
	iptables --append INPUT --protocol udp --match multiport --sports 53 --jump ACCEPT

	# for incoming ping request
	iptables --append INPUT --protocol icmp --icmp-type 8 --jump ACCEPT
	iptables --append OUTPUT --protocol icmp --icmp-type 0 --jump ACCEPT

	# for outgoing ping request
	iptables --append OUTPUT --protocol icmp --icmp-type 8 --jump ACCEPT
	iptables --append INPUT --protocol icmp --icmp-type 0 --jump ACCEPT

	# for window, samba rules
	#iptables --append INPUT --protocol udp --match multiport --sports 137,138 --jump ACCEPT

	# other icmp types
	# https://serverfault.com/questions/340267/iptables-types-of-icmp-which-ones-are-potentially-harmful
	iptables --append INPUT --protocol icmp --jump LOG --log-prefix 'ICMP INPUT '
	iptables --append INPUT --protocol icmp --icmp-type 3 --jump ACCEPT
	iptables --append INPUT --protocol icmp --icmp-type 5 --jump ACCEPT
	iptables --append INPUT --protocol icmp --icmp-type 9 --jump ACCEPT

	iptables --append INPUT --jump LOG --match limit --limit 12/min --log-level 4 --log-prefix 'IP INPUT DROP: '
	iptables --append OUTPUT --jump LOG --match limit --limit 12/min --log-level 4 --log-prefix 'IP OUTPUT DROP: '
	iptables --append INPUT --jump DROP
	iptables --append OUTPUT --jump DROP

	# after updating firewall rules
	#netfilter-persistent save
	notify_send "Success!" "Firewall Rules Updated!"
}


# function to check if all the required commands are available
check_commands_available () {
	echo "Checking for commands availability!"
	for index in ${!Commands_Needed_Array[*]}
	do
		local cmd=${Commands_Needed_Array[$index]}
		eval "whatis $cmd " 2&> /dev/null
		if [ $? -ne 0 ]
		then
			printf "  %-12s \t\t[Not Found]\n" $cmd
			Commands_To_Install_Array=("${Commands_To_Install_Array[@]}" "$index")
		else
			printf "  %-12s \t\t[OK]\n" $cmd
		fi
	done
	if [ ${#Commands_To_Install_Array[@]} -gt 0 ]
	then
		echo -n "Do you want to install uninstalled packages: "
		read answer
		if [[ $answer == 'y' || $answer == 'Y' ]]
		then
			echo "Installing Packages not available..."
			for number in ${Commands_To_Install_Array[*]}
			do
				eval "sudo apt install " ${Commands_Package_Array[$number]}
				if [ $? -eq 0 ]
				then
					create_logs "${Commands_Needed_Array[$number]} installed!"
				else
					create_logs "${Commands_Needed_Array[$number]} not installed!"
				fi
			done
			notify_send "Success!" "Packages installed Successfully!"
		else
			echo "Installation cancelled!"
		fi
	fi
}


# initializing script
init () {
	clear
	if [[ $EUID -ne 0 ]]; then
		echo "You must be root to do this." 1>&2
	   	exit 100
	fi
	echo "Creating Environment..."
	check_commands_available
	create_alias
	create_firewall_rules
	#sleep 1s
	notify_send "Success" "System Modified for user `echo $USER`!"
	echo "Environment Created!"
	exit 0
}

init




#                    comments section for more information
# ===========================================================================
: '
to read about log files
https://www.eurovps.com/blog/important-linux-log-files-you-must-be-monitoring/
/var/log/messages
	same as /var/log/syslog
	generic system activity logs
	informational and non-critical system messages
/var/log/auth.log
	authentication related logs
/var/log/boot.log
	bootup messages by system initialization script
	during startup process
/var/log/dmesg
	kernel ring buffer messages
	hardware devices and their buffers
/var/log/kern.log
	kernel related errors and warnings
	also hardware and connectivity issues
/var/log/faillog
	failed login attempts
/var/log/cron
	cron jobs
/var/log/maillog
	mail server related logs
/var/log/httpd/
	logs recorded by apache server
/var/log/mysql.log
	client connections and long_query_time
'
