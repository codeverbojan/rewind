#import <Foundation/Foundation.h>
// Fixed, bounded local test recipes. Requests arrive through app file sharing;
// URLs only wake the app and cannot supply commands or authentication.
@interface RWDeviceExercise : NSObject
+ (NSDictionary *)lifecycleSource:(NSString *)backend;
+ (BOOL)isLifecycleSource:(id)source backend:(NSString *)backend;
+ (NSDictionary *)recoverySource;
+ (BOOL)isRecoverySource:(id)source;
+ (BOOL)preparedHeader:(id)diagnostics matchesIdentity:(id)identity;
+ (NSDictionary *)preparedHeaderRead:(id)diagnostics matchesIdentity:(id)identity;
+ (BOOL)isManualCaptionChoice:(id)choice source:(id)source videoID:(NSString *)videoID;
+ (NSDictionary *)playbackCase:(NSString *)key;
+ (BOOL)isOfflineExerciseSource:(id)source;
+ (BOOL)isEpisodeExerciseSource:(id)source videoID:(NSString *)videoID;
+ (BOOL)isResumeTorrentSource:(id)source;
+ (NSArray *)stepsForRequest:(id)request build:(NSInteger)build now:(double)now;
+ (NSDictionary *)profilePairForState:(NSDictionary *)state;
+ (BOOL)ownsAudioCompanion:(id)profile parent:(id)parent build:(NSInteger)build;
+ (BOOL)ownsResumeProfile:(id)profile build:(NSInteger)build;
+ (BOOL)ownsKidsProfile:(id)profile build:(NSInteger)build run:(NSString *)run;
@end
