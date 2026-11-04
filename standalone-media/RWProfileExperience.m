#import "RWProfileExperience.h"
#import "RWProfileMotionPlan.h"
#import <AVFoundation/AVFoundation.h>

unsigned RWProfileAvatarColor(NSString *identifier, NSDictionary *profiles) {
    NSArray *keys=[[profiles allKeys]sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){if([a isEqual:b])return NSOrderedSame;if([a isEqual:@"main"])return NSOrderedAscending;if([b isEqual:@"main"])return NSOrderedDescending;return [a compare:b];}];
    unsigned colors[]={0x456a9f,0x308577,0x9a5b72,0xa36c3e,0x6c5b9d,0x467d99};NSUInteger index=[keys indexOfObject:identifier];return colors[index==NSNotFound?0:index%6];
}
UIView *RWProfileAvatar(CGRect frame,unsigned color,BOOL kidsBadge) {
    CGFloat f=frame.size.width/136;UIView *avatar=[[UIView alloc]initWithFrame:frame];avatar.userInteractionEnabled=NO;avatar.backgroundColor=RWColor(color);avatar.layer.cornerRadius=12*f;avatar.clipsToBounds=YES;
    for(int eye=0;eye<2;eye++){UIView *dot=[[UIView alloc]initWithFrame:CGRectMake((37+eye*48)*f,44*f,13*f,16*f)];dot.tag=9201+eye;dot.backgroundColor=RWColor(0xf9f6ef);dot.layer.cornerRadius=6*f;[avatar addSubview:dot];}
    CAShapeLayer *smile=[CAShapeLayer layer];UIBezierPath *path=[UIBezierPath bezierPath];[path moveToPoint:CGPointMake(39*f,82*f)];[path addQuadCurveToPoint:CGPointMake(98*f,82*f) controlPoint:CGPointMake(68*f,111*f)];smile.path=path.CGPath;smile.strokeColor=RWColor(0xf9f6ef).CGColor;smile.fillColor=UIColor.clearColor.CGColor;smile.lineWidth=5*f;smile.lineCap=kCALineCapRound;[avatar.layer addSublayer:smile];
    if(kidsBadge){UILabel *badge=RWLabel(@"KIDS",10*f,UIFontWeightHeavy,RWColor(0x123d39));badge.backgroundColor=RWColor(0xc6edb6);badge.textAlignment=NSTextAlignmentCenter;badge.frame=CGRectMake(79*f,111*f,57*f,25*f);[avatar addSubview:badge];}
    return avatar;
}

@implementation RWProfileButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];self.alpha=1;
    BOOL reduced=!self.cinematic&&UIAccessibilityIsReduceMotionEnabled();
    [UIView animateWithDuration:reduced?0:.10 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{self.transform=highlighted&&!reduced?CGAffineTransformMakeScale(.965,.965):CGAffineTransformIdentity;} completion:nil];
}
@end

@interface RWProfileExperience () <AVAudioPlayerDelegate>
@property(nonatomic,weak) UIView *page,*brand,*heading,*footer,*presentedPage;
@property(nonatomic,copy) NSArray *cards;
@property(nonatomic,strong) UIView *outgoing;
@property(nonatomic,strong) UIView *transitionAvatar,*transitionName,*transitionBackdrop;
@property(nonatomic,strong) UIView *introMark,*introWordmark;
@property(nonatomic,strong) UIView *selectionEffects;
@property(nonatomic,copy) NSArray *backgroundRibbons;
@property(nonatomic,assign) double backgroundStarted;
@property(nonatomic,assign) CGFloat backgroundMinX,backgroundMaxX,backgroundMinY,backgroundMaxY,backgroundMinScale,backgroundMaxScale;
@property(nonatomic,assign) NSUInteger backgroundSamples;
@property(nonatomic,copy) NSString *selectionVariant,*selectionSoundName;
@property(nonatomic,assign) BOOL selectedKids;
@property(nonatomic,assign) NSUInteger introductions;
@property(nonatomic,strong) CADisplayLink *motionProbe;
@property(nonatomic,assign) double probeStarted;
@property(nonatomic,assign) NSUInteger probeSamples;
@property(nonatomic,assign) CGFloat minimumX,maximumX,minimumScale,maximumScale;
@property(nonatomic,weak) UIView *destinationView;
@property(nonatomic,assign) CGPoint centeredAvatar;
@property(nonatomic,assign) double selectionStarted,lastSelectionDuration;
@property(nonatomic,copy) NSString *selectionPhase;
@property(nonatomic,strong) AVAudioPlayer *entranceSound,*selectionSound;
@property(nonatomic,assign) BOOL entered,ownsAudio,lastReducedMotion,lastSoundAccepted;
@property(nonatomic,assign) NSUInteger entrances,selections,soundStarts;
@end
@implementation RWProfileExperience
- (instancetype)init {
    if((self=[super init])){
        _soundEnabled=YES;
        NSNotificationCenter *n=NSNotificationCenter.defaultCenter;
        [n addObserver:self selector:@selector(stop) name:UIApplicationWillResignActiveNotification object:nil];
        [n addObserver:self selector:@selector(stop) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        [n addObserver:self selector:@selector(stop) name:AVAudioSessionInterruptionNotification object:nil];
    }return self;
}
- (void)prepare:(UIView *)page brand:(UIView *)brand heading:(UIView *)heading cards:(NSArray *)cards footer:(UIView *)footer {
    [self cancelTransition];self.page=page;self.brand=brand;self.heading=heading;self.cards=cards;self.footer=footer;
    [self presentIfActive];
}
- (void)fade:(UIView *)view delay:(double)delay duration:(double)duration horizontal:(BOOL)horizontal {
    if(!view)return;
    CABasicAnimation *opacity=[CABasicAnimation animationWithKeyPath:@"opacity"];opacity.fromValue=@0;opacity.toValue=@1;
    NSMutableArray *animations=[NSMutableArray arrayWithObject:opacity];
    if(!self.lastReducedMotion){CABasicAnimation *move=[CABasicAnimation animationWithKeyPath:@"transform"];move.fromValue=[NSValue valueWithCATransform3D:horizontal?CATransform3DMakeScale(.94,1,1):CATransform3DMakeTranslation(0,8,0)];move.toValue=[NSValue valueWithCATransform3D:CATransform3DIdentity];[animations addObject:move];}
    CAAnimationGroup *group=[CAAnimationGroup animation];group.animations=animations;group.duration=duration;group.beginTime=CACurrentMediaTime()+delay;group.fillMode=kCAFillModeBackwards;group.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    // Model opacity stays one: the controls remain tappable during the reveal.
    [view.layer addAnimation:group forKey:@"rewind.profile.entrance"];
}
- (void)presentIfActive {
    if(!self.page.window||self.presentedPage==self.page||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.presentedPage=self.page;BOOL first=!self.entered;self.entered=YES;self.entrances++;self.lastReducedMotion=!self.cinematic&&UIAccessibilityIsReduceMotionEnabled();
    double duration=self.lastReducedMotion?.16:first?.36:.18;
    [self fade:self.brand delay:0 duration:duration horizontal:YES];[self fade:self.heading delay:first?.06:0 duration:duration horizontal:NO];
    NSUInteger index=0;for(UIView *card in self.cards)[self fade:card delay:first&&!self.lastReducedMotion?.09+.035*index++:0 duration:duration horizontal:NO];
    [self fade:self.footer delay:first&&!self.lastReducedMotion?.18:0 duration:duration horizontal:NO];
    if(first){if(self.cinematic)[self replayIntroduction];else[self playSound:YES];}
}
- (void)replayIntroduction {
    if(!self.page.window||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    [self stop];self.lastReducedMotion=!self.cinematic&&UIAccessibilityIsReduceMotionEnabled();self.introductions++;
    UIView *host=self.page.superview;UIControl *stage=[[UIControl alloc]initWithFrame:host.bounds];stage.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;stage.backgroundColor=RWColor(0x0e1116);stage.isAccessibilityElement=YES;stage.accessibilityLabel=@"Rewind";stage.accessibilityHint=@"Tap to skip introduction";stage.accessibilityTraits=UIAccessibilityTraitButton;stage.accessibilityViewIsModal=YES;[stage addTarget:self action:@selector(cancelTransition) forControlEvents:UIControlEventTouchUpInside];self.outgoing=stage;[host addSubview:stage];
    self.selectionStarted=NSProcessInfo.processInfo.systemUptime;self.selectionPhase=@"brand";
    CGPoint center=CGPointMake(CGRectGetMidX(stage.bounds),CGRectGetMidY(stage.bounds)-28);
    // Six simple light bars and a vector mark. No video decoder, particles,
    // realtime blur, network dependency or full-screen bitmap capture.
    if(!self.lastReducedMotion)for(NSUInteger i=0;i<6;i++){
        CALayer *light=[CALayer layer];light.backgroundColor=RWColor(i%2?0xff9d76:0xff6847).CGColor;light.bounds=CGRectMake(0,0,i%2?2:5,stage.bounds.size.height);light.position=CGPointMake(center.x-96+i*38,center.y);light.opacity=0;[stage.layer addSublayer:light];
        CAKeyframeAnimation *brightness=[CAKeyframeAnimation animationWithKeyPath:@"opacity"];brightness.values=@[@0,@0.22,@0.10,@0];brightness.keyTimes=@[@0,@.28,@.55,@1];brightness.duration=.85;brightness.beginTime=CACurrentMediaTime()+.12+i*.025;
        CABasicAnimation *stretch=[CABasicAnimation animationWithKeyPath:@"transform.scale.y"];stretch.fromValue=@.02;stretch.toValue=@1;stretch.duration=.62;stretch.beginTime=brightness.beginTime;stretch.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [light addAnimation:brightness forKey:@"glow"];[light addAnimation:stretch forKey:@"reach"];
    }
    UIView *mark=[[UIView alloc]initWithFrame:CGRectMake(0,0,168,104)];mark.center=center;mark.userInteractionEnabled=NO;self.introMark=mark;
    for(NSUInteger i=0;i<2;i++){CAShapeLayer *chevron=[CAShapeLayer layer];UIBezierPath *shape=[UIBezierPath bezierPath];CGFloat x=i*78;[shape moveToPoint:CGPointMake(x+72,5)];[shape addLineToPoint:CGPointMake(x+4,52)];[shape addLineToPoint:CGPointMake(x+72,99)];[shape closePath];chevron.path=shape.CGPath;chevron.fillColor=RWColor(i?0xff6847:0xff9a76).CGColor;[mark.layer addSublayer:chevron];}
    [stage addSubview:mark];mark.alpha=0;
    UILabel *word=RWLabel(@"REWIND",36,UIFontWeightHeavy,RWColor(0xf5f2eb));RWTracking(word,5);word.textAlignment=NSTextAlignmentCenter;word.frame=CGRectMake(24,center.y+86,stage.bounds.size.width-48,55);word.alpha=0;word.userInteractionEnabled=NO;[stage addSubview:word];self.introWordmark=word;
    if(!self.lastReducedMotion)mark.transform=CGAffineTransformMakeScale(.78,.78);
    [self playSound:YES];
    [self beginMotionProbe];
    [UIView animateWithDuration:.28 delay:0 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction animations:^{mark.alpha=1;mark.transform=CGAffineTransformIdentity;} completion:nil];
    [UIView animateWithDuration:.24 delay:.19 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction animations:^{word.alpha=1;} completion:nil];
    [self performSelector:@selector(finishIntroduction) withObject:nil afterDelay:.82];
}
- (void)finishIntroduction {
    UIView *stage=self.outgoing;if(!stage||![self.selectionPhase isEqual:@"brand"])return;self.selectionPhase=@"brand-reveal";
    [UIView animateWithDuration:.34 delay:0 options:UIViewAnimationOptionCurveEaseIn|UIViewAnimationOptionAllowUserInteraction animations:^{
        self.introWordmark.alpha=0;self.introMark.alpha=0;if(!self.lastReducedMotion)self.introMark.transform=CGAffineTransformMakeScale(8,8);stage.alpha=0;
    } completion:^(BOOL finished){if(self.outgoing==stage)[self cancelTransition];}];
}
- (AVAudioPlayer *)loadSound:(NSString *)name {
    NSURL *url=[NSBundle.mainBundle URLForResource:name withExtension:@"wav" subdirectory:@"Rewind/Sounds"];
    if(!url)return nil;AVAudioPlayer *p=[[AVAudioPlayer alloc]initWithContentsOfURL:url error:nil];p.delegate=self;p.volume=.65;[p prepareToPlay];return p;
}
- (void)playSound:(BOOL)entrance {
    self.lastSoundAccepted=NO;if(!self.soundEnabled||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    AVAudioSession *session=AVAudioSession.sharedInstance;
    // Do not compete with music playing in another app.
    if(session.otherAudioPlaying)return;
    if(![session setCategory:AVAudioSessionCategoryAmbient error:nil]||![session setActive:YES error:nil])return;self.ownsAudio=YES;
    [self.entranceSound stop];[self.selectionSound stop];
    if(entrance&&!self.entranceSound)self.entranceSound=[self loadSound:@"rewind-arrival"];
    if(!entrance){NSString *name=self.selectedKids?@"rewind-select-kids":@"rewind-select-regular";if(![self.selectionSoundName isEqual:name]){self.selectionSoundName=name;self.selectionSound=[self loadSound:name];}}
    AVAudioPlayer *sound=entrance?self.entranceSound:self.selectionSound;sound.currentTime=0;
    self.lastSoundAccepted=[sound play];if(self.lastSoundAccepted)self.soundStarts++;else[self releaseAudio];
}
- (void)releaseAudio {
    if(self.ownsAudio&&[AVAudioSession.sharedInstance.category isEqual:AVAudioSessionCategoryAmbient])[AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];self.ownsAudio=NO;
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if(!self.entranceSound.playing&&!self.selectionSound.playing)[self releaseAudio];
}
- (void)selectCard:(UIView *)card page:(UIView *)page host:(UIView *)host change:(void(^)(void))change destination:(UIView *(^)(void))destination {
    if(self.outgoing||!page.window||!card||!change)return;
    if(![card isKindOfClass:RWProfileButton.class])return;
    RWProfileButton *button=(RWProfileButton *)card;UIView *avatar=button.profileAvatar;NSString *name=button.profileName;
    if(!avatar||avatar.superview!=card||!name.length)return;
    [self stop];self.selections++;self.selectedKids=button.kids;self.selectionVariant=button.kids?@"kids":@"regular";self.lastReducedMotion=!self.cinematic&&UIAccessibilityIsReduceMotionEnabled();
    CGRect origin=[avatar convertRect:avatar.bounds toView:host];
    // The real profile switch and age filtering start immediately. The selected
    // identity remains on an opaque native stage while that Home is constructed.
    change();
    if(!host.window)return;
    UIControl *stage=[[UIControl alloc]initWithFrame:host.bounds];stage.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;stage.accessibilityLabel=[@"Entering profile, " stringByAppendingString:name];stage.accessibilityHint=@"Tap to finish the transition";stage.isAccessibilityElement=YES;stage.accessibilityTraits=UIAccessibilityTraitButton;stage.accessibilityViewIsModal=YES;[stage addTarget:self action:@selector(cancelTransition) forControlEvents:UIControlEventTouchUpInside];self.outgoing=stage;
    UIView *backdrop=[[UIView alloc]initWithFrame:stage.bounds];backdrop.backgroundColor=RWColor(0x0e1116);backdrop.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;backdrop.userInteractionEnabled=NO;[stage addSubview:backdrop];self.transitionBackdrop=backdrop;
    page.userInteractionEnabled=NO;[stage addSubview:page];
    [avatar removeFromSuperview];avatar.frame=origin;[stage addSubview:avatar];self.transitionAvatar=avatar;
    self.centeredAvatar=CGPointMake(CGRectGetMidX(stage.bounds),CGRectGetMidY(stage.bounds)-30);
    UILabel *label=RWLabel(name,24,UIFontWeightMedium,RWColor(0xf5f2eb));label.textAlignment=NSTextAlignmentCenter;label.frame=CGRectMake(32,self.centeredAvatar.y+(self.selectedKids?246:180),stage.bounds.size.width-64,36);label.alpha=0;label.userInteractionEnabled=NO;[stage addSubview:label];self.transitionName=label;
    self.destinationView=destination?destination():nil;[host addSubview:stage];
    self.selectionStarted=NSProcessInfo.processInfo.systemUptime;self.selectionPhase=@"centering";
    [self playSound:NO];
    [self prepareSelectionBackground];
    [self prepareSelectionEffects];
    [self beginMotionProbe];
    BOOL reduced=self.lastReducedMotion;
    if(reduced){avatar.center=self.centeredAvatar;avatar.alpha=0;}
    [UIView animateWithDuration:.18 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{page.alpha=0;} completion:nil];
    [UIView animateWithDuration:reduced?.24:.44 delay:0 usingSpringWithDamping:.84 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{avatar.center=self.centeredAvatar;avatar.alpha=1;if(!reduced)avatar.transform=CGAffineTransformMakeScale(1.35,1.35);label.alpha=1;} completion:^(BOOL finished){if(self.outgoing==stage)self.selectionPhase=@"identity";}];
    // This is a bounded identity transition, never a fake loading spinner or a
    // network gate. Tap skips it; navigation/background cancels all owned work.
    if(!reduced)[self performSelector:@selector(zoomSelectionIdentity) withObject:nil afterDelay:self.selectedKids?1.08:.48];
    [self performSelector:@selector(revealHome) withObject:nil afterDelay:reduced?.62:self.selectedKids?1.82:1.72];
}
- (void)zoomSelectionIdentity {
    if(!self.outgoing||self.introMark||self.lastReducedMotion)return;
    [UIView animateWithDuration:self.selectedKids?.32:.22 delay:0 options:UIViewAnimationOptionCurveEaseIn|UIViewAnimationOptionAllowUserInteraction animations:^{self.transitionAvatar.transform=CGAffineTransformMakeScale(self.selectedKids?2.1:1.5,self.selectedKids?2.1:1.5);self.transitionAvatar.alpha=0;self.transitionName.alpha=0;} completion:nil];
}
- (void)prepareSelectionEffects {
    // Stars and a wink complement the full-screen Kids colour curtains.
    // Effects belong to this one transition; no timers, images or emitters.
    if(self.lastReducedMotion||!self.selectedKids)return;
    UIView *effects=[[UIView alloc]initWithFrame:self.outgoing.bounds];effects.userInteractionEnabled=NO;
    [self.outgoing insertSubview:effects belowSubview:self.transitionAvatar];self.selectionEffects=effects;
    double begin=CACurrentMediaTime()+.45;
    if(self.selectedKids){
        unsigned colors[]={0xffda87,0xa9e4cf,0xf7acbb,0xc5bcff,0xffda87,0xa9e4cf};
        CGFloat angles[]={-155,-95,-35,20,160,215};
        for(NSUInteger i=0;i<6;i++){
            CGFloat angle=angles[i]*M_PI/180,radius=i%2?150:165,size=i%2?12:16;
            CAShapeLayer *star=[CAShapeLayer layer];star.bounds=CGRectMake(-size,-size,size*2,size*2);
            star.position=CGPointMake(self.centeredAvatar.x+cos(angle)*radius,self.centeredAvatar.y+sin(angle)*radius);star.opacity=0;
            UIBezierPath *shape=[UIBezierPath bezierPath];for(NSUInteger n=0;n<8;n++){CGFloat a=n*M_PI/4-M_PI/2,r=n%2?size*.30:size;CGPoint p=CGPointMake(cos(a)*r,sin(a)*r);if(n)[shape addLineToPoint:p];else[shape moveToPoint:p];}[shape closePath];star.path=shape.CGPath;star.fillColor=RWColor(colors[i]).CGColor;[effects.layer addSublayer:star];
            CAKeyframeAnimation *spark=[CAKeyframeAnimation animationWithKeyPath:@"opacity"];spark.values=@[@0,@1,@1,@0];spark.keyTimes=@[@0,@.18,@.64,@1];spark.duration=.67;spark.beginTime=begin+i*.018;
            CAKeyframeAnimation *pop=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];pop.values=@[@.2,@1.15,@.85,@.5];pop.keyTimes=@[@0,@.28,@.65,@1];pop.duration=spark.duration;pop.beginTime=spark.beginTime;
            CABasicAnimation *drift=[CABasicAnimation animationWithKeyPath:@"position"];drift.fromValue=[NSValue valueWithCGPoint:CGPointMake(self.centeredAvatar.x+cos(angle)*(radius-16),self.centeredAvatar.y+sin(angle)*(radius-16))];drift.toValue=[NSValue valueWithCGPoint:CGPointMake(star.position.x+cos(angle)*12,star.position.y+sin(angle)*12)];drift.duration=spark.duration;drift.beginTime=spark.beginTime;
            [star addAnimation:spark forKey:@"spark"];[star addAnimation:pop forKey:@"pop"];[star addAnimation:drift forKey:@"drift"];
        }
        CAKeyframeAnimation *wiggle=[CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];wiggle.values=@[@0,@(-.13),@.12,@(-.05),@0];wiggle.keyTimes=@[@0,@.22,@.52,@.76,@1];wiggle.duration=.62;wiggle.beginTime=begin;
        [self.transitionAvatar.layer addAnimation:wiggle forKey:@"rewind.kids.wiggle"];
        CAKeyframeAnimation *bounce=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];bounce.values=@[@1.35,@1.23,@1.48,@1.30,@1.35];bounce.keyTimes=wiggle.keyTimes;bounce.duration=wiggle.duration;bounce.beginTime=begin;[self.transitionAvatar.layer addAnimation:bounce forKey:@"rewind.kids.bounce"];
        CAKeyframeAnimation *wink=[CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];wink.values=@[@1,@.12,@.12,@1];wink.keyTimes=@[@0,@.3,@.65,@1];wink.beginTime=begin+.11;wink.duration=.30;
        [[self.transitionAvatar viewWithTag:9202].layer addAnimation:wink forKey:@"rewind.kids.wink"];
    }
}
#include "RewindProfileBackground.inc"

- (void)revealHome {
    UIView *stage=self.outgoing;if(!stage)return;self.selectionPhase=@"handoff";
    UIView *avatar=self.transitionAvatar,*target=self.destinationView;
    CGRect end=target.window?[target convertRect:target.bounds toView:stage]:CGRectZero;
    BOOL travel=!self.lastReducedMotion&&!CGRectIsEmpty(end);
    if(travel)[self openSelectionBackground:.55];
    [UIView animateWithDuration:travel?.55:.24 delay:0 options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
        if(!travel)self.transitionBackdrop.alpha=0;self.transitionName.alpha=0;self.selectionEffects.alpha=0;
        if(travel){avatar.transform=CGAffineTransformMakeScale(end.size.width/avatar.bounds.size.width,end.size.height/avatar.bounds.size.height);avatar.center=CGPointMake(CGRectGetMidX(end),CGRectGetMidY(end));}else avatar.alpha=0;
    } completion:^(BOOL finished){if(self.outgoing==stage)[self cancelTransition];}];
}
- (void)keepVisible {[self.outgoing.superview bringSubviewToFront:self.outgoing];}
- (void)beginMotionProbe {
    [self.motionProbe invalidate];self.motionProbe=nil;self.probeSamples=0;self.backgroundSamples=0;
    if(!self.diagnosticSampling)return;self.probeStarted=NSProcessInfo.processInfo.systemUptime;
    self.motionProbe=[CADisplayLink displayLinkWithTarget:self selector:@selector(sampleMotion)];self.motionProbe.frameInterval=2;[self.motionProbe addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)sampleMotion {
    if(!self.motionProbe)return;
    if(!self.outgoing||NSProcessInfo.processInfo.systemUptime-self.probeStarted>3||self.probeSamples>=90){[self.motionProbe invalidate];self.motionProbe=nil;return;}
    CALayer *piece=(CALayer *)((CALayer *)self.backgroundRibbons.firstObject).presentationLayer;
    if(piece&&piece.opacity>.1){CGFloat x=piece.position.x,y=piece.position.y,scale=fabs(piece.transform.m22);if(!self.backgroundSamples){self.backgroundMinX=self.backgroundMaxX=x;self.backgroundMinY=self.backgroundMaxY=y;self.backgroundMinScale=self.backgroundMaxScale=scale;}else{self.backgroundMinX=MIN(self.backgroundMinX,x);self.backgroundMaxX=MAX(self.backgroundMaxX,x);self.backgroundMinY=MIN(self.backgroundMinY,y);self.backgroundMaxY=MAX(self.backgroundMaxY,y);self.backgroundMinScale=MIN(self.backgroundMinScale,scale);self.backgroundMaxScale=MAX(self.backgroundMaxScale,scale);}self.backgroundSamples++;}
    UIView *view=self.introMark?:self.transitionAvatar;CALayer *layer=(CALayer *)view.layer.presentationLayer;if(!layer||layer.opacity<.12||!view.window)return;
    CGFloat x=layer.position.x,scale=layer.transform.m11;
    if(!self.probeSamples){self.minimumX=self.maximumX=x;self.minimumScale=self.maximumScale=scale;}
    else{self.minimumX=MIN(self.minimumX,x);self.maximumX=MAX(self.maximumX,x);self.minimumScale=MIN(self.minimumScale,scale);self.maximumScale=MAX(self.maximumScale,scale);}self.probeSamples++;
}
- (void)cancelTransition {
    [self sampleMotion];[self.motionProbe invalidate];self.motionProbe=nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revealHome) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(zoomSelectionIdentity) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(finishIntroduction) object:nil];
    if(self.outgoing)self.lastSelectionDuration=NSProcessInfo.processInfo.systemUptime-self.selectionStarted;
    [self.transitionAvatar.layer removeAllAnimations];[self.transitionName.layer removeAllAnimations];[self.transitionBackdrop.layer removeAllAnimations];
    [[self.transitionAvatar viewWithTag:9202].layer removeAnimationForKey:@"rewind.kids.wink"];
    [self.selectionEffects removeFromSuperview];self.selectionEffects=nil;self.backgroundRibbons=nil;
    if(self.transitionAvatar){[self.selectionSound stop];[self releaseAudio];}
    [self.outgoing.layer removeAllAnimations];[self.outgoing removeFromSuperview];self.outgoing=nil;self.transitionAvatar=nil;self.transitionName=nil;self.transitionBackdrop=nil;self.destinationView=nil;self.selectionPhase=@"idle";
    if(self.introMark){[self.entranceSound stop];[self releaseAudio];}self.introMark=nil;self.introWordmark=nil;
}
- (void)stop {
    [self cancelTransition];for(UIView *view in self.cards)[view.layer removeAnimationForKey:@"rewind.profile.entrance"];
    [self.brand.layer removeAnimationForKey:@"rewind.profile.entrance"];[self.heading.layer removeAnimationForKey:@"rewind.profile.entrance"];[self.footer.layer removeAnimationForKey:@"rewind.profile.entrance"];
    [self.entranceSound stop];[self.selectionSound stop];[self releaseAudio];
}
- (NSDictionary *)diagnostics {
    CALayer *visible=(CALayer *)self.transitionAvatar.layer.presentationLayer;CGPoint center=visible?visible.position:self.transitionAvatar.center;
    BOOL centered=self.outgoing&&fabs(center.x-self.centeredAvatar.x)<2&&fabs(center.y-self.centeredAvatar.y)<2;
    NSUInteger visibleEffects=0;for(CALayer *effect in self.selectionEffects.layer.sublayers){CALayer *shown=(CALayer *)effect.presentationLayer;if(shown.opacity>.1)visibleEffects++;}
    return @{@"background_samples":@(self.backgroundSamples),@"background_min_x":@(self.backgroundMinX),@"background_max_x":@(self.backgroundMaxX),@"background_min_y":@(self.backgroundMinY),@"background_max_y":@(self.backgroundMaxY),@"background_min_scale":@(self.backgroundMinScale),@"background_max_scale":@(self.backgroundMaxScale),@"background_elapsed":@(self.backgroundRibbons.count?NSProcessInfo.processInfo.systemUptime-self.backgroundStarted:0),@"background_ribbons":@(self.backgroundRibbons.count),@"background_style":self.selectedKids?@"petals-assemble-burst":@"chevrons-assemble-flythrough",@"selection_variant":self.selectionVariant?:@"",@"selection_sound":self.selectionSoundName?:@"",@"visible_effects":@(visibleEffects),@"entrances":@(self.entrances),@"selections":@(self.selections),@"introductions":@(self.introductions),@"cinematic":@(self.cinematic),@"system_reduce_motion":@(UIAccessibilityIsReduceMotionEnabled()),@"brand_visible":@(self.introMark.window!=nil&&self.introMark.alpha>.95),@"motion_samples":@(self.probeSamples),@"motion_min_x":@(self.minimumX),@"motion_max_x":@(self.maximumX),@"motion_min_scale":@(self.minimumScale),@"motion_max_scale":@(self.maximumScale),@"sound_starts":@(self.soundStarts),@"sound_accepted":@(self.lastSoundAccepted),@"sound_enabled":@(self.soundEnabled),@"reduce_motion":@(self.lastReducedMotion),@"transition_active":@(self.outgoing!=nil),@"audio_active":@(self.ownsAudio),@"entrance_duration":@(self.entranceSound.duration),@"selection_duration":@(self.selectionSound.duration),@"phase":self.selectionPhase?:@"idle",@"identity_centered":@(centered),@"selection_elapsed":@(self.outgoing?NSProcessInfo.processInfo.systemUptime-self.selectionStarted:self.lastSelectionDuration),@"avatar_visible":@(self.transitionAvatar.window!=nil&&(visible?visible.opacity:self.transitionAvatar.alpha)>.95)};
}
- (void)dealloc {[[NSNotificationCenter defaultCenter]removeObserver:self];}
@end
