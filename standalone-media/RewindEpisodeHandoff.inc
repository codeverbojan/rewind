// Retain this show's validated episode list for the player's lifetime. Prefer
// refreshed metadata if it remains cached; normal cache eviction must not erase
// the continuation action halfway through watching an episode.
- (void)configureEpisodeHandoff:(RewindPlayer *)player meta:(NSDictionary *)meta videoID:(NSString *)videoID {
    RewindStore *store=[RewindStore shared];NSString *profileID=[store.state[@"activeProfile"]copy],*showID=RWID(meta);
    NSDictionary *show=[store cachedShow:showID];
    if(!show&&[RWID(self.detail)isEqual:showID])show=self.detail;
    if([self.exerciseRequest[@"action"]isEqual:@"episode-handoff"]&&[showID isEqual:@"rw:handoff"])show=self.exerciseEpisodeShow;
    NSDictionary *next=[store playbackAfter:videoID show:show profileID:profileID];if(!next)return;
    NSString *expected=next[@"videoID"];
    player.nextEpisodeLabel=[NSString stringWithFormat:@"Next · S%02ld E%02ld",(long)[next[@"season"]integerValue],(long)[next[@"episode"]integerValue]];
    NSDictionary *(^resolve)(void)=^NSDictionary *{
        NSDictionary *current=[store cachedShow:showID]?:show;
        NSDictionary *result=[store playbackAfter:videoID show:current profileID:profileID];
        return [result[@"videoID"]isEqual:expected]?result:nil;
    };
    player.canPlayNextEpisode=^BOOL{return resolve()!=nil;};
    __weak RewindController *weak=self;
    player.onNextEpisode=^{
        RewindController *controller=weak;NSDictionary *target=resolve();
        if(!controller)return;
        if(!target){[controller syncDiscoveryActivity];[controller render];return;}
        controller.episodeHandoffPresentation=YES;
        [controller chooseSources:target[@"meta"] videoID:target[@"videoID"] restart:YES];
        controller.episodeHandoffPresentation=NO;
    };
}
