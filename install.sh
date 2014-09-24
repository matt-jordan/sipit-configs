#!/bin/bash

SRC_ROOT=~/src
PJPROJECT_SRC_DIR=pjproject
ASTERISK_SRC_DIR=asterisk-13.0.0-beta2

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

INSTALL_PJPROJECT=0
INSTALL_ASTERISK=0
INSTALL_CONFIGS=0

while [ "$#" -gt "0" ]; do
	case ${1} in
		-a|--asterisk)		INSTALL_ASTERISK=1;;
		-i|--install-configs)	INSTALL_CONFIGS=1;;
		-p|--pjproject)		INSTALL_PJPROJECT=1;;
	esac
	shift
done

if [ ${INSTALL_PJPROJECT} -eq 1 ]; then
	setup_pjproject
	build_pjproject
fi

if [ ${INSTALL_ASTERISK} -eq 1 ]; then
	echo "Not right now"
fi

if [ ${INSTALL_CONFIGS} -eq 1 ]; then
	install_asterisk_configs
fi

echo "*** Installation/configuration script complete ***"

exit 0
