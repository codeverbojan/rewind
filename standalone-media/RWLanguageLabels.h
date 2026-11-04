#import <Foundation/Foundation.h>
static inline NSString *RWLanguageDisplay(NSDictionary *record,NSDictionary *labels) {
    NSString *code=[record[@"primaryLanguage"]isKindOfClass:NSString.class]?record[@"primaryLanguage"]:@"";
    if(code.length){NSString *name=[[NSLocale localeWithLocaleIdentifier:@"en"]displayNameForKey:NSLocaleLanguageCode value:code];if(name.length)return name;}
    NSArray *languages=[record[@"originalLanguages"]isKindOfClass:NSArray.class]?record[@"originalLanguages"]:@[];
    NSDictionary *first=[languages.firstObject isKindOfClass:NSDictionary.class]?languages.firstObject:@{};
    NSString *name=[first[@"name"]isKindOfClass:NSString.class]?first[@"name"]:@"";if(name.length)return name;
    NSString *key=[first[@"id"]isKindOfClass:NSString.class]?first[@"id"]:@"";id fallback=labels[key];return [fallback isKindOfClass:NSString.class]?fallback:@"";
}
static inline NSDictionary *RWLanguageBundledLabels(void) {
    static NSDictionary *labels;static dispatch_once_t once;dispatch_once(&once,^{
        NSString *path=[NSBundle.mainBundle pathForResource:@"language-labels" ofType:@"json" inDirectory:@"Rewind"];
        NSData *data=path?[NSData dataWithContentsOfFile:path]:nil;id parsed=data.length&&data.length<=65536?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        labels=[parsed isKindOfClass:NSDictionary.class]&&[parsed count]<=128?parsed:@{};
    });return labels;
}
