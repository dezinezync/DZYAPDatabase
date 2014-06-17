//
//  DZYAPDatabase.m
//  DZYAPDatabase
//
//  Created by Nikhil Nigade on 16/02/14.
//  Copyright (c) 2014 Nikhil Nigade. All rights reserved.
//

static NSString const *kMainConnection = @"main";
static NSString const *kBackgroundConnection = @"background";
static NSString *kDefCollection = @"dzyap";
static NSString *dbName = @"DZYAPDB.sqlite";

static NSUInteger kCacheLimit = 5000;

#import "DZYAPDatabase.h"

@implementation DZYAPDatabase

- (instancetype)init
{
    if(self = [super init])
    {
     
        NSURL *docsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        
        NSString *databasePath = [docsPath.absoluteString stringByAppendingPathComponent:dbName];
        self.db = [[YapDatabase alloc] initWithPath:databasePath];
        self.db.defaultObjectCacheLimit = kCacheLimit;
        self.db.defaultMetadataCacheLimit = kCacheLimit;
        
        self.connections = @{}.mutableCopy;
        
        //Get and set our main connection
        [self.connections setObject:[self.db newConnection] forKey:kMainConnection];
        
        //Get and set our background connection
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            @synchronized(self.connections)
            {
                [self.connections setObject:[self.db newConnection] forKey:kBackgroundConnection];
            }
            
        });
        
    }
    return self;
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

#pragma mark - SET in named Collection
+(void)set:(id)value key:(NSString *)key collection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kMainConnection];
    
    [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction setObject:value forKey:key inCollection:collection];
        
    }];
}

+(void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kMainConnection];
    
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        if([transaction objectForKey:key inCollection:collection] == nil)
        {
            [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
}

+(void)setBG:(id)value key:(NSString *)key collection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    
    [connection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        if([transaction objectForKey:key inCollection:collection] == nil)
        {
            [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
}

+(void)setNXBG:(id)value key:(NSString *)key collection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    __block id ourOBJ;
    
    [connection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        [transaction getObject:&ourOBJ metadata:nil forKey:key inCollection:collection];
        
    } completionBlock:^{
        
        if(ourOBJ == nil)
        {
            [connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *wtransaction) {
                [wtransaction setObject:value forKey:key inCollection:collection];
            }];
        }
        
    }];
}

#pragma mark - GET from default Collection

+(id)get:(NSString *)key
{
    return [DZYAPDatabase get:key fromCollection:kDefCollection];
}

+(void)getBG:(NSString *)key complete:(DZYAPGetBlock)complete
{
    [DZYAPDatabase getBG:key fromCollection:kDefCollection complete:complete];
}

#pragma mark - GET from named Collection
+(id)get:(NSString *)key fromCollection:(NSString *)collection
{
    __block id ourOBJ;
    
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kMainConnection];
    
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        ourOBJ = [transaction objectForKey:key inCollection:collection];
        
    }];
    
    return ourOBJ;
}

+(void)getBG:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
    
    YapDatabaseConnection *connection = (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        id ourOBJ = [transaction objectForKey:key inCollection:collection];
        
        if(ourOBJ == nil) complete(NO, nil);
        else complete(YES, ourOBJ);
        
    }];

}

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
	
    YapDatabaseConnection *connection = (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
       
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
                complete(YES, objs);
            }
            
        }];
        
    }];
    
}

+ (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete
{
	YapDatabaseConnection *connection = (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    
    [connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
        NSInteger total = [transaction numberOfKeysInCollection:collection];
		complete(total);
		
	}];
	
}

#pragma mark - DEL from default Collection

+(void)del:(NSString *)key
{
    [DZYAPDatabase del:key fromCollection:kDefCollection];
}

+(void)delBG:(NSString *)key
{
    [DZYAPDatabase delBG:key fromCollection:kDefCollection];
}

#pragma mark - DEL from named Collection
+(void)del:(NSString *)key fromCollection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kMainConnection];
    
    [connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction removeObjectForKey:key inCollection:collection];
        
    }];
}

+(void)delBG:(NSString *)key fromCollection:(NSString *)collection
{
    YapDatabaseConnection *connection =  (YapDatabaseConnection *)[[DZYAPDatabase shared].connections objectForKey:kBackgroundConnection];
    
    [connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction removeObjectForKey:key inCollection:collection];
        
    }];
}

#pragma mark - COL
+ (void)removeAllObjectsFromCollection:(NSString *)collection
{
	
	[((YapDatabaseConnection *)[DZYAPDatabase shared].connections[kBackgroundConnection]) readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeAllObjectsInCollection:collection];
		
	}];
	
}

+ (void)removeAllObjectsFromAllCollections
{
	
	[((YapDatabaseConnection *)[DZYAPDatabase shared].connections[@"background"]) readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeAllObjectsInAllCollections];
		
	}];
	
}

@end
