/*  Berkelium GLUT Embedding
 *  glut_demo.cpp
 *
 *  Copyright (c) 2009, Ewen Cheslack-Postava
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

#ifdef __APPLE__
#include <GLUT/glut.h>
#else
#include <GL/glut.h>
#endif

#include "berkelium/Berkelium.hpp"
#include "berkelium/Window.hpp"
#include "berkelium/WindowDelegate.hpp"
#include "berkelium/Context.hpp"

#include <string>
#include <cmath>
#include <cstring>

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#ifdef _WIN32
#include <time.h>
#include <windows.h>
#else
#include <sys/select.h>
#endif

using namespace Berkelium;

// Some global data:
// The Berkelium window, i.e. our web page
Window* bk_window = NULL;
// The delegate that handles window events
WindowDelegate* bk_delegate = NULL;
// Storage for a texture
unsigned int web_texture = 0;
// Bool indicating when we need to refresh the entire image
bool needs_full_refresh = true;
// Buffer used to store data for scrolling
char* scroll_buffer = NULL;

// Current angle for animations
float angle = 0;

// And some global constants
#define WIDTH 512
#define HEIGHT 512


void loadRandomPage() {
    if (bk_window == NULL)
        return;

    // Black out the page
    unsigned char black = 0;
    glBindTexture(GL_TEXTURE_2D, web_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, 3, 1, 1, 0,
        GL_LUMINANCE, GL_UNSIGNED_BYTE, &black);

    glutPostRedisplay();

    // And navigate to a new one
#define NUM_SITES 4
    static std::string sites[NUM_SITES] = {
        std::string("http://berkelium.org"),
        std::string("http://google.com"),
        std::string("http://xkcd.com"),
        std::string("http://slashdot.org")
    };

    needs_full_refresh = true;

    unsigned int x = rand() % NUM_SITES;
    std::string url = sites[x];
    bk_window->navigateTo(url.data(), url.length());
}

class GLUTDelegate : public WindowDelegate {
public:
    virtual void onPaint(Window *wini, const unsigned char *bitmap_in, const Rect &bitmap_rect,
        int dx, int dy, const Rect &scroll_rect) {

        glBindTexture(GL_TEXTURE_2D, web_texture);

        // If we've reloaded the page and need a full update, ignore updates
        // until a full one comes in.  This handles out of date updates due to
        // delays in event processing.
        if (needs_full_refresh) {
            if (bitmap_rect.left() != 0 ||
                bitmap_rect.top() != 0 ||
                bitmap_rect.right() != WIDTH ||
                bitmap_rect.bottom() != HEIGHT) {
                return;
            }

            glTexImage2D(GL_TEXTURE_2D, 0, 3, WIDTH, HEIGHT, 0,
                GL_BGRA, GL_UNSIGNED_BYTE, bitmap_in);
            glutPostRedisplay();
            needs_full_refresh = false;
            return;
        }


        // Now, we first handle scrolling. We need to do this first since it
        // requires shifting existing data, some of which will be overwritten by
        // the regular dirty rect update.
        if (dx != 0 || dy != 0) {
            // scroll_rect contains the Rect we need to move
            // First we figure out where the the data is moved to by translating it
            Berkelium::Rect scrolled_rect = scroll_rect.translate(-dx, -dy);
            // Next we figure out where they intersect, giving the scrolled
            // region
            Berkelium::Rect scrolled_shared_rect = scroll_rect.intersect(scrolled_rect);
            // Only do scrolling if they have non-zero intersection
            if (scrolled_shared_rect.width() > 0 && scrolled_shared_rect.height() > 0) {
                // And the scroll is performed by moving shared_rect by (dx,dy)
                Berkelium::Rect shared_rect = scrolled_shared_rect.translate(dx, dy);

                // Copy the data out of the texture
                glGetTexImage(
                    GL_TEXTURE_2D, 0,
                    GL_BGRA, GL_UNSIGNED_BYTE,
                    scroll_buffer
                );

                // Annoyingly, OpenGL doesn't provide convenient primitives, so
                // we manually copy out the region to the beginning of the
                // buffer
                int wid = scrolled_shared_rect.width();
                int hig = scrolled_shared_rect.height();
                for(int jj = 0; jj < hig; jj++) {
                    memcpy(
                        scroll_buffer + (jj*wid * 4),
                        scroll_buffer + ((scrolled_shared_rect.top()+jj)*WIDTH + scrolled_shared_rect.left()) * 4,
                        wid*4
                    );
                }

                // And finally, we push it back into the texture in the right
                // location
                glTexSubImage2D(GL_TEXTURE_2D, 0,
                    shared_rect.left(), shared_rect.top(),
                    shared_rect.width(), shared_rect.height(),
                    GL_BGRA, GL_UNSIGNED_BYTE, scroll_buffer
                );
            }
        }

        // Finally, we perform the main update, just copying the rect that is
        // marked as dirty but not from scrolled data.
        glTexSubImage2D(GL_TEXTURE_2D, 0,
            bitmap_rect.left(), bitmap_rect.top(),
            bitmap_rect.width(), bitmap_rect.height(),
            GL_BGRA, GL_UNSIGNED_BYTE, bitmap_in
        );

        glutPostRedisplay();
    }
};

void display( void )
{
    glClear( GL_COLOR_BUFFER_BIT );

    glPushMatrix();

    float scale = sinf( angle ) * 0.25f + 1.f;
    glScalef( scale, scale, 1.f );

    glRotatef(angle*2.f, 0.f, 0.f, 1.f);

    glColor3f(1.f, 1.f, 1.f);
    glBindTexture(GL_TEXTURE_2D, web_texture);
    glBegin(GL_QUADS);
    glTexCoord2f(0.f, 0.f); glVertex3f(-1.f, -1.f, 0.f);
    glTexCoord2f(0.f, 1.f); glVertex3f(-1.f,  1.f, 0.f);
    glTexCoord2f(1.f, 1.f); glVertex3f( 1.f,  1.f, 0.f);
    glTexCoord2f(1.f, 0.f); glVertex3f( 1.f, -1.f, 0.f);
    glEnd();

    glPopMatrix();

    glutSwapBuffers();
}

void reshape( int w, int h )
{
    glClearColor( .3, .3, .3, 1 );

    glEnable(GL_TEXTURE_2D);
    glShadeModel(GL_SMOOTH);

    glMatrixMode( GL_PROJECTION );
    glLoadIdentity();

    glOrtho( -1.f, 1.f, 1.f, -1.f, -1.f, 1.f );
    glViewport( 0, 0, w, h );

    glutPostRedisplay();
}

void keyboard( unsigned char key, int x, int y )
{
    if (key == 27 || key == 'q') { // ESC
        delete bk_window;
        delete bk_delegate;

        Berkelium::destroy();

        delete scroll_buffer;

        exit(0);
    }
    else if (key == 'n' || key == ' ') {
        loadRandomPage();
    }

    glutPostRedisplay();
}

void special_keyboard(int key, int x, int y) {
    if (key == GLUT_KEY_LEFT)
        bk_window->mouseWheel(20, 0);
    else if (key == GLUT_KEY_RIGHT)
        bk_window->mouseWheel(-20, 0);
    else if (key == GLUT_KEY_UP)
        bk_window->mouseWheel(0, 20);
    else if (key == GLUT_KEY_DOWN)
        bk_window->mouseWheel(0, -20);

    glutPostRedisplay();
}

// FIXME we're using idle and sleep because the GLUT and Chromium message loops
// seem to conflict when using GLUT timers
void idle() {
    {
#ifdef _WIN32
        Sleep(30);
#else
        struct timeval tv;
        tv.tv_sec = 0;
        tv.tv_usec = 30000;
        select(0,NULL,NULL,NULL, &tv);
#endif
    }

    Berkelium::update();

    angle = angle + .1f;
    if (angle > 360.f)
        angle = 0.f;

    glutPostRedisplay();
}

int main (int argc, char** argv) {

    // Create a GLUT window and setup callbacks
    glutInit(&argc, argv);
    glutInitDisplayMode( GLUT_RGBA | GLUT_DOUBLE );
    glutInitWindowSize( WIDTH, HEIGHT );
    glutCreateWindow( "Berkelium Demo" );
    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutKeyboardFunc(keyboard);
    glutSpecialFunc(special_keyboard);
    glutIdleFunc(idle);

    // Create texture to hold rendered view
    glGenTextures(1, &web_texture);
    glBindTexture(GL_TEXTURE_2D, web_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // Initialize Berkelium and create a window
    Berkelium::init();
    bk_window = Window::create();
    bk_delegate = new GLUTDelegate;
    bk_window->setDelegate( bk_delegate );
    bk_window->resize(WIDTH, HEIGHT);

    scroll_buffer = new char[WIDTH*HEIGHT*4];

    loadRandomPage();

    // Start the main rendering loop
    glutMainLoop();

    return 0;
}
