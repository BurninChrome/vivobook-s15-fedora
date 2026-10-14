# COPR "make srpm" entry point (SCM source type).
# https://docs.pagure.org/copr.copr/user_documentation.html#make-srpm
spec := packaging/copr/vivobook-s15-support.spec

srpm:
	dnf -y install git-core rpm-build
	mkdir -p $(outdir)
	git archive --prefix=vivobook-s15-fedora-$$(rpmspec -q --qf '%{version}\n' $(spec) | head -1)/ \
		-o $(outdir)/vivobook-s15-fedora-$$(rpmspec -q --qf '%{version}\n' $(spec) | head -1).tar.gz HEAD
	rpmbuild -bs $(spec) --define "_sourcedir $(outdir)" --define "_srcrpmdir $(outdir)"
