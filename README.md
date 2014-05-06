DZYAPDatabase
=============

Simple Abstraction layer over YAPDatabase for more convenient GETs, SETs, SETNXs and DELs.


~~~~
+(void)set:(id)value key:(NSString *)key;
+(void)setNX:(id)value key:(NSString *)key;
+(void)setBG:(id)value key:(NSString *)key;
+(void)setNXBG:(id)value key:(NSString *)key;

+(void)set:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setNX:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setBG:(id)value key:(NSString *)key collection:(NSString *)collection;
+(void)setNXBG:(id)value key:(NSString *)key collection:(NSString *)collection;

+(id)get:(NSString *)key;
+(void)getBG:(NSString *)key complete:(DZYAPGetBlock)complete;
+(id)get:(NSString *)key fromCollection:(NSString *)collection;
+(void)getBG:(NSString *)key fromCollection:(NSString *)collection complete:(DZYAPGetBlock)complete;

+(void)del:(NSString *)key;
+(void)delBG:(NSString *)key;
+(void)del:(NSString *)key fromCollection:(NSString *)collection;
+(void)delBG:(NSString *)key fromCollection:(NSString *)collection;

+ (void)removeAllObjectsFromCollection:(NSString *)collection;
+ (void)removeAllObjectsFromAllCollections;
~~~~

- - -
#### Difference Between Set and SetNX  
When using `set`, if they key already exists in the database, it's value is replaced with the new value you provide. When using `setNX`, the value is not replaced. Therefore, `setnx` can be used to create unique records in a set-it-and-forget-about-it fashion (I'm aware of it's shorter version ;) )

- - -
#### Difference Between Normal and BG Methods  
When using BG methods, the calls are made on the background thread. This also means, all non-BG methods are called on the main thread. It's usually recommended to call the getBG methods as these will not block your main-thread when fetching large objects. 

- - -
#### Default Collection  
When using the non-collection methods, the default collection is used. This enables you to quickly set and get keys without having to remember what collection name you used in a particular .m file. 

=============
