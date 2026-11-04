#import "RWProfileMotionPlan.h"
#include <math.h>

static NSArray *Frame(double t,double x,double y,double sx,double sy,double r,double a) {
    return @[@(t),@(x),@(y),@(sx),@(sy),@(r),@(a)];
}
static NSArray *Petal(double w,double h,double radius) {
    NSMutableArray *points=[NSMutableArray new];
    double corners[4][2]={{w/2-radius,-h/2+radius},{w/2-radius,h/2-radius},{-w/2+radius,h/2-radius},{-w/2+radius,-h/2+radius}};
    for(int c=0;c<4;c++)for(int i=0;i<=6;i++){double a=(-M_PI/2+c*M_PI/2)+i*M_PI/12;[points addObject:@[@(corners[c][0]+cos(a)*radius),@(corners[c][1]+sin(a)*radius)]];}
    return points;
}
NSDictionary *RWProfileMotionPlan(double w,double h,BOOL kids) {
    if(!isfinite(w)||!isfinite(h)||w<1||h<1||w>4096||h>4096)return @{};
    double u=fmin(w,h)/768,cx=w/2,cy=h/2-30,duration=kids?2.35:2.25;
    NSMutableArray *layers=[NSMutableArray new];
    unsigned adult[]={0xf6bb69,0xf29a58,0xec794e,0xe95e48,0xd34f60,0xad4d83,0x795b9d,0x647dcc,0x419fb3,0x7475c9,0xa65f9d,0xd75e79,0xef7957,0xf5a85c};
    unsigned child[]={0x83debb,0x62c8b0,0xf2d787,0xf1b58a,0xf0a6b5,0xc2a4e2,0x92ace9,0x76cbd9,0x83debb,0xf2d787,0xf0a6b5,0x92ace9};
    NSUInteger count=kids?12:14;
    for(NSUInteger i=0;i<count;i++){
        NSArray *path,*frames;
        if(kids){
            double angle=-M_PI/2+i*2*M_PI/count,r=166*u,rotation=angle-M_PI/2;
            double x=cos(angle),y=sin(angle),start=fmax(w,h)*.92,delay=(i%4)*.035;
            path=Petal((i%2?46:56)*u,(i%2?108:124)*u,18*u);
            frames=@[Frame(0,cx+x*start,cy+y*start,.50,.55,rotation-.35,0),
                Frame(.06+delay,cx+x*start,cy+y*start,.50,.55,rotation-.35,1),
                Frame(.53+delay,cx+x*r*.82,cy+y*r*.82,1.05,1.08,rotation+.08,1),
                Frame(.76,cx+x*r,cy+y*r,1,1,rotation,1),
                Frame(1.00,cx+x*r,cy+y*r,1,1,rotation,1),
                Frame(1.40,cx+x*r*1.8,cy+y*r*1.8,1.9,2.1,rotation+.14,1),
                Frame(1.90,cx+x*r*3.0,cy+y*r*3.0,2.4,3.1,rotation+.22,1),
                Frame(2.35,cx+x*fmax(w,h)*1.8,cy+y*fmax(w,h)*1.8,3.3,4.2,rotation+.25,0)];
        }else{
            NSUInteger j=i%7,group=i/7;double left=(group?8:-252)*u,stride=232*u/7;
            double xa=left+j*stride+u*.65,xb=left+(j+1)*stride-u*.65,offset=(xa+xb)/2;
            double ha=144*(xa-left)/232,hb=144*(xb-left)/232;
            path=@[@[@(xa-offset),@(-ha)],@[@(xb-offset),@(-hb)],@[@(xb-offset),@(hb)],@[@(xa-offset),@(ha)]];
            double side=i%2?1:-1,delay=j*.015+group*.025;
            double startX=cx+(group?1:-1)*(w*.65+j*9*u),startY=cy+side*(h*.66);
            frames=@[Frame(0,startX,startY,.65,.45,side*.30,0),
                Frame(.05+delay,startX,startY,.65,.45,side*.30,1),
                Frame(.60+delay,cx+offset,cy,1,1,0,1),
                Frame(1.00,cx+offset,cy,1,1,0,1),
                Frame(1.32,cx+offset*2.0,cy,2.05,3.6,0,1),
                Frame(1.72,cx+offset*3.0,cy+side*22*u,2.8,7.0,0,1),
                Frame(2.25,cx+offset*22,cy+side*h*.45,4.2,12.0,0,0)];
        }
        [layers addObject:@{@"path":path,@"color":@(kids?child[i]:adult[i]),@"frames":frames}];
    }
    return @{@"style":kids?@"petals-assemble-burst":@"chevrons-assemble-flythrough",@"duration":@(duration),@"layers":layers,@"width":@(w),@"height":@(h),@"easing":@[@.22,@.70,@.30,@1],@"exitEasing":@[@.70,@0,@1,@1]};
}
