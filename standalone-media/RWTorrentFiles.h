#pragma once
#import <Foundation/Foundation.h>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/bdecode.hpp>
#include <sys/stat.h>
#include <errno.h>

// The app's Documents directory is the trusted anchor. System ancestors such
// as /var may themselves be aliases; never resolve a cache child through a link.
static inline bool RWCachePathAllowed(NSString *root,NSString *path,bool directory) {
    if(!root.length||!path.length)return false;
    struct stat st={};if(lstat(root.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return false;
    NSString *prefix=[root stringByAppendingString:@"/"];
    if(![path hasPrefix:prefix])return false;
    NSArray *parts=[[path substringFromIndex:prefix.length]componentsSeparatedByString:@"/"];
    for(NSString *part in parts)if(!part.length||[part isEqual:@"."]||[part isEqual:@".."])return false;
    NSString *cursor=root;
    for(NSUInteger i=0;i<parts.count;i++){
        cursor=[cursor stringByAppendingPathComponent:parts[i]];
        if(lstat(cursor.fileSystemRepresentation,&st))return errno==ENOENT;
        if(S_ISLNK(st.st_mode))return false;
        bool needsDirectory=i+1<parts.count||directory;
        if(needsDirectory?!S_ISDIR(st.st_mode):!S_ISREG(st.st_mode))return false;
    }
    return true;
}

// Before add_torrent can check pre-existing data, inspect directory entries,
// including compact partfiles and files whose metadata has not arrived yet.
// This reads names/stat only, never media bytes, and never follows a link.
static inline bool RWCacheTreeAllowed(NSString *root,NSString *directory) {
    if(!RWCachePathAllowed(root,directory,true))return false;
    if(![NSFileManager.defaultManager fileExistsAtPath:directory])return true;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:directory];NSUInteger visited=0;
    while(pending.count){
        NSString *parent=pending.lastObject;[pending removeLastObject];NSError *error=nil;
        NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:parent error:&error];if(error)return false;
        if(names.count>16384-visited)return false;visited+=names.count;
        for(NSString *name in names){NSString *path=[parent stringByAppendingPathComponent:name];struct stat st={};
            if(lstat(path.fileSystemRepresentation,&st)||S_ISLNK(st.st_mode))return false;
            if(S_ISDIR(st.st_mode)){if(path.pathComponents.count-directory.pathComponents.count>64)return false;[pending addObject:path];}
            else if(!S_ISREG(st.st_mode))return false;
        }
    }
    return true;
}

static inline bool RWTorrentPathComponent(libtorrent::bdecode_node node) {
    if(node.type()!=libtorrent::bdecode_node::string_t)return false;
    auto value=node.string_value();if(value.empty()||value=="."||value=="..")return false;
    for(char c:value)if(c=='/'||c=='\\'||c=='\0')return false;
    return true;
}
static inline bool RWTorrentRawPathsAllowed(const libtorrent::torrent_info &torrent) {
    // file_storage has already removed separators and '..'. Validate original
    // hash-covered metadata as well, so normalized malicious names are refused.
    if(torrent.metadata_size()<=0||torrent.metadata_size()>2*1024*1024)return false;
    auto bytes=torrent.metadata();libtorrent::bdecode_node info;libtorrent::error_code error;
    libtorrent::bdecode(bytes.get(),bytes.get()+torrent.metadata_size(),info,error,nullptr,16,65536);
    if(error||info.type()!=libtorrent::bdecode_node::dict_t||!RWTorrentPathComponent(info.dict_find("name")))return false;
    auto utfName=info.dict_find("name.utf-8");if(utfName&&!RWTorrentPathComponent(utfName))return false;
    auto safeEntry=[](libtorrent::bdecode_node entry){
        auto attributes=entry.dict_find_string_value("attr");for(char c:attributes)if(c=='l')return false;
        return !entry.dict_find("symlink path");
    };
    if(!safeEntry(info))return false;
    auto files=info.dict_find("files");if(!files)return true;
    if(files.type()!=libtorrent::bdecode_node::list_t||files.list_size()>1000)return false;
    for(int i=0;i<files.list_size();i++){
        auto file=files.list_at(i);if(file.type()!=libtorrent::bdecode_node::dict_t||!safeEntry(file))return false;
        for(const char *key:{"path","path.utf-8"}){
            auto path=file.dict_find(key);if(!path){if(key[4]=='\0')return false;continue;}
            if(path.type()!=libtorrent::bdecode_node::list_t||path.list_size()==0)return false;
            for(int j=0;j<path.list_size();j++)if(!RWTorrentPathComponent(path.list_at(j)))return false;
        }
    }
    return true;
}
