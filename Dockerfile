FROM concourse/buildroot:git

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh
