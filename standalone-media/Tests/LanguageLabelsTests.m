#import "../RWLanguageLabels.h"
static int checks,failures;
#define C(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL%d %s\n",__LINE__,#__VA_ARGS__);}}while(0)
static NSDictionary *Read(NSString *p){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:p] options:0 error:nil];}
int main(int argc,char **argv){@autoreleasepool{
 if(argc!=3)return 2;NSDictionary *labels=Read(@(argv[1])),*raw=Read([@(argv[2])stringByAppendingPathComponent:@"labels-0.json"])[@"entities"];C(labels.count==47&&labels.count<=128);
 for(NSString *key in labels){C([raw[key][@"id"]isEqual:key]);C([raw[key][@"labels"][@"en"][@"value"]isEqual:labels[key]]);C([RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":key,@"name":@""}]},labels)isEqual:labels[key]]);}
 C([RWLanguageDisplay(@{@"primaryLanguage":@"fr"},labels)isEqual:@"French"]);
 C([RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":@"Q150",@"name":@"French (named evidence)"}]},labels)isEqual:@"French (named evidence)"]);
 C([RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":@"Q150"}]},labels)isEqual:@"French"]);
 C(!RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":@"Q999999999999"}]},labels).length);
 C(!RWLanguageDisplay(@{@"originalLanguages":NSNull.null},labels).length);
 C(!RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":@"Q150"}]},@{}).length);
 // Never replace an unknown first language with a different known second one.
 C(!RWLanguageDisplay(@{@"originalLanguages":@[@{@"id":@"Q999999999999"},@{@"id":@"Q150"}]},labels).length);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
