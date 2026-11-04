/* Bounded USB-only network acceptance helper. Never edits saved Wi-Fi settings.
 * status is read-only; offline temporarily clears en0 IFF_UP and restores it.
 * No daemon, listeners, account material or interface addresses in output. */
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
static int set_up(int fd,int up){struct ifreq r={0};strcpy(r.ifr_name,"en0");if(ioctl(fd,SIOCGIFFLAGS,&r)<0)return -1;r.ifr_flags=up?(r.ifr_flags|IFF_UP):(r.ifr_flags&~IFF_UP);return ioctl(fd,SIOCSIFFLAGS,&r);}
static int inventory(void){struct ifaddrs *all=0;if(getifaddrs(&all)<0)return -1;int alternate=0;char seen[64][IFNAMSIZ]={{0}};int count=0;
 for(struct ifaddrs *i=all;i;i=i->ifa_next){if(!i->ifa_name)continue;int duplicate=0;for(int n=0;n<count;n++)if(!strcmp(seen[n],i->ifa_name))duplicate=1;
  if(!duplicate&&count<64){strncpy(seen[count++],i->ifa_name,IFNAMSIZ-1);printf("{\"event\":\"interface\",\"name\":\"%s\",\"up\":%s,\"loopback\":%s,\"running\":%s}\n",i->ifa_name,(i->ifa_flags&IFF_UP)?"true":"false",(i->ifa_flags&IFF_LOOPBACK)?"true":"false",(i->ifa_flags&IFF_RUNNING)?"true":"false");}
  if(i->ifa_addr&&strcmp(i->ifa_name,"en0")&&!(i->ifa_flags&IFF_LOOPBACK)&&(i->ifa_flags&IFF_UP)&&(i->ifa_addr->sa_family==AF_INET||(i->ifa_addr->sa_family==AF_INET6&&!IN6_IS_ADDR_LINKLOCAL(&((struct sockaddr_in6 *)i->ifa_addr)->sin6_addr))))alternate=1;
 }freeifaddrs(all);return alternate;
}
int main(int argc,char **argv){setbuf(stdout,0);signal(SIGPIPE,SIG_IGN);int fd=socket(AF_INET,SOCK_DGRAM,0);short original=0;
 if(fd<0||get_flags(fd,&original)<0){printf("{\"event\":\"error\",\"errno\":%d}\n",errno);if(fd>=0)close(fd);return 2;}
 printf("{\"event\":\"status\",\"pid\":%d,\"uid\":%d,\"up\":%s,\"at\":%.6f}\n",getpid(),geteuid(),(original&IFF_UP)?"true":"false",wall());
 int alternate=inventory();printf("{\"event\":\"routing_guard\",\"alternate_routable_interface\":%s}\n",alternate==0?"false":"true");if(argc==2&&!strcmp(argv[1],"status")){close(fd);return alternate<0?2:0;}
 if(argc!=4||strcmp(argv[1],"offline")||geteuid()!=0||alternate!=0||!(original&IFF_UP)||strlen(argv[3])!=36){close(fd);return 3;}
 char *end=0;long duration=strtol(argv[2],&end,10);if(!end||*end||duration<30||duration>120){close(fd);return 3;}
 for(int i=0;i<36;i++)if(!strchr("0123456789abcdef-",argv[3][i])){close(fd);return 3;}
 signal(SIGTERM,interrupt_run);signal(SIGINT,interrupt_run);signal(SIGHUP,interrupt_run);signal(SIGALRM,interrupt_run);alarm((unsigned)duration);
 int error=0,down_result=set_up(fd,0);short current=0;
 if(down_result<0||get_flags(fd,&current)<0||(current&IFF_UP))error=1;
 if(!error){printf("{\"event\":\"offline_ready\",\"run\":\"%s\",\"pid\":%d,\"at\":%.6f,\"maximum_seconds\":%ld}\n",argv[3],getpid(),wall(),duration);
  for(long second=0;second<duration&&!interrupted;second++){
   sleep(1);if(get_flags(fd,&current)<0||(current&IFF_UP)){error=2;break;}
   printf("{\"event\":\"offline_check\",\"at\":%.6f,\"up\":false}\n",wall());
  }
 }
 /* Restore the original UP bit even after a failed down/verification step. */
 int restored=set_up(fd,(original&IFF_UP)!=0)==0&&get_flags(fd,&current)==0&&((current&IFF_UP)==(original&IFF_UP));alarm(0);
 printf("{\"event\":\"restored\",\"run\":\"%s\",\"at\":%.6f,\"ok\":%s,\"error\":%d}\n",argv[3],wall(),restored?"true":"false",error);
 close(fd);return !restored?5:error?4:0;
}
