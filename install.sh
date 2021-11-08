#!/bin/bash

# Directories
PREFIX="${HOME}/Software/Meep"
SRCDIR="${PREFIX}/src"
LOGDIR="${PREFIX}/log"
mkdir -p "${PREFIX}" "${SRCDIR}" "${LOGDIR}"

# Dependencies
read -r -d '' FDPACK <<-'EOM'
	bison,byacc,cscope,ctags,cvs,diffstat,ffmpeg,flex,gcc,gcc-c++,gcc-gfortran,gettext,\
	git,hdf5,hdf5-openmpi,indent,intltool,latex2html,libtool,patch,patchutils,python3,\
	rcs,redhat-rpm-config,rpm-build,subversion,swig,systemtap,wget
EOM
read -r -d '' DVPACK <<-'EOM'
	bzip2,fftw,gc,gmp,gsl,guile,hdf5,hdf5-openmpi,lapack,libffi,libjpeg-turbo,\
	libmatheval,libpng,libpng,libtool-ltdl,libunistring,openblas,openmpi,openssl,pcre,\
	python3,sqlite,zlib
EOM
PYPACK='coverage,h5py,mpi4py-openmpi,matplotlib,numpy,pip,scipy'
if eval "rpm -q {${FDPACK}} {${DVPACK}}-devel python3-{${PYPACK}}" \
    | grep -q 'not installed'
then eval "sudo dnf install -y {${FDPACK}} {${DVPACK}}-devel python3-{${PYPACK}}" \
    | tee "${LOGDIR}/dnf.txt"
fi
ln -sf "/usr/bin/coverage3" "${HOME}/.local/bin/coverage"
if type module &> /dev/null; then
    module load mpi/openmpi-x86_64
else
    echo "module command not found: if you just installed openmp, reboot before trying to run this script again"
    exit
fi
PYTHONVER="$(python -V | cut -d\  -f2 | cut -d. -f1-2)"
export PYTHONPATH="${PYTHONPATH}:/usr/lib64/python${PYTHONVER}/site-packages/openmpi/"

# Compiling Routine
function compile {
    FILE="${REPO}-${VERS//v}.tar.gz"
    SRC="${SRCDIR}/${REPO}"
    LOG="${LOGDIR}/${REPO}"
    mkdir -p "${SRC}" "${LOG}"
    wget "https://github.com/${USER}/${REPO}/releases/download/${VERS}/${FILE}" \
        | tee "${LOG}/wget.txt"
    mv "${FILE}" "${SRCDIR}/${FILE}"
    (
        cd "${SRCDIR}" || exit
        tar xvf "${FILE}" -C "${SRC}" --strip-components=1 | tee "${LOG}/tar.txt"
    )    
    (
        cd "${SRC}" || exit
        ./configure --prefix="${PREFIX}" "${CONF[@]}" | tee "${LOG}/configure.txt"
        make | tee "${LOG}/make.txt"
        # make -j check | tee "${LOG}/check.txt"
        make install | tee "${LOG}/install.txt"
    )
}

# Harminv
USER='NanoComp'
REPO='harminv'
VERS='v1.4.1'
CONF=("--enable-shared")
CC="gcc -fPIC" compile

# libctl
USER='NanoComp'
REPO='libctl'
VERS='v4.5.0'
CONF=("--enable-shared")
compile

# H5utils
USER='NanoComp'
REPO='h5utils'
VERS='1.13.1'
CONF=(--without-{octave,hdf4})
compile

# MPB
USER='NanoComp'
REPO='mpb'
VERS='v1.11.1'
CONF=("--enable-shared" "--with-libctl=${PREFIX}/share/libctl")
PATH="${PATH}:${PREFIX}/bin" \
    LDFLAGS="-L${PREFIX}/lib" \
    CPPFLAGS="-I${PREFIX}/include" \
    compile

# libGDSII 
USER='HomerReid'
REPO='libgdsii'
VERS='v0.21'
CONF=("--enable-shared")
compile

# Meep
USER='NanoComp'
REPO='meep'
VERS='v1.21.0'
CONF=("--enable-shared" "--with-openmp" "--with-mpi"
      "--with-libctl=${PREFIX}/share/libctl")
PATH="${PATH}:${PREFIX}/bin" \
    LDFLAGS="-L${PREFIX}/lib" \
    CPPFLAGS="-I${PREFIX}/include" \
    PYTHON="python3" \
    compile
ln -sf "${PREFIX}/lib/python${PYTHONVER}/site-packages/meep/"* \
       "${PREFIX}/lib64/python${PYTHONVER}/site-packages/meep/"

# bashrc
if ! grep -q "^# meep" "${HOME}/.bashrc"
then cat <<-EOF >> "${HOME}/.bashrc"

	# meep
	module load mpi/openmpi-x86_64
	export PATH="\${PATH}:\${HOME}/Software/Meep/bin"
	export PYTHONPATH="/usr/lib64/python${PYTHONVER}/site-packages/openmpi/:\\
	\${HOME}/Software/Meep/lib64/python${PYTHONVER}/site-packages:\${PYTHONPATH}"
EOF
fi
