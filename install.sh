#!/bin/bash

export ERAN_INSTALL_LOCATION=$(dirname "$0")

set -e

has_cuda=0

# Args for ./configure
# --enable-cxx enables C++ compilation
# --host=CPU-VENDOR-OS targets OS systems from VENDOR using the CPU architecture
#   > The VeRAPAk test server is x86_64-pc-linux-gnu
#     CPU: x86_64
#     VENDOR: pc
#     OS: linux-gnu
# --build=CPU-VENDOR-OS defines what OS is currently running the command (usually inferred)
# --disable-assembly creates a generic C build (typically pretty slow)
gmp_args="--enable-cxx"
mpfr_args=""
cddlib_args=""
elina_args="-use-deeppoly -use-gurobi -use-fconv"
help="0"

while : ; do
    case "$1" in
        "")
            break;;
        -use-cuda|--use-cuda|--elina-use-cuda)
         has_cuda=1;;
        -gmp-*|--gmp-*)
         gmp_args="$gmp_args --${1#--gmp-}";;
        -mpfr-*|--mpfr-*)
         mpfr_args="$mpfr_args --${1#--mpfr-}";;
        -cddlib-*|--cddlib-*)
         cddlib_args="$cddlib_args --${1#--cddlib-}";;
        -elina-*|--elina-*)
         elina_args="$elina_args --${1#--elina-}";;
        -help|--help|-?|--?)
         help="1";;
        -help=*|--help=*)
         help="${1#*=}";;
        *)
            echo "unknown option $1, try --help"
            exit 2;;
    esac
    shift
done

helpMain() {
    echo -e "\e[1m--use-cuda\n\e[22m\tEnables GPU support"
    echo -e "\e[1m--help[=category]\n\e[22m\tShows this help message. Valid categories include 'gmp', 'mpfr', 'cddlib',
\t'elina', 'environment', or 'all'."
}
helpGMP() {
    echo -e "\e[1m--gmp-*\n\e[22m\tAdds args to the ./configure script of GMP"
    echo -e "\e[2m\tOptional Features:
\t  --gmp-disable-option-checking  ignore unrecognized --enable/--with options
\t  --gmp-disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
\t  --gmp-enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
\t  --gmp-enable-silent-rules   less verbose build output (undo: 'make V=1')
\t  --gmp-disable-silent-rules  verbose build output (undo: 'make V=0')
\t  --gmp-enable-maintainer-mode
\t                              enable make rules and dependencies not useful (and
\t                              sometimes confusing) to the casual installer
\t  --gmp-enable-assert         enable ASSERT checking [default=no]
\t  --gmp-enable-alloca         how to get temp memory [default=reentrant]
\t  --gmp-enable-cxx            enable C++ support [default=yes]
\t  --gmp-enable-assembly       enable the use of assembly loops [default=yes]
\t  --gmp-enable-fft            enable FFTs for multiplication [default=yes]
\t  --gmp-enable-old-fft-full   enable old mpn_mul_fft_full for multiplication
\t                              [default=no]
\t  --gmp-enable-nails          use nails on limbs [default=no]
\t  --gmp-enable-profiling      build with profiler support [default=no]
\t  --gmp-enable-fat            build fat libraries on systems that support it
\t                              [default=no]
\t  --gmp-enable-minithres      choose minimal thresholds for testing [default=no]
\t  --gmp-enable-fake-cpuid     enable GMP_CPU_TYPE faking cpuid [default=no]
\t  --gmp-enable-shared[=PKGS]  build shared libraries [default=yes]
\t  --gmp-enable-static[=PKGS]  build static libraries [default=yes]
\t  --gmp-enable-fast-install[=PKGS]
\t                              optimize for fast installation [default=yes]
\t  --gmp-disable-libtool-lock  avoid locking (might break parallel builds)
\e[22m"
}
helpMPFR() {
    echo -e "\e[1m--mpfr-*\n\e[22m\tAdds args to the ./configure script of MPFR"
    echo -e "\e[2m\tOptional Features:
\t  --mpfr-disable-option-checking  ignore unrecognized --enable/--with options
\t  --mpfr-disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
\t  --mpfr-enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
\t  --mpfr-enable-silent-rules   less verbose build output (undo: 'make V=1')
\t  --mpfr-disable-silent-rules  verbose build output (undo: 'make V=0')
\t  --mpfr-disable-maintainer-mode
\t                               disable make rules and dependencies not useful (and
\t                               sometimes confusing) to the casual installer
\t  --mpfr-enable-gmp-internals  enable use of GMP undocumented functions [default=no]
\t  --mpfr-enable-assert         enable ASSERT checking [default=no]
\t  --mpfr-enable-logging        enable MPFR logging (needs nested functions
\t                               and the 'cleanup' attribute) [default=no]
\t  --mpfr-disable-thread-safe   explicitly disable TLS support
\t  --mpfr-enable-thread-safe    build MPFR as thread safe, i.e. with TLS support
\t                               (the system must support it) [default=autodetect]
\t  --mpfr-enable-shared-cache   enable use of caches shared by all threads,
\t                               for all MPFR constants.  It usually makes MPFR
\t                               dependent on PTHREAD [default=no]
\t  --mpfr-enable-warnings       allow MPFR to output warnings to stderr [default=no]
\t  --mpfr-enable-tests-timeout=NUM
\t                               [for developers] enable timeout for test programs
\t                               (NUM seconds, <= 9999) [default=no]; if this is
\t                               enabled, the environment variable \$MPFR_TESTS_TIMEOUT
\t                               overrides NUM (0: no timeout)
\t  --mpfr-enable-tune-for-coverage
\t                               [for developers] tune MPFR for coverage tests
\t  --mpfr-disable-decimal-float explicitly disable decimal floats support
\t  --mpfr-enable-decimal-float  build conversion functions from/to decimal floats
\t                               (see INSTALL file for details) [default=auto]
\t  --mpfr-disable-float128      explicitly disable binary128 support
\t  --mpfr-enable-float128       build conversion functions from/to binary128
\t                               (_Float128 or __float128) [default=autodetect]
\t  --mpfr-enable-debug-prediction
\t                               [for developers] enable debug of branch prediction
\t                               (for x86 and x86-64 with GCC, static libs)
\t  --mpfr-enable-lto            build MPFR with link-time-optimization
\t                               (experimental) [default: no]
\t  --mpfr-enable-formally-proven-code
\t                               use formally proven code when available
\t                               (needs a C99 compiler) [default=no]
\t  --mpfr-enable-dependency-tracking
\t                               do not reject slow dependency extractors
\t  --mpfr-disable-dependency-tracking
\t                               do not reject slow dependency extractors
\t  --mpfr-disable-dependency-tracking
\t                               speeds up one-time build
\t  --mpfr-enable-shared[=PKGS]  build shared libraries [default=yes]
\t  --mpfr-enable-static[=PKGS]  build static libraries [default=yes]
\e[22m"
}
helpCDDLIB() {
    echo -e "\e[1m--cddlib-*\n\e[22m\tAdds args to the ./configure script of CDDLib"
    echo -e "\e[2m\tOptional Features:
\t  --cddlib-disable-option-checking  ignore unrecognized --enable/--with options
\t  --cddlib-disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
\t  --cddlib-enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
\t  --cddlib-enable-silent-rules   less verbose build output (undo: "make V=1")
\t  --cddlib-disable-silent-rules  verbose build output (undo: "make V=0")
\t  --cddlib-enable-dependency-tracking
\t                                 do not reject slow dependency extractors
\t  --cddlib-disable-dependency-tracking
\t                                 speeds up one-time build
\t  --cddlib-enable-shared[=PKGS]  build shared libraries [default=yes]
\t  --cddlib-enable-static[=PKGS]  build static libraries [default=yes]
\t  --cddlib-enable-fast-install[=PKGS]
\t                                 optimize for fast installation [default=yes]
\t  --cddlib-disable-libtool-lock  avoid locking (might break parallel builds)
\e[22m"
}
helpELINA() {
    echo -e "\e[1m--elina-*\n\e[22m\tAdds args to the ./configure script of ELINA"
    echo -e "\e[2m\twhere options include:
\t  --elina-prefix dir          installation directory
\t  --elina-use-apron           use APRON interface (required for Ocaml and Java)
\t  --elina-apron-prefix dir    where to find the APRON library
\t  --elina-apron-srcroot dir   where to find the APRON source directory
\t  --elina-gmp-prefix dir      where to find the GMP library
\t  --elina-mpfr-prefix dir     where to find the MPFR library
\t  --elina-cdd-prefix dir      where to find the CDD library
\t  --elina-java-prefix dir     where to find Java
\t  --elina-use-vector          use vector instructions for the Octagon library
\t  --elina-use-ocaml           enable OCaml support (only available with APRON)
\t  --elina-use-ocamlfind       enable OCamlfind support
\t  --elina-use-java            enable Java support (only available with APRON)
\t  --elina-use-opam            use opam to install ELINA
\t  --elina-no-warn-overflow    Silence all output relating to sound overflow
\e[22m"
}
helpEnvironment() {
    echo -e "Environment variables that affect configuration:
\tAffects all installations:
\t  CC          C compiler command
\t  CFLAGS      C compiler flags
\t  LDFLAGS     linker flags, e.g. -L<lib dir> if you have libraries in a
\t              nonstandard directory <lib dir>
\t  LIBS        libraries to pass to the linker, e.g. -l<library>
\t  CPPFLAGS    (Objective) C/C++ preprocessor flags, e.g. -I<include dir> if
\t              you have headers in a nonstandard directory <include dir>
\t  CPP         C preprocessor
\t  LT_SYS_LIBRARY_PATH
\t              User-defined run-time library search path.
\tGMP-specific
\t  ABI         desired ABI (for processors supporting more than one ABI)
\t  CC_FOR_BUILD
\t              build system C compiler
\t  CPP_FOR_BUILD
\t              build system C preprocessor
\t  CXX         C++ compiler command
\t  CXXFLAGS    C++ compiler flags
\t  CXXCPP      C++ preprocessor
\t  M4          m4 macro processor
\t  YACC        The 'Yet Another Compiler Compiler' implementation to use.
\t              Defaults to the first program found out of: 'bison -y', 'byacc',
\t              'yacc'.
\t  YFLAGS      The list of arguments that will be passed by default to \$YACC.
\t              This script will default YFLAGS to the empty string to avoid a
\t              default value of '-d' given by some make applications.
\tELINA-specific
\t  CXXFLAGS    extra flags to pass to the C++ compiler
\t  GMP_PREFIX  where to find the GMP library
\t  MPFR_PREFIX where to find the MPFR library
\t  CDD_PREFIX  where to find the CDD library
\t  BOOST_PREFIX
\t              where to find the Boost library
\t  JAVA_HOME   where to find Java
"
}

if [ "$help" != "0" ]; then
    helpMain
fi
if [ "$help" == "gmp" ]; then
    helpGMP
elif [ "$help" == "mpfr" ]; then
    helpMPFR
elif [ "$help" == "cddlib" ]; then
    helpCDDLIB
elif [ "$help" == "elina" ]; then
    helpELINA
elif [ "$help" == "all" ]; then
    helpGMP
    helpMPFR
    helpCDDLIB
    helpELINA
fi
if [ "$help" != "0" ]; then
    if [ "$help" != "1" ]; then
        helpEnvironment
    fi
    exit 0
fi


# INSTALLED via APT
# PREREQ for ELINA
#wget ftp://ftp.gnu.org/pub/gnu/m4/m4-1.4.18.tar.gz
#tar -xvzf m4-1.4.18.tar.gz
#cd m4-1.4.18
#./configure
#make
#make install
#cp src/m4 /usr/bin
#cd ..
#rm m4-1.4.18.tar.gz


# PREREQ for ELINA
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
tar -xvf gmp-6.1.2.tar.xz
cd gmp-6.1.2
./configure $gmp_args
make
make install
cd ..
rm gmp-6.1.2.tar.xz


# PREREQ for ELINA
wget https://files.sri.inf.ethz.ch/eran/mpfr/mpfr-4.1.0.tar.xz
tar -xvf mpfr-4.1.0.tar.xz
cd mpfr-4.1.0
./configure $mpfr_args
make
make install
cd ..
rm mpfr-4.1.0.tar.xz

# SPEEDUP for ELINA
wget https://github.com/cddlib/cddlib/releases/download/0.94m/cddlib-0.94m.tar.gz
tar zxf cddlib-0.94m.tar.gz
cd cddlib-0.94m
./configure $cddlib_args
make
make install
cd ..

# SPEEDUP for ELINA
wget https://packages.gurobi.com/9.1/gurobi9.1.2_linux64.tar.gz
tar -xvf gurobi9.1.2_linux64.tar.gz
cd gurobi912/linux64/src/build
sed -ie 's/^C++FLAGS =.*$/& -fPIC/' Makefile
make
cp libgurobi_c++.a ../../lib/
cd ../../
cp lib/libgurobi91.so /usr/local/lib
python3 setup.py install
cd ../../
rm gurobi9.1.2_linux64.tar.gz



export GUROBI_HOME="$(pwd)/gurobi912/linux64"
export PATH="${PATH}:/usr/lib:${GUROBI_HOME}/bin"
export CPATH="${CPATH}:${GUROBI_HOME}/include"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/local/lib:${GUROBI_HOME}/lib

git clone https://github.com/yodarocks1/ELINA.git
cd ELINA
if test "$has_cuda" -eq 1
then
    ./configure -use-cuda $elina_args
    cd ./gpupoly/
    cmake .
    cd ..
else
    ./configure $elina_args
fi
make
make install
cd ..

#git clone https://github.com/eth-sri/deepg.git
#cd deepg/code
#mkdir build
#make shared_object
#cp ./build/libgeometric.so /usr/lib
#cd ../..

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib

#wget https://files.sri.inf.ethz.ch/eran/nets/tensorflow/mnist/mnist_relu_3_50.tf

ldconfig

mkdir python_interface
ln -s ../ELINA/python_interface ./python_interface/elina
ln -s ../tf_verify ./python_interface/eran

echo "To use ERAN, add '$ERAN_INSTALL_LOCATION/python_interface/' to your \$PYTHONPATH, or add the following lines to the top of your python file:"
echo " import sys"
echo " sys.path.insert(0, '$ERAN_INSTALL_LOCATION/python_interface/')"

