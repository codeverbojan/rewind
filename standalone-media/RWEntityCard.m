#import "RWEntityCard.h"
@implementation RWEntityCard {
    UIImageView *_image;UIView *_imageBase;UILabel *_initial,*_titleLabel,*_roleLabel,*_knownLabel;BOOL _requested;NSString *_profile,*_resolvedImageRole,*_photoURL,*_photoLookupError;BOOL _photoFileAvailable,_recoveryRequested;NSUInteger _photoGeneration;
}
- (instancetype)initWithMeta:(NSDictionary *)meta width:(CGFloat)width landscape:(BOOL)landscape {
    if((self=[super initWithFrame:CGRectMake(0,0,width,width+141)])){
        self.meta=meta;_profile=RWString(meta[@"profileID"]);self.accessibilityTraits=UIAccessibilityTraitButton;[self addTarget:self action:@selector(entityTapped) forControlEvents:UIControlEventTouchUpInside];
        BOOL studio=[meta[@"type"]isEqual:@"studio"],mood=[meta[@"type"]isEqual:@"mood"];UIView *base=RWPanel(CGRectMake(0,0,width,width));_imageBase=base;base.userInteractionEnabled=NO;base.clipsToBounds=YES;[self addSubview:base];
        NSString *name=RWString(meta[@"name"]);NSMutableString *initials=[NSMutableString new];for(NSString *part in [name componentsSeparatedByString:@" "])if(part.length){[initials appendString:[part substringWithRange:[part rangeOfComposedCharacterSequenceAtIndex:0]]];if(initials.length>=2)break;}
        _initial=RWLabel(initials.uppercaseString,38,UIFontWeightLight,RWColor(0x8997a9));_initial.textAlignment=NSTextAlignmentCenter;_initial.frame=base.bounds;[base addSubview:_initial];
        _image=[[UIImageView alloc]initWithFrame:studio?CGRectInset(base.bounds,18,18):base.bounds];_image.contentMode=studio?UIViewContentModeScaleAspectFit:UIViewContentModeScaleAspectFill;_image.clipsToBounds=YES;[base addSubview:_image];
        UILabel *title=RWLabel(name,17,UIFontWeightSemibold,RWColor(0xf5f2eb));_titleLabel=title;title.numberOfLines=2;title.frame=CGRectMake(0,width+11,width,43);[self addSubview:title];
        NSArray *roles=meta[@"roles"];NSString *role=mood?@"Mood":studio?(RWString(meta[@"kindLabel"]).length?meta[@"kindLabel"]:@"Company"):[roles containsObject:@"director"]?([roles containsObject:@"cast"]?@"Actor · Director":@"Director"):@"Actor";
        UILabel *subtitle=RWLabel(role,12,UIFontWeightMedium,RWColor(0xff997e));_roleLabel=subtitle;subtitle.frame=CGRectMake(0,width+57,width,18);[self addSubview:subtitle];
        NSMutableArray *credits=[NSMutableArray new];for(NSDictionary *m in meta[@"knownFor"]){if(credits.count==2)break;[credits addObject:RWString(m[@"name"])];}
        NSString *context=mood?RWString(meta[@"biography"]):(credits.count?[credits componentsJoinedByString:@" · "]:RWString(meta[@"biography"]));UILabel *known=RWLabel(context,12,UIFontWeightRegular,RWColor(0xa9b4c2));_knownLabel=known;known.numberOfLines=3;known.frame=CGRectMake(0,width+80,width,51);[self addSubview:known];self.accessibilityLabel=[NSString stringWithFormat:@"%@, %@, %@",name,role,context];
    }return self;
}
- (void)setCompact:(BOOL)compact {_compact=compact;[self setNeedsLayout];}
- (void)layoutSubviews {
    [super layoutSubviews];if(!self.compact)return;
    BOOL studio=[self.meta[@"type"]isEqual:@"studio"];CGFloat image=88,width=self.bounds.size.width-104;
    _imageBase.frame=CGRectMake(0,4,image,image);_imageBase.layer.cornerRadius=8;_initial.frame=_imageBase.bounds;_initial.font=[UIFont systemFontOfSize:24 weight:UIFontWeightLight];
    _image.frame=studio?CGRectInset(_imageBase.bounds,10,10):_imageBase.bounds;
    if(!studio&&_image.image.size.width>0)_image.frame=CGRectMake(0,0,image,MAX(image,image*_image.image.size.height/_image.image.size.width));
    _titleLabel.frame=CGRectMake(104,15,width,44);_titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _roleLabel.frame=CGRectMake(104,65,width,18);_knownLabel.hidden=YES;
}
- (NSDictionary *)diagnostics {return @{@"compact":@(self.compact),@"card_width":@(self.bounds.size.width),@"card_height":@(self.bounds.size.height),@"id":RWID(self.meta),@"name":RWString(self.meta[@"name"]),@"type":RWString(self.meta[@"type"]),@"profile":_profile?:@"",@"image_loaded":@(_image.image!=nil),@"image_recovery_requested":@(_recoveryRequested),@"photo_url_available":@(_photoURL.length>0),@"photo_file_available":@(_photoFileAvailable),@"lookup_error":_photoLookupError?:@"",@"image_role":_resolvedImageRole?:@"",@"roles":self.meta[@"roles"]?:@[],@"known_for":self.meta[@"knownFor"]?:@[],@"credit_count":self.meta[@"creditCount"]?:@0,@"score":self.meta[@"score"]?:@0,@"verified_entity":self.meta[@"verifiedEntity"]?:@NO};}
- (void)cancelArtwork {[[RewindStore shared]cancelArtwork:_image];_requested=NO;_recoveryRequested=NO;_photoGeneration++;}
- (void)entityTapped {if([_profile isEqual:[RewindStore shared].state[@"activeProfile"]]&&self.action)self.action(self.meta);}
- (void)loadArtworkIfVisible {
    if(_requested||!self.window)return;CGRect shown=[self convertRect:self.bounds toView:self.window];for(UIView *parent=self.superview;parent;parent=parent.superview)if(parent.clipsToBounds||parent==self.window)shown=CGRectIntersection(shown,[parent convertRect:parent.bounds toView:self.window]);if(CGRectIsEmpty(shown)||CGRectIsNull(shown))return;[self loadArtwork];
}
- (void)applyPhoto:(NSDictionary *)photo {
    NSString *url=RWString(photo[@"image"]);_photoURL=url;_photoFileAvailable=_photoFileAvailable||RWString(photo[@"imageFile"]).length>0;if(!_requested||!self.window||!url.length||![_profile isEqual:[RewindStore shared].state[@"activeProfile"]])return;
    if([self.meta[@"type"]isEqual:@"studio"]&&![photo[@"imageRole"]isEqual:@"logo"])return;
    __weak RWEntityCard *weak=self;NSUInteger generation=_photoGeneration;[[RewindStore shared]artwork:@[url] role:[self.meta[@"type"]isEqual:@"studio"]?@"logo":[self.meta[@"type"]isEqual:@"mood"]?@"backdrop":@"portrait" identity:RWID(self.meta) into:_image completion:^(BOOL success){RWEntityCard *card=weak;if(!card||generation!=card->_photoGeneration||!card->_requested||!card.window||![card->_profile isEqual:[RewindStore shared].state[@"activeProfile"]])return;if(!success){[card recoverPhoto:url];return;}if(success){card->_initial.hidden=YES;card->_resolvedImageRole=photo[@"imageRole"]?:([card.meta[@"type"]isEqual:@"studio"]?@"logo":@"portrait");if([card.meta[@"type"]isEqual:@"studio"])card->_imageBase.backgroundColor=RWLogoBackdrop(card->_image.image);else if([card.meta[@"type"]isEqual:@"person"]&&card->_image.image.size.width>0){CGFloat w=card->_imageBase.bounds.size.width;card->_image.frame=CGRectMake(0,0,w,MAX(w,w*card->_image.image.size.height/card->_image.image.size.width));}}}];
}
- (void)recoverPhoto:(NSString *)url {
    if(_recoveryRequested||[self.meta[@"type"]isEqual:@"mood"])return;_recoveryRequested=YES;NSUInteger generation=_photoGeneration;NSString *identifier=RWID(self.meta),*profile=_profile;__weak RWEntityCard *weak=self;
    [[RewindStore shared].discoveryMetadata entity:identifier role:self.meta[@"type"] failedImage:url done:^(NSDictionary *record,NSString *error){RWEntityCard *card=weak;if(!card||generation!=card->_photoGeneration||!card->_requested||!card.window||![profile isEqual:[RewindStore shared].state[@"activeProfile"]]||![identifier isEqual:RWID(card.meta)])return;card->_photoLookupError=[error copy];if([record[@"id"]isEqual:identifier]&&RWString(record[@"image"]).length&&![record[@"image"]isEqual:url])[card applyPhoto:record];}];
}
- (void)loadArtwork {
    if(_requested||![_profile isEqual:[RewindStore shared].state[@"activeProfile"]])return;_requested=YES;
    if([self.meta[@"type"]isEqual:@"mood"]){[self applyPhoto:self.meta];return;}
    [self applyPhoto:self.meta];if(RWString(self.meta[@"image"]).length)return;
    __weak RWEntityCard *weak=self;NSString *identifier=RWID(self.meta),*profile=_profile;NSUInteger generation=_photoGeneration;
    [[RewindStore shared].discoveryMetadata entity:identifier role:self.meta[@"type"] done:^(NSDictionary *record,NSString *error){RWEntityCard *card=weak;if(!card||generation!=card->_photoGeneration||!card->_requested||!card.window||![profile isEqual:[RewindStore shared].state[@"activeProfile"]]||![identifier isEqual:RWID(card.meta)])return;card->_photoLookupError=[error copy];if([record[@"id"]isEqual:identifier])[card applyPhoto:record];}];
}
@end
