#import "../RWInteractionMetrics.h"
#include <math.h>
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    RWInteractionMetrics *m=[RWInteractionMetrics new];NSDictionary *home=@{@"screen":@"Home"};
    for(int i=1;i<=100;i++)[m add:@"touch_delivery_delay" seconds:i/1000. context:home];
    NSDictionary *snapshot=[m snapshot],*s=[RWInteractionMetrics summarize:snapshot][@"Home/touch_delivery_delay"];
    CHECK([s[@"window_samples"]intValue]==100);CHECK(fabs([s[@"p50_seconds"]doubleValue]-.050)<.000001);CHECK(fabs([s[@"p95_seconds"]doubleValue]-.095)<.000001);CHECK(![s[@"window_over_100ms"]intValue]);
    [m add:@"touch_delivery_delay" seconds:2 context:home];[m add:@"touch_delivery_delay" seconds:NAN context:home];[m add:@"touch_delivery_delay" seconds:-1 context:home];
    s=[RWInteractionMetrics summarize:[m snapshot]][@"Home/touch_delivery_delay"];CHECK([s[@"total_samples"]intValue]==101&&[s[@"window_over_100ms"]intValue]==1);CHECK([s[@"session_max_seconds"]doubleValue]==2);
    for(int i=0;i<1000;i++)[m add:@"touch_delivery_delay" seconds:.001 context:home];s=[RWInteractionMetrics summarize:[m snapshot]][@"Home/touch_delivery_delay"];CHECK([s[@"window_samples"]intValue]==128);CHECK([s[@"total_samples"]intValue]==1101);CHECK([s[@"session_max_seconds"]doubleValue]==2&&[s[@"window_max_seconds"]doubleValue]==.001);
    CHECK([snapshot[@"samples"][@"Home/touch_delivery_delay"]count]==100);CHECK([[RWInteractionMetrics summarize:snapshot][@"Home/touch_delivery_delay"][@"total_samples"]intValue]==100);
    for(int i=0;i<1000;i++)[m add:@"display_callback_interval" seconds:1./60 context:home];CHECK([[m snapshot][@"samples"][@"Home/display_callback_interval"]count]==720);
    [m add:@"touch_delivery_delay" seconds:.2 context:@{@"screen":@"Search"}];CHECK([[RWInteractionMetrics summarize:[m snapshot]][@"Search/touch_delivery_delay"][@"total_samples"]intValue]==1);
    for(int i=0;i<200;i++)[m add:[NSString stringWithFormat:@"unexpected%d",i] seconds:1 context:home];CHECK([[m snapshot][@"samples"]count]==96);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
