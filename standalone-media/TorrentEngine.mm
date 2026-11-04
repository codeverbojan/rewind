#import "RWSourceAdmission.h"
#import "RWDownloadInventory.h"
#import "TorrentEngine.h"
#import "RWOfflineMedia.h"
#import "RWMediaCache.h"
#import "RWSourceHints.h"
#import "RWTrackerPolicy.h"
#include <libtorrent/session.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/peer_info.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/session_status.hpp>
#include <libtorrent/create_torrent.hpp>
#include <libtorrent/bencode.hpp>
#include <libtorrent/bdecode.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include "RWStreamingHandshake.h"
#include "RWTrackerTLS.h"
#import "RWTrackerTrust.h"
#include <libtorrent/hasher.hpp>
#include "RWTorrentResume.h"
#include <sys/stat.h>
#include "RWByteRange.h"
#include "RWDiscoveryPolicy.h"
#include "RWMediaDuration.h"
#include "RWTransferWindow.h"
#include "RWProbeTiming.h"
#include "RWProbeFocus.h"
#include "RWOpeningEstimate.h"
#include "RWTrackerIsolation.h"
#define RW_PEER_EVIDENCE_IMPLEMENTATION 1
#include "RWPeerEvidence.h"
#include "RWPeerTransport.h"
#include "RWProbeConnections.h"
#include "RWPreparationPolicy.h"
#include "RWPlaybackWindow.h"
#include "RWStartupPrefetch.h"
#include "RWSourceIdentity.h"
#include "RWTorrentFiles.h"
static_assert(sizeof(off_t)==8,"64-bit file offsets required");
#include <memory>
#include <map>
#include <set>
#include <mutex>

namespace lt = libtorrent;
// A queued remove_torrent is not a completed disk teardown. Protect every
// directory touched by a session until its destructor has joined disk jobs.
// The registry holds no session references and cannot extend network lifetime.
static std::mutex CacheSessionsMutex;
static std::map<const lt::session *,std::shared_ptr<std::set<std::string>>> CacheSessions;
static std::shared_ptr<lt::session> NewCacheSession(const lt::settings_pack &settings,int *tlsAnchors) {
#ifdef TORRENT_USE_OPENSSL
    NSData *trusted=RWTrackerTrustedPEM();
    if(!trusted.length)throw std::runtime_error("Tracker certificate bundle is missing or invalid.");
#endif
    auto hashes=std::make_shared<std::set<std::string>>();
    std::shared_ptr<lt::session> session(new lt::session(settings),[hashes](lt::session *value){
        delete value;
        std::lock_guard<std::mutex> lock(CacheSessionsMutex);
        auto entry=CacheSessions.find(value);
        if(entry!=CacheSessions.end()&&entry->second==hashes)CacheSessions.erase(entry);
    });
#ifdef TORRENT_USE_OPENSSL
    auto ready=std::make_shared<RWTrackerTLSState>();
    session->add_extension(std::make_shared<RWTrackerTLS>(std::string((const char *)trusted.bytes,trusted.length),ready));
    bool observePeers=true;
#ifdef RW_ENGINE_TESTING
    observePeers=!getenv("REWIND_FIXTURE_DISABLE_OBSERVER");
#endif
    if(observePeers)session->add_extension(std::make_shared<RWPeerEvidence::Session>());
    session->get_settings(); // FIFO network-thread barrier before any torrent.
    if(ready->status.load()!=1)throw std::runtime_error("Tracker certificate initialization failed.");
    *tlsAnchors=ready->anchors.load();
#else
    *tlsAnchors=0;
#endif
    std::lock_guard<std::mutex> lock(CacheSessionsMutex);CacheSessions[session.get()]=hashes;return session;
}
static void ProtectSessionCache(const std::shared_ptr<lt::session> &session,NSString *hash) {
    std::lock_guard<std::mutex> lock(CacheSessionsMutex);
    auto entry=CacheSessions.find(session.get());
    if(entry!=CacheSessions.end())entry->second->insert(hash.UTF8String);
}
static NSSet *ActiveCacheHashes() {
    NSMutableSet *hashes=[NSMutableSet new];std::lock_guard<std::mutex> lock(CacheSessionsMutex);
    for(const auto &session:CacheSessions)for(const auto &hash:*session.second)[hashes addObject:@(hash.c_str())];
    return hashes;
}
static NSString *EngineDocuments(){
#ifdef RW_ENGINE_TESTING
    const char *root=getenv("REWIND_ENGINE_TEST_ROOT");NSCAssert(root&&*root,@"Isolated engine test root is required");return @(root);
#else
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0];
#endif
}
static NSString *EngineCaches(){
#ifdef RW_ENGINE_TESTING
    NSString *path=[EngineDocuments()stringByAppendingPathComponent:@"Caches"];[[NSFileManager defaultManager]createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];return path;
#else
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0];
#endif
}
static dispatch_queue_t MediaCleanupQueue(){static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("org.local.rewind.media-cleanup",DISPATCH_QUEUE_SERIAL);});return q;}
static NSString *DHTStatePath(){return [EngineCaches()stringByAppendingPathComponent:@"rewind-dht-state.dat"];}
struct NativeTorrent {
    RWProbeTiming timing;
    std::shared_ptr<lt::session> session;
    __strong NSDictionary *source=nil;
    bool probing=false, prioritiesPending=false, resumePending=false, resumeLoaded=false;
    bool focusHeld=false,focusControlled=false;int focusOriginalLimit=0;
    double resumeSavedAt=0;int64_t resumePayload=0;int resumeWrites=0;
    std::string resumeError;
    bool cacheIntegrityFailed=false;
    bool fileIdentityFailure=false;
    uint64_t verifiedReadBytes=0,verifiedReadPieces=0;
    double verifiedReadHashSeconds=0;
    uint64_t deliveredReadBytes=0,readCacheHits=0,readCacheEvictions=0,unlistedPieceReads=0;
    std::map<int,uint64_t> readsByPiece;
    std::unique_ptr<RWMediaDuration> durationProbe;
    NSMutableData *durationBytes=nil;
    double containerDuration=0;
    int enabledProbePieces=0;
    std::vector<lt::download_priority_t> wantedFiles;
    std::vector<int> probePieces;
    size_t probeHeadCount=0;
    uint64_t probeRequestedBytes=0;
    int probeNextPiece=-1;
    int64_t lastPayload=0;
    double lastData=0;
    double firstPeer=-1, metadataSeen=-1, firstPayload=-1, firstOpening=-1;
    RWTransferWindow transfer;
    bool metadataAtStart=false;
    uint64_t allocatedAtStart=0,allocatedCacheAtStart=0,allocatedCacheBytes=0;
    bool compactStorage=false;
    NSDictionary *offlineCertificate=nil;
    double availabilityAt=-1;
    int openingAvailability=-1;
    bool filePrioritiesSubmitted=false;
    uint64_t preparationAllocationBaseline=0;
    bool preparationPartfile=false,preparationPrefixFinished=false;
    RWPlaybackWindow playbackWindow;
    RWStartupPrefetch startupPrefetch;
    RWOpeningEstimate openingEstimate;
    RWPrivateTrackers privateTrackers;
    std::vector<int> playbackPieces;
    bool playbackWindowActive=false;
    double playbackDiskChecked=0;
    uint64_t playbackFreeBytes=0;
    int dhtPeers=0;
    uint64_t uploadLimitWarnings=0;
    lt::torrent_handle handle;
    std::shared_ptr<const lt::torrent_info> info;
    int selected = -1;
    int desired = -1;
    int64_t fileOffset = 0, size = 0;
    int requestedPiece=-1;int64_t requestedOffset=-1;
    std::string directory, path, name, error, metadataSource = "waiting for peers";
    bool publicTest = false, fallbackTried = false;
    double started = 0, connectionBegan = 0, lastCheckProgressAt = 0;
    float lastCheckProgress = -1;
    int trackerPeers = 0;
    std::string trackerError;
    struct Piece { boost::shared_array<char> data; int size; uint64_t used; };
    std::map<int, Piece> pieces;
    std::set<int> pendingReads;
    uint64_t clock = 0;
    size_t cachedBytes = 0;
};

static NSDictionary *ProbeTiming(const NativeTorrent &n) {
    const auto &t=n.timing;
    return @{@"probe_started_uptime":@(t.start),@"metadata_seconds":@(t.metadata),@"first_peer_seconds":@(t.peer),@"first_payload_seconds":@(t.payload),@"opening_verified_seconds":@(t.opening),@"cache_check_observed_seconds":@(t.checkingSeconds),@"focus_held_observed_seconds":@(t.heldSeconds),@"unobserved_gap_seconds":@(t.unknownSeconds),@"timing_basis":@"First observed milestones from probe start; cache/focus durations sum observed intervals of at most3s. Longer gaps remain unknown."};
}

@implementation TorrentEngine {
    NativeTorrent *_native;
    std::vector<std::unique_ptr<NativeTorrent>> _probes;
    NSMutableArray *_raceQueue, *_raceFailures;
    NSMutableSet *_raceHashes;
    NSMutableArray *_metadataTasks;
    NSUInteger _raceIndex, _raceGeneration;
    double _raceStarted;
    BOOL _focusAttempted;NSString *_focusHash;double _focusStarted;NSMutableArray *_focusEvents;NSUInteger _focusTimerGeneration;dispatch_source_t _focusTimer;
    BOOL _discovering;
    BOOL _transportDiagnostics;
    NSDictionary *_selectedSource, *_lastDiscovery;
    double _pausedAt;
    BOOL _dhtStateLoaded;
    int _subtitleIndex;
    int64_t _subtitleOffset,_subtitleSize;
    NSMutableData *_subtitleBytes;
    BOOL _preparing,_preparationPayloadAllowed,_preparationStopped;
    NSString *_preparationPayloadHash;
    double _preparationStarted,_preparationPayloadStarted,_preparationDiskChecked;
    uint64_t _preparationPayload,_preparationAllocation;
    uint64_t _preparationRetiredPayload,_preparationRetiredAllocation;
    NSString *_sessionID;
    NSUInteger _torrentStartCount;
    int _trackerTLSAnchors;
    int _peerReconnectSeconds,_peerConnectionSpeed,_peerConnectionLimit,_peerMaxFailcount;
}
+ (void)removeDownload:(NSString *)hash done:(void (^)(BOOL))done {
    NSRegularExpression *valid=[NSRegularExpression regularExpressionWithPattern:@"^[a-fA-F0-9]{40}$" options:0 error:nil];if(![valid firstMatchInString:hash options:0 range:NSMakeRange(0,hash.length)]){if(done)done(NO);return;}
    dispatch_async(MediaCleanupQueue(),^{NSString *root=[EngineDocuments()stringByAppendingPathComponent:@"Torrents"];NSString *path=[root stringByAppendingPathComponent:hash.lowercaseString];struct stat st={};BOOL ok=NO;
        if(![ActiveCacheHashes() containsObject:hash.lowercaseString]&&lstat(path.fileSystemRepresentation,&st)==0&&!S_ISLNK(st.st_mode)&&S_ISDIR(st.st_mode))ok=[[NSFileManager defaultManager]removeItemAtPath:path error:nil];dispatch_async(dispatch_get_main_queue(),^{if(done)done(ok);});});
}
+ (void)downloadInventory:(NSArray *)history gate:(NSDictionary *)gate pinned:(NSSet *)pinned done:(void (^)(NSDictionary *))done {dispatch_async(MediaCleanupQueue(),^{@autoreleasepool{NSDictionary *snapshot=[RWDownloadInventory snapshotRoot:[EngineDocuments()stringByAppendingPathComponent:@"Torrents"] history:history gate:gate pinned:pinned];dispatch_async(dispatch_get_main_queue(),^{done(snapshot);});}});}
+ (void)clearTemporary:(NSSet *)pinned done:(void (^)(NSDictionary *))done {dispatch_async(MediaCleanupQueue(),^{NSString *root=[EngineDocuments()stringByAppendingPathComponent:@"Torrents"];NSDictionary *report=[RWMediaCache trimRoot:root pinned:pinned active:ActiveCacheHashes() budget:0];dispatch_async(dispatch_get_main_queue(),^{if(done)done(report);});});}
+ (void)afterCleanupWithPinned:(NSSet *)pinned ready:(void (^)(void))ready {dispatch_async(MediaCleanupQueue(),^{
    NSString *root=[EngineDocuments()stringByAppendingPathComponent:@"Torrents"];
    [RWMediaCache trimRoot:root pinned:pinned active:ActiveCacheHashes() budget:2ULL*1024*1024*1024];dispatch_async(dispatch_get_main_queue(),ready);});}
- (void)retireWithPinned:(NSSet *)pinned completion:(void (^)(NSDictionary *))completion {
    dispatch_async(MediaCleanupQueue(),^{for(NSURLSessionTask *task in self->_metadataTasks)[task cancel];self->_raceGeneration++;[self shutdown];NSString *root=[EngineDocuments()stringByAppendingPathComponent:@"Torrents"];
        NSDictionary *report=[RWMediaCache trimRoot:root pinned:pinned active:ActiveCacheHashes() budget:2ULL*1024*1024*1024];dispatch_async(dispatch_get_main_queue(),^{if(completion)completion(report);});});
}
+ (NSUInteger)activeSessionCount {std::lock_guard<std::mutex> lock(CacheSessionsMutex);return CacheSessions.size();}
- (instancetype)init {
    if ((self = [super init])) _native = new NativeTorrent();
    return self;
}
- (dispatch_queue_t)workQueue {return MediaCleanupQueue();}
- (void)perform:(void (^)(TorrentEngine *))work {dispatch_async(MediaCleanupQueue(),^{@autoreleasepool{work(self);}});}
- (void)setTransportDiagnosticsEnabled:(BOOL)enabled {_transportDiagnostics=enabled;}
- (void)dealloc { if(_focusTimer)dispatch_source_cancel(_focusTimer);delete _native; }
- (void)configurePeerRetryForPlayback:(BOOL)playback {
    if(!_native||!_native->session)return;
    // Discovery keeps the library's conservative retry interval. Only the
    // selected torrent, after competing probes are removed, retries sooner.
    // Failure backoff, connection limits and private-peer rules stay intact.
    int seconds=playback&&!_discovering&&!_preparing&&_selectedSource?15:60;
    if(_peerReconnectSeconds==seconds)return;
    lt::settings_pack update;update.set_int(lt::settings_pack::min_reconnect_time,seconds);
    _native->session->apply_settings(update);
    // One network-thread barrier per transition, never per snapshot/poll.
    auto actual=_native->session->get_settings();
    _peerReconnectSeconds=actual.get_int(lt::settings_pack::min_reconnect_time);
    _peerConnectionSpeed=actual.get_int(lt::settings_pack::connection_speed);
    _peerConnectionLimit=actual.get_int(lt::settings_pack::connections_limit);
    _peerMaxFailcount=actual.get_int(lt::settings_pack::max_failcount);
}
- (NSDictionary *)peerRetrySettings {
    return @{@"minimum_reconnect_seconds":@(_peerReconnectSeconds),
        @"connection_attempts_per_second":@(_peerConnectionSpeed),
        @"connection_limit":@(_peerConnectionLimit),@"max_failcount":@(_peerMaxFailcount)};
}
- (void)requestResume:(NativeTorrent *)n {
    if(!n||!n->session||!n->handle.is_valid()||!n->info||n->size<=0||!n->error.empty()||n->resumePending)return;
    n->resumeSavedAt=NSProcessInfo.processInfo.systemUptime;
    try{auto status=n->handle.status();
        // The library saves checking_files as a short have-pieces bitfield;
        // restore continues checking at that boundary. Before resume validation
        // itself completes, leave the previous saved state intact.
        if(status.state==lt::torrent_status::checking_resume_data)return;
        n->resumePayload=status.total_payload_download;
        n->handle.save_resume_data(lt::torrent_handle::flush_disk_cache);n->resumePending=true;
    }catch(const std::exception &error){n->resumePending=false;n->resumeError=error.what();}
}
- (void)checkpoint:(NativeTorrent *)n seconds:(double)seconds {
    [self requestResume:n];double end=NSProcessInfo.processInfo.systemUptime+seconds;
    while(n&&n->resumePending&&NSProcessInfo.processInfo.systemUptime<end){
        n->session->wait_for_alert(lt::milliseconds(25));[self pollAlerts];
    }
}
- (void)shutdown {
    for(NSURLSessionTask *task in _metadataTasks)[task cancel];if(!_native)return;
    [self endDiscoveryFocus:@"shutdown" now:NSProcessInfo.processInfo.systemUptime];_discovering=NO;
    // Called on the cleanup queue after the player and its readers stop.
    if(_native->session){_native->session->pause();double end=NSProcessInfo.processInfo.systemUptime+2;
        [self requestResume:_native];for(auto &probe:_probes)[self requestResume:probe.get()];
        for(auto &probe:_probes)[self checkpoint:probe.get() seconds:std::max(0.,end-NSProcessInfo.processInfo.systemUptime)];
        [self checkpoint:_native seconds:std::max(0.,end-NSProcessInfo.processInfo.systemUptime)];
    }
    // Save only routing state: never restore session settings or torrents.
    try{if(_native->session&&_native->session->status().dht_nodes>0){
        lt::entry state;_native->session->save_state(state,lt::session_handle::save_dht_state);
        std::vector<char> bytes;lt::bencode(std::back_inserter(bytes),state);
        if(!bytes.empty()&&bytes.size()<=256*1024)[[NSData dataWithBytes:bytes.data() length:bytes.size()]writeToFile:DHTStatePath() atomically:YES];
    }}catch(const std::exception &){}
    _probes.clear();delete _native;_native=nullptr;
}
- (BOOL)startMagnet:(NSString *)magnet publicTest:(BOOL)publicTest error:(NSString **)error {
    return [self startMagnet:magnet fileIndex:-1 publicTest:publicTest error:error];
}
- (BOOL)startMagnet:(NSString *)magnet fileIndex:(int)fileIndex publicTest:(BOOL)publicTest error:(NSString **)error {
    if(!_native){if(error)*error=@"Torrent session has been closed.";return NO;}
    try {
        lt::error_code ec;
        auto params = lt::parse_magnet_uri(magnet.UTF8String, ec);
        if (ec) { if (error) *error = @(ec.message().c_str()); return NO; }
        NSString *documents = EngineDocuments();
        NSString *directory = [documents stringByAppendingPathComponent:@"Torrents"];
        if(!RWCachePathAllowed(documents,directory,true)){
            if(error)*error=@"The download cache contains an unsupported path or symbolic link.";return NO;
        }
        NSDictionary *disk = [[NSFileManager defaultManager] attributesOfFileSystemForPath:documents error:nil];
        if ([disk[NSFileSystemFreeSize] unsignedLongLongValue] < 512ULL * 1024 * 1024) {
            if (error) *error = @"Keep at least 512 MB free before starting a download.";
            return NO;
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        // A direct magnet start can also reuse an earlier winner's session.
        [self configurePeerRetryForPlayback:NO];
        if (!_native->session) {
            lt::settings_pack settings;
            settings.set_int(lt::settings_pack::connections_limit, 40);
            // Finishing the small probe must not make us drop useful seed connections.
            settings.set_bool(lt::settings_pack::close_redundant_connections, false);
            settings.set_int(lt::settings_pack::stop_tracker_timeout, 1);
            settings.set_int(lt::settings_pack::active_downloads, 3);
            settings.set_bool(lt::settings_pack::announce_to_all_tiers, true);
            settings.set_bool(lt::settings_pack::announce_to_all_trackers, true);
            settings.set_int(lt::settings_pack::cache_size, 256);
            settings.set_int(lt::settings_pack::max_queued_disk_bytes, 2 * 1024 * 1024);
            settings.set_int(lt::settings_pack::upload_rate_limit, 32 * 1024);
            // Keep peer payload/protocol bounded without charging estimated
            // TCP ACKs against that small allowance. Otherwise a fast download
            // can exhaust upload quota and prevent its next requests leaving.
            settings.set_bool(lt::settings_pack::rate_limit_ip_overhead, false);
            settings.set_int(lt::settings_pack::max_metadata_size, 2 * 1024 * 1024);
            settings.set_bool(lt::settings_pack::enable_upnp, false);
            settings.set_bool(lt::settings_pack::enable_natpmp, false);
            settings.set_bool(lt::settings_pack::enable_lsd, false);
            settings.set_bool(lt::settings_pack::enable_dht, false);
            settings.set_bool(lt::settings_pack::validate_https_trackers,true);
            settings.set_str(lt::settings_pack::listen_interfaces, "0.0.0.0:0");
            settings.set_str(lt::settings_pack::user_agent, "Rewind/0.25 libtorrent/1.2.20");
            settings.set_int(lt::settings_pack::alert_mask,
                lt::alert::error_notification | lt::alert::status_notification | lt::alert::tracker_notification | lt::alert::storage_notification | lt::alert::performance_warning);
#ifdef RW_ENGINE_TESTING
            if(getenv("REWIND_ENGINE_LEGACY_ACK_LIMIT"))settings.set_bool(lt::settings_pack::rate_limit_ip_overhead,true);
            settings.set_str(lt::settings_pack::listen_interfaces, "");
            settings.set_bool(lt::settings_pack::enable_incoming_utp,false);
            settings.set_bool(lt::settings_pack::enable_outgoing_utp,false);
            settings.set_int(lt::settings_pack::download_rate_limit,256*1024);
            if(getenv("REWIND_ENGINE_BENCHMARK_MODE"))settings.set_int(lt::settings_pack::download_rate_limit,1024*1024);
            if(const char *mode=getenv("REWIND_ENGINE_QUALIFICATION_MODE"))settings.set_int(lt::settings_pack::download_rate_limit,[@(mode) isEqual:@"slow"]?128*1024:4*1024*1024);
            if(getenv("REWIND_ENGINE_FOCUS_TEST"))settings.set_int(lt::settings_pack::download_rate_limit,600000);
            settings.set_bool(lt::settings_pack::ignore_limits_on_local_network,false);
            if(getenv("REWIND_TRACKER_TEST_TRUST")){
                settings.set_str(lt::settings_pack::listen_interfaces,"127.0.0.1:0");
                settings.set_bool(lt::settings_pack::ssrf_mitigation,false); // Owned loopback fixture only.
            }
#endif
            _native->session=NewCacheSession(settings,&_trackerTLSAnchors);_sessionID=NSUUID.UUID.UUIDString;
            _peerReconnectSeconds=0;[self configurePeerRetryForPlayback:NO];
            _native->session->add_extension(&RWCreateStreamingHandshake);
            try{NSDictionary *saved=[[NSFileManager defaultManager]attributesOfItemAtPath:DHTStatePath() error:nil];
            double age=[NSDate.date timeIntervalSinceDate:saved[NSFileModificationDate]?:NSDate.distantPast];
            if([saved[NSFileSize]unsignedLongLongValue]<=256*1024&&age>=0&&age<7*86400){
                NSData *data=[NSData dataWithContentsOfFile:DHTStatePath()];
                if(data.length&&data.length<=256*1024){lt::error_code decodeError;lt::bdecode_node state;
                    lt::bdecode((const char *)data.bytes,(const char *)data.bytes+data.length,state,decodeError,nullptr,12,16000);
                    if(!decodeError&&state.type()==lt::bdecode_node::dict_t&&state.dict_find_dict("dht state")){
                        _native->session->load_state(state,lt::session_handle::save_dht_state);_dhtStateLoaded=YES;
                    }
                }
            }
            }catch(const std::exception &){_dhtStateLoaded=NO;}
            lt::settings_pack startDHT;
#ifndef RW_ENGINE_TESTING
            startDHT.set_bool(lt::settings_pack::enable_dht,true);
#endif
            _native->session->apply_settings(startDHT);
        }
        if (_native->handle.is_valid()) _native->session->remove_torrent(_native->handle);
        _native->session->resume();
        _native->info.reset(); _native->selected = -1; _native->size = 0;
        _native->desired = fileIndex;
        _native->error.clear(); _native->name.clear(); _native->path.clear();
        _native->trackerPeers = 0; _native->trackerError.clear();
        _native->pieces.clear(); _native->pendingReads.clear(); _native->cachedBytes = 0;
        _native->publicTest = publicTest; _native->fallbackTried = false;
        _native->metadataSource = "waiting for peers";
        _native->offlineCertificate=nil;_native->resumePending=false;_native->resumeLoaded=false;_native->resumeWrites=0;
        _native->cacheIntegrityFailed=false;_native->verifiedReadBytes=0;_native->verifiedReadPieces=0;_native->verifiedReadHashSeconds=0;
        _native->durationProbe.reset();_native->durationBytes=nil;_native->containerDuration=0;
        _native->deliveredReadBytes=0;_native->readCacheHits=0;_native->readCacheEvictions=0;_native->unlistedPieceReads=0;_native->readsByPiece.clear();
        _native->resumeSavedAt=0;_native->resumePayload=0;_native->resumeError.clear();
        _native->started = NSProcessInfo.processInfo.systemUptime;_native->lastData=_native->started;
        _native->connectionBegan=_native->started;_native->timing.begin(_native->started);
        _native->transfer=RWTransferWindow();_native->transfer.observe(_native->started,0);
        _native->metadataAtStart=false;_native->allocatedAtStart=0;
        _native->playbackWindow.clear();_native->playbackPieces.clear();_native->playbackWindowActive=false;_native->playbackDiskChecked=0;
        _native->availabilityAt=-1;_native->openingAvailability=-1;
        _native->lastCheckProgress=-1;_native->lastCheckProgressAt=_native->started;
        _native->directory = directory.UTF8String;
        NSMutableString *hash = [NSMutableString new];
        for (unsigned char c : params.info_hash.to_string()) [hash appendFormat:@"%02x", c];
        ProtectSessionCache(_native->session,hash);
        NSString *metadataDirectory = [documents stringByAppendingPathComponent:@"TorrentMetadata"];
        if(!RWCachePathAllowed(documents,metadataDirectory,true)){
            if(error)*error=@"The metadata cache contains an unsupported path or symbolic link.";return NO;
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:metadataDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *metadataPath = [metadataDirectory stringByAppendingPathComponent:[hash stringByAppendingPathExtension:@"torrent"]];
        if(!RWCachePathAllowed(documents,metadataPath,false)){
            if(error)*error=@"The saved torrent metadata contains an unsupported path or symbolic link.";return NO;
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:metadataPath]) {
            lt::error_code cacheError;
            auto cached = std::make_shared<lt::torrent_info>(metadataPath.UTF8String, cacheError);
            if (!cacheError && cached->info_hash() == params.info_hash) {
                params.ti = cached; _native->metadataSource = "Saved verified torrent metadata";
            }
        }
        // Publisher torrent metadata is bundled by infohash. Verify the hash
        // before using it; this does not supply any media payload or fake peers.
        if(!params.ti){
            NSString *bundled=[[[NSBundle mainBundle]resourcePath]stringByAppendingPathComponent:[NSString stringWithFormat:@"Rewind/torrents/%@.torrent",hash]];
            NSDictionary *attributes=[[NSFileManager defaultManager]attributesOfItemAtPath:bundled error:nil];
            if(attributes&&[attributes[NSFileSize]unsignedLongLongValue]<=2ULL*1024*1024){
                lt::error_code metadataError;auto publisher=std::make_shared<lt::torrent_info>(bundled.UTF8String,metadataError);
                if(!metadataError&&publisher->info_hash()==params.info_hash){params.ti=publisher;_native->metadataSource="Bundled publisher torrent metadata; payload from BitTorrent peers";}
            }
        }
        if(!params.ti && publicTest){
            NSString *bundled=[[NSBundle mainBundle]pathForResource:@"cosmos-laundromat" ofType:@"torrent"];
            lt::error_code e;auto info=std::make_shared<lt::torrent_info>(bundled.UTF8String,e);
            if(!e&&info->info_hash()==params.info_hash){params.ti=info;_native->metadataSource="Bundled author metadata";}
        }
        // Isolate swarms: different torrents may contain identical filenames.
        directory=[directory stringByAppendingPathComponent:hash];
        if(!RWCacheTreeAllowed(documents,directory)){
            if(error)*error=@"The download cache contains an unsupported path or symbolic link.";return NO;
        }
        if(params.ti&&!RWTorrentRawPathsAllowed(*params.ti)){
            if(error)*error=@"Torrent contains unsupported original file paths or symbolic links.";return NO;
        }
        [[NSFileManager defaultManager]createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        _native->directory=directory.UTF8String;
        _native->allocatedCacheAtStart=[RWMediaCache allocatedBytesAt:directory];
        if(_preparing){
            _native->preparationAllocationBaseline=[RWMediaCache allocatedBytesAt:directory];
            NSString *part=[directory stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.parts",hash]];
            _native->preparationPartfile=[[[NSFileManager defaultManager]attributesOfItemAtPath:part error:nil][NSFileSize]unsignedLongLongValue]>0;
        }
        params.save_path = _native->directory;
        params.storage_mode=lt::storage_mode_sparse;
        NSString *resumePath=[directory stringByAppendingPathComponent:@"rewind.resume"];
        NSDictionary *resumeAttributes=[[NSFileManager defaultManager]attributesOfItemAtPath:resumePath error:nil];
        if(params.ti&&resumeAttributes&&[resumeAttributes[NSFileSize]unsignedLongLongValue]<=1024*1024){
            NSData *bytes=[NSData dataWithContentsOfFile:resumePath];lt::error_code resumeError;
            auto saved=lt::read_resume_data({(const char *)bytes.bytes,static_cast<std::ptrdiff_t>(bytes.length)},resumeError);
            if(!resumeError)_native->resumeLoaded=RWRestoreTorrentProgress(params,saved);
            else _native->resumeError=resumeError.message();
        }
        _native->metadataAtStart=bool(params.ti);
        params.flags &= ~(lt::torrent_flags::auto_managed | lt::torrent_flags::paused);
        // Obtain metadata, then validate size and file paths before downloading payload.
        params.flags |= lt::torrent_flags::upload_mode | lt::torrent_flags::sequential_download;
        params.url_seeds.clear(); params.http_seeds.clear();
        // Metadata is capped at 1000 files below. Start all files disabled so
        // we can observe completion of the later asynchronous file-priority job.
        params.file_priorities.assign(1000,lt::dont_download);
        _native->privateTrackers.prepare(params);
        _native->handle = _native->session->add_torrent(params, ec);_torrentStartCount++;
        if (ec) { if (error) *error = @(ec.message().c_str()); return NO; }
        _native->handle.set_max_connections(_native->probing?12:40);
        return YES;
    } catch (const std::exception &e) {
        if (error) *error = @(e.what());
        return NO;
    }
}
- (void)selectVideo {
    auto &n = *_native;
    if(n.info->priv())n.privateTrackers.learnedPrivate(n.handle);
    const auto &files = n.info->files();
    if(files.num_files()>1000){n.error="This torrent exceeds the 1000-file limit.";n.handle.pause();return;}
    if(!RWTorrentRawPathsAllowed(*n.info)||!RWCacheTreeAllowed(EngineDocuments(),@(n.directory.c_str()))){
        n.error="Torrent contains an unsupported original file path or cached symbolic link.";n.handle.pause();return;
    }
    NSMutableArray *descriptors=[NSMutableArray new];
    for (int i = 0; i < files.num_files(); ++i) {
        auto index = lt::file_index_t(i);
        NSString *relative = @(files.file_path(index).c_str());
        if ((files.file_flags(index) & lt::file_storage::flag_symlink)
            || [relative isAbsolutePath] || [relative.pathComponents containsObject:@".."]) {
            n.error = "Torrent contains an unsupported file path or symbolic link."; n.handle.pause(); return;
        }
        [descriptors addObject:@{@"index":@(i),@"path":relative,@"size":@(files.file_size(index))}];
    }
    NSString *identityError=nil;n.selected=int(RWSelectTorrentVideo(descriptors,n.source?:@{},n.desired,&identityError));
    if(n.selected<0){n.fileIdentityFailure=true;n.error=(identityError?:@"The requested video file is not present in this torrent.").UTF8String;n.handle.pause();return;}
    if(n.info->piece_length()>RWMaxTorrentPieceBytes){n.error="This torrent exceeds the 16 MB verified-piece memory limit.";n.handle.pause();return;}
    auto selected = lt::file_index_t(n.selected);
    n.size = files.file_size(selected); n.fileOffset = files.file_offset(selected);
    n.path = files.file_path(selected, n.directory); n.name = files.file_name(selected).to_string();
    // Catalog runtimes can describe a different cut, or a typical episode.
    // Inspect the bounded, hash-verified container even when a hint exists.
    {
        NSString *ext=@(n.name.c_str()).pathExtension.lowercaseString;
        n.durationProbe.reset(new RWMediaDuration([ext isEqual:@"mkv"]?RWMediaDuration::Matroska:RWMediaDuration::MP4,uint64_t(n.size)));
        n.durationBytes=[NSMutableData new];
    }
    struct stat existing = {};
    bool materialized=stat(n.path.c_str(), &existing)==0;
    uint64_t allocated = materialized ? uint64_t(existing.st_blocks) * 512 : 0;
    n.allocatedAtStart=allocated;
    // Fresh downloads keep verified blocks in libtorrent's compact partfile.
    // A subtitle sharing the final movie piece must not force a multi-gigabyte
    // video file allocation on HFS. Existing materialized downloads stay intact.
    n.compactStorage=!materialized;
#ifdef RW_ENGINE_TESTING
    if(getenv("REWIND_ENGINE_LEGACY_STORAGE"))n.compactStorage=false;
#endif
    if(n.compactStorage)n.preparationPartfile=false; // No export into a video file.
    NSDictionary *disk = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@(n.directory.c_str()) error:nil];
    if (!RWCanStore(uint64_t(n.size),[disk[NSFileSystemFreeSize] unsignedLongLongValue],allocated)) {
        n.error = "There is not enough free space for this video. Remove a previous download first."; n.size = 0; n.handle.pause(); return;
    }
    // Only metadata can establish that a torrent is public. Private torrents
    // retain their own trackers; libtorrent also disables their DHT/PEX.
#ifndef RW_ENGINE_TESTING
    if (!n.info->priv()) {
        auto trackers=n.handle.trackers();
        for (NSString *url in [RWTrackerPolicy publicFallbacks]) {
            NSString *key=[RWTrackerPolicy canonicalKeyForURL:url allowHTTPS:NO];
            bool exists=std::any_of(trackers.begin(),trackers.end(),[&](const lt::announce_entry &entry){
                NSString *existing=[[NSString alloc]initWithBytes:entry.url.data() length:entry.url.size() encoding:NSUTF8StringEncoding];
                return [[RWTrackerPolicy canonicalKeyForURL:existing allowHTTPS:NO]isEqual:key];
            });
            if(!exists){lt::announce_entry entry(url.UTF8String);entry.tier=250;n.handle.add_tracker(entry);}
        }
    }
#endif
    lt::create_torrent creator(*n.info);
    std::vector<char> metadata; lt::bencode(std::back_inserter(metadata), creator.generate());
    NSMutableString *hash = [NSMutableString new];
    for (unsigned char c : n.info->info_hash().to_string()) [hash appendFormat:@"%02x", c];
    NSString *metadataPath = [[EngineDocuments()
        stringByAppendingPathComponent:@"TorrentMetadata"] stringByAppendingPathComponent:[hash stringByAppendingPathExtension:@"torrent"]];
    [[NSData dataWithBytes:metadata.data() length:metadata.size()] writeToFile:metadataPath atomically:YES];
    n.wantedFiles.assign(files.num_files(),lt::dont_download);
    if(!n.compactStorage)n.wantedFiles[n.selected]=lt::default_priority;
    n.prioritiesPending=true;
    if(!_preparing){n.handle.prioritize_files(n.wantedFiles);n.filePrioritiesSubmitted=true;}
    // Stay in upload mode until that asynchronous disk job has committed.
}
- (void)activateVideo {
    if(!_native||!_native->prioritiesPending||!_native->info)return;auto &n=*_native;
    if(_preparing){
        if(!_preparationPayloadAllowed||_preparationStopped||n.preparationPartfile)return;
        RWPreparationRange plan=RWPrepareOpening(n.fileOffset,n.size,n.info->piece_length(),RWPreparationByteBudget);
        if(!plan.allowed)return;
        if(!_preparationPayloadHash||![_preparationPayloadHash isEqual:n.source[@"infoHash"]])return;
        if(!_preparationPayloadStarted)_preparationPayloadStarted=NSProcessInfo.processInfo.systemUptime;
    }
    if(!n.filePrioritiesSubmitted){n.handle.prioritize_files(n.wantedFiles);n.filePrioritiesSubmitted=true;}
    auto status=n.handle.status();
    if(status.state==lt::torrent_status::checking_files||status.state==lt::torrent_status::checking_resume_data)return;
    bool complete=status.is_seeding;
    if(n.handle.get_file_priorities()!=n.wantedFiles&&!complete)return;
    if(n.probing){
        // End-of-file writes can allocate an entire movie on this filesystem.
        // Probe only verified opening pieces, after file priorities settle.
        n.probePieces.clear();n.probeHeadCount=0;n.probeRequestedBytes=0;
        std::vector<lt::download_priority_t> pieces(n.info->num_pieces(),lt::dont_download);
        int64_t first=0,last=0;
        if(!RWPieceRange(n.fileOffset,n.size,0,RWProbeHeadBytes(uint64_t(n.size)),n.info->piece_length(),&first,&last)){n.error="Invalid opening piece range.";return;}
        for(int64_t i=first;i<=last;i++){n.probePieces.push_back(int(i));pieces[size_t(i)]=lt::default_priority;}
        n.probeHeadCount=n.probePieces.size();
        bool cachedHeader=true;for(int piece:n.probePieces)cachedHeader=cachedHeader&&n.handle.have_piece(lt::piece_index_t(piece));
        for(int piece:n.probePieces)if(!n.handle.have_piece(lt::piece_index_t(piece)))n.probeRequestedBytes+=n.info->piece_size(lt::piece_index_t(piece));
        int videoFirst=int(n.fileOffset/n.info->piece_length()),videoLast=int((n.fileOffset+n.size-1)/n.info->piece_length());
        int measure=_preparing?(last<videoLast?int(last)+1:-1):RWProbeAheadPiece(videoFirst,int(last),videoLast,cachedHeader,[&](int piece){return n.handle.have_piece(lt::piece_index_t(piece));});
        if(measure>=0){
            uint64_t cost=n.handle.have_piece(lt::piece_index_t(measure))?0:uint64_t(n.info->piece_size(lt::piece_index_t(measure)));
            if(n.probeRequestedBytes<=RWProbeTransferBudget&&cost<=RWProbeTransferBudget-n.probeRequestedBytes){
                n.probePieces.push_back(measure);pieces[size_t(measure)]=lt::default_priority;n.probeRequestedBytes+=cost;
            }
        }
        n.probeNextPiece=videoFirst;
        n.handle.prioritize_pieces(pieces);
        auto actual=n.handle.get_piece_priorities();n.enabledProbePieces=int(std::count_if(actual.begin(),actual.end(),[](lt::download_priority_t priority){return priority!=lt::dont_download;}));
        if(!complete&&n.enabledProbePieces!=int(n.probePieces.size())){n.error="Opening piece priorities did not apply.";return;}
    }
    n.prioritiesPending=false;n.handle.unset_flags(lt::torrent_flags::upload_mode);
    if(n.probing){for(size_t i=0;i<n.probePieces.size();i++)n.handle.set_piece_deadline(lt::piece_index_t(n.probePieces[i]),RWProbeDeadline(i,n.probeHeadCount));}
    else {n.playbackWindowActive=true;[self prioritizeOffset:0 length:2*1024*1024];}
}
- (void)pollAlerts {
    if (!_native->session) return;
    std::vector<lt::alert *> alerts; _native->session->pop_alerts(&alerts);
    for (auto a : alerts) {
        NativeTorrent *target=_native;
        if(auto event=dynamic_cast<lt::torrent_alert *>(a)){
            for(auto &probe:_probes)if(probe->handle==event->handle){target=probe.get();break;}
        }
        auto &n=*target;
        if(auto warning=lt::alert_cast<lt::performance_alert>(a))
            if(warning->handle==n.handle&&warning->warning_code==lt::performance_alert::upload_limit_too_low)n.uploadLimitWarnings++;
        if(auto saved=lt::alert_cast<lt::save_resume_data_alert>(a)){
            if(saved->handle==n.handle){n.resumePending=false;
                if(n.cacheIntegrityFailed)continue; // A queued save cannot reinstate rejected progress.
                try{auto bytes=lt::write_resume_data_buf(saved->params);
                    BOOL wrote=!bytes.empty()&&bytes.size()<=1024*1024&&[[NSData dataWithBytes:bytes.data() length:bytes.size()]writeToFile:[@(n.directory.c_str())stringByAppendingPathComponent:@"rewind.resume"] atomically:YES];
                    if(wrote){n.resumeWrites++;n.resumeError.clear();
                        if(n.info&&n.size>0&&n.selected>=0){int first=int(n.fileOffset/n.info->piece_length()),last=int((n.fileOffset+n.size-1)/n.info->piece_length());bool complete=saved->params.have_pieces.size()>last;for(int piece=first;complete&&piece<=last;piece++)complete=saved->params.have_pieces[lt::piece_index_t(piece)];
                            if(complete){NSString *directory=@(n.directory.c_str()),*hash=directory.lastPathComponent;NSString *path=n.compactStorage?[directory stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.parts",hash]]:@(n.path.c_str());NSInteger index=[n.source[@"fileIdx"]isKindOfClass:NSNumber.class]?[n.source[@"fileIdx"]integerValue]:-1;n.offlineCertificate=[RWOfflineMedia certificateForPath:path root:[EngineDocuments()stringByAppendingPathComponent:@"Torrents"] hash:hash fileIndex:index];}
                        }
                    }else n.resumeError="Could not save bounded resume data";
                }catch(const std::exception &error){n.resumeError=error.what();}
            }
        }
        if(auto failed=lt::alert_cast<lt::save_resume_data_failed_alert>(a))if(failed->handle==n.handle){n.resumePending=false;n.resumeError=failed->error.message();}
        if(auto reply=lt::alert_cast<lt::dht_reply_alert>(a))if(reply->handle==n.handle)n.dhtPeers+=reply->num_peers;
        if (auto reply = lt::alert_cast<lt::tracker_reply_alert>(a)) {
            if (reply->handle == n.handle) n.trackerPeers += reply->num_peers;
        }
        if (auto failure = lt::alert_cast<lt::tracker_error_alert>(a)) {
            if (failure->handle == n.handle) {
                n.trackerError = failure->error.message();
                if(n.session&&!n.session->is_paused()&&n.error.empty())
                    n.privateTrackers.failed(n.handle,failure->tracker_url());
            }
        }
        if (auto read = lt::alert_cast<lt::read_piece_alert>(a)) {
            if (read->handle != n.handle) continue;
            int index = static_cast<int>(read->piece);
            n.pendingReads.erase(index);
            if (read->error) { n.error = read->error.message(); continue; }
            if (!read->buffer || read->size <= 0 || read->size > RWMaxTorrentPieceBytes) continue;
            if(n.cacheIntegrityFailed)continue;
            // Fast resume's have-pieces flags do not hash the current disk
            // contents. Verify each bounded whole-piece read before exposing
            // any range to a decoder or subtitle parser. Repeated ranges use
            // this already-checked in-memory piece until normal cache eviction.
            double hashBegan=NSProcessInfo.processInfo.systemUptime;
            bool intact=n.info&&index>=0&&index<n.info->num_pieces()&&
                read->size==n.info->piece_size(read->piece)&&
                lt::hasher(read->buffer.get(),read->size).final()==n.info->hash_for_piece(read->piece);
            n.verifiedReadHashSeconds+=NSProcessInfo.processInfo.systemUptime-hashBegan;
            if(!intact){
                n.cacheIntegrityFailed=true;n.error="Cached video data failed its torrent hash check.";
                n.pieces.clear();n.cachedBytes=0;n.offlineCertificate=nil;n.handle.pause();
                // Preserve downloaded media; discard only the unsafe progress
                // claim so a later attempt runs libtorrent's normal recheck.
                NSError *removeError=nil;NSString *resume=[@(n.directory.c_str())stringByAppendingPathComponent:@"rewind.resume"];
                if([[NSFileManager defaultManager]fileExistsAtPath:resume]&&![[NSFileManager defaultManager]removeItemAtPath:resume error:&removeError])n.resumeError="Could not invalidate damaged-cache resume data";
                continue;
            }
            n.verifiedReadBytes+=read->size;n.verifiedReadPieces++;
            if(n.readsByPiece.size()<64||n.readsByPiece.count(index))n.readsByPiece[index]++;else n.unlistedPieceReads++;
            auto old = n.pieces.find(index);
            if (old != n.pieces.end()) { n.cachedBytes -= old->second.size; n.pieces.erase(old); }
            while (!n.pieces.empty() && n.cachedBytes + read->size > RWVerifiedPieceCacheBytes) {
                auto oldest = std::min_element(n.pieces.begin(), n.pieces.end(),
                    [](const auto &a, const auto &b) { return a.second.used < b.second.used; });
                n.cachedBytes -= oldest->second.size; n.pieces.erase(oldest);n.readCacheEvictions++;
            }
            n.pieces.emplace(index, NativeTorrent::Piece{read->buffer, read->size, ++n.clock});
            n.cachedBytes += read->size;
        }
    }
    if(!_native->session->is_paused()){
        if(_native->handle.is_valid()&&_native->error.empty())_native->privateTrackers.settle(_native->handle);
        for(auto &probe:_probes)if(probe->handle.is_valid()&&probe->error.empty())probe->privateTrackers.settle(probe->handle);
    }
}
- (NSDictionary *)snapshot {
    if(!_native)return @{};
    auto &n = *_native;
    if (!n.session || !n.handle.is_valid()) return @{@"state": @"Ready"};
    try {
        [self pollAlerts];
        auto status = n.handle.status();
        if(status.total_payload_download>n.resumePayload&&NSProcessInfo.processInfo.systemUptime-n.resumeSavedAt>=5)[self requestResume:&n];
        if (status.has_metadata && !n.info) {
            n.info = n.handle.torrent_file();
            if (!n.fallbackTried && n.metadataSource == "waiting for peers") n.metadataSource = "BitTorrent peer metadata exchange";
            [self selectVideo];
        }
        [self activateVideo];if(n.playbackWindowActive)[self applyPlaybackWindow];
        double elapsed = NSProcessInfo.processInfo.systemUptime - n.started;
        if (!status.has_metadata && n.publicTest && !n.fallbackTried && elapsed > 30) {
            n.fallbackTried = true;
            NSString *path = [[NSBundle mainBundle] pathForResource:@"cosmos-laundromat" ofType:@"torrent"];
            lt::error_code ec; lt::torrent_info fallback(path.UTF8String, ec);
            if (!ec && fallback.info_hash() == n.handle.info_hash()) {
                n.handle.set_metadata({fallback.metadata().get(), fallback.metadata_size()});
                n.metadataSource = "Bundled author torrent metadata; payload still from BitTorrent peers";
            }
        }
        if (status.errc) n.error = status.errc.message();
        std::vector<int64_t> progress;
        int64_t videoBytes = 0;
        if (n.selected >= 0) {
            n.handle.file_progress(progress, lt::torrent_handle::piece_granularity);
            if (n.selected < (int)progress.size()) videoBytes = progress[n.selected];
        }
        // A complete local file can produce no new peer traffic at all. Still
        // obtain the library's verified have-pieces checkpoint, so offline
        // eligibility is persisted while the player is alive (before close).
        if(n.size>0&&videoBytes>=n.size&&!n.offlineCertificate&&!n.resumePending&&NSProcessInfo.processInfo.systemUptime-n.resumeSavedAt>=5&&status.state!=lt::torrent_status::checking_files&&status.state!=lt::torrent_status::checking_resume_data)[self requestResume:&n];
        auto sessionStatus = n.session->status();
        std::vector<lt::peer_info> peers;n.handle.get_peer_info(peers);
        int interested=0,choked=0,requests=0,queuedRequests=0,withPiece=0;
        int64_t sendBufferBytes=0,sendQuotaBytes=0;
        for(const auto &peer:peers){interested+=bool(peer.flags & lt::peer_info::interesting);choked+=bool(peer.flags & lt::peer_info::remote_choked);requests+=peer.download_queue_length;queuedRequests+=peer.requests_in_buffer;
            sendBufferBytes+=peer.used_send_buffer;sendQuotaBytes+=peer.send_quota;
            if(n.requestedPiece>=0&&n.requestedPiece<peer.pieces.size()&&peer.pieces[lt::piece_index_t(n.requestedPiece)])withPiece++;
        }
        int pieceRequested=0,pieceFinished=0,pieceWriting=0;std::vector<lt::partial_piece_info> queue;n.handle.get_download_queue(queue);
        for(const auto &piece:queue)if(int(piece.piece_index)==n.requestedPiece){pieceRequested=piece.requested;pieceFinished=piece.finished;pieceWriting=piece.writing;}
        NSString *state = !status.has_metadata ? @"Finding peers" :
            (n.size > 0 && videoBytes >= n.size ? @"Download complete — tap Play torrent video" :
             (status.download_payload_rate > 0 ? @"Downloading — tap Play torrent video" : @"Waiting for video data"));
        if (status.paused) state = @"Paused";
        if (!n.error.empty()) state = @"Error";
        NSMutableDictionary *pieceReads=[NSMutableDictionary new];for(const auto &item:n.readsByPiece)pieceReads[[NSString stringWithFormat:@"%d",item.first]]=@(item.second);
        NSDictionary *transport=_transportDiagnostics?RWPeerTransport::Capture(n.handle,RWPeerTransport::SessionLimits(*n.session)):@{};
        return @{@"transport":transport,@"peer_retry_settings":[self peerRetrySettings],@"peer_discovery":RWPeerEvidence::Snapshot(n.handle),@"container_duration_seconds":@(n.containerDuration),@"read_delivered_bytes":@(n.deliveredReadBytes),@"read_cache_hits":@(n.readCacheHits),@"read_cache_evictions":@(n.readCacheEvictions),@"verified_reads_by_piece":pieceReads,@"read_piece_count_limit":@64,@"unlisted_piece_reads":@(n.unlistedPieceReads),@"state": state,@"session_id":_sessionID?:@"",@"torrent_start_count":@(_torrentStartCount),
                 @"download_limit":@(n.handle.download_limit()),@"upload_mode":@(bool(status.flags & lt::torrent_flags::upload_mode)),@"torrent_finished":@(status.is_finished),@"wanted_bytes":@(status.total_wanted),@"wanted_done_bytes":@(status.total_wanted_done),
                 @"interested_peers":@(interested),@"peers_choking_us":@(choked),@"peer_requests_pending":@(requests),@"peer_requests_unsent":@(queuedRequests),
                 @"peer_send_buffer_bytes":@(sendBufferBytes),@"peer_send_quota_bytes":@(sendQuotaBytes),@"upload_limit_warnings":@(n.uploadLimitWarnings),
                 @"session_ip_overhead_upload_bytes":@(sessionStatus.total_ip_overhead_upload),@"session_payload_upload_bytes":@(sessionStatus.total_payload_upload),
                 @"session_upload_bytes_including_overhead":@(sessionStatus.total_upload),
                 @"requested_piece_verified":@(n.requestedPiece>=0&&n.info&&n.requestedPiece<n.info->num_pieces()&&n.handle.have_piece(lt::piece_index_t(n.requestedPiece))),@"requested_video_offset":@(n.requestedOffset),@"requested_piece":@(n.requestedPiece),@"peers_with_requested_piece":@(withPiece),@"requested_piece_pending_blocks":@(pieceRequested),@"requested_piece_finished_blocks":@(pieceFinished),@"requested_piece_writing_blocks":@(pieceWriting),
                 @"resume_loaded":@(n.resumeLoaded),@"resume_pending":@(n.resumePending),@"resume_writes":@(n.resumeWrites),@"resume_error":@(n.resumeError.c_str()),
                 @"verified_read_bytes":@(n.verifiedReadBytes),@"verified_read_pieces":@(n.verifiedReadPieces),@"verified_read_hash_seconds":@(n.verifiedReadHashSeconds),@"cache_integrity_failed":@(n.cacheIntegrityFailed),
                 @"local_checking":@(status.state==lt::torrent_status::checking_files||status.state==lt::torrent_status::checking_resume_data),@"torrent_progress":@(status.progress),
                 @"metadata": @(status.has_metadata), @"metadata_source": @(n.metadataSource.c_str()),@"cache_at_start":@{@"metadata_available":@(n.metadataAtStart),@"resume_loaded":@(n.resumeLoaded),@"allocated_video_bytes":@(n.allocatedAtStart),@"allocated_cache_bytes":@(n.allocatedCacheAtStart),@"disk_data_requires_validation":@(n.allocatedCacheAtStart>0)},
                 @"private_tracker_restricted":@(n.privateTrackers.restricted),@"private_tracker_candidates":@(n.privateTrackers.candidates.size()),@"private_tracker_switches":@(n.privateTrackers.switches),@"private_tracker_draining":@(n.privateTrackers.draining),
                 @"tracker_https_ready":@(_trackerTLSAnchors>0),@"tracker_tls_anchors":@(_trackerTLSAnchors),
                 @"tracker_count":@(n.handle.trackers().size()),@"known_peers":@(status.list_peers),@"connect_candidates":@(status.connect_candidates),@"dht_peers_reported":@(n.dhtPeers),
                 @"announcing_to_trackers":@(status.announcing_to_trackers),@"announcing_to_dht":@(status.announcing_to_dht),@"peers": @(status.num_peers), @"seeds": @(status.num_seeds), @"dht_nodes": @(sessionStatus.dht_nodes),
                 @"download_bytes_per_second": @(status.download_payload_rate),
                 @"peer_payload_bytes": @(status.total_payload_download), @"video_verified_bytes": @(videoBytes),
                 @"video_total_bytes": @(n.size), @"video_name": @(n.name.c_str()),
                 @"video_complete": @(n.size > 0 && videoBytes >= n.size),@"offline_certificate":n.offlineCertificate?:@{},
                 @"elapsed_seconds": @(elapsed), @"tracker_peers_reported": @(n.trackerPeers),
                 @"tracker_error": @(n.trackerError.c_str()), @"error": @(n.error.c_str()),
                 @"startup_prefetch_active":@(n.startupPrefetch.state()==RWStartupPrefetch::Pending),@"startup_prefetch_state":@(n.startupPrefetch.state()),@"startup_prefetch_piece_count":@(n.startupPrefetch.pieces().size()),@"allocated_video_bytes":@([self allocatedVideoBytes]),@"allocated_cache_bytes":@(n.allocatedCacheBytes),@"compact_piece_storage":@(n.compactStorage),@"playback_wanted_piece_count":@(n.playbackPieces.size()),@"playback_wanted_byte_bound":@(n.playbackPieces.size()*(n.info?uint64_t(n.info->piece_length()):0)),@"playback_free_bytes":@(n.playbackFreeBytes),@"web_seeds_enabled": @NO};
    } catch (const std::exception &e) { return @{@"state": @"Error", @"error": @(e.what())}; }
}
#include "TorrentPreparation.inc"
#include "TorrentFocus.inc"
#include "TorrentDiscovery.inc"
- (uint64_t)allocatedVideoBytes { struct stat st={};return !_native->path.empty()&&stat(_native->path.c_str(),&st)==0?(uint64_t)st.st_blocks*512:0; }
- (int64_t)videoSize { return _native->size; }
- (NSString *)videoName { return @(_native->name.c_str()); }
- (void)pause {if(NSThread.isMainThread){[self perform:^(TorrentEngine *e){[e pause];}];return;}if(!_native)return;if(!_pausedAt)_pausedAt=NSProcessInfo.processInfo.systemUptime;[self endDiscoveryFocus:@"paused" now:NSProcessInfo.processInfo.systemUptime];for(auto &probe:_probes)RWPeerEvidence::SetProbeTurnover(probe->handle,false);RWPeerEvidence::SetProbeTurnover(_native->handle,false);if (_native->session) _native->session->pause(); }
- (void)resume {if(NSThread.isMainThread){[self perform:^(TorrentEngine *e){[e resume];}];return;}if(!_native)return;if(_pausedAt){double gap=NSProcessInfo.processInfo.systemUptime-_pausedAt;_raceStarted+=gap;if(_focusHash)_focusStarted+=gap;for(auto &probe:_probes){probe->started+=gap;probe->lastData+=gap;}_pausedAt=0;}if (_native->session) _native->session->resume(); }
- (void)resetPlaybackRequests {
    if(NSThread.isMainThread){[self perform:^(TorrentEngine *e){[e resetPlaybackRequests];}];return;}
    if(!_native)return;_native->playbackWindow.clear();_native->startupPrefetch.cancel();if(_native->playbackWindowActive)[self applyPlaybackWindow];
}
- (void)applyPlaybackWindow {
    auto &n=*_native;if(!n.playbackWindowActive||!n.info||!n.handle.is_valid()||!n.error.empty())return;
    double now=NSProcessInfo.processInfo.systemUptime;
    if(now-n.playbackDiskChecked>=1){
        n.playbackDiskChecked=now;NSDictionary *disk=[[NSFileManager defaultManager]attributesOfFileSystemForPath:@(n.directory.c_str()) error:nil];
        n.allocatedCacheBytes=[RWMediaCache allocatedBytesAt:@(n.directory.c_str())];
        n.playbackFreeBytes=[disk[NSFileSystemFreeSize]unsignedLongLongValue];
        if(n.playbackFreeBytes<512ULL*1024*1024){n.error="Playback stopped to preserve 512 MB of free storage.";n.handle.set_flags(lt::torrent_flags::upload_mode);return;}
    }
    std::vector<int> wanted;size_t limit=RWPlaybackWantedBudget/uint64_t(n.info->piece_length());
    auto add=[&](int piece){if(wanted.size()<limit&&std::find(wanted.begin(),wanted.end(),piece)==wanted.end())wanted.push_back(piece);};
    // Subtitles stay in the partfile and use piece priorities; changing file
    // priorities would asynchronously reset the video's bounded piece window.
    if(_subtitleBytes&&_subtitleBytes.length<_subtitleSize){int64_t first=0,last=0;
        if(RWPieceRange(_subtitleOffset,_subtitleSize,0,uint32_t(_subtitleSize),n.info->piece_length(),&first,&last))for(int64_t p=first;p<=last;p++)add(int(p));
    }
    double rate=n.containerDuration>0?double(n.size)/n.containerDuration:RWRequiredStreamRate(uint64_t(n.size),[n.source[@"durationHintSeconds"]doubleValue]);
    n.startupPrefetch.update(now,[&](int piece){return n.handle.have_piece(lt::piece_index_t(piece));});
    for(int piece:n.playbackWindow.plan(n.fileOffset,n.size,n.info->piece_length(),rate,now,n.startupPrefetch.pieces()))add(piece);
    if(wanted==n.playbackPieces)return;
    n.handle.clear_piece_deadlines();std::vector<lt::download_priority_t> priorities(n.info->num_pieces(),lt::dont_download);
    for(int piece:wanted)priorities[size_t(piece)]=lt::default_priority;
    n.handle.prioritize_pieces(priorities);n.playbackPieces=wanted;
    for(size_t i=0;i<wanted.size();i++)if(!n.handle.have_piece(lt::piece_index_t(wanted[i])))n.handle.set_piece_deadline(lt::piece_index_t(wanted[i]),int(i)*200);
}
- (void)prioritizeOffset:(int64_t)offset length:(NSUInteger)length {
    if(!_native)return;
    auto &n = *_native;
    if (!n.info || n.selected < 0 || offset < 0 || offset >= n.size) return;
    const int pieceLength = n.info->piece_length();
    int64_t first64=0,last64=0;
    if(!RWPieceRange(n.fileOffset,n.size,offset,(uint32_t)std::min<NSUInteger>(length,4*1024*1024),pieceLength,&first64,&last64)||last64>INT_MAX)return;
    int first=(int)first64,last=(int)last64;
    n.requestedOffset=offset;n.requestedPiece=first;
    if(n.playbackWindowActive){n.playbackWindow.request(offset,uint32_t(std::min<NSUInteger>(length,4*1024*1024)),NSProcessInfo.processInfo.systemUptime);[self applyPlaybackWindow];return;}
    for (int i = first; i <= last; ++i) {
        auto piece = lt::piece_index_t(i);
        if (!n.handle.have_piece(piece)) n.handle.set_piece_deadline(piece, (i - first) * 200);
    }
}
- (NSData *)readVerifiedBytesAt:(int64_t)offset length:(NSUInteger)length {
    if(!_native)return nil;
    auto &n = *_native;
    if (!n.info || n.selected < 0 || offset < 0 || offset >= n.size) return nil;
    return [self readGlobal:n.fileOffset+offset available:n.size-offset length:length];
}
- (NSData *)readGlobal:(int64_t)global available:(int64_t)available length:(NSUInteger)length {
    auto &n=*_native;[self pollAlerts];
    if(!n.error.empty()||!n.info||!n.handle.is_valid())return nil;
    int index = int(global / n.info->piece_length());
    auto found = n.pieces.find(index);
    if (found == n.pieces.end()) {
        // Read through libtorrent: a verified piece can still be in its write cache.
        if (n.pendingReads.empty()
            && n.handle.have_piece(lt::piece_index_t(index))) {
            // Reserve capacity before asking libtorrent for a whole verified
            // piece. One pending read plus cached pieces stays within 16 MiB.
            int size=n.info->piece_size(lt::piece_index_t(index));
            while(!n.pieces.empty()&&n.cachedBytes+size>RWVerifiedPieceCacheBytes){
                auto oldest=std::min_element(n.pieces.begin(),n.pieces.end(),[](const auto &a,const auto &b){return a.second.used<b.second.used;});
                n.cachedBytes-=oldest->second.size;n.pieces.erase(oldest);n.readCacheEvictions++;
            }
            n.pendingReads.insert(index); n.handle.read_piece(lt::piece_index_t(index));
        }
        return nil;
    }
    auto &piece = found->second; piece.used = ++n.clock;
    int within = int(global % n.info->piece_length());
    int64_t count = std::min<int64_t>(length, std::min<int64_t>(available, piece.size - within));
    if (count <= 0) return nil;
    n.deliveredReadBytes+=count;n.readCacheHits++;
    return [NSData dataWithBytes:piece.data.get() + within length:(NSUInteger)count];
}
- (NSArray *)subtitleFiles {
    if(!_native||!_native->info)return @[];NSMutableArray *result=[NSMutableArray new];const auto &files=_native->info->files();
    for(int i=0;i<files.num_files();i++){auto index=lt::file_index_t(i);NSString *path=@(files.file_path(index).c_str());
        if(![@[@"srt",@"vtt"]containsObject:path.pathExtension.lowercaseString]||files.file_size(index)<=0||files.file_size(index)>2*1024*1024)continue;
        NSString *name=path.lastPathComponent.stringByDeletingPathExtension;NSString *lower=name.lowercaseString;
        NSString *language=([lower containsString:@"english"]||[lower containsString:@".eng"]||[lower isEqual:@"en"]||[lower isEqual:@"eng"])?@"English":([lower containsString:@"macedonian"]||[lower containsString:@".mkd"])?@"Macedonian":nil;
        if(!language)language=name.length>45?@"Default subtitles":name;
        [result addObject:@{@"index":@(i),@"name":language,@"filename":path.lastPathComponent,@"path":path,@"size":@(files.file_size(index))}];if(result.count>=40)break;
    }return result;
}
- (BOOL)beginSubtitle:(NSInteger)index {
    [self cancelSubtitle];if(!_native->info)return NO;const auto &files=_native->info->files();
    if(index<0||index>=files.num_files())return NO;auto i=lt::file_index_t(int(index));NSString *path=@(files.file_path(i).c_str());
    if(![@[@"srt",@"vtt"]containsObject:path.pathExtension.lowercaseString]||files.file_size(i)<=0||files.file_size(i)>2*1024*1024)return NO;
    _subtitleIndex=int(index);_subtitleOffset=files.file_offset(i);_subtitleSize=files.file_size(i);_subtitleBytes=[NSMutableData new];
    if(_native->playbackWindowActive){[self applyPlaybackWindow];return YES;}
    _native->handle.file_priority(i,lt::default_priority);
    int64_t first=0,last=0;RWPieceRange(_subtitleOffset,_subtitleSize,0,uint32_t(_subtitleSize),_native->info->piece_length(),&first,&last);
    for(int64_t p=first;p<=last;p++)_native->handle.set_piece_deadline(lt::piece_index_t(int(p)),0);return YES;
}
- (NSData *)subtitleData {
    if(!_subtitleBytes||!_native->info)return nil;
    for(int i=0;i<8&&_subtitleBytes.length<_subtitleSize;i++){NSData *part=[self readGlobal:_subtitleOffset+_subtitleBytes.length available:_subtitleSize-_subtitleBytes.length length:256*1024];if(!part.length)break;[_subtitleBytes appendData:part];}
    return _subtitleBytes.length==_subtitleSize?[_subtitleBytes copy]:nil;
}
- (void)cancelSubtitle {if(NSThread.isMainThread){[self perform:^(TorrentEngine *e){[e cancelSubtitle];}];return;}if(!_native)return;if(_subtitleBytes&&_native->handle.is_valid()&&!_native->playbackWindowActive)_native->handle.file_priority(lt::file_index_t(_subtitleIndex),lt::dont_download);_subtitleBytes=nil;_subtitleIndex=-1;_subtitleSize=0;if(_native->playbackWindowActive)[self applyPlaybackWindow];}
@end
