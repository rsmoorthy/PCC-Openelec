################################################################################
#      This file is part of OpenELEC - http://www.openelec.tv
#      Copyright (C) 2009-2014 Stephan Raue (stephan@openelec.tv)
#
#  OpenELEC is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  OpenELEC is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with OpenELEC.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

PKG_NAME="libgpgme11"
PKG_VERSION="1.2.0"
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL="http://mirrors.mit.edu/raspbian/raspbian/pool/main/g/gpgme1.0/libgpgme11_1.2.0-1.4+deb7u1_armhf.deb"
PKG_DEPENDS_TARGET="toolchain libpth libgpg-error0"
PKG_PRIORITY="optional"
PKG_SHORTDESC=""
PKG_LONGDESC=""

PKG_IS_ADDON="no"
PKG_AUTORECONF="no"

unpack() {
  NV_PKG="`echo $PKG_URL | sed 's%.*/\(.*\)$%\1%'`"
  [ -d $PKG_BUILD ] && rm -rf $PKG_BUILD && mkdir -p $PKG_BUILD

  echo $NV_PKG
  dpkg -x $SOURCES/$PKG_NAME/$NV_PKG $PKG_BUILD
  rm -rf $PKG_BUILD/usr/share
}

make_target() {
  :  # nothing
}

makeinstall_target() {
  mkdir -p $INSTALL/usr/lib
    cp -PR ./usr/* $INSTALL/usr/
}

post_makeinstall_target() {
  : #rm -rf $INSTALL/lib $INSTALL/sbin $INSTALL/bin $INSTALL/etc $INSTALL/usr
}

