#import "TorrentLoader.h"
#include "RWByteRange.h"
@interface TorrentLoader ()
@property(atomic,assign) BOOL stopped;
@property(atomic,copy,readwrite) NSDictionary *diagnostics;
@end

@implementation TorrentLoader {
    TorrentEngine *_engine;
    NSMutableArray *_requests;
    dispatch_source_t _timer;
    AVURLAsset *_asset;
    NSString *_name;
    int64_t _size;
    NSMutableArray *_trace;
    uint64_t _bytesSent,_startedRequests,_cancelledRequests;
    double _lastDiagnostic;
    NSMapTable *_lastServed;
    uint64_t _serviceClock,_engineReads,_sharedBytes,_pumpCount;
    NSUInteger _maxReadsPerPump,_maxReadBytesPerPump;
}
- (instancetype)initWithEngine:(TorrentEngine *)engine name:(NSString *)name size:(int64_t)size {
    if ((self = [super init])) {
        _engine = engine;
        _name=[name copy];_size=size;
        _requests = [NSMutableArray new];
        _lastServed=[NSMapTable strongToStrongObjectsMapTable];
        _trace=[NSMutableArray new];
        _timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,engine.workQueue);
        dispatch_source_set_timer(_timer,dispatch_time(DISPATCH_TIME_NOW,0),100*NSEC_PER_MSEC,10*NSEC_PER_MSEC);
        __weak TorrentLoader *weak=self;dispatch_source_set_event_handler(_timer,^{@autoreleasepool{[weak pump];}});dispatch_resume(_timer);
    }
    return self;
}
- (AVPlayerItem *)playerItem {
    NSString *ext = _name.pathExtension.lowercaseString;
    _asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:[@"ministream://video/current." stringByAppendingString:ext]]
                               options:nil];
    [_asset.resourceLoader setDelegate:self queue:_engine.workQueue];
    return [AVPlayerItem playerItemWithAsset:_asset];
}
- (BOOL)resourceLoader:(AVAssetResourceLoader *)loader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)request {
    if(self.stopped)return NO;
    _startedRequests++;[self observeRequest:request event:@"start"];
    [_requests addObject:request];
    [self pump];
    return YES;
}
- (void)resourceLoader:(AVAssetResourceLoader *)loader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)request {
    _cancelledRequests++;[self observeRequest:request event:@"cancel"];
    [_requests removeObject:request];
    [_lastServed removeObjectForKey:request];
}
- (void)observeRequest:(AVAssetResourceLoadingRequest *)request event:(NSString *)event {
    AVAssetResourceLoadingDataRequest *d=request.dataRequest;
    if(_trace.count>=24)[_trace removeObjectAtIndex:0];
    [_trace addObject:@{@"event":event,@"uptime":@(NSProcessInfo.processInfo.systemUptime),@"offset":@(d.requestedOffset),@"current":@(d.currentOffset),@"length":@(d.requestedLength),@"to_end":@(d.requestsAllDataToEndOfResource)}];
}
- (void)pump {
    if(self.stopped)return;
    // Validate and complete metadata/EOF requests before scheduling any reads.
    for (AVAssetResourceLoadingRequest *request in [_requests copy]) {
        if (request.cancelled || request.finished) { [self removeRequest:request]; continue; }
        int64_t size = _size;
        if (size <= 0) continue;
        AVAssetResourceLoadingContentInformationRequest *info = request.contentInformationRequest;
        if (info) {
            NSString *ext = _name.pathExtension.lowercaseString;
            info.contentType = [ext isEqualToString:@"mov"] ? AVFileTypeQuickTimeMovie :
                ([ext isEqualToString:@"m4v"] ? AVFileTypeAppleM4V : AVFileTypeMPEG4);
            info.contentLength = size;
            info.byteRangeAccessSupported = YES;
        }
        AVAssetResourceLoadingDataRequest *dataRequest = request.dataRequest;
        if (!dataRequest) { [request finishLoading]; [self removeRequest:request]; continue; }
        int64_t offset = MAX(dataRequest.currentOffset, dataRequest.requestedOffset);
        int64_t end=0;bool valid=RWRangeEnd(dataRequest.requestedOffset,(int64_t)dataRequest.requestedLength,dataRequest.requestsAllDataToEndOfResource,size,&end);
        if (!valid || offset < 0 || offset > size || end < offset) {
            [request finishLoadingWithError:[NSError errorWithDomain:@"MiniStream" code:1 userInfo:
                @{NSLocalizedDescriptionKey: @"Invalid video byte range"}]];
            [self removeRequest:request]; continue;
        }
        if (offset == end) { [request finishLoading]; [self removeRequest:request]; }
    }
    // iOS9 can leave many overlapping to-end requests alive. Reading every
    // cursor each tick thrashes the bounded whole-piece cache. Give current
    // demand one turn and the least recently served request a fair second turn.
    // An unavailable read still counts as a turn, so it cannot monopolize work.
    AVAssetResourceLoadingRequest *primary=_requests.lastObject;
    for(AVAssetResourceLoadingRequest *r in [_requests reverseObjectEnumerator]){
        AVAssetResourceLoadingDataRequest *d=r.dataRequest;
        if(!d.requestsAllDataToEndOfResource&&d.requestedLength<=1024*1024){primary=r;break;}
    }
    NSMutableSet *served=[NSMutableSet new];NSUInteger reads=0,readBytes=0;
    for(int turn=0;turn<2&&!self.stopped;turn++){
        AVAssetResourceLoadingRequest *chosen=turn==0?primary:nil;uint64_t oldest=UINT64_MAX;
        if(turn==1)for(AVAssetResourceLoadingRequest *r in _requests){
            uint64_t stamp=[[_lastServed objectForKey:r]unsignedLongLongValue];
            if(![served containsObject:r]&&stamp<oldest){oldest=stamp;chosen=r;}
        }
        if(!chosen||_size<=0)continue;
        AVAssetResourceLoadingDataRequest *d=chosen.dataRequest;int64_t end=0;
        if(!RWRangeEnd(d.requestedOffset,d.requestedLength,d.requestsAllDataToEndOfResource,_size,&end))continue;
        int64_t offset=MAX(d.currentOffset,d.requestedOffset);if(offset<0||offset>=end)continue;
        [_lastServed setObject:@(++_serviceClock) forKey:chosen];[served addObject:chosen];
        [_engine prioritizeOffset:offset length:(NSUInteger)MIN(end-offset,2*1024*1024)];
        NSData *data=[_engine readVerifiedBytesAt:offset length:(NSUInteger)MIN(end-offset,256*1024)];
        reads++;_engineReads++;readBytes+=data.length;
        if(!data.length||self.stopped)continue;
        // The engine has verified these exact bytes. Reuse them only for pending
        // cursors inside this span; never skip a gap or finish a prefix as EOF.
        for(AVAssetResourceLoadingRequest *r in [_requests copy]){
            if(r.cancelled||r.finished){[self removeRequest:r];continue;}
            AVAssetResourceLoadingDataRequest *other=r.dataRequest;int64_t otherEnd=0;
            if(!RWRangeEnd(other.requestedOffset,other.requestedLength,other.requestsAllDataToEndOfResource,_size,&otherEnd))continue;
            int64_t cursor=MAX(other.currentOffset,other.requestedOffset);
            if(cursor<offset||cursor>=offset+(int64_t)data.length||cursor>=otherEnd)continue;
            NSUInteger begin=(NSUInteger)(cursor-offset),length=(NSUInteger)MIN(otherEnd-cursor,(int64_t)data.length-begin);
            NSData *part=begin==0&&length==data.length?data:[data subdataWithRange:NSMakeRange(begin,length)];
            [other respondWithData:part];_bytesSent+=part.length;if(r!=chosen)_sharedBytes+=part.length;
            [_lastServed setObject:@(++_serviceClock) forKey:r];[served addObject:r];
            if(other.currentOffset>=otherEnd){[r finishLoading];[self removeRequest:r];}
        }
    }
    // Keep the current decoder demand first in the bounded torrent window.
    // The fair older read must not leave its speculative range ahead of it.
    if(primary&&[_requests containsObject:primary]&&!self.stopped){
        AVAssetResourceLoadingDataRequest *d=primary.dataRequest;int64_t end=0,offset=MAX(d.currentOffset,d.requestedOffset);
        if(RWRangeEnd(d.requestedOffset,d.requestedLength,d.requestsAllDataToEndOfResource,_size,&end)&&offset>=0&&offset<end)
            [_engine prioritizeOffset:offset length:(NSUInteger)MIN(end-offset,2*1024*1024)];
    }
    _pumpCount++;_maxReadsPerPump=MAX(_maxReadsPerPump,reads);_maxReadBytesPerPump=MAX(_maxReadBytesPerPump,readBytes);
    double now=NSProcessInfo.processInfo.systemUptime;
    if(now-_lastDiagnostic>=1){_lastDiagnostic=now;NSMutableArray *active=[NSMutableArray new];
        for(AVAssetResourceLoadingRequest *r in _requests){if(active.count>=8)break;AVAssetResourceLoadingDataRequest *d=r.dataRequest;
            [active addObject:@{@"offset":@(d.requestedOffset),@"current":@(d.currentOffset),@"length":@(d.requestedLength),@"to_end":@(d.requestsAllDataToEndOfResource)}];}
        self.diagnostics=@{@"engine_read_calls":@(_engineReads),@"shared_bytes_delivered":@(_sharedBytes),@"pump_count":@(_pumpCount),@"max_reads_per_pump":@(_maxReadsPerPump),@"max_read_bytes_per_pump":@(_maxReadBytesPerPump),@"started_requests":@(_startedRequests),@"cancelled_requests":@(_cancelledRequests),@"active_count":@(_requests.count),@"bytes_delivered":@(_bytesSent),@"active":active,@"events":[_trace copy]};
    }
}
- (void)removeRequest:(AVAssetResourceLoadingRequest *)request {
    [_requests removeObject:request];[_lastServed removeObjectForKey:request];
}
- (void)stop {
    if(self.stopped)return;self.stopped=YES;
    if(_timer){dispatch_source_cancel(_timer);_timer=nil;}
    [_asset.resourceLoader setDelegate:nil queue:_engine.workQueue];
    dispatch_async(_engine.workQueue,^{[self cancelRequests];});
}
- (void)cancelRequests {
    for (AVAssetResourceLoadingRequest *request in [_requests copy]) {
        [request finishLoadingWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
    }
    [_requests removeAllObjects];
    [_lastServed removeAllObjects];
}
- (void)dealloc {if(_timer)dispatch_source_cancel(_timer);}
@end
