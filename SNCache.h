//
//  SNCache.h
//  SNFramework
//
//  Created by  liukun on 13-2-26.
//  Copyright (c) 2013年 liukun. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kSNCacheAgeForever          -1

@interface SNFileCache : NSObject
{
	NSString *				_cachePath;
    dispatch_queue_t        _ioQueue;
    NSInteger               _maxCacheAge;
    NSMutableDictionary     *_cacheDictionary;
}

@property (nonatomic, retain) NSString *			cachePath;

+ (SNFileCache *)sharedInstance;

- (BOOL)hasCached:(NSString *)key;

- (NSData *)dataForKey:(NSString *)key;
- (void)saveData:(NSData *)data forKey:(NSString *)key;
- (void)saveData:(NSData *)data forKey:(NSString *)key cacheAge:(NSTimeInterval)age;

- (NSString *)cachePathForKey:(NSString *)key;

- (void)saveData:(NSData *)data forKey:(NSString *)key subPath:(NSString *)path;
- (NSData *)dataForKey:(NSString *)key atSubPath:(NSString *)path;
- (void)clearDiskAtSubPath:(NSString *)path;

- (void)removeDataForKey:(NSString *)key;
- (void)clearDisk;  //清空缓存
- (void)cleanDisk;  //清除过期的缓存
- (void)clearDiskWithCompletionBlock:(void(^)(void))block;

//Get the size used by the disk cache
- (unsigned long long)cacheSize;
// cache count
- (int)cacheCount;

@end

#pragma mark -

@interface SNMemoryCache : NSObject
{
    NSCache *memCache;
}

+ (SNMemoryCache *)sharedInstance;

- (id)objectForKey:(NSString *)key;
- (void)saveObject:(NSObject *)obj forKey:(NSString *)key;
- (void)removeObjectForKey:(NSObject *)key;

- (void)clearMemory;

@end