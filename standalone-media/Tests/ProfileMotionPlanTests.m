#import "../RWProfileMotionPlan.h"
#include <math.h>
#include <stdio.h>
static int checks=0;
#define CHECK(x) do{checks++;if(!(x)){fprintf(stderr,"Motion check failed line%d\n",__LINE__);return 1;}}while(0)
int main(int argc,char **argv){@autoreleasepool{
    CHECK(!RWProfileMotionPlan(0,1024,NO).count);CHECK(!RWProfileMotionPlan(NAN,1024,YES).count);CHECK(!RWProfileMotionPlan(768,INFINITY,YES).count);
    NSMutableArray *plans=[NSMutableArray new];
    for(int orientation=0;orientation<2;orientation++)for(int kids=0;kids<2;kids++){
        double w=orientation?1024:768,h=orientation?768:1024;NSDictionary *p=RWProfileMotionPlan(w,h,kids);
        NSArray *layers=p[@"layers"];double duration=[p[@"duration"]doubleValue];CHECK(layers.count==(kids?12:14));CHECK(duration>2&&duration<2.5);NSUInteger shapesMoving=0;
        for(NSDictionary *layer in layers){NSArray *path=layer[@"path"],*frames=layer[@"frames"];CHECK(path.count>=4&&path.count<=32);CHECK(frames.count<=9);
            for(NSArray *point in path)for(NSNumber *v in point)CHECK(isfinite(v.doubleValue)&&fabs(v.doubleValue)<=512);
            double previous=-1;
            for(NSArray *frame in frames){CHECK(frame.count==7);double t=[frame[0]doubleValue];CHECK(t>previous&&t<=duration);previous=t;for(NSNumber *v in frame)CHECK(isfinite(v.doubleValue));CHECK([frame[3]doubleValue]>0&&[frame[4]doubleValue]>0);CHECK([frame[6]doubleValue]>=0&&[frame[6]doubleValue]<=1);}
            CHECK([frames.firstObject[0]doubleValue]==0);CHECK(fabs([frames.lastObject[0]doubleValue]-duration)<.001);CHECK([frames.lastObject[6]doubleValue]==0);
            NSArray *assembled=frames[kids?3:2];CHECK([assembled[1]doubleValue]>0&&[assembled[1]doubleValue]<w);CHECK([assembled[2]doubleValue]>0&&[assembled[2]doubleValue]<h);
            CHECK(fabs([assembled[3]doubleValue]-1)<.001&&fabs([assembled[4]doubleValue]-1)<.001);
            shapesMoving+=fabs([frames.firstObject[1]doubleValue]-[assembled[1]doubleValue])+fabs([frames.firstObject[2]doubleValue]-[assembled[2]doubleValue])>w*.3;
        }CHECK(shapesMoving==layers.count);[plans addObject:p];
    }
    if(argc>1){NSData *json=[NSJSONSerialization dataWithJSONObject:plans options:NSJSONWritingPrettyPrinted error:nil];CHECK([json writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES]);}
    printf("{\"checks\":%d,\"failures\":0,\"scenes\":4}\n",checks);return 0;
}}
