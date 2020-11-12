# R daily

This is a [Homebrew][] tap which will build and install [R][] from the daily development branch snapshot.
[homebrew]: https://brew.sh/
[r]: https://www.r-project.org/

    brew tap crowding/r-daily
    brew install crowding/r-daily/r-daily --HEAD --with-cairo --with-debug --with-java --with-x

    brew install crowding/r/r \
        --with-recommended-packages --with-debug --with-install-source \ 
        --with-cairo --with-java --with-openblas --with-x \ #
        --with-texinfo --with-texi2html # build docs in Info, HTML, or pdf
