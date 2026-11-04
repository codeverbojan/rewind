#import "RWSourceWork.h"
#import "RWFontLookupProbe.h"
#include <sys/stat.h>
#import "RWExploreIndex.h"
#import "RWSearchFixture.h"
#import "RWSubtitles.h"
#import "RWMediaCache.h"
#import "RWReminderPolicy.h"
#import "RWUpcomingPolicy.h"
#import "RWHomePreparation.h"
#import "RWHomeDeferredPreparation.h"
#import "RWDiscoveryEpisodes.h"
#import "RWEntityCreditPolicy.h"
#import "RWPreviewSession.h"
#import "RWDetailHeader.h"
#import "RWDetailPresentation.h"
#import "RWOrientationProbe.h"
#import "RWTrailerPolicy.h"
#import "RWMetadataBudget.h"
#import "RWPlaybackPreparation.h"
#import <mach/mach.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <netinet/in.h>
#import "RWArtworkPolicy.h"
#import <CommonCrypto/CommonDigest.h>
#import "RewindUI.h"
#import "RWProfileExperience.h"
#import "RewindPlayer.h"
#import "RWSourcePolicy.h"
#import "RWLibraryPolicy.h"
#import "RWCatalogPolicy.h"
#import "RWProfiles.h"
#import "RWTVPolicy.h"
#import "RWTrailerView.h"
#import <SafariServices/SafariServices.h>
#import "TorrentEngine.h"
#import "RWPlaybackLifetimeProbe.h"
#import "RWAtomicWriter.h"
#import "RWCast.h"
#import "RWCastStrip.h"
#import "RWEpisodeList.h"
#import "RWDiscoveryMetadataPolicy.h"
#import "RWRecommendationPolicy.h"
#import "RWDiscoveryCatalog.h"
#import "RWHomeDelivery.h"
#import "RWHomePresentation.h"
#import "RWEntityDetailsPolicy.h"
#import "RWEntitySearchPolicy.h"
#import "RWEntityCard.h"
#import "RWPosterCollection.h"
#import "RWHomeView.h"
#import "RWHomeFeedCoordinator.h"
#import "RWHomeRailPolicy.h"
#import <CommonCrypto/CommonDigest.h>
#import "RWAvailabilityList.h"
#import "RWDownloadsList.h"
#import "RWUIProbe.h"
#import "RWDeviceExercise.h"
#import "RWAvailability.h"
#import "RWKidsSurfaceRatings.h"
#include "RWKidsSurfaceRatings.inc"
static void RWDeviceExerciseWake(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info){
    dispatch_async(dispatch_get_main_queue(),^{
        id<UIApplicationDelegate> delegate=UIApplication.sharedApplication.delegate;
        UIWindow *window=[delegate respondsToSelector:@selector(window)]?delegate.window:UIApplication.sharedApplication.keyWindow;
        UIViewController *controller=window.rootViewController;
        if([controller respondsToSelector:@selector(consumeDeviceExercise)])[controller performSelector:@selector(consumeDeviceExercise) withObject:nil afterDelay:.1];
    });
}
static double RWMainStarted;

@interface RewindController : UIViewController <UISearchBarDelegate,UIScrollViewDelegate>
@property(nonatomic,strong) RWProfileExperience *profileExperience;
@property(nonatomic,strong) NSDictionary *exerciseRequest;
@property(nonatomic,strong) RWFontLookupProbe *exerciseFontProbe;
@property(nonatomic,strong) RWKidsSurfaceRatings *exerciseKidsRatings;
@property(nonatomic,copy) NSString *exerciseKidsRevoked;
@property(nonatomic,assign) double exerciseKidsDeadline;
@property(nonatomic,strong) UIView *exerciseArtworkStage;
@property(nonatomic,strong) RWDetailHeader *exerciseArtworkHeader;
@property(nonatomic,strong) UIImageView *exerciseArtworkSeed;
@property(nonatomic,strong) NSMutableDictionary *exerciseArtworkReport;
@property(nonatomic,copy) NSString *exerciseArtworkPhase;
@property(nonatomic,assign) double exerciseArtworkDeadline;
@property(nonatomic,strong) NSMutableDictionary *exerciseNetworkReport;
@property(nonatomic,strong) RewindPlayer *exercisePlayer;
@property(nonatomic,strong) NSMutableDictionary *exerciseRecoveryReport,*exerciseLifecycleReport;
@property(nonatomic,strong) RWPlaybackLifetimeProbe *exerciseLifetimeProbe;
@property(nonatomic,copy) NSString *exerciseHTTPStage;
@property(nonatomic,assign) double exerciseHTTPStarted;
@property(nonatomic,assign) BOOL exerciseResumeOwned;
@property(nonatomic,strong) NSDictionary *exerciseKidsReport;
@property(nonatomic,strong) RWOrientationProbe *exerciseOrientationProbe;
@property(nonatomic,assign) UIInterfaceOrientation exerciseOriginalOrientation,exerciseTargetOrientation;
@property(nonatomic,assign) UIInterfaceOrientationMask exerciseOrientationMask;
@property(nonatomic,strong) NSDictionary *exercisePresentationReport;
@property(nonatomic,assign) NSTimeInterval exerciseOrientationDeadline;
@property(nonatomic,strong) NSArray *exerciseKidsMetas;
@property(nonatomic,copy) NSString *exerciseKidsKind;
@property(nonatomic,strong) NSDictionary *exerciseResumeRecord;
@property(nonatomic,strong) NSDictionary *exercisePlaybackMeta;
@property(nonatomic,copy) NSString *exercisePlaybackMetadataError;
@property(nonatomic) BOOL exercisePlaybackMetadataPending;
@property(nonatomic) double exercisePlaybackMetadataStarted;
@property(nonatomic) double exercisePreparationStarted;
@property(nonatomic,strong) NSDictionary *exercisePreparationReport;
@property(nonatomic,copy) void(^exerciseDownloadRemoval)(void);
@property(nonatomic,strong) NSDictionary *exerciseDownloadReport;
@property(nonatomic,strong) NSDictionary *exerciseEpisodeShow,*exerciseEpisodeReport;
@property(nonatomic,assign) BOOL episodeHandoffPresentation;
@property(nonatomic,strong) NSArray *exerciseEpisodeTargets;
@property(nonatomic,strong) NSMutableDictionary *exerciseEpisodeActions;
@property(nonatomic,strong) NSDictionary *exerciseFeedAnchor,*exerciseFeedReport;
@property(nonatomic,strong) RWPosterCollection *exerciseFeedFixture;
@property(nonatomic,strong) NSArray *exerciseFeedFixtureCards;
@property(nonatomic,copy) NSString *exerciseFeedKind,*exerciseFeedTitle;
@property(nonatomic,assign) double exerciseFeedStarted,exerciseRailSettleStarted;
@property(nonatomic,assign) NSUInteger exerciseRailSettleIndex;
@property(nonatomic,strong) RWHomeView *exerciseLoadingView;
@property(nonatomic,strong) NSArray *exerciseLoadingCards;
@property(nonatomic,assign) double exercisePlaybackStarted,exercisePausedPosition;
@property(nonatomic,strong) NSArray *exerciseSteps;
@property(nonatomic,strong) NSMutableArray *exerciseSamples;
@property(nonatomic,copy) NSString *exerciseProfile;
@property(nonatomic,strong) NSDictionary *exerciseProfilePair,*exerciseProfileAudit,*exerciseHomeAnchor;
@property(nonatomic,strong) NSMutableDictionary *exerciseProfileMotionImages;
@property(nonatomic,copy) NSString *exerciseDetailID;
@property(nonatomic,strong) RWEntityCard *exerciseDetailPhotoFixture;
@property(nonatomic,assign) CGFloat exerciseExploreOffset;
@property(nonatomic,assign) BOOL exerciseRemoteAbsent;
@property(nonatomic,copy) NSString *exerciseAvailabilityTarget;
@property(nonatomic,strong) UIAlertController *exerciseReminderSheet;
@property(nonatomic,strong) NSDictionary *exerciseReminderReport;
@property(nonatomic,strong) NSDictionary *myListSuspendedAnchor;
@property(nonatomic,copy) NSString *myListSuspendedProfile;
@property(nonatomic,strong) RWCatalogSearch *exerciseOriginalCatalogSearch;
@property(nonatomic,strong) RWDiscoveryMetadata *exerciseOriginalEntityMetadata;
@property(nonatomic,strong) NSDictionary *exerciseArtInitial;
@property(nonatomic,strong) NSMutableDictionary *exerciseEntityActions;
@property(nonatomic,strong) UIAlertController *exerciseEntitySheet;
@property(nonatomic,copy) NSString *exerciseArtTarget;
@property(nonatomic,assign) double exerciseArtStarted;
@property(nonatomic,assign) double exerciseEntityStarted;
@property(nonatomic,assign) NSUInteger exerciseEntityRequests;
@property(nonatomic,strong) NSArray *exerciseSearchOldTasks,*exerciseSearchIDs;
@property(nonatomic,copy) NSString *exerciseSearchLocalID;
@property(nonatomic,assign) double exerciseSearchStarted;
@property(nonatomic,assign) NSUInteger exerciseSearchRequests;
@property(nonatomic,strong) NSArray *exerciseLibraryMetas;
@property(nonatomic,strong) NSDictionary *exerciseLibraryReport,*exerciseLibraryAnchor;
@property(nonatomic,assign) CGFloat exerciseLibraryOffset;
@property(nonatomic,strong) NSDictionary *pendingReminder,*notificationOpenEvidence,*notificationLastReceipt,*exerciseNotificationPayload;
@property(nonatomic,strong) NSString *lastReminderID,*notificationEpisodeID,*notificationTitleID;
@property(nonatomic,assign) double lastReminderAt,reminderDeadline;
@property(nonatomic,assign) BOOL reminderProcessScheduled,notificationSeasonPending;
@property(nonatomic,strong) RWCastStrip *exerciseCastBefore;
@property(nonatomic,strong) NSArray *exerciseCastFirstNames;
@property(nonatomic,copy) NSString *exerciseCastPerson;
@property(nonatomic,assign) CGFloat exerciseCastOffset;
@property(nonatomic,assign) NSUInteger exerciseCastCreated;
@property(nonatomic,strong) NSMutableDictionary *detailOpenStages;
@property(nonatomic,strong) NSMutableArray *detailOpenTraces;
@property(nonatomic,assign) NSUInteger exerciseIndex;
@property(nonatomic,assign) double exerciseStarted;
@property(nonatomic,assign) BOOL exercisePriorIdleTimer;
@property(nonatomic,strong) NSDictionary *homePlan, *entity;
@property(nonatomic,strong) RWHomeValidation *homeValidation;
@property(nonatomic,strong) NSDictionary *homeDeferredBatch;
@property(nonatomic,copy) NSString *homeDeferredProfile;
@property(nonatomic,assign) BOOL homeDeferredNeeded,homeDeferredBusy;
@property(nonatomic,assign) double homeInitialLoadingUntil;
@property(nonatomic,assign) double homePromotedMetadataSeconds,homePromotedPolicySeconds;
@property(nonatomic,strong) NSSet *homeExcludedIDs;
@property(nonatomic,strong) NSMutableDictionary *railOffsets;
@property(nonatomic,strong) NSArray *entityItems, *relatedTitles;
@property(nonatomic,strong) RWFeedStore *entityFeed;
@property(nonatomic,strong) RWFeedStore *exploreFeed;
@property(nonatomic,strong) NSString *exploreQuery,*exploreType,*exploreScope,*exploreError;
@property(nonatomic,strong) UISearchBar *exploreSearch;
@property(nonatomic,strong) UILabel *exploreMessage;
@property(nonatomic,assign) NSUInteger exploreGeneration;
@property(nonatomic,assign) BOOL exploreBusy,exploreRemoteBusy,exploreRemoteMore,exploreRemoteStarted;
@property(nonatomic,strong) NSDictionary *exploreCursor;
@property(nonatomic,strong) NSArray *exploreLocalRecords;
@property(nonatomic,assign) NSUInteger exploreEmptyPages;
@property(nonatomic,strong) NSDictionary *entityCursor, *entityHeaderRecord, *entityHighlights;
@property(nonatomic,strong) NSArray *entityHighlightPool,*entityHighlightPending;
@property(nonatomic,strong) NSMutableDictionary *entityHighlightOffsets;
@property(nonatomic,strong) NSString *entityHighlightMode,*entityDetailRequested;
@property(nonatomic,assign) BOOL entityBioExpanded,entityHeaderPending,entityHeaderScheduled,entityHighlightBusy;
@property(nonatomic,assign) NSUInteger entityHighlightGeneration;
@property(nonatomic,strong) RWPosterCollection *entityHighlightRail;
@property(nonatomic,strong) NSArray *entityPendingRatings;
@property(nonatomic,assign) NSUInteger entityEmptyPages,entitySelectionGeneration;
@property(nonatomic,assign) BOOL entitySelecting,entityFocusCredits,entityFeedPrepared;
@property(nonatomic,assign) CGFloat entityCreditsAnchor;
@property(nonatomic,strong) NSString *entityScreenScope;
@property(nonatomic,strong) NSMutableArray *destinationStack, *discoveryTimings;
@property(nonatomic,strong) NSString *entityType, *entitySort, *entityError, *exploreKind, *exploreMood, *upcomingMode, *relatedKey;
@property(nonatomic,assign) NSUInteger entityOffset, entityGeneration, relatedGeneration, entityPageOffset, explorePageOffset, upcomingPageOffset;
@property(nonatomic,assign) BOOL entityBusy, entityMore, homeRefreshStarted;
@property(nonatomic,assign) double discoveryMemoryCooldown;
@property(nonatomic,strong) UIView *sidebar;
@property(nonatomic,strong) NSDictionary *navigationState;
@property(nonatomic,strong) NSArray *navigationTabs;
@property(nonatomic,strong) RWButton *navigationBrand,*navigationSearch,*navigationProfile;
@property(nonatomic,strong) RWPlaybackPreparation *playbackPreparation;
@property(nonatomic,strong) RWTrailerView *preview;
@property(nonatomic,strong) UIView *previewStage;
@property(nonatomic,strong) UIView *heroOverlay;
@property(nonatomic,strong) RWPreviewSession *previewSession;
@property(nonatomic,strong) NSMutableArray *previewEvents;
@property(nonatomic,strong) RWDetailHeader *detailHeader;
@property(nonatomic,assign) BOOL detailNeedsApply,detailApplyScheduled;
@property(nonatomic,strong) NSString *detailApplyKey;
@property(nonatomic,strong) NSDictionary *previewSource;
@property(nonatomic,assign) BOOL previewWantsSound;
@property(nonatomic,strong) NSMutableSet *displayedIDs;
@property(nonatomic,strong) UIScrollView *content;
@property(nonatomic,strong) NSString *page;
@property(nonatomic,strong) NSString *filter;
@property(nonatomic,strong) NSString *browseGenre;
@property(nonatomic,strong) NSString *browseSort;
@property(nonatomic,assign) NSInteger browseYear;
@property(nonatomic,assign) double browseRating;
@property(nonatomic,assign) NSUInteger browseSkip;
@property(nonatomic,assign) NSUInteger browseLocalOffset;
@property(nonatomic,assign) NSUInteger browseBatchCount;
@property(nonatomic,assign) NSUInteger browseGeneration;
@property(nonatomic,strong) NSArray *browseResults;
@property(nonatomic,strong) NSString *browseError;
@property(nonatomic,assign) BOOL browseBusy;
@property(nonatomic,assign) BOOL browseHasMore;
@property(nonatomic,strong) NSString *detailTab;
@property(nonatomic,strong) NSDictionary *detail;
@property(nonatomic,strong) RWButton *moviePlayButton;
@property(nonatomic,strong) UILabel *movieAvailabilityLabel;
@property(nonatomic,strong) UISearchBar *search;
@property(nonatomic,strong) NSTimer *searchTimer;
@property(nonatomic,strong) NSArray *searchResults;
@property(nonatomic,strong) NSString *searchMessage;
@property(nonatomic,assign) NSInteger searchGeneration;
@property(nonatomic,assign) NSInteger season;
@property(nonatomic,assign) CGSize laidOutSize;
@property(nonatomic,strong) NSMutableArray *addonRows;
@property(nonatomic,assign) NSUInteger heroIndex;
@property(nonatomic,assign) NSUInteger renderGeneration;
@property(nonatomic,strong) UILabel *searchMessageLabel;
@property(nonatomic,assign) BOOL loadingSources;
@property(nonatomic,strong) UIView *sourceNotice;
@property(nonatomic,assign) NSUInteger sourceGeneration;
@property(nonatomic,strong) NSString *returnPage;
@property(nonatomic,assign) CGFloat returnOffset;
@property(nonatomic,assign) BOOL reviewMode;
@property(nonatomic,strong) RewindController *reviewController;
@property(nonatomic,strong) NSMutableArray *reviewCases;
@property(nonatomic,strong) NSMutableArray *reviewResults;
@property(nonatomic,assign) BOOL managingProfiles, catalogRenderPending,homeDiscoveryDeferred;
@property(nonatomic,strong) NSString *catalogProfile;
@property(nonatomic,strong) UIView *searchResultsView;
@property(nonatomic,strong) RWPosterCollection *feedGrid;
@property(nonatomic,strong) RWHomeView *homeView;
@property(nonatomic,strong) RWHomeFeedCoordinator *homeFeeds;
@property(nonatomic) BOOL upcomingPreparing,upcomingPrepareAgain;
@property(nonatomic,strong) NSNumber *upcomingRestoreOffset;
@property(nonatomic,copy) NSString *homeFeedOpeningScope;
@property(nonatomic,strong) NSArray *homeFeedOpeningRows;
@property(nonatomic) BOOL homeFeedOpeningBusy,homeFeedOpeningFinished;
@property(nonatomic) NSUInteger homeFeedOpeningGeneration;
@property(nonatomic,strong) RWHomeView *parkedHomeView;
@property(nonatomic,strong) NSDictionary *homeViewContext,*parkedHomeContext;
@property(nonatomic,strong) RWAvailabilityList *upcomingList;
@property(nonatomic,strong) RWDownloadsList *downloadsList;
@property(nonatomic,strong) NSDictionary *downloadsSnapshot;
@property(nonatomic,strong) NSString *downloadsScope;
@property(nonatomic,assign) NSUInteger downloadsGeneration;
@property(nonatomic,assign) BOOL downloadsBusy,downloadsRefreshAgain,downloadsActionBusy;
@property(nonatomic,strong) NSString *upcomingScope;
@property(nonatomic,strong) NSDictionary *exerciseDetailBefore;
@property(nonatomic,strong) NSString *exerciseDetailEntityID;
@property(nonatomic,strong) NSDictionary *homeHeaderRecord;
@property(nonatomic,strong) NSString *homeScope;
@property(nonatomic,strong) RWFeedStore *browseFeed;
@property(nonatomic,strong) NSArray *browsePendingRatings;
@property(nonatomic,strong) UIView *searchExploreBar;
@property(nonatomic,assign) NSUInteger browseEmptyPages;
@property(nonatomic,strong) NSMutableArray *searchTasks;
@property(nonatomic,assign) NSUInteger searchPending, searchVisibleLimit;
@property(nonatomic,assign) double searchBegan, searchFirstResult;
@property(nonatomic,assign) double searchInputAt,searchFirstRendered;
@property(nonatomic,strong) NSMutableDictionary *searchProviderTimes;
@property(nonatomic,strong) NSString *searchResultsQuery;
@property(nonatomic,strong) NSString *prefetchedEpisode;
@property(nonatomic,strong) NSMutableArray *posters,*posterRails;
@property(nonatomic,assign) double lastArtworkScroll;
@property(nonatomic,strong) RWCast *castService;
@property(nonatomic,strong) RWCastStrip *castStage;
@property(nonatomic,strong) NSString *castRequestKey;
@property(nonatomic,assign) double lastCastReport;
@property(nonatomic,strong) RWEpisodeList *episodeList;
@property(nonatomic,assign) double lastEpisodeReport,lastEpisodeScrollTime,lastEpisodeScrollY;
@property(nonatomic,copy) NSString *upcomingKind;
@end

@implementation RewindController
#include "RewindNotifications.inc"
#include "RewindPreparation.inc"
#include "RewindDiscovery.inc"
#include "RewindHomeResidency.inc"
#include "RewindDetailNavigation.inc"
#include "RewindDiscoveryScreens.inc"
#include "RewindEntities.inc"
#include "RewindDetails.inc"
#include "RewindCast.inc"
#include "RewindSeries.inc"
#include "RewindEpisodeHandoff.inc"
#include "RewindBrowser.inc"
#include "RewindReview.inc"
#include "RewindProfiles.inc"
#include "RewindKids.inc"
#include "RewindPreview.inc"
#include "RewindDeviceExercise.inc"
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)viewDidLoad{[super viewDidLoad];self.view.backgroundColor=RWColor(0x0e1116);self.page=@"Profiles";self.filter=@"All";self.browseSort=@"Popular";self.browseResults=@[];self.detailTab=@"Episodes";self.searchResults=@[];self.addonRows=[NSMutableArray new];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(preparationSourcesUpdated:) name:@"RWSourceResultsUpdated" object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(episodesUpdated) name:@"RWEpisodesUpdated" object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(availabilityUpdated) name:@"RWAvailabilityUpdated" object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(ratingsChanged) name:@"RWRatingsUpdated" object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(previewBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(previewForeground) name:UIApplicationDidBecomeActiveNotification object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(upcomingUpdated) name:@"RWUpcomingUpdated" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applyPreparedHome) name:@"RWSeriesCacheUpdated" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(homeFeedUserTouch) name:@"RWUserTouchBegan" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(discoveryUpdated) name:@"RWRecommendationsUpdated" object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(localCatalogReady) name:@"RWLocalCatalogReady" object:nil];[self render];self.laidOutSize=self.view.bounds.size;if(!self.reviewMode){[self performSelector:@selector(beginLayoutReview) withObject:nil afterDelay:3];}}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];if(!CGSizeEqualToSize(self.laidOutSize,self.view.bounds.size)){self.laidOutSize=self.view.bounds.size;[self render];}}
- (void)episodesUpdated {if([self.page isEqual:@"Home"]&&!self.presentedViewController&&!self.reviewMode)[self scheduleCatalogRender];else if([self.page isEqual:@"Details"]&&[self.detail[@"type"]isEqual:@"series"]){self.detail=[[RewindStore shared]cachedDetails:self.detail];[self requestDetailRender];}}
- (void)availabilityUpdated {
    if([self.page isEqual:@"Home"]){[self applyPreparedHome];return;}
    if([self.page isEqual:@"Details"]&&[self.detail[@"type"]isEqual:@"movie"])[self refreshMovieAvailability];
    else if([self.page isEqual:@"Details"]&&[self.detail[@"type"]isEqual:@"series"])[self requestDetailRender];
    else if([self.page isEqual:@"Upcoming"]&&!self.presentedViewController&&!self.reviewMode)[self scheduleCatalogRender];
}
- (void)scheduleCatalogRender {
    if(self.catalogRenderPending||self.reviewMode)return;self.catalogRenderPending=YES;__weak RewindController *weak=self;
    double delay=[self.page isEqual:@"Home"]?1.5:.25;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        weak.catalogRenderPending=NO;if(!weak||weak.presentedViewController)return;
        if(weak.content.dragging||weak.content.decelerating||[weak.homeView isInteracting]||weak.feedGrid.dragging||weak.feedGrid.decelerating||weak.upcomingList.dragging||weak.upcomingList.decelerating||weak.downloadsList.dragging||weak.downloadsList.decelerating){[weak scheduleCatalogRender];return;}
        if([@[@"Home",@"My List",@"Upcoming"]containsObject:weak.page])[weak render];
    });
}
- (void)localCatalogReady {
    [self processPendingReminder];
    if([self.page isEqual:@"Profiles"])return;
    self.homePlan=[RewindStore shared].discoveryHome;
    [self render];if([self.page isEqual:@"Entity"]&&!self.entityFeedPrepared)[self prepareEntityFeed];[self loadCatalogs];[[RewindStore shared]checkEpisodes:^(BOOL changed){}];[[RewindStore shared]checkAvailability];
}
- (void)loadCatalogs {
    RewindStore *store=[RewindStore shared];if(!store.catalogReady)return;NSString *profile=store.state[@"activeProfile"];if([self.catalogProfile isEqual:profile])return;self.catalogProfile=profile;
    __weak RewindController *weak=self;
    for(NSString *type in @[@"movie",@"series"]){
        if(store.restricted){[store catalog:type query:nil genre:@"Family" done:^(id result,NSString *error){
            if(result){NSMutableArray *family=[NSMutableArray new];for(NSDictionary *m in result){NSMutableDictionary *audience=[m mutableCopy];NSDictionary *record=[store.discoveryMetadata record:RWID(m)];if(record.count)audience[@"discovery"]=record;if([RWDiscoveryMetadataPolicy isFamilyTitle:audience])[family addObject:audience];}store.familyCatalog=[RWCatalogPolicy filter:[store.familyCatalog arrayByAddingObjectsFromArray:family] genre:nil year:0 rating:0 sort:@"Popular" now:NSDate.date];[store.ratings resolve:store.familyCatalog];}
            if([profile isEqual:store.state[@"activeProfile"]])[store refreshDiscovery];
        }];}
        else {
            [store catalog:type query:nil genre:nil done:^(id result,NSString *error){if(result&&[profile isEqual:store.state[@"activeProfile"]])[store refreshDiscovery];}];
            [store browse:type sort:@"Newest" genre:nil year:0 skip:0 foreground:NO done:^(id result,NSString *error){if(result&&[profile isEqual:store.state[@"activeProfile"]])[store refreshDiscovery];}];
        }
    }
}

- (NSArray*)recommendations {
    if([self.page isEqual:@"Details"]){[self requestRelatedTitles];return self.relatedTitles?:@[];}
    NSMutableArray *out=[NSMutableArray new];for(NSDictionary *row in [RewindStore shared].discoveryHome[@"rows"])[out addObjectsFromArray:row[@"items"]];return out;
}
#include "RewindDetailTrace.inc"
- (void)showDetails:(NSDictionary*)meta{
    if(![RWID(meta)isEqual:self.notificationTitleID]){self.notificationEpisodeID=nil;self.notificationTitleID=nil;}
    double entered=NSProcessInfo.processInfo.systemUptime,stage=entered;RewindStore *store=[RewindStore shared];
    if(![store allowed:meta]){RWAlert(self,@"Outside this profile’s age limit",@"This title is above the selected age limit or has no known rating.");return;}
    self.detailOpenStages=[NSMutableDictionary new];[self recordDetailOpenStage:@"open.age_guard" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    [store.ratings resolve:@[meta]];[self recordDetailOpenStage:@"open.rating_resolve" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    if(![RWID(self.detail)isEqual:RWID(meta)]){[self stopPreview];[self.castService cancel];self.castRequestKey=nil;self.content.accessibilityIdentifier=@"";}
    [self recordDetailOpenStage:@"open.stop_preview" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    if(![self.page isEqual:@"Details"]||![RWID(self.detail)isEqual:RWID(meta)])[self pushDestination];
    if(![RWID(self.detail)isEqual:RWID(meta)])self.detailTab=@"Episodes";
    [self recordDetailOpenStage:@"open.push_destination" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    self.relatedKey=nil;self.relatedTitles=@[];double opened=NSProcessInfo.processInfo.systemUptime;
    if(![self.page isEqual:@"Details"]){self.returnPage=self.page;self.returnOffset=self.content.contentOffset.y;}
    NSDictionary *cached=[store cachedDetails:meta];[self recordDetailOpenStage:@"open.cached_details" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    self.detail=[store discoveryMeta:cached];self.page=@"Details";self.season=[store.profile[@"selectedSeasons"][RWID(meta)]integerValue];
    [self recordDetailOpenStage:@"open.enrich_metadata" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    [self render];[self recordDetailOpenStage:@"open.render" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    __weak RewindController *weak=self;NSString *identifier=RWID(meta),*profileID=store.state[@"activeProfile"];
    [store.discoveryMetadata refreshArtwork:self.detail];[store.discoveryMetadata enqueue:@[self.detail]];[self recordDetailOpenStage:@"open.enqueue_metadata" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    [self requestRelatedTitles];[self recordDetailOpenStage:@"open.related_request" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    [[RewindStore shared]report:@{@"detail_initial_render_seconds":@(NSProcessInfo.processInfo.systemUptime-opened)}];if(!self.reviewMode)[[RWUIProbe shared]transition:@"details_to_display_callback" started:opened];
    [self recordDetailOpenStage:@"open.report_transition" started:stage];stage=NSProcessInfo.processInfo.systemUptime;
    [[RewindStore shared]details:meta done:^(id result,NSString *error){[weak acceptDetailResult:result profile:profileID identifier:identifier];}];
    [self recordDetailOpenStage:@"open.details_request" started:stage];[self finishDetailOpenTrace:meta entered:entered cached:cached!=meta];
}
- (NSArray*)episodes{NSArray *videos=[self.detail[@"videos"]isKindOfClass:NSArray.class]?self.detail[@"videos"]:@[];return [videos sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){int av=[a[@"season"]intValue]*10000+[a[@"episode"]intValue],bv=[b[@"season"]intValue]*10000+[b[@"episode"]intValue];return av==bv?NSOrderedSame:(av<bv?NSOrderedAscending:NSOrderedDescending);}];}
- (void)chooseSources:(NSDictionary*)meta videoID:(NSString*)videoID restart:(BOOL)restart {
    RewindStore *s=[RewindStore shared];if(self.presentedViewController||!videoID.length||![s allowed:meta])return;double requestedAt=NSProcessInfo.processInfo.systemUptime;
    [self stopPreview];[self.castService cancel];self.castRequestKey=nil;self.sourceGeneration++;self.loadingSources=NO;[self.sourceNotice removeFromSuperview];self.sourceNotice=nil;
    NSDictionary *history=[s record:videoID];double resume=restart||[history[@"completed"]boolValue]?0:[history[@"position"]doubleValue];
    NSMutableArray *all=[[s cachedStreams:meta videoID:videoID]mutableCopy];
    for(id raw in @[meta[@"source"]?:@{},history[@"source"]?:@{},s.profile[@"sources"][videoID]?:@{}]){NSDictionary *normalized=[RWSourcePolicy normalize:raw provider:RWString(raw[@"provider"]).length?raw[@"provider"]:@"Saved source"];if(normalized)[all addObject:normalized];}
    RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:videoID candidates:[s withSourceExperience:all] quality:s.quality resume:resume];player.playRequestedAtUptime=requestedAt;NSDictionary *preparation=nil;player.preparedEngine=[self.playbackPreparation takeEngineForIdentity:[self preparationIdentity:meta videoID:videoID resume:resume] report:&preparation];player.preparationReport=preparation;__weak RewindController *weak=self;
    // Every player launched by an admitted diagnostic request is transient.
    // New recipe names must never opt into normal history/taste writes.
    if(self.exerciseRequest)[player beginDeviceExercise];
    [self configureEpisodeHandoff:player meta:meta videoID:videoID];
    if([self.exerciseRequest[@"action"]isEqual:@"episode-handoff"]){if(![player beginEpisodeExercise])return;self.exercisePlayer=player;}
    if([@[@"download-playback",@"featured-ready"]containsObject:self.exerciseRequest[@"action"]]){if(![player beginOfflineExercise])return;self.exercisePlayer=player;}
    if([self.exerciseRequest[@"action"]isEqual:@"kids-playback"]){if(![player beginKidsExercise:self.exerciseRequest[@"run"]])return;self.exercisePlayer=player;}
    [s setDiscoveryPaused:YES];player.onClose=^{[weak syncDiscoveryActivity];[weak render];};[self presentViewController:player animated:!self.episodeHandoffPresentation completion:nil];
}
- (void)chooseQuality {
    __weak RewindController *weak=self;UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Preferred quality" message:@"Auto tries compatible sources up to 1080p. A fixed quality requires a matching encode and will not silently switch to a different resolution." preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSNumber *q in @[@0,@480,@720,@1080]){NSString *title=q.integerValue?[NSString stringWithFormat:@"%@p",q]:@"Auto · up to 1080p";[a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[[RewindStore shared]setQuality:q.integerValue];[weak render];}]];}
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=self.view;a.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,300,1,1);[self presentViewController:a animated:YES completion:nil];
}
- (void)addSource:(NSDictionary*)meta videoID:(NSString*)videoID{
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Add source" message:@"Paste a magnet link or a direct MP4/HLS video address." preferredStyle:UIAlertControllerStyleAlert];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"https:// or magnet:";f.keyboardType=UIKeyboardTypeURL;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;}];__weak RewindController *weak=self;
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"Save and play" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSString *text=[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSURL *url=[NSURL URLWithString:text];if(![@[@"https",@"http",@"magnet"]containsObject:url.scheme.lowercaseString]){RWAlert(weak,@"Invalid source",@"Use a magnet, HTTP, or HTTPS link.");return;}NSDictionary *source=@{@"name":@"My source",@"url":text};[[RewindStore shared]setSource:source forID:videoID];[weak play:meta videoID:videoID source:source resume:0];}]];[self presentViewController:a animated:YES completion:nil];
}
- (void)play:(NSDictionary*)meta videoID:(NSString*)videoID source:(NSDictionary*)source resume:(double)resume{
    if(self.presentedViewController||![[RewindStore shared]allowed:meta])return;double requestedAt=NSProcessInfo.processInfo.systemUptime;[self.playbackPreparation cancel];[self stopPreview];RewindPlayer *player=[[RewindPlayer alloc]initWithMeta:meta videoID:videoID source:source resume:resume];player.playRequestedAtUptime=requestedAt;[self configureEpisodeHandoff:player meta:meta videoID:videoID];__weak RewindController *weak=self;[[RewindStore shared]setDiscoveryPaused:YES];player.onClose=^{[weak syncDiscoveryActivity];[weak render];};[self presentViewController:player animated:YES completion:nil];
}
- (void)trailer:(NSDictionary*)meta {if(![[RewindStore shared]allowed:meta])return;[self.content setContentOffset:CGPointZero animated:YES];if([self.preview canPlay])[self.preview playWithSound];else [self schedulePreview:YES];}
- (void)editIntro:(NSString*)videoID{
    NSDictionary *old=[[RewindStore shared]profile][@"intros"][videoID];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Intro timing" message:@"Set the intro's start and end in seconds. Skip intro appears only inside this interval." preferredStyle:UIAlertControllerStyleAlert];
    for(NSString *key in @[@"start",@"end"])[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=[key isEqual:@"start"]?@"Start, e.g. 30":@"End, e.g. 90";f.keyboardType=UIKeyboardTypeDecimalPad;if(old)f.text=[old[key]stringValue];}];__weak RewindController *weak=self;
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];if(old)[a addAction:[UIAlertAction actionWithTitle:@"Remove timing" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){[[[RewindStore shared]profile][@"intros"]removeObjectForKey:videoID];[[RewindStore shared]save];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){double start=a.textFields[0].text.doubleValue,end=a.textFields[1].text.doubleValue;if(!a.textFields[1].text.length||start<0||end<=start||end>3600){RWAlert(weak,@"Invalid timing",@"Enter an end after the start, within the first hour.");return;}[[RewindStore shared]profile][@"intros"][videoID]=@{@"start":@(start),@"end":@(end)};[[RewindStore shared]save];}]];[self presentViewController:a animated:YES completion:nil];
}
#include "RewindSearch.inc"
- (void)addAddon{
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Connect an add-on" message:@"Paste a Stremio-compatible HTTPS manifest.json address." preferredStyle:UIAlertControllerStyleAlert];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"https://…/manifest.json";f.keyboardType=UIKeyboardTypeURL;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;}];__weak RewindController *weak=self;
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"Connect" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){NSString *url=[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];[[RewindStore shared]addAddon:url done:^(id result,NSString *error){if(error)RWAlert(weak,@"Could not connect",error);else{[weak loadCatalogs];[weak render];}}];}]];[self presentViewController:a animated:YES completion:nil];
}
- (void)dealloc {[self.playbackPreparation cancel];[self.preview stop];[self.searchTimer invalidate];[[NSNotificationCenter defaultCenter]removeObserver:self];}
@end

@interface RewindDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation RewindDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options{if(application.applicationState!=UIApplicationStateActive)RWMetadataBudget.shared.paused=YES;self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[RewindController new];[self.window makeKeyAndVisible];UILocalNotification *launchNote=options[UIApplicationLaunchOptionsLocalNotificationKey];if([launchNote isKindOfClass:UILocalNotification.class])[(RewindController *)self.window.rootViewController receiveReminder:launchNote.userInfo userInitiated:YES origin:@"cold_launch"];CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,RWDeviceExerciseWake,CFSTR("org.local.rewind.device-exercise"),NULL,CFNotificationSuspensionBehaviorDrop);[[RWUIProbe shared]transition:@"main_to_profile_display_callback" started:RWMainStarted];[application setMinimumBackgroundFetchInterval:3600];/* One bounded pending-request admission check after cold startup; no polling. */dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{[(RewindController *)self.window.rootViewController consumeDeviceExercise];});return YES;}
- (void)applicationDidBecomeActive:(UIApplication *)application {[(RewindController *)self.window.rootViewController presentProfileEntrance];[(RewindController *)self.window.rootViewController processPendingReminder];[[RWUIProbe shared]wake];[RWMetadataBudget shared].paused=NO;[[RewindStore shared]checkEpisodes:^(BOOL changed){}];[[RewindStore shared]checkAvailability];[(RewindController *)self.window.rootViewController performSelector:@selector(consumeDeviceExercise) withObject:nil afterDelay:1];}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {if(![url.scheme isEqual:@"rewind-lab"])return NO;[(RewindController *)self.window.rootViewController performSelector:@selector(consumeDeviceExercise) withObject:nil afterDelay:1];return YES;}
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if(application.applicationState==UIApplicationStateBackground)RWMetadataBudget.shared.paused=YES;
    RewindStore *store=RewindStore.shared;[store checkEpisodesInBackground:^(BOOL changed){
        NSDictionary *metrics=store.episodeCheckDiagnostics;UIBackgroundFetchResult result=changed?UIBackgroundFetchResultNewData:([metrics[@"errors"]count]&&![metrics[@"accepted"]unsignedIntegerValue]?UIBackgroundFetchResultFailed:UIBackgroundFetchResultNoData);
        // Finish durable state before releasing the OS window; retain a bounded
        // escape if disk I/O stalls (20s network + at most 8s persistence).
        [store save];__block BOOL finished=NO;void(^finish)(UIBackgroundFetchResult)=^(UIBackgroundFetchResult value){if(finished)return;finished=YES;completionHandler(value);};
        [RWAtomicWriter.shared whenIdle:^{finish(result);}];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{finish(UIBackgroundFetchResultFailed);});
    }];
}
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if(notification.userInfo[@"rewindReminderProbe"])[[RewindStore shared]report:@{@"notification_probe_delivery":@{@"run":notification.userInfo[@"rewindReminderProbe"],@"application_state":@(application.applicationState),@"received_at":@(NSDate.date.timeIntervalSince1970)}}];
    [(RewindController *)self.window.rootViewController receiveReminder:notification.userInfo userInitiated:application.applicationState==UIApplicationStateInactive origin:@"notification_callback"];
}
- (void)applicationDidEnterBackground:(UIApplication*)application{
    [[RWUIProbe shared]stop];
    [RWMetadataBudget shared].paused=YES;
    __block UIBackgroundTaskIdentifier task=UIBackgroundTaskInvalid;
    void (^finish)(void)=^{if(task!=UIBackgroundTaskInvalid){[application endBackgroundTask:task];task=UIBackgroundTaskInvalid;}};
    task=[application beginBackgroundTaskWithExpirationHandler:finish];[[RewindStore shared]save];[[RWAtomicWriter shared]whenIdle:finish];
}
@end
int main(int argc,char *argv[]){@autoreleasepool{RWMainStarted=NSProcessInfo.processInfo.systemUptime;return UIApplicationMain(argc,argv,NSStringFromClass(RWApplication.class),NSStringFromClass(RewindDelegate.class));}}
