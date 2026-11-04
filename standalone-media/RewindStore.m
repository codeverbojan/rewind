#import "RWEpisodeFetcher.h"
#import "RWEpisodeCatalog.h"
#import "RWReminderPolicy.h"
#import "RWUpcomingPolicy.h"
#import "RWUpcomingSelection.h"
#import "RWHomePreparation.h"
#import "RWHomeRailPolicy.h"
#import "RWHomeCategoryPolicy.h"
#import "RWHomeDeferredPreparation.h"
#import "RWEntityCreditPolicy.h"
#import "RWDiscoveryCandidatePolicy.h"
#import "RWRecommendationSignals.h"
#import "RWArtworkLoader.h"
#import "RWArtworkPolicy.h"
#import "RWMetadataBudget.h"
#import "RWLocalCatalog.h"
#import "RWUIProbe.h"
#import "RWSourceCache.h"
#import "RWSourceExperience.h"
#import "RWAvailability.h"
#import "RWAvailabilityCache.h"
#import "RWViewingSignals.h"
#import "RWRecommendationPolicy.h"
#import "RWDiscoveryCatalog.h"
#import "RWHomeDelivery.h"
#import "RWDiscoveryEpisodes.h"
#import "RWDiscoverySnapshot.h"
#import "RWExploreIndex.h"
#import "RWEntityDetailsPolicy.h"
#import "RWEntitySearchPolicy.h"
#import "RWOfflineMedia.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RewindStore.h"
#import "RWMediaIdentity.h"
#import "RWSourcePolicy.h"
#import "RWSourceWork.h"
#import "RWMediaCache.h"
#import "RWProfiles.h"
#import "RWRatingPolicy.h"
#import "RWSkipPolicy.h"
#import "RWTrailers.h"
#import "RWTVPolicy.h"
#import "RWCatalogPolicy.h"
#import "RWRequestCoalescer.h"
#import "RWAtomicWriter.h"
#import "RWStateSaveScheduler.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

NSString *RWString(id value) { return [value isKindOfClass:NSString.class] ? value : ([value isKindOfClass:NSNumber.class] ? [value stringValue] : @""); }
NSString *RWID(NSDictionary *meta) { NSString *s=RWString(meta[@"id"]); return s.length?s:RWString(meta[@"imdb_id"]); }
NSString *RWDocuments(void) { return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0]; }
NSString *RWTime(double seconds) { if (!isfinite(seconds)||seconds<0) seconds=0; int t=(int)seconds; return t>=3600?[NSString stringWithFormat:@"%d:%02d:%02d",t/3600,(t/60)%60,t%60]:[NSString stringWithFormat:@"%d:%02d",t/60,t%60]; }
static NSString *Esc(NSString *s) { return [s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]]; }
static NSString *Key(NSString *s) { unsigned char hash[CC_SHA256_DIGEST_LENGTH]; NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding]; CC_SHA256(d.bytes,(CC_LONG)d.length,hash); NSMutableString *r=[NSMutableString new];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[r appendFormat:@"%02x",hash[i]];return r; }
static NSDictionary *ReadJSON(NSString *path) { NSData *d=[NSData dataWithContentsOfFile:path];id j=d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil;return [j isKindOfClass:NSDictionary.class]?j:nil; }

// The view owns this binding. Reuse or destruction cancels its interest in a
// shared transfer without cancelling another view's request for the same source.
@interface RWArtworkBinding : NSObject
@property(nonatomic,weak) RWArtworkLoader *loader;
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSArray *urls;
@property(nonatomic,copy) NSString *role,*identity,*profile;
@property(nonatomic,copy) void(^completion)(BOOL);
@property(nonatomic,assign) BOOL finished,paused,covered;
@end
@implementation RWArtworkBinding
- (void)dealloc {[self.loader cancel:self.token];}
@end
@implementation RewindStore {
    RWArtworkLoader *_artworkLoader;NSUInteger _artworkGeneration;NSMutableArray *_artworkSamples,*_artworkHeroSamples;NSHashTable *_artworkViews;double _artworkCooldown;
    NSMutableDictionary *_diagnostics,*_stateSaveReasons;NSUInteger _stateSaveRejected;RWStateSaveScheduler *_stateSaveScheduler;
    NSString *_imageFolder;
    NSDictionary *_bundledArtwork;
    RWSourceCache *_sourceCache;
    RWSourceWork *_sourceWork;
    RWRequestCoalescer *_jsonRequests, *_streamRequests;
    NSCache *_detailCache;

    BOOL _reportScheduled,_checkingAvailability,_homeAvailabilityVisible;NSUInteger _availabilityWatchGeneration;NSString *_homeAvailabilityType;
    NSDictionary *_offlineEvidence;double _offlineEvidenceAt;
    NSMutableDictionary *_discoveryRatings;NSUInteger _discoveryGeneration;
    BOOL _discoveryScheduled,_discoveryPaused,_homeAvailabilityBusy,_candidateBusy,_homePublicationRequested,_homeRefreshRequested;
    NSUInteger _candidateGeneration;NSString *_candidateOwner;
    NSArray *_homeRefreshBatch;NSMutableSet *_homeRefreshFinished;NSDictionary *_homeRefreshBatchScope;
    NSUInteger _homeGeneration,_homeCompleted;NSMutableDictionary *_homeSnapshots;NSMutableArray *_homeRefreshAudit;NSMutableDictionary *_homeMetadataAttempts;
    RWDiscoveryEpisodes *_discoveryEpisodes;NSArray *_discoveryPrepared;NSDictionary *_discoveryContext,*_homePreparedMetadata;
    dispatch_queue_t _recommendationQueue;NSOperation *_relatedWork;
    NSDictionary *_publisherSources;
    NSArray *_upcomingRequests;NSUInteger _upcomingRequestIndex,_upcomingDays,_upcomingTargetDays;NSString *_upcomingDay;BOOL _upcomingVisible;double _upcomingChecked,_upcomingRetryAfter,_upcomingRequestBegan;NSMutableDictionary *_upcomingFailures;NSMutableArray *_upcomingTrace;
    RWEpisodeFetcher *_episodeFetcher;NSDictionary *_lastEpisodeFetch;RWTrailers *_trailers; NSURLSession *_episodeSession; BOOL _checkingEpisodes; NSMutableDictionary *_seriesCache; RWEpisodeCatalog *_episodeCatalog;NSMutableArray *_homeRailRejections,*_homeRailEvents;
}
+ (instancetype)shared { static RewindStore *s;static dispatch_once_t once;dispatch_once(&once,^{s=[RewindStore new];});return s; }
- (instancetype)init {
    if ((self=[super init])) {
        double startupBegan=NSProcessInfo.processInfo.systemUptime;
        [RWSourcePolicy setLegacyEnabled:[NSUserDefaults.standardUserDefaults boolForKey:@"RWLegacyQualified373"]];
        [RWSourcePolicy setNativeSurroundEnabled:[NSUserDefaults.standardUserDefaults boolForKey:@"RWNativeSurroundQualified"]];
        self.state=[ReadJSON([RWDocuments() stringByAppendingPathComponent:@"rewind-state.json"]) mutableCopy]?:[NSMutableDictionary new];
        for(NSString *key in @[@"history",@"sources",@"intros",@"sourceHealth",@"segmentCache"])if(![self.state[key] isKindOfClass:NSDictionary.class])self.state[key]=[NSMutableDictionary new];
        if(![self.state[@"saved"] isKindOfClass:NSArray.class])self.state[@"saved"]=[NSMutableArray new];
        if(![self.state[@"addons"] isKindOfClass:NSArray.class])self.state[@"addons"]=[NSMutableArray new];
        for(NSString *key in @[@"keptDownloads",@"hidden"])if(![self.state[key]isKindOfClass:NSArray.class])self.state[key]=[NSMutableArray new];
        if(!RWString(self.state[@"subtitleLanguage"]).length)self.state[@"subtitleLanguage"]=@"en";
        if(!self.state[@"subtitlesEnabled"])self.state[@"subtitlesEnabled"]=@YES;
        for(NSDictionary *r in [self.state[@"history"]allValues]){NSDictionary *source=r[@"source"];NSString *hash=RWString(source[@"infoHash"]);
            if(hash.length&&[source[@"verifiedWidth"]intValue]>0&&[r[@"position"]doubleValue]>5&&!self.state[@"sourceHealth"][hash])self.state[@"sourceHealth"][hash]=@{@"success":r[@"updated"]?:@0};}
        [RWProfiles prepare:self.state];
        double compactBegan=NSProcessInfo.processInfo.systemUptime;
        [RWAvailabilityCache compactState:self.state];
        double ownershipBegan=NSProcessInfo.processInfo.systemUptime;
        NSUInteger ownedAvailability=[RWAvailabilityCache prepareSnapshots:self.state];
        double ownershipSeconds=NSProcessInfo.processInfo.systemUptime-ownershipBegan;
        [[RWUIProbe shared]work:@"availability_cache_compact" started:compactBegan];
        // Old fixed deadlines and cache-only health checks were recorded as
        // source failures. Clear their ten-minute penalties once after fixing
        // those decisions; future source failures keep their normal cooldown.
        if([NSUserDefaults.standardUserDefaults integerForKey:@"RWPlaybackPolicyVersion"]<23){
            for(NSString *hash in [self.state[@"sourceHealth"]allKeys]){NSMutableDictionary *health=[self.state[@"sourceHealth"][hash]mutableCopy];[health removeObjectForKey:@"failure"];self.state[@"sourceHealth"][hash]=health;}
            [NSUserDefaults.standardUserDefaults setInteger:23 forKey:@"RWPlaybackPolicyVersion"];[self saveForReason:NSStringFromSelector(_cmd)];
        }
        NSString *resources=[[NSBundle mainBundle] resourcePath];
        self.ratings=[[RWRatings alloc]initWithCache:[RWDocuments()stringByAppendingPathComponent:@"rewind-ratings.json"] bundled:[resources stringByAppendingPathComponent:@"Rewind/rating-entities.json"]];
        _seriesCache=[NSMutableDictionary new];_episodeCatalog=[[RWEpisodeCatalog alloc]initWithSnapshot:@{} now:NSDate.date.timeIntervalSince1970];_bundledArtwork=@{};_publisherSources=@{};
        self.familyCatalog=@[];self.movies=@[];self.series=@[];self.freshMovies=@[];self.freshSeries=@[];self.curatedMovies=@[];self.curatedSeries=@[];self.openFilms=@[];self.discoveryCatalog=@[];self.upcomingCatalog=@[];
        _homeSnapshots=[NSMutableDictionary new];self.discoveryHome=@{};_discoveryRatings=[NSMutableDictionary new];_discoveryPaused=YES;[RWMetadataBudget shared].backgroundPaused=YES;_discoveryEpisodes=[RWDiscoveryEpisodes new];_discoveryPrepared=@[];
        _recommendationQueue=dispatch_queue_create("org.rewind.recommendations",DISPATCH_QUEUE_SERIAL);
        self.imdbIndex=[[RWIMDbIndex alloc]initWithFolder:[RWDocuments()stringByAppendingPathComponent:@"RatingsIndex"] bundled:[resources stringByAppendingPathComponent:@"Rewind/imdb-ratings.sqlite"]];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(refreshDiscovery) name:@"RWDiscoveryMetadataUpdated" object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(imdbIndexUpdated) name:@"RWIMDbIndexUpdated" object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(refreshDiscovery) name:@"RWAvailabilityUpdated" object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(refreshDiscovery) name:@"RWRatingsUpdated" object:nil];
        NSURLSessionConfiguration *config=[NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest=18;config.timeoutIntervalForResource=30;config.HTTPMaximumConnectionsPerHost=3;
        config.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.30 (iPad; iOS 9)",@"Accept":@"application/json,image/*;q=0.8,*/*;q=0.5"};
        config.URLCache=[[NSURLCache alloc]initWithMemoryCapacity:2*1024*1024 diskCapacity:8*1024*1024 diskPath:@"RewindNetwork"];
        self.session=[NSURLSession sessionWithConfiguration:config];
        NSURLSessionConfiguration *episodes=[NSURLSessionConfiguration ephemeralSessionConfiguration];episodes.timeoutIntervalForRequest=8;episodes.timeoutIntervalForResource=10;episodes.HTTPMaximumConnectionsPerHost=2;_episodeSession=[NSURLSession sessionWithConfiguration:episodes];
        _artworkSamples=[NSMutableArray new];_artworkHeroSamples=[NSMutableArray new];_artworkViews=[NSHashTable weakObjectsHashTable];
        _jsonRequests=[RWRequestCoalescer new];_streamRequests=[RWRequestCoalescer new];
        _detailCache=[NSCache new];_detailCache.totalCostLimit=2*1024*1024;_detailCache.countLimit=16;
        self.catalogSearch=[[RWCatalogSearch alloc]initWithURLCache:config.URLCache];

        _trailers=[[RWTrailers alloc]initWithCache:[RWDocuments()stringByAppendingPathComponent:@"rewind-trailers.json"] bundled:[resources stringByAppendingPathComponent:@"Rewind/trailer-entities.json"]];_sourceCache=[[RWSourceCache alloc]initWithCapacity:16];_diagnostics=[NSMutableDictionary new];
        _imageFolder=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0] stringByAppendingPathComponent:@"RewindImages"];
        _artworkLoader=[[RWArtworkLoader alloc]initWithFolder:_imageFolder resources:[resources stringByAppendingPathComponent:@"Rewind"] configuration:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(pauseArtwork) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(resumeArtwork) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(clearMemory) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [self report:@{@"build":@([NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]integerValue]),@"launched":@YES,@"system":[UIDevice currentDevice].systemVersion,@"cpu_bits":@(sizeof(void*)*8)}];
        [self report:@{@"startup":@{@"critical_store_seconds":@(NSProcessInfo.processInfo.systemUptime-startupBegan),@"catalog_ready":@NO,@"availability_owned_records":@(ownedAvailability),@"availability_ownership_seconds":@(ownershipSeconds)}}];
        // Give UIKit the first profile frame before catalog parsing starts.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self loadLocalCatalog];});
    }return self;
}
- (void)loadLocalCatalog {
    NSString *resources=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Rewind"];
    [RWLocalCatalog loadDocuments:RWDocuments() resources:resources done:^(NSDictionary *data){
        double began=NSProcessInfo.processInfo.systemUptime;
        self->_seriesCache=[data[@"shows"]mutableCopy];self->_episodeCatalog=data[@"episodeCatalog"];self.familyCatalog=data[@"family"][@"items"]?:@[];self->_bundledArtwork=data[@"artwork"];[self->_artworkLoader setBundledArtwork:self->_bundledArtwork];self->_publisherSources=data[@"publishers"];
        self.movies=data[@"catalog"][@"movie"]?:@[];self.series=data[@"catalog"][@"series"]?:@[];self.freshMovies=data[@"fresh"][@"movie"]?:@[];self.freshSeries=data[@"fresh"][@"series"]?:@[];
        self.curatedMovies=data[@"curated"][@"movie"]?:@[];self.curatedSeries=data[@"curated"][@"series"]?:@[];self.openFilms=data[@"open"][@"movies"]?:@[];self.discoveryCatalog=data[@"candidates"][@"items"]?:@[];
        self.upcomingCatalog=[RWUpcomingPolicy merge:@[] incoming:data[@"upcoming"][@"items"] now:NSDate.date.timeIntervalSince1970];self->_upcomingDays=[RWUpcomingPolicy cachedDays:data[@"upcoming"] now:NSDate.date.timeIntervalSince1970];self->_upcomingChecked=self->_upcomingDays?[data[@"upcoming"][@"checked"]doubleValue]:0;self->_upcomingDay=RWString(data[@"upcoming"][@"day"]);
        self->_homeSnapshots=[data[@"home"][@"profiles"]mutableCopy]?:[NSMutableDictionary new];
        self.discoveryMetadata=[[RWDiscoveryMetadata alloc]initWithPath:[RWDocuments()stringByAppendingPathComponent:@"discovery-metadata.json"] cached:data[@"metadata"] seed:data[@"metadataSeed"]];self.discoveryMetadata.paused=self->_discoveryPaused;
        self.discoveryHome=[RWHomeDelivery restore:self->_homeSnapshots[self.state[@"activeProfile"]] profile:self.profile quality:self.quality now:NSDate.date.timeIntervalSince1970];self.catalogReady=YES;
        NSMutableDictionary *metrics=[self->_diagnostics[@"startup"]mutableCopy];[metrics addEntriesFromDictionary:data[@"metrics"]];metrics[@"apply_seconds"]=@(NSProcessInfo.processInfo.systemUptime-began);metrics[@"catalog_ready"]=@YES;[self report:@{@"startup":metrics}];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RWLocalCatalogReady" object:self];[self refreshDiscovery];
    }];
}
#include "RewindTVStore.inc"
#include "RewindAvailability.inc"
#include "RewindSearchStore.inc"
#include "RewindUpcomingStore.inc"
#include "RewindDiscoveryStore.inc"
- (NSMutableDictionary *)profile {return [RWProfiles active:self.state];}
- (BOOL)restricted {return [[self profile][@"maxAge"]integerValue]>=0;}
- (BOOL)allowed:(NSDictionary *)meta {
    if(![meta isKindOfClass:NSDictionary.class])return NO;NSInteger age=[[self profile][@"maxAge"]integerValue];
    if(![RWRatingPolicy allows:[self.ratings rating:RWID(meta)] age:age])return NO;
    if(age<0)return YES;
    // Ratings gate every entry point. Family/children genres select the Kids
    // catalog only after the rating passes; animation alone is not a rating.
    NSMutableDictionary *audience=[meta mutableCopy];NSDictionary *record=[self.discoveryMetadata record:RWID(meta)];if(record.count)audience[@"discovery"]=record;
    if([RWDiscoveryMetadataPolicy isAdultAudience:audience])return NO;
    if([RWDiscoveryMetadataPolicy isFamilyTitle:audience])return YES;
    for(NSDictionary *family in self.familyCatalog)if([RWID(family)isEqual:RWID(meta)]&&[RWDiscoveryMetadataPolicy isFamilyTitle:family])return YES;
    return NO;
}
- (NSArray *)allowedItems:(NSArray *)items {NSMutableArray *out=[NSMutableArray new];for(id m in items)if([self allowed:m])[out addObject:m];return out;}
- (void)switchProfile:(NSString *)identifier {if(!self.state[@"profiles"][identifier])return;[_episodeFetcher cancel];[self cancelRelatedTitles];[self cancelDiscoveryCandidates];self.state[@"activeProfile"]=identifier;[self clearHomeRefreshBatch];_artworkGeneration++;[_artworkLoader clearMemory];[_sourceCache removeAllObjects];[_homeMetadataAttempts removeAllObjects];_discoveryGeneration++;_homeGeneration++;_availabilityWatchGeneration++;_checkingAvailability=NO;self.discoveryHome=[RWHomeDelivery restore:_homeSnapshots[identifier] profile:self.profile quality:self.quality now:NSDate.date.timeIntervalSince1970];_discoveryPrepared=@[];[_discoveryEpisodes removeAll];_homePreparedMetadata=nil;_offlineEvidence=@{};_homeAvailabilityBusy=NO;[self.discoveryMetadata cancelPending];[self saveForReason:NSStringFromSelector(_cmd)];[self refreshDiscovery];}
- (void)feedback:(NSDictionary *)meta like:(BOOL)like {
    if(![self allowed:meta])return;NSMutableArray *liked=[[self profile][@"liked"]mutableCopy],*hidden=[[self profile][@"hidden"]mutableCopy];NSString *key=RWID(meta);
    NSIndexSet *old=[liked indexesOfObjectsPassingTest:^BOOL(NSDictionary *m,NSUInteger i,BOOL *stop){return [RWID(m)isEqual:key];}];BOOL wasLiked=old.count>0;[liked removeObjectsAtIndexes:old];
    if(like){[hidden removeObject:key];if(!wasLiked){NSMutableDictionary *signal=[meta mutableCopy];signal[@"discoveryLikedAt"]=@(NSDate.date.timeIntervalSince1970);[liked addObject:signal];}}else if(![hidden containsObject:key])[hidden addObject:key];
    [self profile][@"liked"]=liked;[self profile][@"hidden"]=hidden;[self saveForReason:NSStringFromSelector(_cmd)];[self refreshDiscovery];
}
#include "RewindSourceExperience.inc"
- (void)clearMemory { [self cancelDiscoveryCandidates];[self pauseArtwork];_artworkCooldown=NSProcessInfo.processInfo.systemUptime+30;NSUInteger artworkGeneration=_artworkGeneration;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(artworkGeneration==self->_artworkGeneration)[self resumeArtwork];});[_detailCache removeAllObjects];[self.catalogSearch clearCache];[self setDiscoveryPaused:YES];[self.discoveryMetadata cancelPending];[_discoveryRatings removeAllObjects];[_discoveryEpisodes removeAll];_homePreparedMetadata=nil;_discoveryPrepared=@[]; }
- (void)save {[self saveForReason:@"user_or_lifecycle"];}
- (void)saveForReason:(NSString *)reason {
    if(!_stateSaveReasons)_stateSaveReasons=[NSMutableDictionary new];
    _stateSaveReasons[reason]=@([_stateSaveReasons[reason]unsignedIntegerValue]+1);
    if(!_stateSaveScheduler){__weak RewindStore *weak=self;_stateSaveScheduler=[[RWStateSaveScheduler alloc]initWithPersist:^{[weak persistState];}];}
    BOOL backgroundObservation=[@[@"noteAvailability:videoID:sources:complete:error:",@"recordAvailabilityWatchCheck:videoID:",@"refreshHomeTargets:index:profile:generation:",@"noteDiscoveryExposure:",@"refreshDiscoveryCandidates"]containsObject:reason];
    [_stateSaveScheduler requestDeferred:backgroundObservation];
}
- (void)persistState {
    double began=NSProcessInfo.processInfo.systemUptime;
    NSDictionary *main=self.state[@"profiles"][@"main"];
    for(NSString *key in @[@"history",@"saved",@"sources",@"intros",@"quality",@"subtitleLanguage",@"subtitlesEnabled",@"subtitleSize",@"subtitleDelay"])if(main[key])self.state[key]=main[key];
    // Snapshot on the state's owning thread; conversion and atomic writing are
    // ordered together, including the background/automatic-close flush barrier.
    if(![[RWAtomicWriter shared]writeJSON:self.state path:[RWDocuments()stringByAppendingPathComponent:@"rewind-state.json"]])_stateSaveRejected++;
    [[RWUIProbe shared]work:@"state_snapshot" started:began];
}
- (void)report:(NSDictionary *)values {
    [_diagnostics addEntriesFromDictionary:values];_diagnostics[@"updated"]=@([NSDate date].timeIntervalSince1970);
    if(_reportScheduled)return;_reportScheduled=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
        self->_reportScheduled=NO;self->_diagnostics[@"metadata_budget"]=[RWMetadataBudget shared].diagnostics;
        self->_diagnostics[@"state_saves"]=@{@"reasons":[self->_stateSaveReasons copy]?:@{},@"rejected":@(self->_stateSaveRejected),@"deferred_pending":@(self->_stateSaveScheduler.pending)};self->_diagnostics[@"atomic_writer"]=[RWAtomicWriter shared].diagnostics;
        // Serialize a stable snapshot on main, once per batch. Atomic disk I/O
        // runs serially off main, so older reports cannot overwrite newer ones.
        double began=NSProcessInfo.processInfo.systemUptime;NSData *data=[NSJSONSerialization dataWithJSONObject:self->_diagnostics options:0 error:nil];[[RWUIProbe shared]work:@"diagnostic_encode" started:began];
        [[RWAtomicWriter shared]write:data path:[RWDocuments()stringByAppendingPathComponent:@"session-report.json"]];
    });
}
- (void)JSON:(NSString *)url done:(RWResult)done {[self JSON:url foreground:YES done:done];}
- (void)JSON:(NSString *)url foreground:(BOOL)foreground done:(RWResult)done {
    NSURL *u=[NSURL URLWithString:url];if(!u||![@[@"http",@"https"] containsObject:u.scheme.lowercaseString]){done(nil,@"Invalid web address");return;}
    NSString *requestKey=foreground?url:[@"background:" stringByAppendingString:url];
    [_jsonRequests perform:requestKey start:^(RWLookupResult finish){
    BOOL discoveryHost=[@[@"www.wikidata.org",@"api.tvmaze.com"]containsObject:u.host.lowercaseString];
    BOOL metadata=!foreground||discoveryHost||[u.host.lowercaseString isEqual:@"v3-cinemeta.strem.io"];__block NSURLSessionDataTask *task=nil;
    // Foreground is priority within the existing metadata budget, not a way
    // around it. Keep the same short discovery request timeout after promotion.
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:u];if(!foreground||discoveryHost)request.timeoutInterval=8;
    task=[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)response statusCode]:0;
        id result=nil;NSString *message=nil;
        if(error){message=error.code==NSURLErrorNotConnectedToInternet?@"The iPad is offline. Connect Wi-Fi and try again.":error.code==NSURLErrorTimedOut?@"The connection timed out. Try again.":(error.code<=NSURLErrorSecureConnectionFailed&&error.code>=NSURLErrorClientCertificateRequired)?@"A secure connection could not be established.":@"Cannot reach this service. Try again.";}
        else if(status<200||status>=300)message=[NSString stringWithFormat:@"The provider returned HTTP %ld.",(long)status];
        else if(data.length>5*1024*1024)message=@"The provider response is too large.";
        else{result=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if([result isKindOfClass:NSDictionary.class]&&[result[@"meta"]isKindOfClass:NSDictionary.class]&&[result[@"meta"][@"type"]isEqual:@"series"]){NSDictionary *owned=[RWDiscoveryEpisodes immutableShow:result[@"meta"]];if(owned){NSMutableDictionary *response=[result mutableCopy];response[@"meta"]=owned;result=[response copy];}}if([u.host isEqual:@"api.tvmaze.com"]&&[@[@"/schedule",@"/schedule/web"]containsObject:u.path]&&[result isKindOfClass:NSArray.class])result=@{@"episodes":result};if(![result isKindOfClass:NSDictionary.class]){result=nil;message=@"The provider returned an unreadable response.";}}
        dispatch_async(dispatch_get_main_queue(),^{if(metadata)[[RWMetadataBudget shared]complete:task];task=nil;if(error)[self report:@{@"network_last_failure":@{@"host":u.host?:@"",@"code":@(error.code),@"domain":error.domain?:@"",@"http":@(status)}}];finish(result,message);});
    }];if(metadata)[[RWMetadataBudget shared]enqueue:task foreground:foreground];else[task resume];
    } done:done];
}
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip done:(RWResult)done {[self browse:type sort:sort genre:genre year:year skip:skip foreground:YES done:done];}
- (void)browse:(NSString *)type sort:(NSString *)sort genre:(NSString *)genre year:(NSInteger)year skip:(NSUInteger)skip foreground:(BOOL)foreground done:(RWResult)done {
    NSString *url=[RWCatalogPolicy URLForType:type sort:sort genre:genre year:year skip:skip now:NSDate.date];
    if(!url){done(nil,@"Choose a valid release year.");return;}
    [self JSON:url foreground:foreground done:^(id result,NSString *error){
        NSArray *items=[result[@"metas"]isKindOfClass:NSArray.class]?result[@"metas"]:nil;
        if(items&&[sort isEqual:@"Newest"]&&!year&&!genre.length&&!skip){if([type isEqual:@"movie"])self.freshMovies=items;else self.freshSeries=items;
            NSData *d=[NSJSONSerialization dataWithJSONObject:@{@"movie":self.freshMovies,@"series":self.freshSeries} options:0 error:nil];[[RWAtomicWriter shared]write:d path:[RWDocuments()stringByAppendingPathComponent:@"rewind-current-catalog.json"]];}
        done(items,error);
    }];
}
- (void)catalog:(NSString *)type query:(NSString *)query genre:(NSString *)genre done:(RWResult)done {
    NSString *extra=query.length?[@"search=" stringByAppendingString:Esc(query)]:(genre.length?[@"genre=" stringByAppendingString:Esc(genre)]:@"skip=0");
    NSString *url=[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/catalog/%@/top/%@.json",Esc(type),extra];
    [self JSON:url foreground:query.length||genre.length done:^(id result,NSString *error){
        NSArray *items=[result[@"metas"] isKindOfClass:NSArray.class]?result[@"metas"]:nil;
        if(items){NSMutableArray *valid=[NSMutableArray new];for(id m in items)if([m isKindOfClass:NSDictionary.class]&&RWID(m).length&&RWString(m[@"name"]).length)[valid addObject:m];items=valid;
            if(!query.length&&!genre.length){if([type isEqualToString:@"movie"])self.movies=items;else self.series=items;
                NSData *d=[NSJSONSerialization dataWithJSONObject:@{@"movie":self.movies,@"series":self.series} options:0 error:nil];[[RWAtomicWriter shared]write:d path:[RWDocuments() stringByAppendingPathComponent:@"rewind-catalog.json"]];}
        }
        BOOL connected=items!=nil;
        if(query.length&&[type isEqual:@"movie"]){NSMutableArray *merged=[items mutableCopy]?:[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];for(NSDictionary *m in merged)[ids addObject:RWID(m)];
            for(NSDictionary *m in self.openFilms)if([RWString(m[@"name"])rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound&&![ids containsObject:RWID(m)])[merged addObject:m];
            if(merged.count)items=merged;
        }
        [self report:@{@"catalog_connected":@(connected)}];done(items,error);
    }];
}
- (NSDictionary *)cachedDetails:(NSDictionary *)meta {
    NSString *key=[RWString(meta[@"type"])stringByAppendingFormat:@":%@",RWID(meta)];
    NSDictionary *cached=[_detailCache objectForKey:key][@"meta"]?:[self cachedShow:RWID(meta)];
    if(!cached)return meta;NSMutableDictionary *merged=[meta mutableCopy];[merged addEntriesFromDictionary:cached];return merged;
}
- (void)details:(NSDictionary *)meta done:(RWResult)done {
    if([RWID(meta) hasPrefix:@"rw:"]){done(meta,nil);return;}
    NSString *key=[RWString(meta[@"type"])stringByAppendingFormat:@":%@",RWID(meta)];
    NSDictionary *cached=[_detailCache objectForKey:key];double began=NSProcessInfo.processInfo.systemUptime;
    if(cached&&began-[cached[@"time"]doubleValue]<([meta[@"type"]isEqual:@"series"]?180:600)){
        [self report:@{@"detail_lookup":@{@"id":RWID(meta),@"cached":@YES,@"seconds":@0}}];done([self cachedDetails:meta],nil);return;
    }
    NSString *url=[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/meta/%@/%@.json",Esc(RWString(meta[@"type"])),Esc(RWID(meta))];
    NSString *profileID=self.state[@"activeProfile"];[self JSON:url done:^(id result,NSString *error){
        NSMutableDictionary *merged=[[self cachedDetails:meta]mutableCopy];NSDictionary *full=result[@"meta"];
        if([full isKindOfClass:NSDictionary.class]&&[RWID(full)isEqual:RWID(meta)]){
            [merged addEntriesFromDictionary:full];NSUInteger bytes=[NSJSONSerialization dataWithJSONObject:full options:0 error:nil].length;
            if(bytes&&bytes<=512*1024)[self->_detailCache setObject:@{@"meta":full,@"time":@(NSProcessInfo.processInfo.systemUptime)} forKey:key cost:bytes];
            [self acceptShow:merged profile:profileID notify:NO];
        }
        [self report:@{@"detail_lookup":@{@"id":RWID(meta),@"cached":@NO,@"seconds":@(NSProcessInfo.processInfo.systemUptime-began),@"error":error?:@""}}];done(merged,error);
    }];
}
- (NSString *)canonicalArtworkURL:(NSString *)url {
    NSURLComponents *artwork=[NSURLComponents componentsWithString:url];
    if([artwork.host.lowercaseString isEqual:@"images.metahub.space"]){NSMutableArray *query=[NSMutableArray new];for(NSURLQueryItem *item in artwork.queryItems)if(![item.name isEqual:@"format"])[query addObject:item];[query addObject:[NSURLQueryItem queryItemWithName:@"format" value:@"jpg"]];artwork.queryItems=query;url=artwork.URL.absoluteString;}
    return url;
}
- (void)pauseArtwork {
    _artworkGeneration++;for(UIImageView *view in _artworkViews){RWArtworkBinding *binding=objc_getAssociatedObject(view,@selector(cancelArtwork:));if(binding&&!binding.finished)binding.paused=YES;}[_artworkLoader clearMemory];
}
- (void)setArtworkVisible:(BOOL)visible inView:(UIView *)root {
    for(UIImageView *view in _artworkViews.allObjects)if([view isDescendantOfView:root]){RWArtworkBinding *binding=objc_getAssociatedObject(view,@selector(cancelArtwork:));if(!binding)continue;binding.covered=!visible;if(!visible&&!binding.finished){binding.paused=YES;[_artworkLoader cancel:binding.token];}}
    if(visible)[self resumeArtwork];
}
- (void)resumeArtwork {
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||NSProcessInfo.processInfo.systemUptime<_artworkCooldown)return;
    for(UIImageView *view in _artworkViews.allObjects){RWArtworkBinding *binding=objc_getAssociatedObject(view,@selector(cancelArtwork:));if(!binding.paused||binding.covered||!view.window||![binding.profile isEqual:self.state[@"activeProfile"]])continue;
        CGRect visible=[view convertRect:view.bounds toView:view.window];BOOL hidden=view.hidden;for(UIView *parent=view.superview;parent;parent=parent.superview){hidden|=parent.hidden;if(parent.clipsToBounds||parent==view.window)visible=CGRectIntersection(visible,[parent convertRect:parent.bounds toView:view.window]);}
        if(!hidden&&!CGRectIsEmpty(visible)&&!CGRectIsNull(visible))[self artwork:binding.urls role:binding.role identity:binding.identity into:view completion:binding.completion];
    }
}
- (void)cancelArtwork:(UIImageView *)view {objc_setAssociatedObject(view,@selector(cancelArtwork:),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
- (void)artwork:(NSArray *)urls role:(NSString *)role identity:(NSString *)identity into:(UIImageView *)view completion:(void(^)(BOOL))completion {
    RWArtworkBinding *previous=objc_getAssociatedObject(view,@selector(cancelArtwork:));
    NSMutableArray *canonical=[NSMutableArray new];for(NSString *url in [RWArtworkPolicy validURLs:urls])[canonical addObject:[self canonicalArtworkURL:url]];
    // Keep a same-title preview during resize/metadata upgrades, but never leave
    // another title or profile's pixels on a reused view, even without a URL.
    BOOL sameOwner=previous&&[previous.profile isEqual:self.state[@"activeProfile"]]&&
        (identity.length?[previous.identity isEqual:identity]:(!previous.identity.length&&[previous.urls isEqual:canonical]));
    [self cancelArtwork:view];if(!sameOwner||!canonical.count)view.image=nil;
    if(!canonical.count){if(completion)completion(NO);return;}
    CGFloat scale=view.window.screen.scale?:UIScreen.mainScreen.scale;NSDictionary *request=[RWArtworkPolicy requestForRole:role identity:identity width:view.bounds.size.width height:view.bounds.size.height scale:scale];
    NSString *profile=[self.state[@"activeProfile"]copy];NSUInteger generation=_artworkGeneration;
    RWArtworkBinding *binding=[RWArtworkBinding new];binding.loader=_artworkLoader;binding.urls=canonical;binding.role=role;binding.identity=identity;binding.profile=profile;binding.completion=completion;[_artworkViews addObject:view];objc_setAssociatedObject(view,@selector(cancelArtwork:),binding,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||NSProcessInfo.processInfo.systemUptime<_artworkCooldown){binding.paused=YES;return;}
    __weak UIImageView *weak=view;__weak RWArtworkBinding *weakBinding=binding;
    binding.token=[_artworkLoader loadURLs:canonical request:request result:^(NSDictionary *result,BOOL final){
        UIImageView *target=weak;RWArtworkBinding *current=weakBinding;if(!target||!current||current.paused||current.covered||objc_getAssociatedObject(target,@selector(cancelArtwork:))!=current||generation!=self->_artworkGeneration||![profile isEqual:self.state[@"activeProfile"]])return;
        CGImageRef bitmap=(__bridge CGImageRef)result[@"bitmap"];
        if(bitmap){BOOL contained=[result[@"presentation"]isEqual:@"fit"];CGFloat imageScale=scale;if(contained)imageScale=MAX(scale,MAX(CGImageGetWidth(bitmap)/MAX(1,target.bounds.size.width),CGImageGetHeight(bitmap)/MAX(1,target.bounds.size.height)));
            target.contentMode=contained?UIViewContentModeCenter:UIViewContentModeScaleAspectFill;target.image=[UIImage imageWithCGImage:bitmap scale:imageScale orientation:UIImageOrientationUp];
        }
        if(final){current.finished=YES;current.completion=nil;NSMutableDictionary *sample=[result mutableCopy];[sample removeObjectForKey:@"bitmap"];sample[@"displayed"]=@(bitmap!=NULL);[self->_artworkSamples addObject:sample];while(self->_artworkSamples.count>16)[self->_artworkSamples removeObjectAtIndex:0];[self report:@{@"artwork_samples":[self->_artworkSamples copy]}];if(completion)completion(bitmap!=NULL);
            if([role isEqual:@"hero"]){[self->_artworkHeroSamples addObject:sample];while(self->_artworkHeroSamples.count>8)[self->_artworkHeroSamples removeObjectAtIndex:0];[self report:@{@"artwork_hero_samples":[self->_artworkHeroSamples copy]}];[self->_artworkLoader diagnostics:^(NSDictionary *metrics){[self report:@{@"artwork_pipeline":metrics}];}];}
        }
    }];
}
- (void)artwork:(NSArray *)urls into:(UIImageView *)view completion:(void(^)(BOOL))completion {[self artwork:urls role:view.bounds.size.width>view.bounds.size.height?@"backdrop":@"poster" identity:@"" into:view completion:completion];}
- (void)image:(NSString *)url into:(UIImageView *)view {[self image:url into:view completion:nil];}
- (void)image:(NSString *)url into:(UIImageView *)view completion:(void(^)(BOOL))completion {
    if(!url.length){[self cancelArtwork:view];view.image=nil;if(completion)completion(NO);return;}
    [self artwork:@[url] role:view.bounds.size.width>view.bounds.size.height?@"backdrop":@"portrait" identity:@"" into:view completion:completion];
}
- (NSArray *)history { NSMutableArray *values=[NSMutableArray new];for(NSDictionary *r in [[self profile][@"history"]allValues])if([self allowed:r[@"meta"]])[values addObject:r];return [values sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"updated"]compare:a[@"updated"]];}]; }
- (NSArray *)saved { return [self allowedItems:[self profile][@"saved"]]; }
- (BOOL)isSaved:(NSDictionary *)meta {for(NSDictionary *m in [self saved])if([RWID(m)isEqual:RWID(meta)])return YES;return NO;}
- (void)toggleSaved:(NSDictionary *)meta {if(![self allowed:meta])return;NSMutableArray *list=[[self profile][@"saved"]mutableCopy];NSUInteger index=[list indexOfObjectPassingTest:^BOOL(NSDictionary *m,NSUInteger i,BOOL *stop){return [RWID(m)isEqual:RWID(meta)];}];if(index==NSNotFound){NSMutableDictionary *signal=[meta mutableCopy];signal[@"discoverySavedAt"]=@(NSDate.date.timeIntervalSince1970);[list insertObject:signal atIndex:0];}else[list removeObjectAtIndex:index];[self profile][@"saved"]=list;[self saveForReason:NSStringFromSelector(_cmd)];[self refreshDiscovery];}
- (NSDictionary *)record:(NSString *)videoID {return [self profile][@"history"][videoID];}
- (void)remember:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source position:(double)position duration:(double)duration {
    [self remember:meta videoID:videoID source:source position:position duration:duration metrics:nil];
}
- (void)remember:(NSDictionary *)meta videoID:(NSString *)videoID source:(NSDictionary *)source position:(double)position duration:(double)duration metrics:(NSDictionary *)metrics {
    if(!videoID.length||!isfinite(position)||position<0||![self allowed:meta])return;
    if([meta[@"type"]isEqual:@"series"]&&position>3){if(![self.profile[@"unfollowedShows"]containsObject:RWID(meta)])[self follow:meta enabled:YES];self.profile[@"selectedSeasons"][RWID(meta)]=meta[@"season"]?:@1;NSDictionary *update=self.profile[@"episodeUpdates"][RWID(meta)];if([update[@"episode"][@"id"]isEqual:videoID])[self.profile[@"episodeUpdates"]removeObjectForKey:RWID(meta)];}
    NSDictionary *old=[self record:videoID];NSMutableDictionary *record=[old mutableCopy]?:[NSMutableDictionary new];
    [record addEntriesFromDictionary:@{@"meta":meta,@"videoID":videoID,@"source":source?:@{},@"position":@(position),@"duration":@(isfinite(duration)?duration:0),@"updated":@(NSDate.date.timeIntervalSince1970),@"completed":@(duration>0&&position>=duration-12)}];
    [record addEntriesFromDictionary:[RWViewingSignals merge:old metrics:metrics duration:duration]];
    [record removeObjectForKey:@"progressOverride"];
    self.profile[@"history"][videoID]=record;[_discoveryEpisodes invalidate:RWID(meta)];[self saveForReason:NSStringFromSelector(_cmd)];
}
- (void)setSource:(NSDictionary *)source forID:(NSString *)videoID {[self profile][@"sources"][videoID]=source;[self saveForReason:NSStringFromSelector(_cmd)];}
- (BOOL)addOn:(NSDictionary *)addon supports:(NSString *)resource type:(NSString *)type {
    NSDictionary *m=addon[@"manifest"];for(id r in m[@"resources"]){if([r isKindOfClass:NSString.class]&&[r isEqual:resource])return YES;if([r isKindOfClass:NSDictionary.class]&&[r[@"name"]isEqual:resource]&&(!r[@"types"]||[r[@"types"]containsObject:type]))return YES;}return NO;
}
- (NSInteger)quality { id q=[self profile][@"quality"]; return [q isKindOfClass:NSNumber.class]&&[@[@480,@720,@1080]containsObject:q]?[q integerValue]:0; }
- (void)setQuality:(NSInteger)quality {
    if(self.quality==quality)return;
    [self clearHomeRefreshBatch];[self profile][@"quality"]=@(quality);_availabilityWatchGeneration++;_checkingAvailability=NO;_homeGeneration++;_discoveryGeneration++;_homeAvailabilityBusy=NO;_homeRefreshRequested=NO;_homePublicationRequested=NO;_discoveryPrepared=@[];_discoveryContext=nil;_offlineEvidence=@{};_offlineEvidenceAt=0;[_homeMetadataAttempts removeAllObjects];
    [self saveForReason:NSStringFromSelector(_cmd)];[self refreshDiscovery];
}
#include "RewindStreams.inc"
- (void)addAddon:(NSString *)url done:(RWResult)done {
    NSURL *u=[NSURL URLWithString:url];if(![u.scheme.lowercaseString isEqual:@"https"]||![u.path hasSuffix:@"/manifest.json"]){done(nil,@"Use the add-on's HTTPS manifest.json address.");return;}
    [self JSON:url done:^(id result,NSString *error){
        if(error){done(nil,error);return;}if(!RWString(result[@"id"]).length||![result[@"resources"]isKindOfClass:NSArray.class]){done(nil,@"This is not a valid Stremio add-on manifest.");return;}
        NSMutableArray *addons=[self.state[@"addons"]mutableCopy];for(NSDictionary *a in [addons copy])if([a[@"manifest"][@"id"]isEqual:result[@"id"]])[addons removeObject:a];
        if(addons.count>=8){done(nil,@"This version supports up to eight add-ons.");return;}
        [addons addObject:@{@"base":[url substringToIndex:url.length-14],@"manifest":result}];self.state[@"addons"]=addons;[self saveForReason:NSStringFromSelector(_cmd)];done(result,nil);
    }];
}
- (void)segments:(NSDictionary *)meta videoID:(NSString *)videoID duration:(double)duration done:(RWResult)done {
    NSString *imdb=RWID(meta);NSInteger season=[meta[@"season"]integerValue],episode=[meta[@"episode"]integerValue];NSRegularExpression *valid=[NSRegularExpression regularExpressionWithPattern:@"^tt[0-9]+$" options:0 error:nil];
    if(![meta[@"type"]isEqual:@"series"]||episode<1||episode>2000||season<0||season>100||![valid firstMatchInString:imdb options:0 range:NSMakeRange(0,imdb.length)]){done(@[],nil);return;}
    NSDictionary *cached=self.state[@"segmentCache"][videoID];if(cached&&[NSDate date].timeIntervalSince1970-[cached[@"checked"]doubleValue]<7*86400){done([RWSkipPolicy segments:cached[@"data"] imdb:imdb season:season episode:episode duration:duration],nil);return;}
    NSString *url=[NSString stringWithFormat:@"https://api.introdb.app/segments?imdb_id=%@&season=%ld&episode=%ld",Esc(imdb),(long)season,(long)episode];
    [self JSON:url done:^(id result,NSString *error){if(result){if([self.state[@"segmentCache"]count]>=100)[self.state[@"segmentCache"]removeAllObjects];self.state[@"segmentCache"][videoID]=@{@"data":result,@"checked":@([NSDate date].timeIntervalSince1970)};[self saveForReason:NSStringFromSelector(_cmd)];}done([RWSkipPolicy segments:result imdb:imdb season:season episode:episode duration:duration],error);}];
}
- (void)trailer:(NSDictionary *)meta done:(RWResult)done {
    if(![self allowed:meta]){done(nil,@"This title is unavailable for this profile.");return;}
    if(RWString(meta[@"preview"]).length){done(@{@"url":meta[@"preview"],@"name":@"Preview",@"imdb":RWID(meta),@"lookupSeconds":@0},nil);return;}
    [_trailers resolve:[self.discoveryMetadata enrich:meta] done:^(id source,NSString *error){
        [self report:@{@"trailer_resolution":self->_trailers.diagnostics}];
        // Embedded related videos cannot be constrained by this profile's ratings.
        if(self.restricted&&RWString(source[@"youtubeID"]).length){done(nil,@"No age-filtered trailer is available for this profile.");return;}
        done(source,error);
    }];
}
- (void)nativeTrailer:(NSDictionary *)meta done:(RWResult)done {if(![self allowed:meta]){done(nil,@"This title is unavailable for this profile.");return;}[_trailers resolveNative:[self.discoveryMetadata enrich:meta] done:^(id source,NSString *error){[self report:@{@"trailer_resolution":self->_trailers.diagnostics}];done(source,error);}];}
- (void)embeddedTrailerUnsupported {[_trailers embeddedUnsupported];[self report:@{@"trailer_embedded_compatibility":@"provider_script_syntax_unsupported"}];}
- (NSDictionary *)trailerDiagnostics {return _trailers.diagnostics;}
- (void)trailerFailed:(NSString *)imdb embedded:(BOOL)embedded {[_trailers failed:imdb embedded:embedded];}
- (void)cancelTrailer:(NSString *)identifier {[_trailers cancel:identifier];}
- (void)trailerFailed:(NSString *)imdb {[_trailers failed:imdb];}
@end
