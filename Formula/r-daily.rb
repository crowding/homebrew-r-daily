class RDaily < Formula
  desc "Software environment for statistical computing"
  homepage "https://www.r-project.org/"
  license "GPL-2.0-or-later"
  head "ftp://stat.ethz.ch/Software/R/R-devel.tar.gz"

  livecheck do
    url "https://stat.ethz.ch/R/daily/"
    regex(%r{R-devel.tar.gz<\/a>\s*(\d+-[a-z0-9]+-\d+ *\d+:\d+)}i)
  end
  
  option "with-debug", "build with debugging symbols"
  option "with-install-source", "install source to prefix for debugging"
  option "without-recommended-packages", "skip building recommended packages"
  
  depends_on "pkg-config" => :build
  depends_on "gcc" # for gfortran
  depends_on "gettext"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "pcre2"
  depends_on "readline"
  depends_on "xz"
  depends_on "openblas" => :optional
  depends_on :x11 => :optional
  depends_on "cairo" => :optional
  depends_on :java => :optional
  depends_on "tcl-tk" => :optional
  depends_on "texinfo" => :optional
  depends_on "texi2html" => :optional
  conflicts_with "r", because: "both install `r` binaries"
  conflicts_with cask: "r", because: "both install `r` binaries"

  # needed to preserve executable permissions on files without shebangs
  skip_clean "lib/R/bin", "lib/R/doc"

  def install
    # Fix dyld: lazy symbol binding failed: Symbol not found: _clock_gettime
    if MacOS.version == "10.11" && MacOS::Xcode.installed? &&
        MacOS::Xcode.version >= "8.0"
      ENV["ac_cv_have_decl_clock_gettime"] = "no"
    end

    args = [
            "--prefix=#{prefix}",
            "--enable-memory-profiling",
            "--with-aqua",
            "--with-lapack",
            "--enable-R-shlib",
            "SED=/usr/bin/sed", # don't remember Homebrew's sed shim
           ]

    if  "recommended-packages"
      args << "--without-recommended-packages"
    else
      args << "--with-recommended-packages"      
    end

    if build.with? "openblas"
      args << "--with-blas=-L#{Formula["openblas"].opt_lib} -lopenblas"
      ENV.append "LDFLAGS", "-L#{Formula["openblas"].opt_lib}"
    else
      args << "--with-blas=-framework Accelerate"
      ENV.append_to_cflags "-D__ACCELERATE__" if ENV.compiler != :clang
    end

    if build.with? "x11"
      args << "--with-x"
    else
      args << "--without-x"
    end

    if build.with? "cairo"
      args << "--with-cairo"
    else
      args << "--without-cairo"
    end

    if build.with? "tcl-tk"
      args << "--with-tcltk"
    else
      args << "--without-tcltk"
    end

    if build.with? "java"
      args << "--enable-java"
    else
      args << "--disable-java"
    end

    if build.with? "texinfo"
      #TODO build Info manuals
    end

    if build.with? "texi2html"
      #TODO build html manuals
    end
    
    if build.with? "debug"
      ENV.append "CFLAGS", "-g -fPIC"
      ENV.append "FFLAGS", "-g -fPIC"
      ENV.append "CXXFLAGS", "-g -fPIC"
      ENV.append "FCFLAGS", "-g -fPIC"
    end

    # Help CRAN packages find gettext and readline
    ["gettext", "readline"].each do |f|
      ENV.append "CPPFLAGS", "-I#{Formula[f].opt_include}"
      ENV.append "LDFLAGS", "-L#{Formula[f].opt_lib}"
    end

    system "./configure", *args
    system "make"
    ENV.deparallelize do
      system "make", "install"
    end

    cd "src/nmath/standalone" do
      system "make"
      ENV.deparallelize do
        system "make", "install"
      end
    end

    r_home = lib/"R"

    if build.with? "install-source"
      #TODO
    end
    
    # make Homebrew packages discoverable for R CMD INSTALL
    inreplace r_home/"etc/Makeconf" do |s|
      s.gsub!(/^CPPFLAGS =.*/, "\\0 -I#{HOMEBREW_PREFIX}/include")
      s.gsub!(/^LDFLAGS =.*/, "\\0 -L#{HOMEBREW_PREFIX}/lib")
      s.gsub!(/.LDFLAGS =.*/, "\\0 $(LDFLAGS)")
    end

    include.install_symlink Dir[r_home/"include/*"]
    lib.install_symlink Dir[r_home/"lib/*"]

    # avoid triggering mandatory rebuilds of r when gcc is upgraded
    inreplace lib/"R/etc/Makeconf", Formula["gcc"].prefix.realpath,
    Formula["gcc"].opt_prefix
  end

  def post_install
    short_version =
      `#{bin}/Rscript -e 'cat(as.character(getRversion()[1,1:2]))'`.strip
    site_library = HOMEBREW_PREFIX/"lib/R/#{short_version}/site-library"
    site_library.mkpath
    ln_s site_library, lib/"R/site-library"
  end

  test do
    assert_equal "[1] 2", shell_output("#{bin}/Rscript -e 'print(1+1)'").chomp
    assert_equal ".dylib", shell_output("#{bin}/R CMD config DYLIB_EXT").chomp

    system bin/"Rscript", "-e", "install.packages('gss', '.', 'https://cloud.r-project.org')"
    assert_predicate testpath/"gss/libs/gss.so", :exist?,
    "Failed to install gss package"
  end
end
