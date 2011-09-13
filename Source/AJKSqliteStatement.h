#import "sqlite3.h"

@interface AJKSqliteStatement : NSObject {
	
}


@property (copy, readonly) NSString *query;
@property (assign, readonly) sqlite3_stmt *statementHandle;

- (id)initForquery:(NSString *)query withHandle:(sqlite3_stmt *)statementHandle;
- (void)reset;

- (int32_t)useCount;
- (void)incrementUseCount;
- (void)decrementUseCount;

@end