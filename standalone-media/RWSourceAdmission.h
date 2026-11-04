#pragma once
#import <Foundation/Foundation.h>
#import "RWSourceIdentity.h"
#import "RWSourceHints.h"
#include <math.h>
// Retained source descriptions, not simultaneous network jobs. Keep a bounded
// backlog across provider updates instead of discarding everything after12.
static const NSUInteger RWSourceAdmissionLimit=64;
static const NSUInteger RWSourceOfferScanLimit=256;
static inline double RWAdmissionScore(NSDictionary *source){id value=source[@"score"];return [value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue])?[value doubleValue]:0;}
static inline void RWAdmitSources(NSMutableArray *queue,NSMutableSet *keys,NSUInteger started,id offered){
    if(![offered isKindOfClass:NSArray.class]||started>queue.count||queue.count>RWSourceAdmissionLimit)return;
    NSUInteger scanned=0;
    for(id raw in offered){if(scanned++>=RWSourceOfferScanLimit)break;if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *source=raw;
        NSString *hash=source[@"infoHash"],*url=source[@"url"];
        if(![hash isKindOfClass:NSString.class]||hash.length!=40||![url isKindOfClass:NSString.class]||![url hasPrefix:@"magnet:"])continue;
        NSString *key=RWSourceCandidateKey(source);
        if([keys containsObject:key]){for(NSUInteger i=0;i<queue.count;i++)if([RWSourceCandidateKey(queue[i])isEqual:key]){queue[i]=RWMergeSourceHints(queue[i],source);break;}continue;}
        if(queue.count==RWSourceAdmissionLimit){
            // Never evict or restart a started handle. A higher-ranked late
            // result can replace only the worst entry still waiting to start.
            NSUInteger worst=NSNotFound;for(NSUInteger i=started;i<queue.count;i++)if(worst==NSNotFound||RWAdmissionScore(queue[i])<=RWAdmissionScore(queue[worst]))worst=i;
            if(worst==NSNotFound||RWAdmissionScore(source)<=RWAdmissionScore(queue[worst]))continue;
            [keys removeObject:RWSourceCandidateKey(queue[worst])];[queue removeObjectAtIndex:worst];
        }
        [keys addObject:key];[queue addObject:source];
    }
    if(queue.count-started<2)return;
    NSRange waiting=NSMakeRange(started,queue.count-started);
    NSArray *sorted=[[queue subarrayWithRange:waiting]sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){double x=RWAdmissionScore(a),y=RWAdmissionScore(b);return x>y?NSOrderedAscending:x<y?NSOrderedDescending:NSOrderedSame;}];
    [queue replaceObjectsInRange:waiting withObjectsFromArray:sorted];
}
