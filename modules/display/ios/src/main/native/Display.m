/*
 * Copyright (c) 2016, 2019 Gluon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GLUON BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include "Display.h"

extern JNIEnv *jEnv;
#define GET_MAIN_JENV \
if (jEnv == NULL) NSLog(@"ERROR: Java has been detached already, but someone is still trying to use it at %s:%s:%d\n", __FUNCTION__, __FILE__, __LINE__);\
JNIEnv *env = jEnv;

JNIEXPORT jint JNICALL
JNI_OnLoad_Display(JavaVM *vm, void *reserved)
{
#ifdef JNI_VERSION_1_8
    //min. returned JNI_VERSION required by JDK8 for builtin libraries
    JNIEnv *env;
    if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_8) != JNI_OK) {
        return JNI_VERSION_1_4;
    }
    return JNI_VERSION_1_8;
#else
    return JNI_VERSION_1_4;
#endif
}

static int DisplayInited = 0;

// Display
jclass mat_jDisplayServiceClass;
jmethodID mat_jDisplayService_notifyDisplay = 0;
Display *_display;

bool iPhoneX;

JNIEXPORT void JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_initDisplay
(JNIEnv *env, jclass jClass)
{
    if (DisplayInited)
    {
        return;
    }
    DisplayInited = 1;

    mat_jDisplayServiceClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "com/gluonhq/attach/display/impl/IOSDisplayService"));
    mat_jDisplayService_notifyDisplay = (*env)->GetMethodID(env, mat_jDisplayServiceClass, "notifyDisplay", "(Ljava/lang/String;)V");
    GLASS_CHECK_EXCEPTION(env);

    _display = [[Display alloc] init];
    [_display isIPhoneX];
}

JNIEXPORT jboolean JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_isIphone
(JNIEnv *env, jclass jClass)
{
    NSString *deviceModel = (NSString*)[UIDevice currentDevice].model;
    if ([[deviceModel substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"iPad"]) {
        return JNI_FALSE;
    } else {
        return JNI_TRUE;
    }
}

JNIEXPORT jdoubleArray JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_screenSize
(JNIEnv *env, jclass jClass)
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenSize = CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);

    jdoubleArray output = (*env)->NewDoubleArray(env, 2);
    if (output == NULL)
    {
        return NULL;
    }
    jdouble res[] = {screenSize.width, screenSize.height};
    (*env)->SetDoubleArrayRegion(env, output, 0, 2, res);
    return output;
}

JNIEXPORT jdoubleArray JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_screenBounds
(JNIEnv *env, jclass jClass)
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    jdoubleArray output = (*env)->NewDoubleArray(env, 2);
    if (output == NULL)
    {
        return NULL;
    }
    jdouble res[] = {screenBounds.size.width, screenBounds.size.height};
    (*env)->SetDoubleArrayRegion(env, output, 0, 2, res);
    return output;
}

JNIEXPORT jfloat JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_screenScale
(JNIEnv *env, jclass jClass)
{
    return [UIScreen mainScreen].scale;
}

JNIEXPORT jboolean JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_isNotchFound
(JNIEnv *env, jclass jClass)
{
    if (iPhoneX)
    {
        return JNI_TRUE;
    } else {
        return JNI_FALSE;
    }
}

JNIEXPORT void JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_startObserver
(JNIEnv *env, jclass jClass)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_display startObserver];
    });
    return;
}

JNIEXPORT void JNICALL Java_com_gluonhq_attach_display_impl_IOSDisplayService_stopObserver
(JNIEnv *env, jclass jClass)
{
    [_display stopObserver];
    return;   
}

void sendNotch() {
    GET_MAIN_JENV;
    NSString *notch = [_display getNotch];
    NSLog(@"Notch is %@", notch);
    const char *notchChars = [notch UTF8String];
    jstring arg = (*env)->NewStringUTF(env, notchChars);
    (*env)->CallVoidMethod(env, mat_jDisplayServiceClass, mat_jDisplayService_notifyDisplay, arg);
    (*env)->DeleteLocalRef(env, arg);
}

@implementation Display 

- (void) isIPhoneX 
{
    iPhoneX = NO;
    if ([[UIDevice currentDevice].model hasPrefix:@"iPhone"] &&
        [[UIScreen mainScreen] nativeBounds].size.height == 2436) 
    {
        iPhoneX = YES;
    }
}

- (void) startObserver 
{
    if (iPhoneX) 
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
        sendNotch();
    }
}

- (void) stopObserver 
{
    if (iPhoneX) 
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    }
}

- (NSString*) getNotch
{
    if (! iPhoneX) {
        return @"UNKNOWN";
    }

    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    NSMutableString *value; 
    if (orientation == UIDeviceOrientationPortraitUpsideDown)
        value = [NSMutableString stringWithString: @"BOTTOM"];
    else if (orientation == UIDeviceOrientationPortrait)
        value = [NSMutableString stringWithString: @"TOP"];
    else if (orientation == UIDeviceOrientationLandscapeLeft) // home button on the right side, notch to the left.
        value = [NSMutableString stringWithString: @"LEFT"];
    else if (orientation == UIDeviceOrientationLandscapeRight) // home button on the left side, notch to the right.
        value = [NSMutableString stringWithString: @"RIGHT"];
    else 
        value = [NSMutableString stringWithString: @"UNKNOWN"];
    return value;
}

-(void)OrientationDidChange:(NSNotification*)notification
{
    sendNotch();
}

@end
