# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/gdb/gdb-6.7.ebuild,v 1.1 2007/10/10 20:14:54 vapier Exp $

EAPI="prefix"

inherit flag-o-matic eutils

export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY/cross-} != ${CATEGORY} ]] ; then
		export CTARGET=${CATEGORY/cross-}
	fi
fi

PATCH_VER="1.0"
DESCRIPTION="GNU debugger"
HOMEPAGE="http://sources.redhat.com/gdb/"
SRC_URI="http://ftp.gnu.org/gnu/gdb/${P}.tar.bz2
	ftp://sources.redhat.com/pub/gdb/releases/${P}.tar.bz2
	mirror://gentoo/${P}-patches-${PATCH_VER}.tar.bz2"

LICENSE="GPL-2 LGPL-2"
[[ ${CTARGET} != ${CHOST} ]] \
	&& SLOT="${CTARGET}" \
	|| SLOT="0"
KEYWORDS="~amd64-linux ~x86-linux ~sparc-solaris ~sparc64-solaris ~x86-solaris"
IUSE="nls test vanilla"

RDEPEND=">=sys-libs/ncurses-5.2-r2"
DEPEND="${RDEPEND}
	test? ( dev-util/dejagnu )
	nls? ( sys-devel/gettext )"

src_unpack() {
	unpack ${A}
	cd "${S}"
	use vanilla || EPATCH_SUFFIX="patch" epatch "${WORKDIR}"/patch
	strip-linguas -u bfd/po opcodes/po
}

src_compile() {
	replace-flags -O? -O2
	econf \
		--disable-werror \
		$(use_enable nls) \
		|| die
	emake || die
}

src_test() {
	make check || ewarn "tests failed"
}

src_install() {
	emake \
		DESTDIR="${D}" \
		libdir=/nukeme/pretty/pretty/please includedir=/nukeme/pretty/pretty/please \
		install || die
	rm -r "${D}"/nukeme || die

	# Don't install docs when building a cross-gdb
	if [[ ${CTARGET} != ${CHOST} ]] ; then
		rm -r "${ED}"/usr/share
		return 0
	fi

	dodoc README
	docinto gdb
	dodoc gdb/CONTRIBUTE gdb/README gdb/MAINTAINERS \
		gdb/NEWS gdb/ChangeLog gdb/PROBLEMS
	docinto sim
	dodoc sim/ChangeLog sim/MAINTAINERS sim/README-HACKING

	dodoc "${WORKDIR}"/extra/gdbinit.sample

	# Remove shared info pages
	rm -f "${ED}"/usr/share/info/{annotate,bfd,configure,standards}.info*
}

pkg_postinst() {
	# portage sucks and doesnt unmerge files in /etc
	rm -vf "${EROOT}"/etc/skel/.gdbinit
}
