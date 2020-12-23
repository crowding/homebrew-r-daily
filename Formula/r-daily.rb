class TexRequirement < Requirement
  extend T::Sig
  cask "mactex"
  fatal true

  satisfy(:build_env => false) { which("pdflatex") && which("pdftex") && which("tex") }

  sig { returns(String) }
  def display_s
    "pdflatex"
  end

  def message; <<~EOS
    Binaries 'pdflatex', 'pdftex' and 'tex' are required; install them via one of:
      brew install --cask mactex
      brew install --cask mactex-no-gui
    Or whatever your preferred TeX distribution is.
    EOS
  end
end

class RDaily < Formula
  desc "Software environment for statistical computing"
  homepage "https://www.r-project.org/"
  license "GPL-2.0-or-later"
  head "ftp://stat.ethz.ch/Software/R/R-devel.tar.gz"

  livecheck do
    url "https://stat.ethz.ch/R/daily/"
    regex(%r{R-devel.tar.gz<\/a>\s*(\d+-[a-z0-9]+-\d+ *\d+:\d+)}i)
  end
  
  option "without-debug", "build without debugging symbols"
  #option "without-install-source", "install source to prefix for debugging"
  option "without-recommended-packages", "skip building recommended packages"
  option "without-tcl-tk", "Do not include Tcl/Tk"
  option "without-manuals", "Skip building pdf/info manuals"
  
  depends_on "pkg-config" => :build
  depends_on "gcc" # for gfortran
  depends_on "gettext"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "pcre2"
  depends_on "readline"
  depends_on "xz"
  depends_on TexRequirement
  depends_on "texinfo"
  depends_on "texi2html"
  depends_on "openblas" => :recommended
  depends_on "libxt" => :recommended
  depends_on "cairo" => :recommended
  depends_on "openjdk@11" => :recommended
  depends_on "openmotif" => :recommended
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

    if build.with? "recommended-packages"
      args << "--with-recommended-packages"
    else
      args << "--without-recommended-packages"      
    end

    if build.with? "openblas"
      #   For compilers to find openblas you may need to set:
      #   export LDFLAGS="-L/usr/local/opt/openblas/lib"
      # export CPPFLAGS="-I/usr/local/opt/openblas/include"

      # For pkg-config to find openblas you may need to set:
      #   export PKG_CONFIG_PATH="/usr/local/opt/openblas/lib/pkgconfig"
      
      args << "--with-blas=-L#{Formula["openblas"].opt_lib} -lopenblas"
      ENV.append "LDFLAGS", "-L#{Formula["openblas"].opt_lib}"
      ENV.append "CPPFLAGS", "-I#{Formula["openblas"].opt_include}"
    else
      args << "--with-blas=-framework Accelerate"
      ENV.append_to_cflags "-D__ACCELERATE__" if ENV.compiler != :clang
    end

    if build.with? "libxt"
      args << "--with-x"
      ENV.append "LDFLAGS", "-L#{Formula["libxt"].opt_lib}/"
      ENV.append "CPPFLAGS", "-I#{Formula["libxt"].opt_include}"
      ENV.append "LDFLAGS", "-L#{Formula["libx11"].opt_lib}/"
      ENV.append "CPPFLAGS", "-I#{Formula["libx11"].opt_include}"
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
      # tcl-tk is keg-only, which means it was not symlinked into /usr/local,
      # because macOS already provides this software and installing another version in
      # parallel can cause all kinds of trouble.
      #      ENV.append "LDFLAGS", "-L#{Formula["tcl-tk"].opt_lib}"
      #      ENV.append "CPPFLAGS", "-I#{Formula["tcl-tk"].opt_include}"
    else
      args << "--without-tcltk"
    end

    if build.with? "openjdk@11"
      args << "--enable-java"
    else
      args << "--disable-java"
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

    ENV["PDFLATEX"] = which("pdflatex")
    ENV["PDFTEX"] = which("pdftex")
    ENV["TEX"] = which("tex")
    
    system "./configure", *args

    system "make"

    if build.with? "manuals"
      system "make", "info"
      system "make", "pdf"
    end

    ENV.deparallelize do
      system "make", "install"
    end

    cd "src/nmath/standalone" do
      system "make"
      ENV.deparallelize do
        system "make", "install"
      end
    end

    if build.with? "manuals"
      system "make", "install-info"
      system "make", "install-pdf"
    end

    r_home = lib/"R"

    # if build.with? "install-source"
    #   raise "debug"
    #   #TODO
    # end
    
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
