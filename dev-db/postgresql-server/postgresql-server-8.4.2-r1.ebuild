# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/postgresql-server/postgresql-server-8.4.2-r1.ebuild,v 1.7 2010/02/21 15:59:55 arfrever Exp $

EAPI="2"
PYTHON_DEPEND="python? 2"

# weird test failures.
RESTRICT="test"

WANT_AUTOCONF="latest"
WANT_AUTOMAKE="none"
inherit autotools eutils multilib python toolchain-funcs versionator prefix

KEYWORDS="~x86-freebsd ~amd64-linux ~x86-linux"

DESCRIPTION="PostgreSQL server"
HOMEPAGE="http://www.postgresql.org/"
SRC_URI="mirror://postgresql/source/v${PV}/postgresql-${PV}.tar.bz2"
LICENSE="POSTGRESQL"
SLOT="$(get_version_component_range 1-2)"
IUSE_LINGUAS="
	linguas_af linguas_cs linguas_de linguas_es linguas_fa linguas_fr
	linguas_hr linguas_hu linguas_it linguas_ko linguas_nb linguas_pl
	linguas_pt_BR linguas_ro linguas_ru linguas_sk linguas_sl linguas_sv
	linguas_tr linguas_zh_CN linguas_zh_TW"
IUSE="pg_legacytimestamp doc perl python selinux tcl uuid xml nls kernel_linux ${IUSE_LINGUAS}"

wanted_languages() {
	for u in ${IUSE_LINGUAS} ; do
		use $u && echo -n "${u#linguas_} "
	done
}

RDEPEND="~dev-db/postgresql-base-${PV}:${SLOT}[pg_legacytimestamp=]
	perl? ( >=dev-lang/perl-5.6.1-r2 )
	python? ( dev-python/egenix-mx-base )
	selinux? ( sec-policy/selinux-postgresql )
	tcl? ( >=dev-lang/tcl-8 )
	uuid? ( dev-libs/ossp-uuid )
	xml? ( dev-libs/libxml2 dev-libs/libxslt )"
DEPEND="${RDEPEND}
	sys-devel/flex
	xml? ( dev-util/pkgconfig )"
PDEPEND="doc? ( dev-db/postgresql-docs:${SLOT} )"

S="${WORKDIR}/postgresql-${PV}"

pkg_setup() {
	enewgroup postgres 70
	enewuser postgres 70 /bin/bash /var/lib/postgresql postgres

	if use python; then
		python_set_active_version 2
	fi
}

src_prepare() {
	epatch "${FILESDIR}/postgresql-${SLOT}-common.patch" \
		"${FILESDIR}/postgresql-${SLOT}-server.patch" \
		"${FILESDIR}/postgresql-8.3-prefix.patch"

	eprefixify "${S}/src/include/pg_config_manual.h"

	if hasq test ${FEATURES}; then
		sed -e "s|/no/such/location|${S}/src/test/regress/tmp_check/no/such/location|g" -i src/test/regress/{input,output}/tablespace.source
	else
		echo "all install:" > "${S}/src/test/regress/GNUmakefile"
	fi

	eautoconf
}

src_configure() {
	# TODO: test if PPC really cannot work with other CFLAGS settings
	# use ppc && CFLAGS="-pipe -fsigned-char"

	# eval is needed to get along with pg_config quotation of space-rich entities.
	eval econf "$(${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/bin/pg_config --configure)" \
		$(use_with perl) \
		$(use_with python) \
		$(use_with tcl) \
		$(use_with xml libxml) \
		$(use_with xml libxslt) \
		$(use_with uuid ossp-uuid) \
		--with-system-tzdata="${EPREFIX}/usr/share/zoneinfo" \
		--with-includes="${EPREFIX}/usr/include/postgresql-${SLOT}/" \
		--with-libraries="${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/$(get_libdir)" \
		"$(built_with_use ~dev-db/postgresql-base-${PV} nls && use_enable nls nls "$(wanted_languages)")"
}

src_compile() {
	local bd
	for bd in .  contrib $(use xml && echo contrib/xml2); do
		PATH="${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/bin:${PATH}" \
			emake -C $bd -j1 LD="$(tc-getLD) $(get_abi_LDFLAGS)" || die "emake in $bd failed"
	done
}

src_install() {
	if use perl ; then
		mv -f "${S}/src/pl/plperl/GNUmakefile" "${S}/src/pl/plperl/GNUmakefile_orig"
		sed -e "s:\$(DESTDIR)\$(plperl_installdir):\$(plperl_installdir):" \
			"${S}/src/pl/plperl/GNUmakefile_orig" > "${S}/src/pl/plperl/GNUmakefile"
	fi

	for bd in . contrib $(use xml && echo contrib/xml2) ; do
		PATH="${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/bin:${PATH}" \
			emake install -C $bd -j1 DESTDIR="${D}" || die "emake install in $bd failed"
	done

	rm -rf "${ED}/usr/share/postgresql-${SLOT}/man/man7/" "${ED}/usr/share/doc/postgresql-${SLOT}/html"
	rm "${ED}"/usr/share/postgresql-${SLOT}/man/man1/{clusterdb,create{db,lang,user},drop{db,lang,user},ecpg,pg_{config,dump,dumpall,restore},psql,reindexdb,vacuumdb}.1

	dodoc README HISTORY doc/{README.*,TODO,bug.template}

	dodir /etc/eselect/postgresql/slots/${SLOT}
	cat >"${ED}/etc/eselect/postgresql/slots/${SLOT}/service" <<-__EOF__
		postgres_ebuilds="\${postgres_ebuilds} ${PF}"
		postgres_service="postgresql-${SLOT}"
	__EOF__

	newinitd "${FILESDIR}/postgresql.init-${SLOT}" postgresql-${SLOT} || die "Inserting init.d-file failed"
	newconfd "${FILESDIR}/postgresql.conf-${SLOT}" postgresql-${SLOT} || die "Inserting conf.d-file failed"

	keepdir /var/run/postgresql
	fperms 0770 /var/run/postgresql
	fowners postgres:postgres /var/run/postgresql
}

pkg_postinst() {
	eselect postgresql update
	[[ "$(eselect postgresql show)" = "(none)" ]] && eselect postgresql set ${SLOT}
	[[ "$(eselect postgresql show-service)" = "(none)" ]] && eselect postgresql set-service ${SLOT}

	ewarn "Please note that the standard location of the socket has changed from /tmp"
	ewarn "to /var/run/postgresql and you have to be in the 'postgres' group to access"
	ewarn "the socket."
	ewarn "This can break applications which have the standard location hard-coded."
	ewarn "If such an application links against the libpq, please re-emerge it,"
	ewarn "if that doesn't help or the application accesses the socket without using libpq,"
	ewarn "please file a bug-report."
	ewarn "You can set PGOPTS='-k /tmp' in /etc/conf.d/postgresql-${SLOT} to restore the original location."

	elog "Execute the following command to setup the initial database environment:"
	elog
	elog "emerge --config =${CATEGORY}/${PF}"
	elog
	elog "The autovacuum function, which was in contrib, has been moved to the main"
	elog "PostgreSQL functions starting with 8.1 and starting with 8.4 is now"
	elog "enabled by default. You can disable it in the cluster's postgresql.conf."
	elog
	elog "The timestamp format is 64bit integers now. If you upgrade from older databases"
	elog "this may force you to either do a dump and reload or enable pg_legacytimestamp"
	elog "until you find time to do so. If the database can't start please try enabling"
	elog "pg_legacytimestamp and rebuild."
}

pkg_postrm() {
	eselect postgresql update
}

pkg_config() {
	[[ -z "${PGDATA}" ]] && PGDATA="${EPREFIX}/var/lib/postgresql/${SLOT}/data"

	einfo "You can pass options to initdb by setting the PG_INITDB_OPTS variable."
	einfo "More information can be found here:"
	einfo "    http://www.postgresql.org/docs/${SLOT}/static/creating-cluster.html"
	einfo "    http://www.postgresql.org/docs/${SLOT}/static/app-initdb.html"
	einfo "Simply add the options you would have added to initdb to the PG_INITDB_OPTS variable."
	einfo
	einfo "You can change the directory where the database cluster is being created by setting"
	einfo "the PGDATA variable."
	einfo
	einfo "PG_INITDB_OPTS is currently set to:"
	einfo "    \"${PG_INITDB_OPTS}\""
	einfo "and the database cluster will be created in:"
	einfo "    \"${PGDATA}\""
	einfo "Are you ready to continue? (Y/n)"
	read answer
	[ -z $answer ] && answer=Y
	[ "$answer" == "Y" ] || [ "$answer" == "y" ] || die "aborted"

	if [[ -f "${PGDATA}/PG_VERSION" ]] ; then
		eerror "The given directory \"${PGDATA}\" already contains a database cluster."
		die "cluster already exists"
	fi

	[ -z "${PG_MAX_CONNECTIONS}" ] && PG_MAX_CONNECTIONS="128"
	einfo "Checking system parameters..."

	if ! use kernel_linux ; then
		SKIP_SYSTEM_TESTS=yes
		einfo "  Tests not supported on this OS (yet)"
	fi

	if [ -z ${SKIP_SYSTEM_TESTS} ] ; then
		einfo "Checking whether your system supports at least ${PG_MAX_CONNECTIONS} connections..."

		local SEMMSL=$(sysctl -n kernel.sem | cut -f1)
		local SEMMNS=$(sysctl -n kernel.sem | cut -f2)
		local SEMMNI=$(sysctl -n kernel.sem | cut -f4)
		local SHMMAX=$(sysctl -n kernel.shmmax)

		local SEMMSL_MIN=17
		local SEMMNS_MIN=$(( ( ${PG_MAX_CONNECTIONS}/16 ) * 17 ))
		local SEMMNI_MIN=$(( ( ${PG_MAX_CONNECTIONS}+15 ) / 16 ))
		local SHMMAX_MIN=$(( 500000 + ( 30600 * ${PG_MAX_CONNECTIONS} ) ))

		for p in SEMMSL SEMMNS SEMMNI SHMMAX ; do
			if [ $(eval echo \$$p) -lt $(eval echo \$${p}_MIN) ] ; then
				eerror "The value for ${p} $(eval echo \$$p) is below the recommended value $(eval echo \$${p}_MIN)"
				eerror "You have now several options:"
				eerror "  - Change the mentioned system parameter"
				eerror "  - Lower the number of max.connections by setting PG_MAX_CONNECTIONS to a value lower than ${PG_MAX_CONNECTIONS}"
				eerror "  - Set SKIP_SYSTEM_TESTS in case you want to ignore this test completely"
				eerror "More information can be found here:"
				eerror "  http://www.postgresql.org/docs/${SLOT}/static/kernel-resources.html"
				die "system test failed"
			fi
		done
		einfo "Passed."
	else
		einfo "Skipped."
	fi

	einfo "Creating the data directory ..."
	mkdir -p "${PGDATA}"
	chown -Rf postgres:postgres "${PGDATA}"
	chmod 0700 "${PGDATA}"

	einfo "Initializing the database ..."

	su postgres -c "${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/bin/initdb --pgdata \"${PGDATA}\" ${PG_INITDB_OPTS}"

	einfo
	einfo "You can use the '${EROOT}/etc/init.d/postgresql-${SLOT}' script to run PostgreSQL instead of 'pg_ctl'."
	einfo

	if [ "${PGDATA}" != "${EPREFIX}/var/lib/postgresql/${SLOT}/data" ] ; then
		ewarn "You didn't install the database cluster in the standard location, please make sure that you set"
		ewarn "PGDATA=\"${PGDATA}\" in the appropriate conf.d file (probably /etc/conf.d/postgresql-${SLOT})"
	fi
}

src_test() {
	einfo ">>> Test phase [check]: ${CATEGORY}/${PF}"
	PATH="${EPREFIX}/usr/$(get_libdir)/postgresql-${SLOT}/bin:${PATH}" \
		emake -j1 check  || die "Make check failed. See above for details."

	einfo "Yes, there are other tests which could be run."
	einfo "... and no, we don't plan to add/support them."
	einfo "For now, the main regressions tests will suffice."
	einfo "If you think other tests are necessary, please submit a"
	einfo "bug including a patch for this ebuild to enable them."
}
