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

// Manage tables
- (BOOL)createTable:(NSString *)tableName withColumns:(NSDictionary *)columnsForTypes error:(NSError **)outError;

// 
- (BOOL)rollback;
- (BOOL)commit;
- (BOOL)beginTransaction;
- (BOOL)beginDeferredTransaction;

// Querying the status of the database
- (int64_t)identifierOfLastInsert;
- (int)numberOfChanges;
- (BOOL)hasEncounteredError;
- (int)lastErrorCode;
- (NSString *)lastErrorMessage;

// Manage cached objects
- (void)removeUnusedCachedStatements;


// Treat these methods as largely private, you should only be used to creat more efficient execute... style methods
- (AJKSqliteStatement *)statementForQuery:(NSString *)query error:(NSError **)outError;
- (void)bindObject:(id)objectToBind toColumn:(int)columnIndex inStatement:(sqlite3_stmt *)statement;
- (void)addResultSet:(AJKResultSet *)resultSet;

// Treat these methods as private, only AJKSqliteStatement and AJKResultSet should call these methods
- (void)decrementUsageOfStatement:(AJKSqliteStatement *)statement;
- (void)finishedUsingResultSet:(AJKResultSet *)resultSet;

@end