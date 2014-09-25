#!/bin/bash

SRC_ROOT=~/projects
PJPROJECT_SRC_DIR=pjproject
ASTERISK_SRC_DIR=13

# Python scripts
setup_python() {
	echo "*** Installing Python libraries ***"

	pip install ari
}

# System libraries
setup_system() {
	echo "*** Installing System libraries ***"

	PACKAGES="build-essential"
	PACKAGES="${PACKAGES} libncurses-dev libssl-dev libxml2-dev libsqlite3-dev uuid-dev uuid"
	PACKAGES="${PACKAGES} libspandsp-dev binutils-dev libsrtp-dev libedit-dev libjansson-dev"
	PACKAGES="${PACKAGES} subversion git libxslt1-dev"

	aptitude install -y ${PACKAGES}	
}

# Install Asterisk configuration files/other things
install_asterisk_configs() {
	echo "*** Installing Asterisk configs ***"

	cp -v asterisk/*.conf /etc/asterisk/
}

# Copy over site specific config headers
setup_pjproject() {
	echo "*** Configuring pjproject ***"

	sudo -u ${USERNAME} cp pjproject/config_site.h ${SRC_ROOT}/${PJPROJECT_SRC_DIR}/pjlib/include/pj/config_site.h

}

build_pjproject() {
	pushd ${SRC_ROOT}/${PJPROJECT_SRC_DIR}
	sudo -u ${USERNAME} ./configure --enable-shared --external-srtp --prefix=/usr
	sudo -u ${USERNAME} make dep
	sudo -u ${USERNAME} make
	make install
	popd
}

build_asterisk() {
	pushd ${SRC_ROOT}/${ASTERISK_SRC_DIR}
	sudo -u ${USERNAME} ./configure --enable-dev-mode --with-pjproject
	sudo -u ${USERNAME} make menuselect.makeopts

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

	sudo -u ${USERNAME} make
	if [ -f /usr/sbin/asterisk ] ; then
		make uninstall
	fi

	make install
	popd
}

INSTALL_PJPROJECT=0
INSTALL_ASTERISK=0
INSTALL_CONFIGS=0
SETUP_SYSTEM=0

while [ "$#" -gt "0" ]; do
	case ${1} in
		-a|--asterisk)		INSTALL_ASTERISK=1;;
		-i|--install-configs)	INSTALL_CONFIGS=1;;
		-p|--pjproject)		INSTALL_PJPROJECT=1;;
		-s|--system)		SETUP_SYSTEM=1;;
	esac
	shift
done

if [ ${SETUP_SYSTEM} -eq 1 ]; then
	setup_python
	setup_system
fi

if [ ${INSTALL_PJPROJECT} -eq 1 ]; then
	setup_pjproject
	build_pjproject
fi

if [ ${INSTALL_ASTERISK} -eq 1 ]; then
	build_asterisk	
fi

if [ ${INSTALL_CONFIGS} -eq 1 ]; then
	install_asterisk_configs
fi

echo "*** Installation/configuration script complete ***"

exit 0
