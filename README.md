sipit-configs
=============

Asterisk configuration for SIPit

# CAUTION

Nothing in these scripts is "safe". They will overwrite your system, they will install stuff, they will open you up to the world. Do not, under any circumstance, use these scripts as-is. They are toxic. They will kill you.

# Overview

These scripts set up the Digium machines for SIPit. They generally will:
1. Install (most) packages needed for pjproject and Asterisk. You will need git to get the scripts initially, and you probably should do a full system update before using the scripts to do any further installs.
2. Install pjproject.
3. Install Asterisk.
4. Drop in a bunch of config files for Asterisk, a Digium phone, and some other goodies.

# Usage

Options include:
* -a -- perform a full install of Asterisk
* -qa -- just do a quick build/install of Asterisk
* -p -- perform a full instal of PJPROJECT
* -s -- install the system libraries
* -i -- install the configuration files for Asterisk and the Digium phones

# PJPROJECT

The script for pjproject will configure it to use IPv6. It assumes that we only care about having external SRTP; the rest is left untouched.

# Asterisk

Asterisk is built in `-dev-mode`, with the usual slew of handy compilation options. It is also built with external MWI, so that an ARI script can be used to control MWI programmatically.
