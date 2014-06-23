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

@interface NSObject (PGPerformSelectorOnMainThreadWithTwoObjects)
- (void) performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 waitUntilDone:(BOOL)wait;
- (void) performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 returningObject:(id *)returning waitUntilDone:(BOOL)wait;
- (void) performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 withObject:(id)arg3 waitUntilDone:(BOOL)wait;
@end

@implementation NSObject (PGPerformSelectorOnMainThreadWithTwoObjects)

- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 waitUntilDone:(BOOL)wait
{
	[self performSelectorOnMainThread:selector withObject:arg1 withObject:arg2 returningObject:nil waitUntilDone:wait];
}

- (void) performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 returningObject:(id *)returning waitUntilDone:(BOOL)wait
{
	NSMethodSignature *sig = [self methodSignatureForSelector:selector];
	if (!sig) return;
	
	NSInvocation* invo = [NSInvocation invocationWithMethodSignature:sig];
	[invo setTarget:self];
	[invo setSelector:selector];
	[invo setArgument:&arg1 atIndex:2];
	[invo setArgument:&arg2 atIndex:3];
	if(returning) [invo setArgument:&returning atIndex:4];
	[invo retainArguments];
	[invo performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:wait];
}

- (void) performSelectorOnMainThread:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 withObject:(id)arg3 waitUntilDone:(BOOL)wait
{
	NSMethodSignature *sig = [self methodSignatureForSelector:selector];
	if (!sig) return;
	
	NSInvocation* invo = [NSInvocation invocationWithMethodSignature:sig];
	[invo setTarget:self];
	[invo setSelector:selector];
	[invo setArgument:&arg1 atIndex:2];
	[invo setArgument:&arg2 atIndex:3];
	[invo setArgument:&arg3 atIndex:4];
	[invo retainArguments];
	[invo performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:wait];
}

@end

@implementation DZYAPDatabase

- (instancetype)init
{
    if(self = [super init])
    {
     
        NSURL *docsPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        
        NSString *databasePath = [docsPath.absoluteString stringByAppendingPathComponent:dbName];
        _db = [[YapDatabase alloc] initWithPath:databasePath];
        _db.defaultObjectCacheLimit = kCacheLimit;
        _db.defaultMetadataCacheLimit = kCacheLimit;
        
		_connection = [_db newConnection];
		_bgConnection = [_db newConnection];
		
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

#pragma mark - GET from default Collection

+(id)get:(NSString *)key
{
    return [DZYAPDatabase get:key fromCollection:kDefCollection returningValue:nil];
}

+(void)getBG:(NSString *)key complete:(DZYAPGetBlock)complete
{
    [DZYAPDatabase getBG:key fromCollection:kDefCollection complete:complete];
}

+(id)get:(NSString *)key fromCollection:(NSString *)collection
{
	return [DZYAPDatabase get:key fromCollection:collection returningValue:nil];
}

#pragma mark - GET from named Collection
+(id)get:(NSString *)key fromCollection:(NSString *)collection returningValue:(id *)returning
{
	if(![NSThread isMainThread])
	{
		id ourReturningObj;
		[[DZYAPDatabase shared] performSelectorOnMainThread:@selector(get:fromCollection:returningValue:) withObject:key withObject:collection returningObject:&ourReturningObj waitUntilDone:YES];
		return ourReturningObj;
	}
	
	__block id ourOBJ;
	
	[[DZYAPDatabase shared] get:key fromCollection:collection returningValue:&ourOBJ];
	
	return ourOBJ;
	
}

+(void)getBG:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
	
	if(![NSThread isMainThread])
	{
		[[DZYAPDatabase shared] performSelectorOnMainThread:@selector(getBG:fromCollection:complete:) withObject:key withObject:collection withObject:complete waitUntilDone:NO];
		return;
	}
	
	[[DZYAPDatabase shared] getBG:key fromCollection:collection complete:complete];

}

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
	
	if(![NSThread isMainThread])
	{
		[[DZYAPDatabase shared] performSelectorOnMainThread:@selector(getAllFromCollection:complete:) withObject:collection withObject:complete waitUntilDone:NO];
		return;
	}
	
	[[DZYAPDatabase shared] getAllFromCollection:collection complete:complete];
    
}

+ (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete
{
	
	if(![NSThread isMainThread])
	{
		[[DZYAPDatabase shared] performSelectorOnMainThread:@selector(getCountFromCollection:complete:) withObject:collection withObject:complete waitUntilDone:NO];
		return;
	}
	
	[[DZYAPDatabase shared] getCountFromCollection:collection complete:complete];
	
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
    [[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction removeObjectForKey:key inCollection:collection];
        
    }];
}

+(void)delBG:(NSString *)key fromCollection:(NSString *)collection
{
	
	[[DZYAPDatabase shared].bgConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeObjectForKey:key inCollection:collection];
		
	}];
	
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

- (id)get:(NSString *)key fromCollection:(NSString *)collection returningValue:(id *)returning
{

	[self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		*returning = [transaction objectForKey:key inCollection:collection];
		
	}];
	
	return *returning;
	
}

- (void)getBG:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
{
	[self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		id ourOBJ = [transaction objectForKey:key inCollection:collection];
		
		if(ourOBJ == nil) complete(NO, nil);
		else complete(YES, ourOBJ);
		
	}];
}

- (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete
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
				complete(YES, objs);
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

@end
