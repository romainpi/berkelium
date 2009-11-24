# Berkelium Build Script
#
# Parameters:
#  BERKELIUM_CHROME_ROOT_SEARCH_PATHS - list of paths to search for berkelium in.  Should be absolute paths.
#
# Outputs:
#  BERKELIUM_CHROME_FOUND - TRUE if Chrome is found and berkelium will be built.

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
  SET(CHROME_ROOT_SEARCH_PATHS
    ${BERKELIUM_CHROME_ROOT_SEARCH_PATHS} # User provided search paths go first
    # Followed by a few reasonable choices within this directory
    ${BERKELIUM_TOP_LEVEL}/chrome
    ${BERKELIUM_TOP_LEVEL}/chromium
    ${BERKELIUM_TOP_LEVEL}/build/chromium
    ${BERKELIUM_TOP_LEVEL}/build/c
    )

  FOREACH(CHROME_ROOT_SEARCH_PATH ${CHROME_ROOT_SEARCH_PATHS})
    IF(EXISTS ${CHROME_ROOT_SEARCH_PATH})
      IF(NOT CHROME_ROOT)
        SET(CHROME_ROOT ${CHROME_ROOT_SEARCH_PATH})
      ENDIF()
    ENDIF()
  ENDFOREACH()
ENDIF()
FIND_PACKAGE(Chrome)

SET(BERKELIUM_CHROME_FOUND ${CHROME_FOUND})

IF(CHROME_FOUND)

  INCLUDE_DIRECTORIES(${BERKELIUM_TOP_LEVEL}/include ${CHROME_INCLUDE_DIRS})
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

  ADD_DEPENDENCIES(berkelium libberkelium)
  ADD_DEPENDENCIES(ppmrender libberkelium)

  IF(APPLE)
    ADD_LIBRARY(plugin_carbon_interpose SHARED ${CHROME_ROOT}/src/chrome/browser/plugin_carbon_interpose_mac.cc)
    SET_TARGET_PROPERTIES(plugin_carbon_interpose PROPERTIES COMPILE_FLAGS ${CHROMIUM_CFLAGS})
    SET_TARGET_PROPERTIES(plugin_carbon_interpose PROPERTIES LINK_FLAGS "-framework Carbon")
    TARGET_LINK_LIBRARIES(plugin_carbon_interpose -L. debug liblibberkelium_d.dylib optimized liblibberkelium.dylib )
    ADD_DEPENDENCIES(plugin_carbon_interpose libberkelium)

    ADD_CUSTOM_TARGET(plugin_carbon_interpose.dylib
                      DEPENDS plugin_carbon_interpose
                      COMMAND
                        ln -sf libplugin_carbon_interpose.dylib plugin_carbon_interpose.dylib &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/libplugin_carbon_interpose.dylib
                        ../plugin_carbon_interpose.dylib)

    SET(CHROMIUM_FRAMEWORK Chromium\ Framework.framework)
    ADD_CUSTOM_TARGET(ppmrender.app
                      COMMAND
                        mkdir -p ppmrender.app &&
                        mkdir -p ppmrender.app/Contents &&
                        mkdir -p ppmrender.app/Contents/Resources &&
                        mkdir -p ppmrender.app/Contents/Frameworks &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender.app ppmrender.app/Contents/Resources/Berkelium\ Helper.app &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender.app/Contents ppmrender.app/Contents/Frameworks/${CHROMIUM_FRAMEWORK} &&
                        mkdir -p ppmrender.app/Contents/MacOS &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/ppmrender ppmrender.app/Contents/MacOS &&
                        ln -sf berkelium ppmrender.app/Contents/MacOS &&
                        ln -sf ${CMAKE_CURRENT_BINARY_DIR}/berkelium ppmrender.app/Contents/MacOS/berkelium &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/chrome.pak ppmrender.app/Contents/Resources/chrome.pak &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/theme.pak ppmrender.app/Contents/Resources/theme.pak &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/linkCursor.png ppmrender.app/Contents/Resources/linkCursor.png  &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/renderer.sb ppmrender.app/Contents/Resources/renderer.sb &&
                        ln -sf ${CHROME_ROOT}/src/xcodebuild/Release/${CHROMIUM_FRAMEWORK}/Resources/en_US.lproj ppmrender.app/Contents/Resources/en_US.lproj)

    ADD_CUSTOM_TARGET(osx ALL DEPENDS ppmrender.app)
    ADD_CUSTOM_TARGET(osx-install DEPENDS plugin_carbon_interpose.dylib chrome.pak Versions)
  ENDIF()

ENDIF(CHROME_FOUND)
