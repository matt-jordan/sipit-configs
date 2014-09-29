#!/bin/bash

SRC_ROOT=~/src
PJPROJECT_SRC_DIR=pjproject
ASTERISK_SRC_DIR=asterisk-13-sipit

# It should go without saying that these scripts are completely
# unsafe to use in production

USERNAME=digium
GROUPNAME=digium

# Python scripts
setup_python() {
	echo "*** Installing Python libraries ***"

	pip install ari
}

# System libraries
setup_system() {
	echo "*** Installing System libraries ***"

	PACKAGES="build-essential python-pip vim apache2 ssh ccache"
	PACKAGES="${PACKAGES} libncurses-dev libssl-dev libxml2-dev libsqlite3-dev uuid-dev uuid"
	PACKAGES="${PACKAGES} libspandsp-dev binutils-dev libsrtp-dev libedit-dev libjansson-dev"
	PACKAGES="${PACKAGES} subversion git libxslt1-dev"
	PACAKGES="${PACKAGES} apache2"

	aptitude install -y ${PACKAGES}	
}


# Install Asterisk configuration files/other things
install_asterisk_configs() {
	echo "*** Installing Asterisk configs ***"

	sudo -u ${USERNAME} cp -v asterisk/*.conf /etc/asterisk/

	primary_ip_addr=`hostname -I | awk '{printf $1;}'`
	sudo -u ${USERNAME} sed -i s/REPLACE_WITH_MY_SERVER/${primary_ip_addr}/g /etc/asterisk/pjsip.conf
}

# Install Digium phone configuration files
install_dphone_configs() {
	echo "*** Installing Digium Phone configs ***"

	chown -R ${USERNAME}:${GROUPNAME} /var/www/html

	sudo -u ${USERNAME} cp -v phone/000fd305c374.cfg /var/www/html/000fd305c374.cfg
	sudo -u ${USERNAME} cp -v phone/*.xml /var/www/html/

	primary_ip_addr=`hostname -I | awk '{printf $1;}'`
	sudo -u ${USERNAME} sed -i s/REPLACE_WITH_MY_SERVER/${primary_ip_addr}/g /var/www/html/000fd305c374.cfg

	hostname=`hostname | awk '{printf $1;}'`
	sudo -u ${USERNAME} sed -i s/REPLACE_WITH_HOSTNAME/${hostname}/g /var/www/html/matt_contacts.xml
}

# Install TLS configs
install_tls() {
	echo "*** Installing TLS certificates ***"

	if [ ! -d /etc/asterisk/tls ]; then
		mkdir /etc/asterisk/tls
		chown -R ${USERNAME}:${GROUPNAME} /etc/asterisk/tls
	fi

	sudo -u ${USERNAME} cp -v tls/* /etc/asterisk/tls
}

# Copy over site specific config headers
setup_pjproject() {
	echo "*** Configuring pjproject ***"

	sudo -u ${USERNAME} cp -v pjproject/config_site.h ${SRC_ROOT}/${PJPROJECT_SRC_DIR}/pjlib/include/pj/config_site.h

}

build_pjproject() {
	pushd ${SRC_ROOT}/${PJPROJECT_SRC_DIR}
	sudo -u ${USERNAME} ./aconfigure CFLAGS="-O2" --enable-shared --with-external-srtp --prefix=/usr
	sudo -u ${USERNAME} make dep
	sudo -u ${USERNAME} make
	make install
	popd
}

quick_build_asterisk() {
	pushd ${SRC_ROOT}/${ASTERISK_SRC_DIR}

	sudo -u ${USERNAME} make
	if [ -f /usr/sbin/asterisk ] ; then
		make uninstall
	fi

	make install

	chown -R ${USERNAME}:${GROUPNAME} /usr/lib/asterisk
	chown -R ${USERNAME}:${GROUPNAME} /var/lib/asterisk
	chown -R ${USERNAME}:${GROUPNAME} /var/spool/asterisk
	chown -R ${USERNAME}:${GROUPNAME} /var/log/asterisk
	chown -R ${USERNAME}:${GROUPNAME} /var/run/asterisk
	chown -R ${USERNAME}:${GROUPNAME} /etc/asterisk
	chown ${USERNAME}:${GROUPNAME} /usr/sbin/asterisk
	popd
}


build_asterisk() {
	pushd ${SRC_ROOT}/${ASTERISK_SRC_DIR}
	sudo -u ${USERNAME} ./configure --enable-dev-mode --with-pjproject
	sudo -u ${USERNAME} make menuselect.makeopts

	echo "*** Enabling extra sounds ***"
	sudo -u ${USERNAME} menuselect/menuselect --enable EXTRA-SOUNDS-EN-WAV menuselect.makeopts

	echo "*** Enabling external MWI ***"
	sudo -u ${USERNAME} menuselect/menuselect --disable app_voicemail menuselect.makeopts
	sudo -u ${USERNAME} menuselect/menuselect --enable res_mwi_external menuselect.makeopts
	sudo -u ${USERNAME} menuselect/menuselect --enable res_stasis_mailbox menuselect.makeopts 
	sudo -u ${USERNAME} menuselect/menuselect --enable res_ari_mailboxes menuselect.makeopts 

	echo "*** Enabling debug menuselect flags ***"
	sudo -u ${USERNAME} menuselect/menuselect --enable DONT_OPTIMIZE menuselect.makeopts 
	sudo -u ${USERNAME} menuselect/menuselect --enable BETTER_BACKTRACES menuselect.makeopts 
	sudo -u ${USERNAME} menuselect/menuselect --enable MALLOC_DEBUG menuselect.makeopts 
	sudo -u ${USERNAME} menuselect/menuselect --enable DO_CRASH menuselect.makeopts 

	quick_build_asterisk

	popd
}

INSTALL_PJPROJECT=0
QUICK_BUILD_ASTERISK=0
INSTALL_ASTERISK=0
INSTALL_CONFIGS=0
SETUP_SYSTEM=0

while [ "$#" -gt "0" ]; do
	case ${1} in
		-a|--asterisk)		INSTALL_ASTERISK=1;;
		-qa|--quick-asterisk)	QUICK_BUILD_ASTERISK=1;;
		-i|--install-configs)	INSTALL_CONFIGS=1;;
		-p|--pjproject)		INSTALL_PJPROJECT=1;;
		-s|--system)		SETUP_SYSTEM=1;;
	esac
	shift
done

if [ ${SETUP_SYSTEM} -eq 1 ]; then
	setup_system
	setup_python
fi

if [ ${INSTALL_PJPROJECT} -eq 1 ]; then
	setup_pjproject
	build_pjproject
fi

if [ ${INSTALL_ASTERISK} -eq 1 ]; then
	build_asterisk	
fi

if [ ${QUICK_BUILD_ASTERISK} -eq 1 ]; then
	quick_build_asterisk
fi

if [ ${INSTALL_CONFIGS} -eq 1 ]; then
	install_asterisk_configs
	install_dphone_configs
	install_tls
fi

echo "*** Installation/configuration script complete ***"

exit 0
