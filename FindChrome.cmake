INCLUDE(FindPkgConfig)
SET(CHROME_FOUND TRUE)
SET(CHROMIUMDIR ${CHROME_ROOT})
IF(NOT CHROME_MODE)
  SET(CHROMIUMMODE Release)
ELSE()
  SET(CHROMIUMMODE ${CHROME_MODE})
ENDIF()
STRING(COMPARE EQUAL ${CHROMIUMMODE} "Debug" CHROMIUM_ISDEBUG)
IF(CHROMIUM_ISDEBUG)
SET(CHROMIUM_DEBUGFLAGS -D_DEBUG)
ELSE()
SET(CHROMIUM_DEBUGFLAGS -DNDEBUG)
ENDIF()

IF(APPLE)
IF(NOT CHROMIUMBUILDER)
SET(CHROMIUMBUILDER "xcode")
ENDIF()
ENDIF()

IF(CHROMIUMBUILDER)
  STRING(COMPARE EQUAL ${CHROMIUMBUILDER} "xcode" CHROMIUM_ISXCODE)
ENDIF()
IF(CHROMIUMBUILDER)
  STRING(COMPARE EQUAL ${CHROMIUMBUILDER} "scons" CHROMIUM_ISSCONS)
ENDIF()
IF(CHROMIUM_ISXCODE)
  SET(CHROMIUM_PLAT mac)
  SET(CHROMIUM_PLAT_CFLAGS -pthread)
  SET(SNOW)

  SET(CHROMIUM_PLAT_LDFLAGS -dynamiclib -pthread ${CHROMIUMDIR}/src/third_party/WebKit/WebKitLibraries/libWebKitSystemInterface${SNOW}Leopard.a "-framework CoreAudio" "-framework AudioToolbox" "-framework Cocoa" "-framework QuartzCore" "-framework Security" "-framework SecurityInterface" "-framework SystemConfiguration" -ObjC "-framework Carbon" -Wl,${CHROMIUMDIR}/src/xcodebuild/chrome.build/${CHROMIUMMODE}/chrome_dll.build/Objects-normal/i386/keystone_glue.o "-framework OpenGL")
  SET(CHROMIUM_START_GROUP)
  SET(CHROMIUM_END_GROUP)
  SET(CHROMIUM_DLLEXT dylib)
ELSE()
  PKG_CHECK_MODULES(CHROMIUM_PLAT gtk+-2.0 glib-2.0 gthread-2.0 gio-unix-2.0)  # will set MONO_FOUND
  SET(CHROMIUM_PLAT linux)
  SET(CHROMIUM_PLAT_LDFLAGS ${CHROMIUM_PLAT_LDFLAGS}  ssl3 nss3 nssutil3 smime3 plds4 plc4 nspr4 pthread gdk-x11-2.0 gdk_pixbuf-2.0 linux_versioninfo pangocairo-1.0 gio-2.0 pango-1.0 cairo gobject-2.0 gmodule-2.0 glib-2.0 fontconfig freetype rt gconf-2 glib-2.0 X11 asound harfbuzz harfbuzz_interface sandbox nonnacl_util_linux)
  SET(CHROMIUM_START_GROUP -Wl,--start-group)
  SET(CHROMIUM_END_GROUP -Wl,--end-group)
  SET(CHROMIUM_DLLEXT so)
ENDIF()

IF(NOT CHROMIUM_ISSCONS)
  IF(NOT CHROMIUM_ISXCODE)
    ### Make build (Linux 32/64-bit) ###
    SET(CHLIBS $(CHROMIUMLIBPATH))
    SET(CHROMIUM_DATADIR ${CHROMIUMDIR}/src/out/${CHROMIUMMODE})
    IF(NOT CHROMIUM_CHLIBS)
      SET(CHROMIUM_CHLIBS ${CHROMIUM_DATADIR}/obj.target)
    ENDIF()

   SET(CHROME_LIBRARY_DIRS ${CHROMIUM_CHLIBS} ${CHROMIUM_CHLIBS}/app ${CHROMIUM_CHLIBS}/base ${CHROMIUM_CHLIBS}/ipc ${CHROMIUM_CHLIBS}/chrome ${CHROMIUM_CHLIBS}/net ${CHROMIUM_CHLIBS}/media ${CHROMIUM_CHLIBS}/webkit ${CHROMIUM_CHLIBS}/sandbox ${CHROMIUM_CHLIBS}/skia ${CHROMIUM_CHLIBS}/printing ${CHROMIUM_CHLIBS}/v8/tools/gyp ${CHROMIUM_CHLIBS}/sdch ${CHROMIUM_CHLIBS}/build/temp_gyp ${CHROMIUM_CHLIBS}/native_client/src/trusted/plugin/ ${CHROMIUM_CHLIBS}/native_client/src/shared/srpc ${CHROMIUM_CHLIBS}/native_client/src/shared/imc ${CHROMIUM_CHLIBS}/native_client/src/shared/platform ${CHROMIUM_CHLIBS}/native_client/src/trusted/nonnacl_util ${CHROMIUM_CHLIBS}/native_client/src/trusted/nonnacl_util/linux ${CHROMIUM_CHLIBS}/native_client/src/trusted/service_runtime/ ${CHROMIUM_CHLIBS}/ ${CHROMIUM_CHLIBS}/native_client/src/trusted/desc/ ${CHROMIUM_CHLIBS}/third_party/bzip2 ${CHROMIUM_CHLIBS}/third_party/ffmpeg ${CHROMIUM_CHLIBS}/third_party/harfbuzz ${CHROMIUM_CHLIBS}/third_party/hunspell ${CHROMIUM_CHLIBS}/third_party/icu ${CHROMIUM_CHLIBS}/third_party/libevent ${CHROMIUM_CHLIBS}/third_party/libjpeg ${CHROMIUM_CHLIBS}/third_party/libpng ${CHROMIUM_CHLIBS}/third_party/libxml ${CHROMIUM_CHLIBS}/third_party/libxslt ${CHROMIUM_CHLIBS}/third_party/modp_b64 ${CHROMIUM_CHLIBS}/third_party/sqlite ${CHROMIUM_CHLIBS}/third_party/zlib ${CHROMIUM_CHLIBS}/third_party/WebKit/JavaScriptCore/JavaScriptCore.gyp ${CHROMIUM_CHLIBS}/third_party/WebKit/WebCore/WebCore.gyp)


    SET(CHROMIUM_TPLIBS event zlib png xml jpeg xslt bzip2 ${CHROMIUM_CHLIBS}/third_party/sqlite/libsqlite.a google_nacl_imc_c base_i18n)

    SET(CHROMIUM_GENINCLUDES ${CHROMIUM_CHLIBS}/gen/chrome)
  ELSE(NOT CHROMIUM_ISXCODE)
    ### XCode Build System (Mac OS X) ###
    SET(CHROMIUM_CHLIBS ${CHROMIUMLIBPATH})
    IF (NOT CHROMIUN_CHLIBS)
       SET(CHROMIUM_CHLIBS ${CHROMIUMDIR}/src/xcodebuild/${CHROMIUMMODE})
    ENDIF()
    SET(CHROMIUM_DATADIR ${CHROMIUM_CHLIBS})

    SET(CHROME_LIBRARY_DIRS ${CHROMIUM_CHLIBS})
    SET(CHROMIUM_TPLIBS ${CHROMIUM_CHLIBS}/libevent.a ${CHROMIUM_CHLIBS}/libxslt.a ${CHROMIUM_CHLIBS}/libjpeg.a ${CHROMIUM_CHLIBS}/libpng.a ${CHROMIUM_CHLIBS}/libz.a ${CHROMIUM_CHLIBS}/libxml2.a ${CHROMIUM_CHLIBS}/libbz2.a ${CHROMIUM_CHLIBS}/libsqlite3.a ${CHROMIUM_CHLIBS}/libprofile_import.a ${CHROMIUM_CHLIBS}/libpcre.a libgoogle_nacl_imc_c)
    IF(CHROME_IS_OVER_VERSION_29000)
        # Uncomment me for experimental 29000 builds (Crash in WebCore calling CoreGraphics after about 3 renders, in __dyld_misaligned_stack_error)
        SET(CHROMIUM_TPLIBS ${CHROMIUM_TPLIBS} base_i18n ${CHROMIUM_CHLIBS}/libsync.a ${CHROMIUM_CHLIBS}/libsyncapi.a ${CHROMIUM_CHLIBS}/libprotobuf_lite.a )
    ELSE()
        SET(CHROMIUM_TPLIBS ${CHROMIUM_TPLIBS} base_gfx)
    ENDIF()
    SET(GENINCLUDES ${CHROMIUMDIR}/src/xcodebuild/DerivedSources/${CHROMIUMMODE}/chrome)

  ENDIF(NOT CHROMIUM_ISXCODE)
ELSE(NOT CHROMIUM_ISSCONS)
  ### SCONS Build System (deprecated) ###
  SET(CHROMIUM_DATADIR ${CHROMIUMDIR}/src/out/${CHROMIUMMODE})
  IF(NOT CHROMIUMLIBPATH)
    SET(CHROMIUMLIBPATH ${CHROMIUM_DATADIR}/lib)
  ENDIF()
  SET(GENINCLUDES ${CHROMIUM_DATADIR}) #not sure

  SET(CHROME_LIBRARY_DIRS ${CHROMIUMLIBPATH})
  SET(CHROMIUM_TPLIBS event xslt jpeg png z xml2 bz2 ${CHROMIUMLIBPATH}/libsqlite.a google_nacl_imc_c  base_i18n)
ENDIF(NOT CHROMIUM_ISSCONS)

SET(CHROMIUMLIBS ${CHROMIUMLDFLAGS} ${CHROMIUM_TPLIBS}  dl m common browser debugger renderer utility printing app_base base icui18n icuuc icudata skia net googleurl sdch modp_b64 v8_snapshot v8_base glue pcre wtf webkit webcore media ffmpeg hunspell plugin  appcache ipc worker database common_constants npGoogleNaClPluginChrome nonnacl_srpc platform sel sel_ldr_launcher nonnacl_util_chrome nrd_xfer gio expiration nacl)
SET(CHROMIUM_ARCHFLAGS)
# Flags that affect both compiling and linking
SET(CHROMIUM_CLIBFLAGS ${CHROMIUM_ARCHFLAGS} -fvisibility=hidden -fvisibility-inlines-hidden -fPIC -pthread -Wall -fno-rtti)
SET(CHROME_INCLUDE_DIRS ${GENINCLUDES} ${CHROMIUMDIR}/src/ ${CHROMIUMDIR}/src/third_party/npapi ${CHROMIUMDIR}/src/third_party/WebKit/JavaScriptCore ${CHROMIUMDIR}/src/third_party/icu/public/common ${CHROMIUMDIR}/src/skia/config ${CHROMIUMDIR}/src/third_party/skia/include/core ${CHROMIUMDIR}/src/webkit/api/public ${CHROMIUMDIR}/src/third_party/WebKit/WebCore/platform/text)
SET(CHROME_CFLAGS ${CHROMIUM_DEBUGFLAGS} ${CHROMIUM_CLIBFLAGS} ${CHROMIUM_PLAT_CFLAGS} -Wall -DNVALGRIND -D_REENTRANT -D__STDC_FORMAT_MACROS -DCHROMIUM_BUILD -DU_STATIC_IMPLEMENTATION -g )

SET(CHROME_LIBRARIES ${CHROMIUM_START_GROUP} ${CHROMIUM_PLAT_LDFLAGS} ${CHROMIUMLIBS} ${CHROMIUM_END_GROUP})
SET(CHROME_LDFLAGS -g -shared ${CHROMIUM_CLIBFLAGS})
#OBJDIR=$(CHROMIUMMODE)
#EXEDIR=$(CHROMIUMMODE)

FOREACH(CHROMIUMLIB ${CHROME_LIBRARY_DIRS})
  IF(NOT EXISTS ${CHROMIUMLIB})
    IF(CHROME_FOUND)
      MESSAGE(STATUS "Failed to find Chrome library directory at ${CHROMIUMLIB}")
    ENDIF()
    SET(CHROME_FOUND FALSE)
  ENDIF()
ENDFOREACH()
FOREACH(CHROMIUMINC ${CHROME_INCLUDE_DIRS})
  IF(NOT EXISTS ${CHROMIUMINC})
    IF(CHROME_FOUND)
      MESSAGE(STATUS "Failed to find Chrome include directory at ${CHROMIUMINC}")
    ENDIF()
    SET(CHROME_FOUND FALSE)
  ENDIF()
ENDFOREACH()

IF(CHROME_FOUND)
  IF(APPLE)
     IF(NOT CHROME_SYMLINKS_TARGET)
       SET(CHROME_SYMLINKS_TARGET chromium)
     ENDIF()
     SET(CHROME_SYMLINKS_COMMAND_TARGET ${CHROME_SYMLINKS_TARGET}.app)
     ADD_CUSTOM_TARGET(${CHROME_SYMLINKS_TARGET}
                      ALL
                      COMMAND
                        mkdir -p ${CHROME_SYMLINKS_TARGET}.app &&
                        mkdir -p ${CHROME_SYMLINKS_TARGET}.app/Contents &&
                        mkdir -p ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources &&
                        mkdir -p ${CHROME_SYMLINKS_TARGET}.app/Contents/Frameworks &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET}.app ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/Berkelium\ Helper.app &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET}.app/Contents ${CHROME_SYMLINKS_TARGET}.app/Contents/Frameworks/${CHROMIUM_FRAMEWORK} &&
                        mkdir -p ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS &&
                        "((" ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET}_d ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET} ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS ")" || ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET} ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS || ln -sf ${CMAKE_CURRENT_BINARY_DIR}/${CHROME_SYMLINKS_TARGET}_d ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS ")" &&
                        ln -sf berkelium ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/berkelium ${CHROME_SYMLINKS_TARGET}.app/Contents/MacOS/berkelium &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/chrome.pak ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/chrome.pak &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/theme.pak ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/theme.pak &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/linkCursor.png ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/linkCursor.png  &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/renderer.sb ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/renderer.sb &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/en_US.lproj ${CHROME_SYMLINKS_TARGET}.app/Contents/Resources/en_US.lproj)     
  ELSE()
   SET(CHROME_SYMLINKS_COMMAND_TARGET chrome.pak)
   SET(CHROME_SYMLINKS_COMMAND ln -sf ${CHROMIUM_DATADIR}/libavformat.so.52 && ln -sf ${CHROMIUM_DATADIR}/libavutil.so.50 && ln -sf ${CHROMIUM_DATADIR}/libavcodec.so.52 &&ln -sf ${CHROMIUM_DATADIR}/locales && ln -sf ${CHROMIUM_DATADIR}/resources && ln -sf ${CHROMIUM_DATADIR}/themes && ln -sf ${CHROMIUM_DATADIR}/chrome.pak)

  ENDIF()


  IF(NOT CHROME_FOUND_QUIETLY)
    MESSAGE(STATUS "Found Chrome: headers at ${CHROME_INCLUDE_DIRS}, libraries at ${CHROME_LIBRARY_DIRS}")
    MESSAGE(STATUS "Found Chrome: LDFLAGS at ${CHROME_LDFLAGS}")
    MESSAGE(STATUS "Found Chrome: CFLAGS at ${CHROME_CFLAGS}")
  ELSE()
    MESSAGE(STATUS "Chrome Found ")
  ENDIF()
ENDIF(CHROME_FOUND)
