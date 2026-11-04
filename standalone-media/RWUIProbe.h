#import <UIKit/UIKit.h>
@interface RWUIProbe : NSObject
+ (instancetype)shared;
@property(nonatomic,copy) NSDictionary *context;
@property(nonatomic,assign) BOOL deviceExerciseActive;
- (void)resetMeasurements;
- (NSDictionary *)measurementSnapshot;
- (void)beginIntervalTrace;
- (NSArray *)intervalTrace;
- (void)wake;
- (void)stop;
- (void)work:(NSString *)kind started:(double)started;
- (void)transition:(NSString *)kind started:(double)started;
- (void)touchTimestamp:(double)timestamp dispatched:(double)dispatched finished:(double)finished context:(NSDictionary *)context;
@end
@interface RWApplication : UIApplication
@end
