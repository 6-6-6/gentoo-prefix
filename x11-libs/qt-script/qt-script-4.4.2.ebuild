# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/x11-libs/qt-script/qt-script-4.4.2.ebuild,v 1.8 2009/02/06 16:20:35 armin76 Exp $

EAPI="prefix 1"
inherit qt4-build

DESCRIPTION="The ECMAScript module for the Qt toolkit"
HOMEPAGE="http://www.trolltech.com/"

LICENSE="|| ( GPL-3 GPL-2 )"
SLOT="4"
KEYWORDS="~amd64-linux ~x86-linux ~ppc-macos ~x86-macos"
IUSE=""

DEPEND="~x11-libs/qt-core-${PV}
	!<=x11-libs/qt-4.4.0_alpha:${SLOT}"
RDEPEND="${DEPEND}"

QT4_TARGET_DIRECTORIES="src/script/"
QT4_EXTRACT_DIRECTORIES="${QT4_TARGET_DIRECTORIES}
include/Qt/
include/QtCore/
include/QtScript/
src/corelib/global/
src/corelib/kernel/
src/corelib/plugin/"

src_compile() {
	local myconf
	myconf="${myconf} -no-xkb -no-tablet -no-fontconfig -no-xrender -no-xrandr
		-no-xfixes -no-xcursor -no-xinerama -no-xshape -no-sm -no-opengl
		-no-nas-sound -no-dbus -iconv -no-cups -no-nis -no-gif -no-libpng
		-no-libmng -no-libjpeg -no-openssl -system-zlib -no-webkit -no-phonon
		-no-qt3support -no-xmlpatterns -no-freetype -no-libtiff -no-accessibility
		-no-fontconfig -no-glib -no-opengl -no-svg"

	qt4-build_src_compile
}
