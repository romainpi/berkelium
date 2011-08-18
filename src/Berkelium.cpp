/*  Berkelium - Embedded Chromium
 *  Berkelium.cpp
 *
 *  Copyright (c) 2009, Patrick Reiter Horn
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *  * Neither the name of Sirikata nor the names of its contributors may
 *    be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "berkelium/Berkelium.hpp"
#include "base/path_service.h"
#include "base/file_util.h"
#include "Root.hpp"

namespace Berkelium {

// See ForkedProcessHook.cpp for Berkelium::forkedProcessHook

bool initEx (FileString homeDirectory, FileString berkeliumPath) {
    if (berkeliumPath.size() > 0) {
        FilePath subprocess(berkeliumPath.get<FilePath::StringType>());
        subprocess = subprocess.AppendASCII("berkelium");
        PathService::Override(base::FILE_EXE, subprocess);
    }

    new Root();
    if (!Root::getSingleton().init(homeDirectory)) {
        Root::destroy();
        return false;
    }
    return true;
}
bool init (FileString homeDirectory) {
    return initEx(homeDirectory, FileString::empty());
}
void destroy () {
    Root::destroy();
}
void update () {
    Root::getSingleton().update();
}
void setErrorHandler (ErrorDelegate *errorHandler) {
    Root::getSingleton().setErrorHandler(errorHandler);
}

}
