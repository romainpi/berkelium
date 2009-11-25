#!/bin/bash

# build-chromium.sh
# Builds Chromium as a dependency for Berkelium.
#
# Parameters:
# --use-root - enable the use of the root account where necessary
# --deps - try to build dependencies as well (may require --use-root on some platforms)
# -j[x] - build with x parallel compiler invocations
# --build-dir x - use x as the build directory for chromium
# --install-dir x - use x as the install destination for chromium
# --app-dir x - use x to "install" to, i.e. add symlinks from Chromium that are needed
#               by the final binary created by linking to libberkelium

platform="`uname -s`"
proctype="`uname -m`"

USE_ROOT=false
USER=`whoami`
USER_SHELL="/bin/bash"
SAME_USER=true

if [ x"${platform}" = x"Darwin" ]; then
    NUM_PROCS=-j2
elif [ x"${platform}" = x"Linux" ]; then
    NUM_PROCS=-j`cat /proc/cpuinfo|grep processor|wc -l`
fi

PWD=`pwd`

WITH_DEPS=false

# The work directory for the build -- where gclient, the chromium source, etc live
# FIXME allow paramter to override this
CHROMIUM_BUILD_DIR="${PWD}/build/"
# The directory that contains patches.  How do we make sure we always have access to this?
# Currently assumes you are running from the base directory of this repository, i.e. won't
# work from outside this project
CHROMIUM_PATCHES_DIR="${PWD}/patches"
# The directory to install to.  Currently this just ends up being a sym link.
CHROMIUM_INSTALL_DIR="${PWD}/installed-chromium"
# The directory to install the app to
CHROMIUM_APP_DIR=""

FORCE_32BIT=false

################################################################################################################################
# Define a function to execute a command as a different user if necessary
################################################################################################################################

function user_eval {
    if $SAME_USER ; then
        pushd "${PWD}" >/dev/null
        $USER_SHELL -c "$1"
        RET=$?
        popd >/dev/null
        return $RET
    else
        su - $USER -s /usr/bin/env -- $USER_SHELL -c "export OLDPATH='$OLDPATH'; export PATH='$PATH'; cd ${PWD}; $1"
        return $?
    fi
}

################################################################################################################################
# Define a function to make a symlink to an existing installation
################################################################################################################################

function make_symlink {
    TARGET=$1
    LINK_NAME=$2

    user_eval "cd ${PWD}; rm -f $LINK_NAME; ln -fs $TARGET $LINK_NAME && (touch -m $LINK_NAME || true)"
}

# Unlike make_symlink, this will delete the contents, if this is not a symlink.
function clean_dir {
    DIRECTORY=$1
    user_eval "cd ${PWD}; rm -f ${DIRECTORY} 2>/dev/null; rm -rf ${DIRECTORY}"
}


# Usage: careful_patch directory patchfile
function careful_patch {
    user_eval "cd $1 && (patch --batch -R -p0 -N --dry-run < $2 || patch --batch -p0 -N < $2)"
    RET=$?
    return $RET
}

################################################################################################################################
# Parse command-line arguments
################################################################################################################################

until [ -z "$1" ] # until all parameters used up
do
    case "$1" in
        --use-root )
            USE_ROOT=true
            ;;
        --deps )
            WITH_DEPS=true
            ;;
        -j* )
            NUM_PROCS="$1"
            ;;
        --build-dir )
            shift
            CHROMIUM_BUILD_DIR="$1"
            ;;
        --install-dir )
            shift
            CHROMIUM_INSTALL_DIR="$1"
            ;;
        --app-dir )
            shift
            CHROMIUM_APP_DIR="$1"
            ;;
    esac
    shift
done


# Make sure we have absolute paths
if [ -z `echo ${CHROMIUM_BUILD_DIR} | grep ^/` ]; then
    CHROMIUM_BUILD_DIR=${PWD}/${CHROMIUM_BUILD_DIR}
fi
if [ -z `echo ${CHROMIUM_PATCHES_DIR} | grep ^/` ]; then
    CHROMIUM_PATCHES_DIR=${PWD}/${CHROMIUM_PATCHES_DIR}
fi
if [ -z `echo $CHROMIUM_INSTALL_DIR} | grep ^/` ]; then
    CHROMIUM_INSTALL_DIR=${PWD}/${CHROMIUM_INSTALL_DIR}
fi


CHROMIUM_DEPOTTOOLS_DIR="${CHROMIUM_BUILD_DIR}/depot_tools"
CHROMIUM_CHECKOUT_DIR="${CHROMIUM_BUILD_DIR}/chromium"

# Chromium revision to build. Ideally we could keep these synced across all platforms.
if [ x"${CHROMIUM_REV}" = x ]; then
    if [ x"${platform}" = x"Darwin" ]; then
        CHROMIUM_REV=28789
    elif [ x"${platform}" = x"Linux" ]; then
        CHROMIUM_REV=29571
    fi
fi

if [ x"${platform}" = x"Darwin" ]; then

    mkdir -p ${CHROMIUM_BUILD_DIR}
    cd ${CHROMIUM_BUILD_DIR}
    if [ \! -e depot_tools ]; then
        curl -o depot_tools.tar.gz http://src.chromium.org/svn/trunk/tools/depot_tools.tar.gz
        tar -zxf depot_tools.tar.gz
    fi
    PATH=${CHROMIUM_DEPOTTOOLS_DIR}:$PATH
    echo "${CHROMIUM_CHECKOUT_DIR}"
    mkdir -p ${CHROMIUM_CHECKOUT_DIR}
    cd ${CHROMIUM_CHECKOUT_DIR}
    gclient config http://src.chromium.org/svn/trunk/src
    python -c 'execfile(".gclient");solutions[0]["custom_deps"]={"src/third_party/WebKit/LayoutTests":None,"src/webkit/data/layout_tests":None,};open(".gclient","w").write("solutions="+repr(solutions));';
    gclient sync --force --revision src@${CHROMIUM_REV}
    cd src/chrome
    xcodebuild -project chrome.xcodeproj -configuration Release -target chrome


    # "Install" process, symlinking libraries and data to the appropriate locations
    if [ x"${CHROMIUM_APP_DIR}" != x ]; then
        # Make sure the top level build dir is there
        if [ \! -e ${CHROMIUM_APP_DIR} ]; then
            user_eval "mkdir -p ${CHROMIUM_APP_DIR}" || true
        fi

        ln -sf ${CHROMIUM_DATADIR}/chrome.pak ${CHROMIUM_APP_DIR}/chrome.pak
        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/chrome.pak ${CHROMIUM_APP_DIR}/chrome.pak
        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Versions ${CHROMIUM_APP_DIR}/Versions
    fi
elif [ x"${platform}" = x"Linux" ]; then

    # Make sure the top level build dir is there
    if [ \! -e ${CHROMIUM_BUILD_DIR} ]; then
        user_eval "mkdir -p ${CHROMIUM_BUILD_DIR}" || true
    fi

    # Real dependencies
    if $WITH_DEPS ; then
        if $USE_ROOT ; then
            echo "Installing Chromium Prerequisites. Package listing is from:"
            echo "http://code.google.com/p/chromium/wiki/LinuxBuildInstructionsPrerequisites"
            case "$DISTRO" in
                debian )
                    apt-get install subversion pkg-config python ruby perl g++ g++-multilib
                    apt-get install bison flex gperf libnss3-dev libnspr4-dev libgtk2.0-dev libnspr4-0d libasound2-dev
                    apt-get install msttcorefonts libgconf2-dev libcairo2-dev libdbus-1-dev
                    apt-get install liborbit2-dev libpopt-dev orbit2
                    apt-get install libnss3-dev
                    ;;
                fedora )
                    yum install subversion pkgconfig python perl ruby gcc-c++ bison \
                        flex gperf nss-devel nspr-devel gtk2-devel.i386 glib2-devel.i386 \
                        freetype-devel.i386 atk-devel.i386 pango-devel.i386 cairo-devel.i386 \
                        fontconfig-devel.i386 GConf2-devel.i386 dbus-devel.i386 alsa-lib-devel
                    rpm --force -Uvh /var/cache/yum/updates/packages/pango-devel-1.22.3-1.fc10.i386.rpm
                    ;;
            esac


            if $FORCE_32BIT; then
                # make sure /usr/local/lib32 exists
                if ! [ -e /usr/local/lib32 ]; then
                    mkdir /usr/local/lib32
                fi
                if ! [ -e /usr/lib32/libnss3.so -o -e /usr/local/lib32/libnss3.so ] ; then
                    #------------from google's script
                    mkdir -p /usr/local/lib32
                    find_curl # make sure curl is available
                    for deb in nspr/libnspr4-0d_4.7.1~beta2-0ubuntu1_i386.deb \
                        nss/libnss3-1d_3.12.0~beta3-0ubuntu1_i386.deb \
                        sqlite3/libsqlite3-0_3.4.2-2_i386.deb; do
                        WORKDIR=$(mktemp -d -p /tmp)
                        pushd ${WORKDIR}
                        letter=$(echo ${deb} | sed -e "s/^\\(.\\).*$/\\1/")
                        user_eval "${CURL_BIN} -O http://mirrors.kernel.org/ubuntu/pool/main/${letter}/${deb}"
                        ar x $(basename ${deb})
                        tar xf data.tar.gz
                        for lib in usr/lib/* ; do
                            libbase=$(basename ${lib})
                            mv ${lib} /usr/local/lib32/${libbase}
                            so=$(echo ${libbase} | sed -e "s/^\\(.*\\.so\\)\\..*$/\\1/")
                            if [ ${so} != ${libbase} ] ; then
                                ln -s -f ${libbase} /usr/local/lib32/${so}
                            fi
                        done
                        popd
                        rm -rf ${WORKDIR}
                    done
                    #-------------------------
                fi

                #ln -s ../local/lib32/libnss3.so /usr/lib32/
                #ln -s ../local/lib32/libnspr4.so /usr/lib32/
                #ln -s ../local/lib32/libnssutil3.so /usr/lib32/
                #ln -s ../local/lib32/libplc4.so /usr/lib32/
                #ln -s ../local/lib32/libplds4.so /usr/lib32/
                #ln -s ../local/lib32/libsmime3.so /usr/lib32/
                #ln -s ../local/lib32/libsqlite3.so /usr/lib32/
                #ln -s ../local/lib32/libssl3.so /usr/lib32/
                ln -s /usr/lib32/libcrypto.so.* /usr/local/lib32/libcrypto.so
                ln -s /usr/lib32/libssl.so.* /usr/local/lib32/libssl.so
                ln -s /usr/lib32/libgtk-x11-2.0.so.? /usr/local/lib32/libgtk-x11-2.0.so
                ln -s /usr/lib32/libgdk-x11-2.0.so.? /usr/local/lib32/libgdk-x11-2.0.so
                ln -s /usr/lib32/libgdk_pixbuf-2.0.so.? /usr/local/lib32/libgdk_pixbuf-2.0.so
                ln -s /usr/lib32/libatk-1.0.so.? /usr/local/lib32/libatk-1.0.so
                for lib in gio-2.0.so.0 gdk-x11-2.0.so.0 atk-1.0.so.0 gdk_pixbuf-2.0.so.0 \
                    pangocairo-1.0.so.0 pango-1.0.so.0 pangoft2-1.0.so.0 gthread-2.0.so.0 glib-2.0.so.0 \
                    gobject-2.0.so.0 gmodule-2.0.so.0 glib-2.0.so.0 gtk-x11-2.0.so.0 \
                    cairo.so.2 freetype.so.6 z.so.1 fontconfig.so.1 \
                    X11.so.6 Xrender.so.1 Xext.so.6 gconf-2.so.4 asound.so.2; do
                    so=$(echo ${lib} | sed -e "s/^\\(.*\\.so\\)\\..*$/\\1/")
                    ln -s /usr/lib32/lib$lib /usr/local/lib32/lib$so
                done
            fi
        fi
    fi

    # Depot tools
    if [ \! -e ${CHROMIUM_DEPOTTOOLS_DIR} ]; then
        user_eval "cd ${CHROMIUM_BUILD_DIR} &&
                 svn co http://src.chromium.org/svn/trunk/tools/depot_tools/"
    fi

    # And now for the real chromium
    echo "Installing Chromium... DUN dunn dunnnnn"
    echo "As of October 2008, it takes about three gigabytes of disk space to install and build the source tree."
    echo "Hit Ctrl-C if you are going to run out of space, so you don't end up with truncated objects."
    clean_dir ${CHROMIUM_INSTALL_DIR}
    if [ \! -e ${CHROMIUM_CHECKOUT_DIR} ]; then
        user_eval "export PATH=\"${CHROMIUM_DEPOTTOOLS_DIR}:${PATH}\" &&
               mkdir -p ${CHROMIUM_CHECKOUT_DIR} &&
               cd ${CHROMIUM_CHECKOUT_DIR} &&
               gclient config http://src.chromium.org/svn/trunk/src &&
               python -c '"'execfile(".gclient");solutions[0]["custom_deps"]={"src/third_party/WebKit/LayoutTests":None,"src/webkit/data/layout_tests":None,};open(".gclient","w").write("solutions="+repr(solutions));'"'";
    fi
    if [ x"${CHROMIUM_DEBUG}" = xtrue ]; then
        echo "*** Building Chromium in Debug mode"
        MAKEFLAGS=" BUILDTYPE=Debug"
        OUTDIR=Debug
    else
        echo "Building Chromium in Release. export CHROMIUM_DEBUG=true for debug mode."
        MAKEFLAGS=" BUILDTYPE=Release"
        OUTDIR=Release
    fi
    if [ x"$proctype" = x"x86_64" ]; then
        CHROME_PLATFORM=x64
    else
        CHROME_PLATFORM=ia32
    fi
    if $FORCE_32BIT; then
        CHROME_PLATFORM=ia32
    fi
    if [ -e ${CHROMIUM_CHECKOUT_DIR} ]; then
#sed -e "s/\"src\/native_client/#\".\/src\/native_client/" .gclient > .gclient-bak && mv .gclient-bak .gclient &&'"
        user_eval "gcc --version | grep -q '4\.4' && export GCC_VERSION=44 && export GYP_DEFINES='gcc_version=44 no_strict_aliasing=1';
                 cd ${CHROMIUM_CHECKOUT_DIR} &&
                 python -c '"'execfile(".gclient");solutions[0]["custom_deps"]={"src/third_party/WebKit/LayoutTests":None,"src/webkit/data/layout_tests":None,};open(".gclient","w").write("solutions="+repr(solutions));'"' &&
                 export PATH=\"${CHROMIUM_DEPOTTOOLS_DIR}:${PATH}\" &&
                 export GYP_GENERATORS=make &&
                 gclient sync --force --revision src@${CHROMIUM_REV}" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}" "${CHROMIUM_PATCHES_DIR}/chromium_mainthread.patch" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}/src" "${CHROMIUM_PATCHES_DIR}/chromium_sandbox_pic.patch" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}/src" "${CHROMIUM_PATCHES_DIR}/chromium_nacl_inline_pic.patch" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}/src" "${CHROMIUM_PATCHES_DIR}/chromium_transparency_26900.patch" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}/src" "${CHROMIUM_PATCHES_DIR}/chromium_win32_sandbox_exports.patch" &&
        careful_patch "${CHROMIUM_CHECKOUT_DIR}/src" "${CHROMIUM_PATCHES_DIR}/chromium_wmode_opaque.patch" &&
        user_eval "cd ${CHROMIUM_CHECKOUT_DIR} &&
                 export PATH=\"${CHROMIUM_DEPOTTOOLS_DIR}:${PATH}\" &&
                 export GYP_GENERATORS=make &&
                 export CHROMIUM_ROOT="'"$PWD"'" &&
                 export CXX='g++ -fPIC' &&
                 export CC='gcc -fPIC' &&
                 export GYP_DEFINES="'"$GYP_DEFINES "target_arch='"$CHROME_PLATFORM &&
                 gclient runhooks --force &&
                 cd src &&
                 CXX='g++ -fPIC' CC='gcc -fPIC' make VERBOSE=1 -r $NUM_PROCS $MAKEFLAGS chrome" && \
                     make_symlink ${CHROMIUM_CHECKOUT_DIR}/src/out/$OUTDIR ${CHROMIUM_INSTALL_DIR} && \
                     echo ${OUTDIR} > ${CHROMIUM_BUILD_DIR}/compilemode.txt || \
                     export FAILED="$FAILED chromium"



        # "Install" process, symlinking libraries and data to the appropriate locations
        if [ x"${CHROMIUM_APP_DIR}" != x ]; then
            # Make sure the top level build dir is there
            if [ \! -e ${CHROMIUM_APP_DIR} ]; then
                user_eval "mkdir -p ${CHROMIUM_APP_DIR}" || true
            fi

            user_eval "ln -sf ${CHROMIUM_DATADIR}/chrome.pak ${CHROMIUM_APP_DIR}/chrome.pak
                       ln -sf ${CHROMIUM_DATADIR}/libavcodec.so.52 ${CHROMIUM_APP_DIR}/libavcodec.so.52
                       ln -sf ${CHROMIUM_DATADIR}/libavformat.so.52 ${CHROMIUM_APP_DIR}/libavformat.so.52
                       ln -sf ${CHROMIUM_DATADIR}/libavutil.so.52 ${CHROMIUM_APP_DIR}/libavutil.so.52
                       ln -sf ${CHROMIUM_DATADIR}/locales ${CHROMIUM_APP_DIR}/locales
                       ln -sf ${CHROMIUM_DATADIR}/resources ${CHROMIUM_APP_DIR}/resources
                       ln -sf ${CHROMIUM_DATADIR}/themes ${CHROMIUM_APP_DIR}/themes" || \
                           export FAILED="$FAILED chromium"

        fi
    else
        export FAILED="$FAILED chromium"
    fi
fi

if [ x"${FAILED}" != x ]; then
    echo ${FAILED}
    exit 1
fi

exit 0
