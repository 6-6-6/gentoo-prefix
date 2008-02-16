# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/sqlite/sqlite-3.5.3.ebuild,v 1.8 2008/02/14 17:26:45 coldwind Exp $

EAPI="prefix 1"

inherit versionator alternatives eutils flag-o-matic libtool

DESCRIPTION="an SQL Database Engine in a C Library"
HOMEPAGE="http://www.sqlite.org/"
DOC_PV=$(replace_all_version_separators _)
SRC_URI="http://www.sqlite.org/${P}.tar.gz
	doc? ( http://www.sqlite.org/${PN}_docs_${DOC_PV}.zip )"

LICENSE="as-is"
SLOT="3"
KEYWORDS="~amd64-linux ~ia64-linux ~x86-linux ~ppc-macos ~x86-macos ~sparc-solaris ~x86-solaris"
IUSE="debug doc soundex tcl +threadsafe"
RESTRICT="!tcl? ( test )"

DEPEND="tcl? ( dev-lang/tcl )"
RDEPEND="${DEPEND}"

SOURCE="/usr/bin/lemon"
ALTERNATIVES="${SOURCE}-3 ${SOURCE}-0"

src_unpack() {
	# test
	if has test ${FEATURES}; then
		if ! has userpriv ${FEATURES}; then
			ewarn "The userpriv feature must be enabled to run tests."
			eerror "Testsuite will not be run."
		fi
		if ! use tcl; then
			ewarn "You must enable the tcl use flag if you want to run the test"
			ewarn "suite."
			eerror "Testsuite will not be run."
		fi
	fi

	unpack ${A}
	cd "${S}"

	epatch "${FILESDIR}"/sandbox-fix2.patch

	elibtoolize
	epunt_cxx
}

src_compile() {
	# not available via configure and requested in bug #143794
	use soundex && append-flags -DSQLITE_SOUNDEX=1

	econf ${myconf} \
		$(use_enable debug) \
		$(use_enable threadsafe) \
		$(use_enable threadsafe cross-thread-connections) \
		$(use_enable tcl)

	emake all || die "emake all failed"
}

src_test() {
	if use tcl ; then
		if has userpriv ${FEATURES} ; then
			if use debug ; then
				emake fulltest || die "some test failed"
			else
				emake test || die "some test failed"
			fi
		fi
	fi
}

src_install () {
	emake \
		DESTDIR="${D}" \
		TCLLIBDIR="${EPREFIX}/usr/$(get_libdir)" \
		install \
		|| die "emake install failed"

	newbin lemon lemon-${SLOT} || die

	dodoc README VERSION || die
	doman sqlite3.1 || die

	dohtml doc/*.html art/*.gif || die

	if use doc; then
		dohtml -r "${WORKDIR}"/${PN}-docs-${PV}/* || die
	fi
}
