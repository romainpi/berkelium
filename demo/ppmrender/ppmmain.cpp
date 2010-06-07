/*  Berkelium sample application
 *  ppmmain.cpp
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
#include "berkelium/Window.hpp"
#include "berkelium/WindowDelegate.hpp"
#include "berkelium/Context.hpp"

#include <stdio.h>
#include <sys/types.h>
#ifdef _WIN32
#define sleep(x) Sleep(x*1000)
#include <time.h>
#include <windows.h>
#else
#include <sys/select.h>
#endif
#include <sstream>
#include <iostream>
#include <memory>

using namespace Berkelium;

class TestDelegate : public WindowDelegate {
    std::string mURL;
public:

    virtual void onAddressBarChanged(Window *win, const char*newURL,size_t newURLLength) {
        mURL = std::string(newURL,newURLLength);
        std::cout << "*** onAddressChanged to "<<mURL<<std::endl;
    }

    virtual void onStartLoading(Window *win, const char* newURL, size_t newURLLength) {
        std::cout << "*** Start loading "<<std::string(newURL,newURLLength)<<" from "<<mURL<<std::endl;
    }
    virtual void onLoad(Window *win) {
        sleep(1);
        win->resize(1280,1024);
        win->resize(500,400);
        win->resize(600,500);
        win->resize(1024,768);
/*
        sleep(3);
        std::cout << "*** onLoad "<<mURL<<std::endl;
        if (mURL.find("yahoo") != std::string::npos) {
            return;
        }
        if (mURL.find("google") == std::string::npos) {
            win->navigateTo("http://google.com");
            return;
        }
        if (mURL.find("yahoo") == std::string::npos) {
            win->navigateTo("http://yahoo.com");
        }
*/
    }
    virtual void onLoadError(Window *win, const char* error, size_t errorLength) {
        std::cout << "*** onLoadError "<<mURL<<": "<<std::string(error,errorLength)<<std::endl;
    }

    virtual void onResponsive(Window *win) {
        std::cout << "*** onResponsive "<<mURL<<std::endl;
    }

    virtual void onUnresponsive(Window *win) {
        std::cout << "*** onUnresponsive "<<mURL<<std::endl;
    }

    virtual void onPaint(Window *wini, const unsigned char *bitmap_in, const Rect &bitmap_rect,
                         int dx, int dy, const Rect &scroll_rect) {
        std::cout << "*** onPaint "<<mURL<<std::endl;
        static int call_count = 0;
        FILE *outfile;
        {
            std::ostringstream os;
            os << "/tmp/chromium_render_" << time(NULL) << "_" << (call_count++) << ".ppm";
            std::string str (os.str());
            outfile = fopen(str.c_str(), "wb");
        }
        const int width = bitmap_rect.width();
        const int height = bitmap_rect.height();

        fprintf(outfile, "P6 %d %d 255\n", width, height);
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                unsigned char r,g,b,a;
		b = *(bitmap_in++);
		g = *(bitmap_in++);
		r = *(bitmap_in++);
		a = *(bitmap_in++);
                fputc(r, outfile);  // Red
                //fputc(255-a, outfile);  // Alpha
                fputc(g, outfile);  // Green
                fputc(b, outfile);  // Blue
                //(pixel >> 24) & 0xff;  // Alpha
            }
        }
        fclose(outfile);
    }

    virtual void onBeforeUnload(Window *win, bool *proceed) {
        std::cout << "*** onBeforeUnload "<<mURL<<std::endl;
        *proceed = true;
    }
    virtual void onCancelUnload(Window *win) {
        std::cout << "*** onCancelUnload "<<mURL<<std::endl;
    }
    virtual void onCrashed(Window *win) {
        std::cout << "*** onCrashed "<<mURL<<std::endl;
    }

    virtual void onCreatedWindow(Window *win, Window *newWindow) {
        std::cout << "*** onCreatedWindow from source "<<mURL<<std::endl;
        newWindow->setDelegate(new TestDelegate);
    }

    virtual void onChromeSend(
        Window *win,
        WindowDelegate::Data message,
        const WindowDelegate::Data *contents,
        size_t numContents)
    {
        std::cout << "*** onChromeSend ("<<std::string(message.message,message.length)<<"):"<<std::endl;
        for (size_t iter=0;iter<numContents;++iter) {
            std::cout << "\t\'"<<std::string(contents[iter].message,
                                             contents[iter].length)<<"\'" <<std::endl;
        }
    }

    virtual void onPaintPluginTexture(
        Window *win,
        void* sourceGLTexture,
        const std::vector<Rect> srcRects, // relative to destRect
        const Rect &destRect) {}

////////// WIDGET FUNCTIONS //////////
    virtual void onWidgetCreated(Window *win, Widget *newWidget, int zIndex) {}
    virtual void onWidgetDestroyed(Window *win, Widget *newWidget) {}

    // Will be called before the first call to paint.
    virtual void onWidgetResize(
        Window *win,
        Widget *wid,
        int newWidth,
        int newHeight) {}

    // Never called for the main window.
    virtual void onWidgetMove(
        Window *win,
        Widget *wid,
        int newX,
        int newY) {}

    virtual void onWidgetPaint(
        Window *win,
        Widget *wid,
        const unsigned char *sourceBuffer,
        const Rect &rect,
        int dx, int dy,
        const Rect &scrollRect) {}
};
extern "C" void _chkstk() {}
#define WIDTH 1024
#define HEIGHT 768
int main (int argc, char **argv) {
    printf("RUNNING MAIN!\n");
    Berkelium::init();
    std::string url;
/*
    std::auto_ptr<Window> win(Window::create());
    win->resize(800,600);
    win->setDelegate(new TestDelegate);
    url = "http://web.archive.org/web/20080724161936/http://dunnbypaul.net/js_mouse/";
    win->navigateTo(url.data(),url.length());
    win->setTransparent(true); //false);
    //win->navigateTo("http://google.com");
    std::auto_ptr<Window> win2(Window::create());
    url = "http://slashdot.org";
    win2->resize(800,600);
    win2->setDelegate(new TestDelegate);
    win2->navigateTo(url.data(),url.length());
    std::auto_ptr<Window> win3(Window::create());
    url = "http://vegastrike.sourceforge.net";
    win3->resize(800,600);
    win3->setDelegate(new TestDelegate);
    win3->navigateTo(url.data(),url.length());
*/

    std::auto_ptr<Window> win4(Window::create());
    win4->resize(800,600);
    win4->setDelegate(new TestDelegate);
    if (argc < 2) {
        url="http://xkcd.com";
    } else {
        url=argv[1];
    }
    win4->navigateTo(url.data(),url.length());

    while(true) {
        Berkelium::update();
        {
#ifdef _WIN32
            Sleep(10);
#else
            struct timeval tv;
            tv.tv_sec = 0;
            tv.tv_usec = 10000;
			select(0,NULL,NULL,NULL, &tv);
#endif
        }
    }
    char *buffer = new char[WIDTH*HEIGHT*3];
    int retval=Berkelium::renderToBuffer(&buffer[0],WIDTH,HEIGHT);
    delete []buffer;
    return retval;
}
