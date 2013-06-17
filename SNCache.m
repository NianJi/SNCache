//
//  SNCache.m
//  SNFramework
//
//  Created by  liukun on 13-2-26.
//  Copyright (c) 2013年 liukun. All rights reserved.
//

#import "SNCache.h"

//默认文件缓存时间
static const NSInteger kDefaultFileCacheAge = 60 * 60 * 24 * 7; // 1 week

@implementation SNFileCache

@synthesize cachePath = _cachePath;

+ (SNFileCache *)sharedInstance
{
    static dispatch_once_t once;
    static SNFileCache * __singleton__;
    dispatch_once( &once, ^{ __singleton__ = [[SNFileCache alloc] init]; } ); 
    return __singleton__;
}

- (id)init
{
	self = [super init];
	if ( self )
	{
        NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		self.cachePath = [NSString stringWithFormat:@"%@/SNCache/", cachesDirectory];
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.suning.SNFileCache", DISPATCH_QUEUE_SERIAL);
        //清除过期的缓存
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[self cachePathForKey:@"SNCache.plist"]];
		
		if([dict isKindOfClass:[NSDictionary class]]) {
			_cacheDictionary = [dict mutableCopy];
		} else {
			_cacheDictionary = [[NSMutableDictionary alloc] init];
		}
        
        [self cleanDisk];
	}
	return self;
}

- (void)dealloc
{    
	self.cachePath = nil;
    dispatch_release(_ioQueue);
	
	[super dealloc];
}

- (NSString *)cachePathForKey:(NSString *)key
{
	NSString * pathName = self.cachePath;
	
	if ( NO == [[NSFileManager defaultManager] fileExistsAtPath:pathName] )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:pathName
								  withIntermediateDirectories:YES
												   attributes:nil
														error:NULL];
	}
    
	return [pathName stringByAppendingString:key];
}

- (BOOL)hasCached:(NSString *)key
{
    NSDate* date = [_cacheDictionary objectForKey:key];
	if(!date) return NO;
	if([date isKindOfClass:[NSDate class]] && [[[NSDate date] earlierDate:date] isEqualToDate:date]) return NO;
	return [[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForKey:key]];
}

- (NSData *)dataForKey:(NSString *)key
{
	if([self hasCached:key])
    {
		return [NSData dataWithContentsOfFile:[self cachePathForKey:key]
                                      options:0
                                        error:NULL];
	}
    else
    {
		return nil;
	}
}

- (void)saveData:(NSData *)data forKey:(NSString *)key
{
    [self saveData:data forKey:key cacheAge:kDefaultFileCacheAge];
}

- (void)saveData:(NSData *)data forKey:(NSString *)key cacheAge:(NSTimeInterval)age
{
    if (!data || !key)
    {
        return;
    }
    
    dispatch_async(_ioQueue, ^
    {
        NSFileManager *fileManager = NSFileManager.new;
        
        if (![fileManager fileExistsAtPath:self.cachePath])
        {
            [fileManager createDirectoryAtPath:self.cachePath
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:NULL];
        }
        
        [fileManager createFileAtPath:[self cachePathForKey:key]
                             contents:data
                           attributes:nil];
        [fileManager release];
        
        if (age == kSNCacheAgeForever)
        {
            [_cacheDictionary setObject:__INT(kSNCacheAgeForever)
                                 forKey:key];
        }
        else
        {
            [_cacheDictionary setObject:[NSDate dateWithTimeIntervalSinceNow:age]
                                 forKey:key];
        }
        [_cacheDictionary writeToFile:[self cachePathForKey:@"SNCache.plist"]
                           atomically:YES];
    });
}

- (void)removeDataForKey:(NSString *)key
{
	dispatch_async(_ioQueue, ^
    {
        [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForKey:key] error:nil];
    });
}

- (NSString *)cachePathForKey:(NSString *)key atSubPath:(NSString *)path
{
    NSString * pathName = [self.cachePath stringByAppendingPathComponent:path];
	
	if ( NO == [[NSFileManager defaultManager] fileExistsAtPath:pathName] )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:pathName
								  withIntermediateDirectories:YES
												   attributes:nil
														error:NULL];
	}
    
	return [pathName stringByAppendingPathComponent:key];
}

- (void)saveData:(NSData *)data forKey:(NSString *)key subPath:(NSString *)path
{
    if (!data || !key)
    {
        return;
    }
    
    dispatch_async(_ioQueue, ^{
        
        NSFileManager *fileManager = NSFileManager.new;
        
        if (![fileManager fileExistsAtPath:[self.cachePath stringByAppendingPathComponent:path]])
        {
            [fileManager createDirectoryAtPath:[self.cachePath stringByAppendingPathComponent:path]
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:NULL];
        }
        
        [fileManager createFileAtPath:[self cachePathForKey:key atSubPath:path]
                             contents:data
                           attributes:nil];
        [fileManager release];
        
    });
}
- (NSData *)dataForKey:(NSString *)key atSubPath:(NSString *)path
{
    return [NSData dataWithContentsOfFile:[self cachePathForKey:key atSubPath:path]
                                  options:0
                                    error:NULL];
}
- (void)clearDiskAtSubPath:(NSString *)path
{
    dispatch_async(_ioQueue, ^{
        
        [[NSFileManager defaultManager] removeItemAtPath:[self.cachePath stringByAppendingPathComponent:path]
                                                   error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[self.cachePath stringByAppendingPathComponent:path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
}

- (void)clearDisk
{
	dispatch_async(_ioQueue, ^
    {
        [_cacheDictionary removeAllObjects];
        [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.cachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
}

- (void)cleanDisk
{
    dispatch_async(_ioQueue, ^
    {
        for(NSString* key in _cacheDictionary)
        {
			NSDate *date = [_cacheDictionary objectForKey:key];
			if([date isKindOfClass:[NSDate class]] && [[[NSDate date] earlierDate:date] isEqualToDate:date])
            {
				[[NSFileManager defaultManager] removeItemAtPath:[self cachePathForKey:key]
                                                           error:NULL];
			}
		}
    });
}

- (void)clearDiskWithCompletionBlock:(void (^)(void))block
{
    dispatch_async(_ioQueue, ^
    {
        for(NSString* key in _cacheDictionary)
        {
            NSDate *date = [_cacheDictionary objectForKey:key];
            if([[[NSDate date] earlierDate:date] isEqualToDate:date])
            {
                [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForKey:key]
                                                           error:NULL];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    });
}

- (unsigned long long)cacheSize
{
    unsigned long long size = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.cachePath];
    for (NSString *fileName in fileEnumerator)
    {
        NSString *filePath = [self.cachePath stringByAppendingPathComponent:fileName];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        size += [attrs fileSize];
    }
    return size;
}

- (int)cacheCount
{
    int count = 0;
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:self.cachePath];
    for (NSString *fileName in fileEnumerator)
    {
        count += 1;
    }
    
    return count;
}

@end


#pragma mark -

@implementation SNMemoryCache

+ (SNMemoryCache *)sharedInstance
{
    static dispatch_once_t once;
    static SNMemoryCache * __singleton__;
    dispatch_once( &once, ^{ __singleton__ = [[SNMemoryCache alloc] init]; } );
    return __singleton__;
}

- (id)init
{
	self = [super init];
	if ( self )
	{
        memCache = [[NSCache alloc] init];
        memCache.name = @"com.suning.SNMemoryCache";
        
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
	}
    
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [super dealloc];
}

- (BOOL)hasCached:(NSString *)key
{
	return [memCache objectForKey:key] ? YES : NO;
}

- (id)objectForKey:(NSString *)key
{
	return [memCache objectForKey:key];
}

- (void)saveObject:(NSObject *)obj forKey:(NSString *)key
{
	if ( nil == key )
		return;
	
	if ( nil == obj )
		return;
	
	[memCache setObject:obj forKey:key];
}

- (void)removeObjectForKey:(NSObject *)key
{
	[memCache removeObjectForKey:key];
}

- (void)clearMemory
{
	[memCache removeAllObjects];
}


@end