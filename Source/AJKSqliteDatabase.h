#import "sqlite3.h"

@class AJKResultSet, AJKSqliteStatement;


extern NSString *const AJKSqliteDatabaseError;


@interface AJKSqliteDatabase : NSObject {
	
}

+ (dispatch_queue_t)queue;

@property (assign) BOOL shouldLog;
@property (readwrite, assign) sqlite3 *database;
@property (copy) NSURL *databaseURL;
@property (assign) int numberOfAttemptsToTry;

- (id)initWithURL:(NSURL *)url;

// 
- (BOOL)executeUpdate:(NSString *)query;
- (BOOL)executeUpdate:(NSString *)query withArguments:(NSArray *)arguments error:(NSError **)outError;
- (AJKResultSet *)executeQuery:(NSString *)query;
- (AJKResultSet *)executeQuery:(NSString *)query withArguments:(NSArray *)arguments error:(NSError **)outError;

// Create table
- (BOOL)createTable:(NSString *)tableName withString:(NSString *)columns;

// 
- (BOOL)rollback;
- (BOOL)commit;
- (BOOL)beginTransaction;
- (BOOL)beginDeferredTransaction;

// Manage tables
- (BOOL)createTable:(NSString *)tableName withColumns:(NSString *)columns;

// Querying the status of the database
- (int64_t)identifierOfLastInsert;
- (int)numberOfChanges;
- (BOOL)hasEncounteredError;
- (int)lastErrorCode;
- (NSString *)lastErrorMessage;

// Manage cached objects
- (void)removeUnusedCachedStatements;

// Treat these methods as private, only AJKSqliteStatement and AJKResultSet should call these methods
- (void)decrementUsageOfStatement:(AJKSqliteStatement *)statement;
- (void)finishedUsingResultSet:(AJKResultSet *)resultSet;

@end