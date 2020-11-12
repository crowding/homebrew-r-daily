# R daily

This is a [Homebrew][] tap which will build and install [R][] from the daily development branch snapshot.
[homebrew]: https://brew.sh/
[r]: https://www.r-project.org/

    brew tap crowding/r-daily
    brew install crowding/r-daily/r-daily --HEAD

    brew install crowding/r-daily/r-daily \
        --HEAD \
        --with-recommended-packages --with-debug --with-install-source \ 
        --with-cairo --with-java --with-openblas --with-x \
        --with-texinfo --with-texi2html

    brew install crowding/r-daily/r-daily --HEAD --with-cairo --with-java --with-openblas --with-x --with-recommended-packages --with-debug --with-install-source --with-texinfo --with-texi2html
