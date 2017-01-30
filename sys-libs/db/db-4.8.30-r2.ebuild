# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-libs/db/db-4.8.30-r2.ebuild,v 1.12 2015/03/20 14:41:50 jlec Exp $

EAPI=5

inherit eutils db flag-o-matic java-pkg-opt-2 autotools multilib multilib-minimal toolchain-funcs

#Number of official patches
#PATCHNO=`echo ${PV}|sed -e "s,\(.*_p\)\([0-9]*\),\2,"`
PATCHNO=${PV/*.*.*_p}
if [[ ${PATCHNO} == "${PV}" ]] ; then
	MY_PV=${PV}
	MY_P=${P}
	PATCHNO=0
else
	MY_PV=${PV/_p${PATCHNO}}
	MY_P=${PN}-${MY_PV}
fi

S="${WORKDIR}/${MY_P}/build_unix"
DESCRIPTION="Oracle Berkeley DB"
HOMEPAGE="http://www.oracle.com/technology/software/products/berkeley-db/index.html"
SRC_URI="http://download.oracle.com/berkeley-db/${MY_P}.tar.gz"
for (( i=1 ; i<=${PATCHNO} ; i++ )) ; do
	export SRC_URI="${SRC_URI} http://www.oracle.com/technology/products/berkeley-db/db/update/${MY_PV}/patch.${MY_PV}.${i}"
done

LICENSE="Sleepycat"
SLOT="4.8"
KEYWORDS="~ppc-aix ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="doc java cxx tcl test"

REQUIRED_USE="test? ( tcl )"

# the entire testsuite needs the TCL functionality
DEPEND="tcl? ( >=dev-lang/tcl-8.5.15-r1:0=[${MULTILIB_USEDEP}] )
	test? ( >=dev-lang/tcl-8.5.15-r1:0=[${MULTILIB_USEDEP}] )
	java? ( >=virtual/jdk-1.5 )
	|| ( sys-devel/binutils-apple
		 sys-devel/native-cctools
		 >=sys-devel/binutils-2.16.1
	)"
RDEPEND="tcl? ( >=dev-lang/tcl-8.5.15-r1:0=[${MULTILIB_USEDEP}] )
	java? ( >=virtual/jre-1.5 )
	abi_x86_32? (
		!<=app-emulation/emul-linux-x86-baselibs-20140508-r2
		!app-emulation/emul-linux-x86-baselibs[-abi_x86_32(-)]
	)"

src_prepare() {
	cd "${WORKDIR}"/"${MY_P}" || die
	for (( i=1 ; i<=${PATCHNO} ; i++ ))
	do
		epatch "${DISTDIR}"/patch."${MY_PV}"."${i}"
	done
	epatch "${FILESDIR}"/${PN}-4.8-libtool.patch
	epatch "${FILESDIR}"/${PN}-4.8.24-java-manifest-location.patch
	epatch "${FILESDIR}"/${PN}-4.8.30-rename-atomic-compare-exchange.patch

	epatch "${FILESDIR}"/${PN}-4.6-interix.patch

	pushd dist > /dev/null || die "Cannot cd to 'dist'"

	# need to upgrade local copy of libtool.m4
	# for correct shared libs on aix (#213277).
	local g="" ; type -P glibtoolize > /dev/null && g=g
	local _ltpath="$(dirname "$(dirname "$(type -P ${g}libtoolize)")")"
	cp -f "${_ltpath}"/share/aclocal/libtool.m4 aclocal/libtool.m4 \
		|| die "cannot update libtool.ac from libtool.m4"

	# need to upgrade ltmain.sh for AIX,
	# but aclocal.m4 is created in ./s_config,
	# and elibtoolize does not work when there is no aclocal.m4, so:
	${g}libtoolize --force --copy || die "${g}libtoolize failed."
	# now let shipped script do the autoconf stuff, it really knows best.
	#see code below
	#sh ./s_config || die "Cannot execute ./s_config"

	# use the includes from the prefix
	epatch "${FILESDIR}"/${PN}-4.6-jni-check-prefix-first.patch
	epatch "${FILESDIR}"/${PN}-4.3-listen-to-java-options.patch

	popd > /dev/null

	sed -e "/^DB_RELEASE_DATE=/s/%B %e, %Y/%Y-%m-%d/" -i dist/RELEASE \
		|| die

	# Include the SLOT for Java JAR files
	# This supersedes the unused jarlocation patches.
	sed -r -i \
		-e '/jarfile=.*\.jar$/s,(.jar$),-$(LIBVERSION)\1,g' \
		"${S}"/../dist/Makefile.in || die

	cd "${S}"/../dist || die
	rm -f aclocal/libtool.m4
	sed -i \
		-e '/AC_PROG_LIBTOOL$/aLT_OUTPUT' \
		configure.ac || die
	sed -i \
		-e '/^AC_PATH_TOOL/s/ sh, none/ bash, none/' \
		aclocal/programs.m4 || die
	AT_M4DIR="aclocal aclocal_java" eautoreconf
	# Upstream sucks - they do autoconf and THEN replace the version variables.
	. ./RELEASE
	sed -i \
		-e "s/__EDIT_DB_VERSION_MAJOR__/$DB_VERSION_MAJOR/g" \
		-e "s/__EDIT_DB_VERSION_MINOR__/$DB_VERSION_MINOR/g" \
		-e "s/__EDIT_DB_VERSION_PATCH__/$DB_VERSION_PATCH/g" \
		-e "s/__EDIT_DB_VERSION_STRING__/$DB_VERSION_STRING/g" \
		-e "s/__EDIT_DB_VERSION_UNIQUE_NAME__/$DB_VERSION_UNIQUE_NAME/g" \
		-e "s/__EDIT_DB_VERSION__/$DB_VERSION/g" configure || die
}

src_configure() {
	# Add linker versions to the symbols. Easier to do, and safer than header file
	# mumbo jumbo.
	if [[ ${CHOST} == *-linux-gnu || ${CHOST} == *-solaris* ]] ; then
		# we hopefully use a GNU binutils linker in this case
		append-ldflags -Wl,--default-symver
	fi

	multilib-minimal_src_configure
}

multilib_src_configure() {
	local myconf=()

	tc-ld-disable-gold #470634

	# compilation with -O0 fails on amd64, see bug #171231
	if [[ ${ABI} == amd64 ]]; then
		local CFLAGS=${CFLAGS} CXXFLAGS=${CXXFLAGS}
		replace-flags -O0 -O2
		is-flagq -O[s123] || append-flags -O2
	fi

	# use `set` here since the java opts will contain whitespace
	if multilib_is_native_abi && use java ; then
		myconf+=(
			--with-java-prefix="${JAVA_HOME}"
			--with-javac-flags="$(java-pkg_javac-args)"
		)
	fi

	tc-export CC CXX # would use CC=xlc_r on aix if not set

	# Bug #270851: test needs TCL support
	if use tcl || use test ; then
		myconf+=(
			--enable-tcl
			--with-tcl=${EPREFIX}/usr/$(get_libdir)
		)
	else
		myconf+=(--disable-tcl )
	fi

	ECONF_SOURCE="${S}"/../dist \
	STRIP="true" \
	econf \
		--enable-compat185 \
		--enable-o_direct \
		--without-uniquename \
		$([[ ${ABI} == arm ]] && echo --with-mutex=ARM/gcc-assembly) \
		$([[ ${ABI} == amd64 ]] && echo --with-mutex=x86/gcc-assembly) \
		$(use_enable cxx) \
		$(use_enable cxx stl) \
		$(multilib_native_use_enable java) \
		"${myconf[@]}" \
		$(use_enable test)
}

multilib_src_test() {
	multilib_is_native_abi || return

	S=${BUILD_DIR} db_src_test
}

multilib_src_install() {
	emake install DESTDIR="${D}"

	db_src_install_headerslot

	db_src_install_usrlibcleanup

	if multilib_is_native_abi && use java; then
		java-pkg_regso "${ED}"/usr/"$(get_libdir)"/libdb_java*.so
		java-pkg_dojar "${ED}"/usr/"$(get_libdir)"/*.jar
		rm -f "${ED}"/usr/"$(get_libdir)"/*.jar
	fi
}

multilib_src_install_all() {
	db_src_install_usrbinslot

	db_src_install_doc

	dodir /usr/sbin
	# This file is not always built, and no longer exists as of db-4.8
	if [[ -f "${ED}"/usr/bin/berkeley_db_svc ]] ; then
		mv "${ED}"/usr/bin/berkeley_db_svc \
			"${ED}"/usr/sbin/berkeley_db"${SLOT/./}"_svc || die
	fi
}

pkg_postinst() {
	multilib_foreach_abi db_fix_so
}

pkg_postrm() {
	multilib_foreach_abi db_fix_so
}
