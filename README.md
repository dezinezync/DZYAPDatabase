DZYAPDatabase
=============

Simple Abstraction layer over YAPDatabase for more convenient GETs, SETs, SETNXs and DELs.

The API has been updated to completely utilize blocks. This prevents from dead-locking on threads.


~~~~
#pragma mark - SET
+ (void)set:(id)value key:(NSString *)key;
+ (void)setNX:(id)value key:(NSString *)key;

+ (void)set:(id)value key:(NSString *)key collection:(NSString *)collection;
+ (void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection;


+ (void)get:(NSString *)key completion:(DZYAPGetBlock)complete;
+ (void)get:(NSString *)key fromCollection:(NSString *)collection completion:(DZYAPGetBlock)complete;
+ (void)getMutli:(NSArray *)keys fromCollection:(NSString *)collection completion:(DZYAPGetBatchBlock)complete;

+ (void)getAllFromCollection:(NSString *)collection complete:(DZYAPGetBatchBlock)complete;
+ (void)getCountFromCollection:(NSString *)collection complete:(DZYapGetCountBlock)complete;

+(void)del:(NSString *)key;
+(void)del:(NSString *)key fromCollection:(NSString *)collection;

+ (void)removeAllObjectsFromCollection:(NSString *)collection;
+ (void)removeAllObjectsFromAllCollections;
~~~~

- - -
#### Difference Between Set and SetNX  
When using `set`, if they key already exists in the database, it's value is replaced with the new value you provide. When using `setNX`, the value is not replaced. Therefore, `setnx` can be used to create unique records in a set-it-and-forget-about-it fashion (I'm aware of it's shorter version ;) )

- - -
#### Default Collection  
When using the non-collection methods, the default collection is used. This enables you to quickly set and get keys without having to remember what collection name you used in a particular .m file. 

=============
