# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-util/cscope/cscope-15.6-r2.ebuild,v 1.1 2007/09/21 08:46:34 ulm Exp $

EAPI="prefix"

inherit elisp-common eutils

DESCRIPTION="Interactively examine a C program"
HOMEPAGE="http://cscope.sourceforge.net/"
SRC_URI="mirror://sourceforge/cscope/${P}.tar.gz"

LICENSE="as-is GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ia64 ~ppc-macos ~sparc-solaris ~x86 ~x86-macos ~x86-solaris"
IUSE="emacs"

RDEPEND=">=sys-libs/ncurses-5.2"
DEPEND="${RDEPEND}
	sys-devel/flex
	sys-devel/bison
	>=sys-devel/autoconf-2.60
	emacs? ( virtual/emacs )"

SITEFILE=50${PN}-gentoo.el

src_unpack() {
	unpack ${A}

	# warn users of insecure web frontend, see bug #158831
	cd "${S}"
	epatch "${FILESDIR}/${PN}-158831-warning_webscope.patch"
	epatch "${FILESDIR}"/${P}-darwin.patch
}

src_compile() {
	STRIP="no"

	econf --with-ncurses="${EPREFIX}"/usr || die "econf failed"
	make clean || die "make clean failed"
	emake || die "emake failed"

	if use emacs ; then
		cd "${S}"/contrib/xcscope || die
		elisp-compile *.el || die "elisp-compile failed"
	fi
}

src_install() {
	einstall || die "einstall failed"
	dodoc AUTHORS ChangeLog NEWS README* TODO || die "dodoc failed"

	if use emacs ; then
		cd "${S}"/contrib/xcscope || die
		elisp-install ${PN} *.el *.elc || die "elisp-install failed"
		elisp-site-file-install "${FILESDIR}/${SITEFILE}" \
			|| die "elisp-site-file-install failed"
		dobin cscope-indexer || die "dobin failed"
	fi

	cd "${S}"/contrib/webcscope || die
	docinto webcscope
	dodoc INSTALL TODO cgi-lib.pl cscope hilite.c || die "dodoc failed"
	insinto /usr/share/doc/${PF}/webcscope/icons; doins icons/*.gif
}

pkg_postinst() {
	use emacs && elisp-site-regen
}

pkg_postrm() {
	use emacs && elisp-site-regen
}
