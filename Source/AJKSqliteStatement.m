#import "AJKSqliteStatement.h"
#import "AJKSqliteDatabase.h"

#import "AJKDispatchQueueFunctions.h"
#import "libkern/OSAtomic.h"


@interface AJKSqliteStatement () {
	sqlite3_stmt *statementHandle_;
	int32_t useCount_;
}

@property (copy, readwrite) NSString *query;
@property (assign, readwrite) sqlite3_stmt *statementHandle;


- (void)close;

@end



@implementation AJKSqliteStatement
@synthesize query = query_, statementHandle = statementHandle_;


- (id)initForQuery:(NSString *)query withHandle:(sqlite3_stmt *)statementHandle
{
	self = [super init];
	
	if(self) {
		self.query = query;
		statementHandle_ = statementHandle;
	}
	
	return self;
}


- (void)reset
{
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		sqlite3_reset([self statementHandle]);
	});
}



- (int32_t)useCount
{
	return useCount_;
}


- (void)incrementUseCount
{
	OSAtomicIncrement32(&useCount_);
}


- (void)decrementUseCount
{
	OSAtomicDecrement32(&useCount_);
}


- (void)close
{
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		sqlite3_finalize([self statementHandle]);
	});
}


- (void)finalize
{
	[self close];
	[super finalize];
}


- (void)dealloc
{
	[self close];
}



@end