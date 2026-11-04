// Rewind-only lab helper. No persistent process, touch injection or lock bypass.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <signal.h>
#include <unistd.h>
#include <notify.h>
static void wakeRequest(void *library){
    usleep(500000);printf("request_wake_result=%u\n",notify_post("org.local.rewind.device-exercise"));
}
int main(int argc,char **argv){@autoreleasepool{
    alarm(12);
    void *library=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
    mach_port_t (*port)(void)=dlsym(library,"SBSSpringBoardServerPort");
    void (*locked)(mach_port_t,BOOL *,BOOL *)=dlsym(library,"SBGetScreenLockStatus");
    int (*launch)(CFStringRef,Boolean)=dlsym(library,"SBSLaunchApplicationWithIdentifier");
    if(!library||!port||!locked||!launch)return 2;
    BOOL screenLocked=YES,passcode=YES;locked(port(),&screenLocked,&passcode);
    CFStringRef (*front)(void)=dlsym(library,"SBSCopyFrontmostApplicationDisplayIdentifier");
    CFStringRef frontID=front?front():NULL;BOOL rewindFront=frontID&&CFEqual(frontID,CFSTR("org.local.ministreamlab"));if(frontID)CFRelease(frontID);
    printf("locked=%d passcode=%d front_is_rewind=%d\n",screenLocked,passcode,rewindFront);fflush(stdout);
    if(argc==2&&!strcmp(argv[1],"screenshot")){
        if(screenLocked||!rewindFront)return 8;
        UIImage *(*capture)(void)=dlsym(RTLD_DEFAULT,"_UICreateScreenUIImage");
        if(!capture)capture=dlsym(RTLD_DEFAULT,"UICreateScreenUIImage");if(!capture)return 9;
        UIImage *screen=capture();NSData *png=screen?UIImagePNGRepresentation(screen):nil;
        return png&&[png writeToFile:@"/var/mobile/Media/RewindLab/screen.png" atomically:YES]?0:10;
    }
    if(argc==2&&!strcmp(argv[1],"launch")){
        if(screenLocked&&passcode){fprintf(stderr,"Unlock the iPad before the Rewind test.\n");return 3;}
        if(screenLocked){
            // iOS 9 has the three-argument ABI. Device and user confirmed this
            // wakes/unlocks this passcode-free iPad and opens Rewind.
            int (*open)(NSString *,NSDictionary *,BOOL)=dlsym(library,"SBSLaunchApplicationWithIdentifierAndLaunchOptions");
            NSString **unlock=dlsym(library,"SBSApplicationLaunchOptionUnlockDeviceKey");
            void (*undim)(void)=dlsym(library,"SBSUndimScreen");
            if(!open||!unlock||!*unlock)return 5;if(undim)undim();
            int result=open(@"org.local.ministreamlab",@{*unlock:@YES},NO);
            printf("launch_without_passcode_result=%d\n",result);if(!result)wakeRequest(library);return result?6:0;
        }
        int result=launch(CFSTR("org.local.ministreamlab"),false);printf("launch_result=%d\n",result);if(!result)wakeRequest(library);return result?4:0;
    }return 0;
}}
