/*  Berkelium Implementation
 *  ContextImpl.cpp
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

#include "berkelium/Platform.hpp"
#include "berkelium/Protocol.hpp"

#include "content/browser/site_instance.h"
#include "Root.hpp"
#include "ContextImpl.hpp"

#include "base/utf_string_conversions.h"
#include "base/ref_counted.h"
#include "base/scoped_ptr.h"
#include "base/time.h"
#include "googleurl/src/gurl.h"
#include "net/base/filter.h"
#include "net/base/load_states.h"
#include "chrome/browser/profiles/profile.h"
#include "net/url_request/url_request.h"
#include "net/url_request/url_request_job.h"
#include "net/http/http_response_headers.h"
#include "net/base/io_buffer.h"
#include "net/base/net_errors.h"
#include "content/browser/in_process_webkit/session_storage_namespace.h"
#include "content/browser/in_process_webkit/webkit_context.h"
#include "content/browser/child_process_security_policy.h"


namespace Berkelium {
ContextImpl::ContextImpl(const ContextImpl&other) {
    init(other.mProfile, other.mSiteInstance, other.mSessionNamespace);
}
ContextImpl::ContextImpl(Profile *prof, SiteInstance*si, SessionStorageNamespace *ssn) {
    init(prof, si, ssn);
}
ContextImpl::ContextImpl(Profile *prof) {
    init(prof,
         SiteInstance::CreateSiteInstance(prof),
         new SessionStorageNamespace(prof));
}

void ContextImpl::init(Profile*prof, SiteInstance*si, SessionStorageNamespace *ssn) {
    mSiteInstance = si;
    mProfile = prof;
    mSessionNamespace = ssn;
}


ContextImpl::~ContextImpl() {
}
Context* ContextImpl::clone() const{
    return new ContextImpl(*this);
}
ContextImpl* ContextImpl::getImpl() {
    return this;
}
const ContextImpl* ContextImpl::getImpl() const{
    return this;
}

SchemeTable ContextImpl::schemes;

class ProtocolRequestJob : public net::URLRequestJob {
  public:
    explicit ProtocolRequestJob (net::URLRequest* request, Protocol * handler) 
      : net::URLRequestJob(request)
      , mHandler(handler)
      , mReadPos(0)
      , mURL(request->url()) {
    }

    static net::URLRequestJob* Factory (net::URLRequest* request, const std::string& scheme) {
      SchemeTable::iterator iter = ContextImpl::schemes.find(scheme);

      if (iter != ContextImpl::schemes.end())
        return new ProtocolRequestJob(request, iter->second);
      else
        return 0;
    }

    void Start () {
      std::wstring urlString;

      UTF8ToWide(mURL.spec().c_str(), mURL.spec().length(), &urlString);

      HGLOBAL bufferHandle = 0, headerHandle = 0;

      bool result = mHandler->HandleRequest(urlString.c_str(), urlString.length(), bufferHandle, headerHandle);

      if (bufferHandle) {
        mBuffer = std::string((const char *)bufferHandle, LocalSize(bufferHandle));
        LocalFree(bufferHandle);
      }
      if (headerHandle) {
        mHeaders = new net::HttpResponseHeaders(std::string((const char *)headerHandle, LocalSize(headerHandle)));
        LocalFree(headerHandle);
      }

      if (result) {
        this->NotifyHeadersComplete();
      } else {
        NotifyDone(
          net::URLRequestStatus(net::URLRequestStatus::FAILED, net::ERR_FILE_NOT_FOUND)
        );
      }
    }

    bool ReadRawData (net::IOBuffer* buf, int buf_size, int *bytes_read) {
      DCHECK(bytes_read);

      unsigned size = std::max<unsigned>(std::min<unsigned>(buf_size, mBuffer.length() - mReadPos), 0);

      if (size) {
        memcpy(buf->data(), mBuffer.c_str() + mReadPos, size);
        mReadPos += size;
      }

      *bytes_read = (int)size;
      return true;
    }

    void GetResponseInfo (net::HttpResponseInfo* info) {
      if (mHeaders)
        info->headers = mHeaders;
    }
    
    bool GetMoreData() {
      if (mReadPos < mBuffer.length())
        return true;
      else
        return false;
    }

    bool GetMimeType(std::string* mime_type) const { 
      return mHeaders->GetMimeType(mime_type);
    }

    bool GetURL(GURL *gurl) const {
      *gurl = mURL;
      return true;
    }

    virtual int GetResponseCode() const {
      return mHeaders->response_code();
    }

    virtual bool GetCharset(std::string* charset) { 
      return mHeaders->GetCharset(charset);
    }

  protected:
    Protocol * mHandler;
    scoped_refptr<net::HttpResponseHeaders> mHeaders;
    std::string mBuffer;
    unsigned mReadPos;
    GURL mURL;
};

void ContextImpl::registerProtocol (const char * scheme, size_t schemeLen, Protocol * handler) {
  std::string schemeStr(scheme, schemeLen);
  schemes[schemeStr] = handler;
  net::URLRequest::RegisterProtocolFactory(schemeStr, ProtocolRequestJob::Factory);
  ChildProcessSecurityPolicy::GetInstance()->GrantScheme(1, schemeStr);
}

void ContextImpl::unregisterProtocol (const char * scheme, size_t schemeLen) {
  std::string schemeStr(scheme, schemeLen);
  SchemeTable::iterator iter = schemes.find(schemeStr);
  if (iter != schemes.end())
    schemes.erase(iter);
}


}
