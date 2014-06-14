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
typedef void(^DZYAPDelBlock)(BOOL finished);

@interface DZYAPDatabase : NSObject

@property (nonatomic, strong) YapDatabase *db;
@property (nonatomic, strong) NSMutableDictionary *connections;

+ (instancetype)shared;

#pragma mark - SET
// Set a value, will replace value if it already exists
+(void)set:(id)value key:(NSString *)key;
// Set a value, will not replace an existing object
+(void)setNX:(id)value key:(NSString *)key;

+(void)setBG:(id)value key:(NSString *)key;
+(void)setNXBG:(id)value key:(NSString *)key;

+(void)set:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setBG:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setNXBG:(id)value key:(NSString *)key collection:(NSString *)collection;


#pragma mark - GET
+(id)get:(NSString *)key;

+(void)getBG:(NSString *)key complete:(DZYAPGetBlock)complete;

+(id)get:(NSString *)key fromCollection:(NSString *)collection;
+(void)getBG:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete;

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete;

#pragma mark - DEL
+(void)del:(NSString *)key;
+(void)delBG:(NSString *)key;

+(void)del:(NSString *)key fromCollection:(NSString *)collection;
+(void)delBG:(NSString *)key fromCollection:(NSString *)collection;

#pragma mark - COL
+ (void)removeAllObjectsFromCollection:(NSString *)collection;
+ (void)removeAllObjectsFromAllCollections;

@end
