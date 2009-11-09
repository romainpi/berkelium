
CMAKE_MINIMUM_REQUIRED(VERSION 2.4)
SET(CMAKE_VERBOSE_MAKEFILE OFF)
SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS TRUE)
IF(COMMAND CMAKE_POLICY)
  # Use new policy for absolute path libraries.  We have no reason to depend on the
  # old version which adds library search paths unnecessarily
  CMAKE_POLICY(SET CMP0003 NEW)
ENDIF(COMMAND CMAKE_POLICY)
SET(BERKELIUM_TOP_LEVEL ${CMAKE_CURRENT_SOURCE_DIR})
SET(CMAKE_MODULE_PATH ${BERKELIUM_TOP_LEVEL})
GET_FILENAME_COMPONENT(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ABSOLUTE)
IF(NOT CHROME_ROOT)
  SET(CHROME_ROOT ${BERKELIUM_TOP_LEVEL}/../../dependencies/ch/c)
  IF(NOT EXISTS ${CHROME_ROOT})
    SET(CHROME_ROOT ${BERKELIUM_TOP_LEVEL}/chrome)
    IF(NOT EXISTS ${CHROME_ROOT})
      SET(CHROME_ROOT ${BERKELIUM_TOP_LEVEL}/chromium)
    ENDIF()
  ENDIF()
ENDIF()
FIND_PACKAGE(Chrome)

IF(CHROME_FOUND)

  INCLUDE_DIRECTORIES(${CHROME_INCLUDE_DIRS})
  LINK_DIRECTORIES(${CHROME_LIBRARY_DIRS})
  SET(BERKELIUM_SOURCE_NAMES src/Berkelium src/Context src/ContextImpl src/NavigationController src/RenderWidget src/MemoryRenderViewHost src/Root src/Window src/WindowImpl)


  SET(BERKELIUM_SOURCES)
  FOREACH(BERKELIUM_SOURCE_FILE ${BERKELIUM_SOURCE_NAMES})
    SET(BERKELIUM_SOURCES ${BERKELIUM_SOURCES}   ${BERKELIUM_TOP_LEVEL}/${BERKELIUM_SOURCE_FILE}.cpp)
  ENDFOREACH()

  SET(CHROMIUM_LDFLAGS "")
  FOREACH(CHROME_LDFLAG ${CHROME_LDFLAGS})
    SET(CHROMIUM_LDFLAGS "${CHROMIUM_LDFLAGS} ${CHROME_LDFLAG}")
  ENDFOREACH()
  FOREACH(CHROME_CFLAG ${CHROME_CFLAGS})
    SET(CHROMIUM_CFLAGS "${CHROMIUM_CFLAGS} ${CHROME_CFLAG}")
  ENDFOREACH()


  ADD_LIBRARY(libberkelium SHARED ${BERKELIUM_SOURCES})
  SET_TARGET_PROPERTIES(libberkelium PROPERTIES DEBUG_POSTFIX "_d")
  SET_TARGET_PROPERTIES(libberkelium PROPERTIES LINK_FLAGS ${CHROMIUM_LDFLAGS})
  SET_TARGET_PROPERTIES(libberkelium PROPERTIES COMPILE_FLAGS "${CHROMIUM_CFLAGS}")
  SET_TARGET_PROPERTIES(libberkelium PROPERTIES DEBUG_POSTFIX "_d")
  TARGET_LINK_LIBRARIES(libberkelium ${CHROME_LIBRARIES})

  ADD_EXECUTABLE(ppmrender ${BERKELIUM_TOP_LEVEL}/ppmmain.cpp)
  IF(APPLE)
    SET( CHROMIUM_DYLIB_EXT .dylib)
  ELSE()
    SET( CHROMIUM_DYLIB_EXT .so)
  ENDIF()
  TARGET_LINK_LIBRARIES(ppmrender -L. debug liblibberkelium_d${CHROMIUM_DYLIB_EXT} optimized liblibberkelium${CHROMIUM_DYLIB_EXT} )


  ADD_EXECUTABLE(berkelium ${BERKELIUM_TOP_LEVEL}/subprocess.cpp)
  TARGET_LINK_LIBRARIES(berkelium -L. debug liblibberkelium_d${CHROMIUM_DYLIB_EXT} optimized liblibberkelium${CHROMIUM_DYLIB_EXT} )
IF(APPLE)
    ADD_LIBRARY(plugin_carbon_interpose SHARED ${CHROME_ROOT}/src/chrome/browser/plugin_carbon_interpose_mac.cc)
    SET_TARGET_PROPERTIES(plugin_carbon_interpose PROPERTIES COMPILE_FLAGS ${CHROMIUM_CFLAGS})
    SET_TARGET_PROPERTIES(plugin_carbon_interpose PROPERTIES LINK_FLAGS "-framework Carbon")
    TARGET_LINK_LIBRARIES(plugin_carbon_interpose -L. debug liblibberkelium_d.dylib optimized liblibberkelium.dylib )
    ADD_DEPENDENCIES(plugin_carbon_interpose libberkelium)



    ADD_CUSTOM_TARGET(plugin_carbon_interpose.dylib ALL DEPENDS plugin_carbon_interpose COMMAND ln -sf libplugin_carbon_interpose.dylib plugin_carbon_interpose.dylib && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/libplugin_carbon_interpose.dylib ../plugin_carbon_interpose.dylib)
  ENDIF()

  ADD_DEPENDENCIES(berkelium libberkelium)
  ADD_DEPENDENCIES(ppmrender libberkelium)

  IF(APPLE)
    SET(CHROMIUM_FRAMEWORK Chromium\ Framework.framework)
    ADD_CUSTOM_TARGET(chrome.pak ALL COMMAND ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/chrome.pak ../chrome.pak && ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/chrome.pak ../chrome.pak)
    ADD_CUSTOM_TARGET(Versions ALL COMMAND ln -sf $CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Versions ../../Versions && ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Versions ../Versions && ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Versions Versions)
    ADD_CUSTOM_TARGET(ppmrender.app ALL COMMAND mkdir -p ppmrender.app && mkdir -p ppmrender.app/Contents && mkdir -p ppmrender.app/Contents/Resources && mkdir -p ppmrender.app/Contents/Frameworks && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender.app ppmrender.app/Contents/Resources/Berkelium\ Helper.app && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender.app/Contents ppmrender.app/Contents/Frameworks/Chromium\ Framework.app && mkdir -p ppmrender.app/Contents/MacOS && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender ppmrender.app/Contents/MacOS && ln -sf berkelium ppmrender.app/Contents/MacOS && ln -sf ${CMAKE_CURRENT_BINARY_DIR}/berkelium ppmrender.app/Contents/MacOS/berkelium)
  ELSE()
    ADD_CUSTOM_TARGET(chrome.pak ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/chrome.pak ../chrome.pak && ln -sf ${CHROMIM_DATADIR}/chrome.pak)
    ADD_CUSTOM_TARGET(libavcodec.so.52 ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/libavcodec.so.52 ../libavcodec.so.52 && ln -sf ${CHROMIUM_DATADIR}/libavcodec.so.52)
    ADD_CUSTOM_TARGET(libavformat.so.52 ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/libavformat.so.52 ../libavformat.so.52 && ln -sf ${CHROMIUM_DATADIR}/libavformat.so.52)
    ADD_CUSTOM_TARGET(libavutil.so.52 ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/libavutil.so.52 ../libavutil.so.52 && ln -sf ${CHROMIUM_DATADIR}/libavutil.so.52)

    ADD_CUSTOM_TARGET(locales ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/locales && ln -sf ${CHROMIUM_DATADIR}/locales ../locales)
    ADD_CUSTOM_TARGET(resources ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/resources && ln -sf ${CHROMIUM_DATADIR}/resources ../resources)
    ADD_CUSTOM_TARGET(themes ALL COMMAND ln -sf ${CHROMIUM_DATADIR}/themes && ln -sf ${CHROMIUM_DATADIR}/themes ../themes)
  ENDIF()

ENDIF(CHROME_FOUND)
