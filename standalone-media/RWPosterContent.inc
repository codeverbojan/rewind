- (void)updateMeta:(NSDictionary *)meta {
    BOOL changedIdentity=![RWID(self.meta)isEqual:RWID(meta)];self.meta=meta;
    if(!_contentsBuilt){self.accessibilityLabel=RWString(meta[@"name"]);return;}
    NSArray *urls=[RWArtworkPolicy URLsForMeta:meta landscape:_landscape];
    if(changedIdentity||![_artURLs isEqual:urls]){[self cancelArtwork];_art.image=nil;_artComplete=NO;_placeholder.hidden=YES;_fallbackIcon.hidden=YES;_retryAfter=0;_artURLs=urls;}
    NSDictionary *text=[RWHomePresentation cardText:meta];self.accessibilityLabel=text[@"accessibility"];
    _placeholder.text=RWString(meta[@"name"]);_title.text=text[@"title"];_detail.text=text[@"secondary"];
    CGFloat width=self.bounds.size.width,height=_base.bounds.size.height;NSDictionary *record=meta[@"historyRecord"];
    if(record&&!_progressTrack){
        _resumeShade=[[UIView alloc]initWithFrame:_base.bounds];_resumeShade.backgroundColor=[UIColor colorWithWhite:0 alpha:.18];[_base addSubview:_resumeShade];
        _resumePlay=[[UIImageView alloc]initWithImage:RWIcon(@"play",26,UIColor.whiteColor)];_resumePlay.center=CGPointMake(width/2,height/2);[_base addSubview:_resumePlay];
        _progressTrack=[[UIView alloc]initWithFrame:CGRectMake(0,height-3,width,3)];_progressTrack.backgroundColor=RWColor(0x5a5c60);[_base addSubview:_progressTrack];
        _progress=[[UIView alloc]initWithFrame:CGRectZero];_progress.backgroundColor=RWColor(0xff6847);[_progressTrack addSubview:_progress];
    }
    _resumeShade.hidden=!record;_resumePlay.hidden=!record;_progressTrack.hidden=!record;
    double duration=[record[@"duration"]doubleValue],position=[record[@"position"]doubleValue];_progress.frame=CGRectMake(0,0,duration>0?width*MIN(1,MAX(0,position/duration)):0,3);
    if([text[@"rating"]length]&&!_rating){_rating=RWLabel(@"",10,UIFontWeightBold,RWColor(0xf3e6bb));_rating.backgroundColor=[RWColor(0x10151c)colorWithAlphaComponent:.9];_rating.textAlignment=NSTextAlignmentCenter;_rating.layer.cornerRadius=4;_rating.clipsToBounds=YES;_rating.frame=CGRectMake(8,8,66,25);[_base addSubview:_rating];}
    _rating.text=text[@"rating"];_rating.hidden=self.hidesArtworkBadges||![text[@"rating"]length];if(_rating)[_base bringSubviewToFront:_rating];
    if([text[@"kind"]length]&&!_kind){_kind=RWLabel(@"",11,UIFontWeightSemibold,RWColor(0xe3e8ee));_kind.backgroundColor=[RWColor(0x10151c)colorWithAlphaComponent:.9];_kind.textAlignment=NSTextAlignmentCenter;_kind.layer.cornerRadius=4;_kind.clipsToBounds=YES;_kind.frame=CGRectMake(width-63,8,55,25);[_base addSubview:_kind];}
    _kind.text=text[@"kind"];_kind.hidden=self.hidesArtworkBadges||![text[@"kind"]length];if(_kind)[_base bringSubviewToFront:_kind];
}
