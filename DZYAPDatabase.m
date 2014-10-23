//
//  DZYAPDatabase.m
//  DZYAPDatabase
//
//  Created by Nikhil Nigade on 16/02/14.
//  Copyright (c) 2014 Nikhil Nigade. All rights reserved.
//

#ifndef asyncMain

#define asyncMain(block) {\
	if([NSThread isMainThread])\
	{\
		block();\
	}\
	else\
	{\
		dispatch_async(dispatch_get_main_queue(), block);\
	}\
};

#endif

#ifndef safeBlock

#define safeBlock(queue,block, ...) {\
	if(block) {\
		dispatch_async(queue,^{\
			block(__VA_ARGS__);\
		});\
	}\
}

#endif

static NSString *const kMainConnection = @"main";
static NSString *const kBackgroundConnection = @"background";
static NSString *const kDefCollection = @"dzyap";
static NSString *const dbName = @"DZYAPDB.sqlite";
static NSString *const secureKey = @"dzyapdb.secure";

static NSUInteger kCacheLimit = 5000;

#import "DZYAPDatabase.h"
#import <CommonCrypto/CommonCrypto.h>

@interface NSData (Crypto)

// Source: http://www.lantean.co/encrypting-and-decrypting-nsdata-with-aes256/

- (NSData *)encryptWithKey:(NSString *)key;
- (NSData *)decryptWithKey:(NSString *)key;

@end

@implementation NSData (Crypto)

- (NSData *)encryptWithKey:(NSString *)key
{
//  'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256 + 1];
    bzero( keyPtr, sizeof( keyPtr ) );
    
//  fetch key data
    [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
//  See the doc: For block ciphers, the output size will always be less than or equal to the input size plus the size of one block.
//  That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc( bufferSize );
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt( kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted );
    if( cryptStatus == kCCSuccess )
    {
//  The returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free( buffer );
    return nil;
}

- (NSData*)decryptWithKey:(NSString *)key
{
//  'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1];
    bzero( keyPtr, sizeof( keyPtr ) );
    
//  fetch key data
    [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
//  See the doc: For block ciphers, the output size will always be less than or equal to the input size plus the size of one block.
//  That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc( bufferSize );
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt( kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted );
    
    if( cryptStatus == kCCSuccess )
    {
//  The returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free( buffer );
    return nil;
}

@end

@interface DZYAPDatabase()

@property (nonatomic, copy) NSString *encKey;

@end

@implementation DZYAPDatabase

- (instancetype)init
{
    if(self = [super init])
    {
        
//        __weak DZYAPDatabase *weakSelf = self;
		
        NSURL *docsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        
        NSString *databasePath = [docsPath.absoluteString stringByAppendingPathComponent:dbName];
        _db = [[YapDatabase alloc] initWithPath:databasePath];
        _db.defaultObjectCacheLimit = kCacheLimit;
        _db.defaultMetadataCacheLimit = kCacheLimit;
		
//		Main Thread connection : Read Only
		_connection = [_db newConnection];
		_connection.objectPolicy = YapDatabasePolicyShare;
//		Background Thread connection : ReadWrite
		_bgConnection = [_db newConnection];
		_bgConnection.objectPolicy = YapDatabasePolicyShare;
        
    }
    return self;
}

+ (NSData *)encryptObject:(id)obj
{
    
    if(!obj) return nil;
    if(![DZYAPDatabase shared].encKey || ![DZYAPDatabase shared].encKey.length) return nil;
    
    NSData *uncrypt = [NSKeyedArchiver archivedDataWithRootObject:obj];
    
    NSData *encrypt = [uncrypt encryptWithKey:[DZYAPDatabase shared].encKey];
    
    return encrypt;
    
}

+ (id)decryptData:(NSData *)data
{
    
    if(!data || !strlen([data bytes])) nil;
    if(![DZYAPDatabase shared].encKey || ![DZYAPDatabase shared].encKey.length) return nil;
    
    NSData *uncrypt = [data decryptWithKey:[DZYAPDatabase shared].encKey];
    
    id object = [NSKeyedUnarchiver unarchiveObjectWithData:uncrypt];
    
    return object;
    
}

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    static DZYAPDatabase *DZDB;
    dispatch_once(&onceToken, ^{
        DZDB = [[DZYAPDatabase alloc] init];
    });
    
    return DZDB;
}

+ (void)setEncryptionKey:(NSString *)key
{
    if(!key || !key.length)
    {
        NSLog(@"Not a valid signing key. Ignoring request.");
        return;
    }
    [DZYAPDatabase shared].encKey = key;
}

#pragma mark - SET in Default Collection
+(void)set:(id)value key:(NSString *)key
{
    [DZYAPDatabase set:value key:key collection:kDefCollection];
}

+(void)setNX:(id)value key:(NSString *)key
{
    [DZYAPDatabase setNX:value key:key collection:kDefCollection];
}

+(void)setBG:(id)value key:(NSString *)key
{
    [DZYAPDatabase setBG:value key:key collection:kDefCollection];
}

+(void)setNXBG:(id)value key:(NSString *)key
{
    [DZYAPDatabase setNXBG:value key:key collection:kDefCollection];
}

+ (void)setSecure:(id)value key:(NSString *)key
{
    [DZYAPDatabase setSecure:value key:key collection:kDefCollection];
}

#pragma mark - SET in named Collection
+(void)set:(id)value key:(NSString *)key collection:(NSString *)collection
{
    
    [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction setObject:value forKey:key inCollection:collection];
        
    }];
    
}

+(void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection
{
	
	[[DZYAPDatabase shared].bgConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        if([transaction objectForKey:key inCollection:collection] == nil)
        {
            [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
}

+(void)setBG:(id)value key:(NSString *)key collection:(NSString *)collection
{
	
	[[DZYAPDatabase shared].bgConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        if([transaction objectForKey:key inCollection:collection] == nil)
        {
            [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
}

+(void)setNXBG:(id)value key:(NSString *)key collection:(NSString *)collection
{
	
	__block id ourOBJ;
    
    [[DZYAPDatabase shared].bgConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        [transaction getObject:&ourOBJ metadata:nil forKey:key inCollection:collection];
        
    } completionBlock:^{
        
        if(ourOBJ == nil)
        {
            [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
	
}

+ (void)setSecure:(id)value key:(NSString *)key collection:(NSString *)collection
{
 
    if(![DZYAPDatabase shared].encKey || ![[DZYAPDatabase shared].encKey length])
    {
        NSLog(@"No encryption key set. Not proceeding.");
        return;
    }
    
    NSData *secured = [DZYAPDatabase encryptObject:value];
    
    if(!secured || !strlen([secured bytes]))
    {
        NSLog(@"Encryption failed. Not proceeding.");
        return;
    }
    
    [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction setObject:secured forKey:key inCollection:collection withMetadata:@{secureKey:@(YES)}];
        
    }];
    
}

#pragma mark - GET from default Collection

+ (void)get:(NSString *)key completion:(DZYAPGetBlock)complete
{
    [DZYAPDatabase get:key fromCollection:kDefCollection completion:complete];
}

+ (void)getSecure:(NSString *)key completion:(DZYAPGetBlock)complete
{
    [DZYAPDatabase getSecure:key fromCollection:kDefCollection complete:complete];
}

#pragma mark - GET from named Collection
+ (void)get:(NSString *)key fromCollection:(NSString *)collection completion:(DZYAPGetBlock)complete
{
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[[DZYAPDatabase shared] get:key fromCollection:collection completion:complete];
	});

}

+ (void)getSecure:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        [[DZYAPDatabase shared] getSecure:key fromCollection:collection completion:complete];
        
    });
    
}

+ (void)getMutli:(NSArray *)keys fromCollection:(NSString *)collection completion:(DZYAPGetBatchBlock)complete
{
	
    if(![keys count]) complete(YES,keys);
	
	__block NSMutableArray *backingArray = [keys mutableCopy];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
        [[DZYAPDatabase shared].connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			[keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				
                id requiredObj = [transaction objectForKey:obj inCollection:collection];
                if(requiredObj)
				{
                    [backingArray replaceObjectAtIndex:idx withObject:requiredObj];
				}
				
				if((idx+1) == [keys count]) complete(YES,backingArray);
				
			}];
			
		}];
		
	});
	
}

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBatchBlock)complete
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[[DZYAPDatabase shared] getAllFromCollection:collection complete:complete];
	});
}

+ (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete
{
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[[DZYAPDatabase shared] getCountFromCollection:collection complete:complete];
	});

}

#pragma mark - DEL from default Collection

+ (void)del:(NSString *)key
{
    [DZYAPDatabase del:key fromCollection:kDefCollection];
}

#pragma mark - DEL from named Collection
+ (void)del:(NSString *)key fromCollection:(NSString *)collection
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		[[DZYAPDatabase shared] del:key fromCollection:collection];
		
	});
}

#pragma mark - COL
+ (void)removeAllObjectsFromCollection:(NSString *)collection
{
	
	[[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeAllObjectsInCollection:collection];
		
	}];
	
}

+ (void)removeAllObjectsFromAllCollections
{
	
	[[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeAllObjectsInAllCollections];
		
	}];
	
}

#pragma mark - Class Methods

- (void)set:(id)value key:(NSString *)key inCollection:(NSString *)collection
{
	
	[self.bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction setObject:value forKey:key inCollection:collection];
		
	}];
	
}

- (void)setNX:(id)value key:(NSString *)key inCollection:(NSString *)collection
{
	
	[self.bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		id obj = [transaction objectForKey:key inCollection:collection];
		if(obj) return;
		
		[transaction setObject:value forKey:key inCollection:collection];
		
	}];
	
}

- (void)get:(NSString *)key fromCollection:(NSString *)collection completion:(DZYAPGetBlock)complete
{

	__block id ourObj;
	
	[self.bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		ourObj = [transaction objectForKey:key inCollection:collection];
		NSDictionary *meta = [transaction metadataForKey:key inCollection:collection];
        
        if(meta && [[meta objectForKey:secureKey] boolValue])
        {
//          Is Secured according to the DB
            
            if(ourObj)
            {
                
//              It is actually Encrypted
                if([ourObj isKindOfClass:[NSData class]])
                {
                    id sendObj = [DZYAPDatabase decryptData:ourObj];
                    safeBlock(dispatch_get_main_queue(),complete,YES, sendObj);
                }
                else
                {
//                    It isn't encrypted
                    safeBlock(dispatch_get_main_queue(),complete,YES, ourObj);
                }
                
            }
            else
            {
                safeBlock(dispatch_get_main_queue(),complete,NO, nil);
            }
            
        }
        else
        {
            if(ourObj)
            {
                complete(YES, ourObj);
                return;
            }
            complete(NO, nil);
            
        }
		
	}];
	
}

- (void)getSecure:(NSString *)key fromCollection:(NSString *)collection completion:(DZYAPGetBlock)complete
{
    
    __block id ourObj;
    
    [self.bgConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
       
        ourObj = [transaction objectForKey:key inCollection:collection];
        NSDictionary *meta = [transaction metadataForKey:key inCollection:collection];
        
        if(meta && [[meta objectForKey:secureKey] boolValue])
        {
//          Is Secured according to the DB
            
            if(ourObj)
            {
                
//              It is actually Encrypted
                if([ourObj isKindOfClass:[NSData class]])
                {
                    id sendObj = [DZYAPDatabase decryptData:ourObj];
                    safeBlock(dispatch_get_main_queue(),complete,YES, sendObj);
                }
                else
                {
//                    It isn't encrypted
                    safeBlock(dispatch_get_main_queue(),complete,YES, ourObj);
                }
                
            }
            else
            {
                safeBlock(dispatch_get_main_queue(),complete,NO, nil);
            }
            
        }
        else
        {
            if(ourObj)
            {
                safeBlock(dispatch_get_main_queue(),complete,YES, ourObj);
                return;
            }
            safeBlock(dispatch_get_main_queue(),complete,NO, nil);
            
        }
        
   }];
    
}

- (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBatchBlock)complete
{
	
	[self.connection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		NSInteger total = [transaction numberOfKeysInCollection:collection];
		
		if(total == 0)
		{
			complete(YES, @[]);
			return;
		}
		
		__block NSMutableArray *objs = [NSMutableArray arrayWithCapacity:total];
		
		[[transaction allKeysInCollection:collection] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			
			id objx = [transaction objectForKey:obj inCollection:collection];
			[objs addObject:objx];
			
			if([objs count] == total)
			{
				complete(YES, [NSArray arrayWithArray:objs]);
				return;
			}
			
		}];
		
	}];
	
}

- (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete
{
	[self.connection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		NSInteger total = [transaction numberOfKeysInCollection:collection];
		
		complete(total);
		
	}];
}

- (void)del:(NSString *)key fromCollection:(NSString *)collection
{
	
	[self.bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeObjectForKey:key inCollection:collection];
		
	}];
	
}

@end
