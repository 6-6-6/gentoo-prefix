# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-perl/Text-WikiFormat/Text-WikiFormat-0.78.ebuild,v 1.8 2007/07/10 23:33:26 mr_bones_ Exp $

EAPI="prefix"

inherit perl-module

DESCRIPTION="Translate Wiki formatted text into other formats"
SRC_URI="mirror://cpan/authors/id/C/CH/CHROMATIC/${P}.tar.gz"
HOMEPAGE="http://search.cpan.org/~chromatic/${P}/"

SLOT="0"
LICENSE="|| ( Artistic GPL-2 )"
KEYWORDS="~amd64-linux ~x86-linux ~ppc-macos ~sparc-solaris"

DEPEND="dev-perl/URI
	virtual/perl-Scalar-List-Utils
		>=dev-perl/module-build-0.28
	dev-lang/perl"
IUSE=""

SRC_TEST="do"
