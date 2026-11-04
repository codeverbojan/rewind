/* Bounded Wi-Fi power acceptance helper. Restores original AllowEnable.
 * No saved networks/passwords read or changed. No listener or permanent daemon.
 * ABI source: davidmurray/ios-reversed-headers MobileWiFi/WiFiManager.h. */
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netinet/in.h>
static volatile sig_atomic_t interrupted=0;
static void interrupt_run(int sig){(void)sig;interrupted=1;}
static double wall(void){struct timeval t;gettimeofday(&t,0);return t.tv_sec+t.tv_usec/1000000.;}
static int get_flags(int fd,short *flags){struct ifreq r={0};strcpy(r.ifr_name,"en0");if(ioctl(fd,SIOCGIFFLAGS,&r)<0)return -1;*flags=r.ifr_flags;return 0;}
static int inventory(void){struct ifaddrs *all=0;if(getifaddrs(&all)<0)return -1;int alternate=0;char seen[64][IFNAMSIZ]={{0}};int count=0;
 for(struct ifaddrs *i=all;i;i=i->ifa_next){if(!i->ifa_name)continue;int duplicate=0;for(int n=0;n<count;n++)if(!strcmp(seen[n],i->ifa_name))duplicate=1;
  if(!duplicate&&count<64){strncpy(seen[count++],i->ifa_name,IFNAMSIZ-1);printf("{\"event\":\"interface\",\"name\":\"%s\",\"up\":%s,\"loopback\":%s,\"running\":%s}\n",i->ifa_name,(i->ifa_flags&IFF_UP)?"true":"false",(i->ifa_flags&IFF_LOOPBACK)?"true":"false",(i->ifa_flags&IFF_RUNNING)?"true":"false");}
  if(i->ifa_addr&&strcmp(i->ifa_name,"en0")&&!(i->ifa_flags&IFF_LOOPBACK)&&(i->ifa_flags&IFF_UP)&&(i->ifa_addr->sa_family==AF_INET||(i->ifa_addr->sa_family==AF_INET6&&!IN6_IS_ADDR_LINKLOCAL(&((struct sockaddr_in6 *)i->ifa_addr)->sin6_addr))))alternate=1;
 }freeifaddrs(all);return alternate;
}

static int routable_en0(void){struct ifaddrs *all=0;if(getifaddrs(&all)<0)return -1;int found=0;for(struct ifaddrs *i=all;i;i=i->ifa_next){if(!i->ifa_addr||strcmp(i->ifa_name,"en0")||!(i->ifa_flags&IFF_UP))continue;if(i->ifa_addr->sa_family==AF_INET&&((struct sockaddr_in *)i->ifa_addr)->sin_addr.s_addr!=INADDR_ANY)found=1;if(i->ifa_addr->sa_family==AF_INET6&&!IN6_IS_ADDR_LINKLOCAL(&((struct sockaddr_in6 *)i->ifa_addr)->sin6_addr)&&!IN6_IS_ADDR_UNSPECIFIED(&((struct sockaddr_in6 *)i->ifa_addr)->sin6_addr))found=1;}freeifaddrs(all);return found;}
static void *manager;
static CFPropertyListRef (*copy_property)(void *,CFStringRef);
static void (*set_property)(void *,CFStringRef,CFPropertyListRef);
static int power(void){CFPropertyListRef value=copy_property(manager,CFSTR("AllowEnable"));if(!value)return -1;int state=-1;if(CFGetTypeID(value)==CFBooleanGetTypeID())state=CFBooleanGetValue(value);else if(CFGetTypeID(value)==CFNumberGetTypeID()){int n=-1;if(CFNumberGetValue(value,kCFNumberIntType,&n)&&(n==0||n==1))state=n;}CFRelease(value);return state;}
static void pump(double seconds){double began=wall();CFRunLoopRunInMode(kCFRunLoopDefaultMode,seconds,false);double left=seconds-(wall()-began);if(left>0&&!interrupted)usleep((useconds_t)(left*1000000));}
int main(int argc,char **argv){setbuf(stdout,0);signal(SIGPIPE,SIG_IGN);
 void *library=dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",RTLD_NOW|RTLD_LOCAL);
 void *(*create)(CFAllocatorRef,int)=library?dlsym(library,"WiFiManagerClientCreate"):0;
 copy_property=library?dlsym(library,"WiFiManagerClientCopyProperty"):0;set_property=library?dlsym(library,"WiFiManagerClientSetProperty"):0;
 if(!create||!copy_property||!set_property){fprintf(stderr,"symbols library=%d create=%d copy=%d set=%d\n",library!=0,create!=0,copy_property!=0,set_property!=0);return 2;}manager=create(kCFAllocatorDefault,0);if(!manager){fprintf(stderr,"create failed\n");return 2;}
 int original=power(),fd=socket(AF_INET,SOCK_DGRAM,0);short flags=0;if(original<0||fd<0||get_flags(fd,&flags)<0){fprintf(stderr,"state power=%d socket=%d errno=%d\n",original,fd,errno);if(fd>=0)close(fd);CFRelease(manager);return 2;}
 printf("{\"event\":\"status\",\"pid\":%d,\"uid\":%d,\"enabled\":%s,\"up\":%s,\"at\":%.6f}\n",getpid(),geteuid(),original?"true":"false",(flags&IFF_UP)?"true":"false",wall());
 int alternate=inventory();printf("{\"event\":\"routing_guard\",\"alternate_routable_interface\":%s}\n",alternate==0?"false":"true");
 if(argc==2&&!strcmp(argv[1],"status")){close(fd);CFRelease(manager);return alternate<0?2:0;}
 if(argc!=4||strcmp(argv[1],"offline")||geteuid()!=0||alternate!=0||original!=1||strlen(argv[3])!=36){close(fd);CFRelease(manager);return 3;}
 char *end=0;long duration=strtol(argv[2],&end,10);if(!end||*end||duration<30||duration>120){close(fd);CFRelease(manager);return 3;}
 for(int i=0;i<36;i++)if(!strchr("0123456789abcdef-",argv[3][i])){close(fd);CFRelease(manager);return 3;}
 signal(SIGTERM,interrupt_run);signal(SIGINT,interrupt_run);signal(SIGHUP,interrupt_run);signal(SIGALRM,interrupt_run);alarm((unsigned)duration+10);
 CFPropertyListRef originalValue=copy_property(manager,CFSTR("AllowEnable"));if(!originalValue){alarm(0);close(fd);CFRelease(manager);return 2;}set_property(manager,CFSTR("AllowEnable"),kCFBooleanFalse);int error=0;
 double ready_limit=wall()+5;while(wall()<ready_limit&&!interrupted){if(power()==0&&routable_en0()==0)break;pump(.1);}
 get_flags(fd,&flags);printf("{\"event\":\"offline_observation\",\"enabled_value\":%d,\"up\":%s,\"routable_en0\":%d}\n",power(),(flags&IFF_UP)?"true":"false",routable_en0());if(power()!=0||routable_en0()!=0)error=1;
 if(!error){printf("{\"event\":\"offline_ready\",\"run\":\"%s\",\"pid\":%d,\"at\":%.6f,\"maximum_seconds\":%ld}\n",argv[3],getpid(),wall(),duration);
  double until=wall()+duration;while(wall()<until&&!interrupted){pump(1);if(power()!=0||routable_en0()!=0){error=2;break;}printf("{\"event\":\"offline_check\",\"at\":%.6f,\"enabled\":false,\"routable_en0\":false}\n",wall());}
 }
 set_property(manager,CFSTR("AllowEnable"),originalValue);CFRelease(originalValue);
 double restore_limit=wall()+15;while(wall()<restore_limit){if(power()==original&&get_flags(fd,&flags)==0&&(flags&IFF_UP))break;pump(.1);}
 int restored=power()==original&&get_flags(fd,&flags)==0&&(flags&IFF_UP);alarm(0);
 printf("{\"event\":\"restored\",\"run\":\"%s\",\"at\":%.6f,\"ok\":%s,\"error\":%d}\n",argv[3],wall(),restored?"true":"false",error);
 close(fd);CFRelease(manager);return !restored?5:error?4:0;
}
