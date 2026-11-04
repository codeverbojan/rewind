@implementation RWKidsSurfaceRatings
- (BOOL)owned {return [RWDeviceExercise ownsKidsProfile:RewindStore.shared.profile build:self.build run:self.run];}
- (BOOL)busy {return self.original.busy;}
- (NSDictionary *)rating:(NSString *)identifier {NSDictionary *override=[self owned]?self.overrides[identifier]:nil;return override?:[self.original rating:identifier];}
- (NSDictionary *)snapshot {NSDictionary *original=[self.original snapshot];if(![self owned])return original;NSMutableDictionary *result=[original mutableCopy],*cache=[original[@"cache"]mutableCopy],*publishers=[original[@"publishers"]mutableCopy];[cache addEntriesFromDictionary:self.overrides];for(NSString *key in self.overrides)[publishers removeObjectForKey:key];result[@"cache"]=cache;result[@"publishers"]=publishers;return result;}
- (void)resolve:(NSArray *)items {[self.original resolve:items];}
@end
