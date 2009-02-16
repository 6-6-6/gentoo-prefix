# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/mail-filter/procmail/procmail-3.22-r10.ebuild,v 1.7 2009/02/15 13:49:23 ranger Exp $

EAPI="prefix"

inherit eutils flag-o-matic toolchain-funcs

DESCRIPTION="Mail delivery agent/filter"
HOMEPAGE="http://www.procmail.org/"
SRC_URI="http://www.procmail.org/${P}.tar.gz"

LICENSE="|| ( Artistic GPL-2 )"
SLOT="0"
KEYWORDS="~amd64-linux ~x86-linux ~ppc-macos ~x86-macos ~sparc-solaris ~x86-solaris"
IUSE="mbox selinux"

DEPEND="virtual/libc virtual/mta"
RDEPEND="virtual/libc
	selinux? ( sec-policy/selinux-procmail )"
PROVIDE="virtual/mda"

src_unpack() {
	unpack ${A}
	cd "${S}"

	# disable flock, using both fcntl and flock style locking
	# doesn't work with NFS with 2.6.17+ kernels, bug #156493

	sed -e "s:/\*#define NO_flock_LOCK:#define NO_flock_LOCK:" \
		-i config.h || die "sed failed"

	if ! use mbox ; then
		echo "# Use maildir-style mailbox in user's home directory" > "${S}"/procmailrc
		echo 'DEFAULT=$HOME/.maildir/' >> "${S}"/procmailrc
		cd "${S}"
		epatch "${FILESDIR}/gentoo-maildir3.diff"
	else
		echo '# Use mbox-style mailbox in /var/spool/mail' > "${S}"/procmailrc
		echo 'DEFAULT=${EPREFIX}/var/spool/mail/$LOGNAME' >> "${S}"/procmailrc
	fi

	# Do not use lazy bindings on lockfile and procmail
	if [[ ${CHOST} != *-darwin* ]]; then
		epatch "${FILESDIR}/${PN}-lazy-bindings.diff"
	fi

	# Fix for bug #102340
	epatch "${FILESDIR}/${PN}-comsat-segfault.diff"

	# Fix for bug #119890
	epatch "${FILESDIR}/${PN}-maxprocs-fix.diff"

	# Prefixify config.h
	epatch "${FILESDIR}"/${PN}-prefix.patch
	eprefixify config.h Makefile src/autoconf src/recommend.c

	# Fix for bug #200006
	epatch "${FILESDIR}/${PN}-pipealloc.diff"
}

src_compile() {
	# -finline-functions (implied by -O3) leaves strstr() in an infinite loop.
	# To work around this, we append -fno-inline-functions to CFLAGS
	append-flags -fno-inline-functions

	sed -e "s:CFLAGS0 = -O:CFLAGS0 = ${CFLAGS}:" \
		-e "s:LDFLAGS0= -s:LDFLAGS0 = ${LDFLAGS}:" \
		-e "s:LOCKINGTEST=__defaults__:#LOCKINGTEST=__defaults__:" \
		-e "s:#LOCKINGTEST=/tmp:LOCKINGTEST=/tmp:" \
		-i Makefile || die "sed failed"

	emake CC="$(tc-getCC)" || die
}

src_install() {
	cd "${S}"/new
	insinto /usr/bin
	insopts -m 6755
	doins procmail || die

	doins lockfile || die
	fowners root:mail /usr/bin/lockfile
	fperms 2775 /usr/bin/lockfile

	dobin formail mailstat || die
	insopts -m 0644

	doman *.1 *.5

	cd "${S}"
	dodoc FAQ FEATURES HISTORY INSTALL KNOWN_BUGS README

	insinto /etc
	doins procmailrc || die

	docinto examples
	dodoc examples/*
}

pkg_postinst() {
	if ! use mbox ; then
		elog "Starting with mail-filter/procmail-3.22-r9 you'll need to ensure"
		elog "that you configure a mail storage  location using DEFAULT in"
		elog "/etc/procmailrc, for example:"
		elog "\tDEFAULT=\$HOME/.maildir/"
	fi
}
