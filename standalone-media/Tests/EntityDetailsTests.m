#import "../RWEntityDetailsPolicy.h"
static NSDictionary *Claim(id value){return @{@"mainsnak":@{@"datavalue":@{@"value":value}}};}
static NSDictionary *Date(NSString *date,NSInteger precision){return @{@"time":date,@"precision":@(precision),@"calendarmodel":@"http://www.wikidata.org/entity/Q1985727"};}
static NSDictionary *Entity(NSDictionary *claims){return @{@"id":@"Q20",@"labels":@{@"mul":@{@"value":@"A real name"}},@"claims":claims,@"sitelinks":@{@"enwiki":@{@"title":@"An exact article"}}};}
static NSArray *Facts(NSDictionary *claims){return [RWEntityDetailsPolicy details:Entity(claims) role:@"person" labels:@{}][@"facts"];}
static NSDictionary *Page(NSDictionary *page){return @{@"query":@{@"pages":@{@"1":page}}};}
static NSDictionary *Title(NSString *identifier,NSString *year,id rating,NSUInteger votes,NSString *role){return @{@"id":identifier,@"type":@"movie",@"name":identifier,@"releaseInfo":year,@"imdbRating":rating,@"imdbVotes":@(votes),@"creditEntityID":@"Q20",@"creditRole":role,@"videos":@[@{@"id":@"big unwanted episode object"}]};}
int main(int argc,const char **argv){@autoreleasepool{int checks=0,failures=0;
#define CHECK(...) do{checks++;if(!(__VA_ARGS__)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *claims=@{@"P569":@[Claim(Date(@"+1982-11-12T00:00:00Z",11))],@"P19":@[Claim(@{@"id":@"Q100"})],@"P106":@[Claim(@{@"id":@"Q101"})],@"P18":@[Claim(@"Portrait.jpg")]};
    NSDictionary *labels=@{@"Q100":@{@"labels":@{@"en":@{@"value":@"New York City"}}},@"Q101":@{@"labels":@{@"mul":@{@"value":@"actor"}}}};
    NSDictionary *person=[RWEntityDetailsPolicy details:Entity(claims) role:@"cast" labels:labels];
    CHECK([person[@"name"]isEqual:@"A real name"]);CHECK([person[@"kindLabel"]isEqual:@"actor"]);CHECK([person[@"facts"]count]==2);CHECK([person[@"facts"][0][@"value"]isEqual:@"12 Nov 1982"]);CHECK([person[@"facts"][1][@"value"]isEqual:@"New York City"]);CHECK([person[@"entitySourceURL"]hasSuffix:@"Q20"]);CHECK([person[@"wikipediaTitle"]isEqual:@"An exact article"]);CHECK([person[@"imageRole"]isEqual:@"portrait"]);
    CHECK([[RWEntityDetailsPolicy labelIDs:Entity(claims) studio:NO]isEqual:@[@"Q101",@"Q100"]]);
    CHECK([Facts(@{@"P569":@[Claim(Date(@"+1982-11-12T00:00:00Z",9))]})[0][@"value"]isEqual:@"1982"]);
    CHECK([Facts(@{@"P569":@[Claim(Date(@"+1982-11-12T00:00:00Z",10))]})[0][@"value"]isEqual:@"Nov 1982"]);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"+1982-11-12T00:00:00Z",8))]}).count);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"+1982-02-31T00:00:00Z",11))]}).count);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"+1900-02-29T00:00:00Z",11))]}).count);
    CHECK([Facts(@{@"P569":@[Claim(Date(@"+2000-02-29T00:00:00Z",11))]})[0][@"value"]isEqual:@"29 Feb 2000"]);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"+1982-13-01T00:00:00Z",10))]}).count);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"-1982-11-12T00:00:00Z",11))]}).count);
    CHECK(!Facts(@{@"P569":@[Claim(Date(@"+19822-11-12T00:00:00Z",11))]}).count);
    NSMutableDictionary *uncertain=[Date(@"+1982-11-12T00:00:00Z",11)mutableCopy];uncertain[@"before"]=@1;CHECK(!Facts(@{@"P569":@[Claim(uncertain)]}).count);
    uncertain[@"before"]=@0;uncertain[@"calendarmodel"]=@"different calendar";CHECK([Facts(@{@"P569":@[Claim(uncertain)]})[0][@"value"]isEqual:@"1982"]);
    NSDictionary *normal=Claim(Date(@"+1982-11-12T00:00:00Z",9));NSMutableDictionary *preferred=[Claim(Date(@"+1983-01-01T00:00:00Z",9))mutableCopy];
    CHECK(!Facts(@{@"P569":@[normal,preferred]}).count);preferred[@"rank"]=@"preferred";CHECK([Facts(@{@"P569":@[normal,preferred]})[0][@"value"]isEqual:@"1983"]);preferred[@"rank"]=@"deprecated";CHECK([Facts(@{@"P569":@[normal,preferred]})[0][@"value"]isEqual:@"1982"]);
    NSDictionary *studio=[RWEntityDetailsPolicy details:Entity(@{@"P571":@[Claim(Date(@"+1998-01-01T00:00:00Z",9))],@"P31":@[Claim(@{@"id":@"Q101"})],@"P154":@[Claim(@"Logo.svg")],@"P18":@[Claim(@"Office.jpg")]}) role:@"studio" labels:@{@"Q101":@{@"labels":@{@"en":@{@"value":@"television network"}}}}];
    CHECK([studio[@"imageFile"]isEqual:@"Logo.svg"]);CHECK([studio[@"imageRole"]isEqual:@"logo"]);CHECK([studio[@"kindLabel"]isEqual:@"television network"]);CHECK([studio[@"facts"][0][@"value"]isEqual:@"1998"]);CHECK([studio[@"facts"][0][@"label"]isEqual:@"Founded"]);
    CHECK(![RWEntityDetailsPolicy details:@{@"id":@"Qwrong"} role:@"person" labels:@{}].count);
    NSMutableArray *manyRefs=[NSMutableArray new];for(int i=1;i<20;i++)[manyRefs addObject:Claim(@{@"id":[NSString stringWithFormat:@"Q%d",i]})];CHECK([RWEntityDetailsPolicy labelIDs:Entity(@{@"P106":manyRefs}) studio:NO].count==12);
    NSMutableDictionary *page=[@{@"ns":@0,@"title":@"Name ? # / identity",@"extract":@"  A biography.[1] Exact identity.  ",@"pageprops":@{@"wikibase_item":@"Q20"}}mutableCopy];
    NSDictionary *bio=[RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"];CHECK([bio[@"biography"]isEqual:@"A biography. Exact identity."]);CHECK([bio[@"biographyCredit"]containsString:@"CC BY-SA"]);NSURL *url=[NSURL URLWithString:bio[@"biographySourceURL"]];CHECK(!url.query&&!url.fragment&&[url.host isEqual:@"en.wikipedia.org"]);CHECK([url.absoluteString containsString:@"%23"]);
    CHECK(![RWEntityDetailsPolicy biography:Page(page) entityID:@"Q21"].count);page[@"ns"]=@1;CHECK(![RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"].count);[page removeObjectForKey:@"ns"];CHECK(![RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"].count);page[@"ns"]=@0;page[@"missing"]=@"";CHECK(![RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"].count);[page removeObjectForKey:@"missing"];page[@"pageprops"]=@{@"wikibase_item":@"Q20",@"disambiguation":@""};CHECK(![RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"].count);page[@"pageprops"]=@{@"wikibase_item":@"Q20"};
    page[@"extract"]=[@"é🙂 "stringByPaddingToLength:2500 withString:@"é🙂 " startingAtIndex:0];CHECK([[RWEntityDetailsPolicy biography:Page(page) entityID:@"Q20"][@"biography"]length]<=1400);
    NSDictionary *identity=@{@"id":@"Q20",@"creditRole":@"cast"};double now=1792454400;
    NSMutableArray *titles=[@[Title(@"tt1",@"2000",@8.1,50000,@"cast"),Title(@"tt2",@"2026",@10,1,@"cast"),Title(@"tt3",@"2024",@7.9,30000,@"cast"),Title(@"tt4",@"2028",@9,100000,@"cast"),Title(@"tt5",@"2000",@10,1000000,@"director"),Title(@"tt6",@"2022",@"10bad",1000000,@"cast")]mutableCopy];
    NSDictionary *result=[RWEntityDetailsPolicy highlights:titles entity:identity now:now];CHECK([result[@"knownFor"][0][@"id"]isEqual:@"tt1"]);CHECK([result[@"recent"][0][@"id"]isEqual:@"tt2"]);CHECK([result[@"rated"]count]==2);CHECK([result[@"pool"]count]==5);CHECK([result[@"knownFor"]count]==4);for(NSDictionary *m in result[@"pool"])CHECK(!m[@"videos"]);
    NSMutableDictionary *duplicate=[titles[0]mutableCopy];duplicate[@"name"]=@"New title";[titles addObject:duplicate];CHECK([[RWEntityDetailsPolicy highlights:titles entity:identity now:now][@"pool"]count]==5);
    NSMutableDictionary *future=[Title(@"tt7",@"2026",@9,50000,@"cast")mutableCopy];future[@"released"]=@"2026-12-01T00:00:00Z";CHECK(![[RWEntityDetailsPolicy highlights:@[future] entity:identity now:now][@"knownFor"]count]);
    NSDictionary *linked=@{@"id":@"tt8",@"type":@"series",@"releaseInfo":@"2004–2015",@"imdbRating":@8,@"imdbVotes":@50000,@"discovery":@{@"cast":@[@{@"id":@"Q20"}]}};CHECK([[RWEntityDetailsPolicy highlights:@[linked] entity:identity now:now][@"knownFor"]count]==1);
    CHECK(![[RWEntityDetailsPolicy highlights:titles entity:@{@"id":@"Qbad",@"creditRole":@"cast"} now:now][@"pool"]count]);
    NSMutableArray *many=[NSMutableArray new];for(int i=0;i<1000;i++)[many addObject:Title([NSString stringWithFormat:@"tt%05d",i],[NSString stringWithFormat:@"%d",1926+i%100],@(8.5-i*.002),10000,@"cast")];result=[RWEntityDetailsPolicy highlights:many entity:identity now:now];CHECK([result[@"pool"]count]<=120);CHECK([result[@"knownFor"]count]==8&&[result[@"recent"]count]==8&&[result[@"rated"]count]==8);CHECK([result isEqual:[RWEntityDetailsPolicy highlights:many entity:identity now:now]]);
    if(argc>1){NSString *folder=[NSString stringWithUTF8String:argv[1]];NSDictionary *entities=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"entities.json"]] options:0 error:nil][@"entities"];for(NSString *qid in @[@"Q36301",@"Q798768"]){NSDictionary *sample=[RWEntityDetailsPolicy details:entities[qid] role:[qid isEqual:@"Q798768"]?@"studio":@"person" labels:@{}];CHECK([sample[@"name"]length]&&[sample[@"facts"]count]&&[sample[@"wikipediaTitle"]length]);NSDictionary *response=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:[qid stringByAppendingString:@"-biography.json"]]] options:0 error:nil];CHECK([[RWEntityDetailsPolicy biography:response entityID:qid][@"biography"]length]>100);}}
    CHECK([[RWEntityDetailsPolicy cleanBiography:@"Pixar (, ) is an animation studio."]isEqual:@"Pixar is an animation studio."]);
    CHECK([[RWEntityDetailsPolicy cleanBiography:@"Actor (born 1982) and director."]isEqual:@"Actor (born 1982) and director."]);
    CHECK([[RWEntityDetailsPolicy cleanBiography:@"Studio (formerly A/B) produces films."]isEqual:@"Studio (formerly A/B) produces films."]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
