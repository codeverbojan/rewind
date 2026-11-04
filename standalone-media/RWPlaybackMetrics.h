#import <Foundation/Foundation.h>
@interface RWPlaybackMetrics : NSObject
- (instancetype)initAtUptime:(double)uptime;
@property(nonatomic,readonly) NSString *sessionID;
- (void)setContext:(NSDictionary *)context;
- (void)setExpectedStartPosition:(double)position;
- (void)noteSeek;
- (void)beginAttemptAtUptime:(double)uptime;
- (void)markStage:(NSString *)stage uptime:(double)uptime;
- (void)recordEvent:(NSString *)event values:(NSDictionary *)values uptime:(double)uptime;
- (void)recordDiscovery:(NSDictionary *)discovery uptime:(double)uptime;
- (void)recordSourceOutcome:(NSDictionary *)outcome engine:(NSString *)engine uptime:(double)uptime;
- (void)recordLookupObservation:(NSDictionary *)observation quality:(NSInteger)quality uptime:(double)uptime;
- (void)recordAtUptime:(double)uptime position:(double)position ready:(BOOL)ready wantsPlay:(BOOL)wantsPlay frameVisible:(BOOL)frameVisible;
- (void)recordAtUptime:(double)uptime position:(double)position ready:(BOOL)ready wantsPlay:(BOOL)wantsPlay frameVisible:(BOOL)frameVisible seeking:(BOOL)seeking;
- (void)recordResources:(NSDictionary *)resources;
- (NSDictionary *)snapshot;
- (NSArray *)samples;
@end
