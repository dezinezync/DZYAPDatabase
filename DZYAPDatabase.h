//
//  DZYAPDatabase.h
//  DZYAPDatabase
//
//  Created by Nikhil Nigade on 16/02/14.
//  Copyright (c) 2014 Nikhil Nigade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YapDatabase.h"

typedef void(^DZYAPGetBlock)(BOOL finished,id obj);
typedef void(^DZYAPGetBatchBlock)(BOOL finished, NSArray *batch);
typedef void(^DZYAPDelBlock)(BOOL finished);
typedef void(^DZYapGetCountBlock)(NSInteger count);

@interface DZYAPDatabase : NSObject

@property (nonatomic, strong) YapDatabase *db;
@property (nonatomic, strong) YapDatabaseConnection *connection;
@property (nonatomic, strong) YapDatabaseConnection *bgConnection;

#pragma mark - SET
// Set a value, will replace value if it already exists
+ (void)set:(id)value key:(NSString *)key;
// Set a value, will not replace an existing object
+ (void)setNX:(id)value key:(NSString *)key;

+ (void)set:(id)value key:(NSString *)key collection:(NSString *)collection;
+ (void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection;


#pragma mark - GET
+ (void)get:(NSString *)key completion:(DZYAPGetBlock)complete;
+ (void)get:(NSString *)key fromCollection:(NSString *)collection completion:(DZYAPGetBlock)complete;
+ (void)getMutli:(NSArray *)keys fromCollection:(NSString *)collection completion:(DZYAPGetBatchBlock)complete;

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBatchBlock)complete;
+ (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete;

#pragma mark - DEL
+(void)del:(NSString *)key;
+(void)del:(NSString *)key fromCollection:(NSString *)collection;

#pragma mark - COL
+ (void)removeAllObjectsFromCollection:(NSString *)collection;
+ (void)removeAllObjectsFromAllCollections;

@end
