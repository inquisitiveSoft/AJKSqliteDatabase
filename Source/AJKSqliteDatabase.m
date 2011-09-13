#import "AJKSqliteDatabase.h"
#import "AJKResultSet.h"
#import "AJKSqliteStatement.h"

#import "AJKBlockFunctions.h"


NSString *const AJKSqliteDatabaseError = @"AJKSqliteDatabaseError";



@interface AJKSqliteDatabase () {
	NSMutableDictionary *cachedStatements_, *activeResultsSets_;
}

- (AJKSqliteStatement *)statementForquery:(NSString *)query error:(NSError **)outError;
- (void)bindObject:(id)objectToBind toColumn:(int)columnIndex inStatement:(sqlite3_stmt *)statement;

// Managing result sets
- (void)addResultSet:(AJKResultSet *)resultSet;

@end


@implementation AJKSqliteDatabase
@synthesize database, databaseURL = databaseURL_, numberOfAttemptsToTry = numberOfAttemptsToTry_, shouldLog = shouldLog_;


+ (dispatch_queue_t)queue
{
	// It might be better to have a queue per database, but this works for me
	static dispatch_queue_t sqliteDatabaseQueue = nil;
	static dispatch_once_t createSqliteDatabaseQueue;
	dispatch_once(&createSqliteDatabaseQueue, ^{
		sqliteDatabaseQueue = dispatch_queue_create("Sqlite database access queue", NULL);
	});
	
	return sqliteDatabaseQueue;
}


- (id)initWithURL:(NSURL *)url
{
	self = [super init];
	
	if (self) {
		self.databaseURL = url;
		self.numberOfAttemptsToTry = 4;
		
		activeResultsSets_ = [[NSMutableDictionary alloc] init];
		cachedStatements_ = [[NSMutableDictionary alloc] init];
		
		// Try to open the database, if a url isn't supplied then the Sqlite database will be created in memory
		NSString *databasePath = [url path];
		__block int result = 0;
		dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
			sqlite3 *databaseHandle = nil;
			result = sqlite3_open((databasePath ? [databasePath fileSystemRepresentation] : ":memory:"), &databaseHandle);
			self.database = databaseHandle;
		});
		
		
		if((result != SQLITE_OK) || !database) {
			NSLog(@"Couldn't open a SQlite database at the path:'%@', error number:%d, description:'%@'", databasePath, result, [self lastErrorMessage]);
			return nil;
		}
	}
	
	return self;
}



#pragma mark -
#pragma mark -


- (BOOL)executeUpdate:(NSString *)query;
{
	return [self executeUpdate:query withArguments:nil error:NULL];
}


- (BOOL)executeUpdate:(NSString *)query withArguments:(NSArray *)arguments error:(NSError **)outError
{
	AJKSqliteStatement *statement = [self statementForquery:query error:outError];
	if(!statement)
		return NO;
	
	
	// Retrieve the number of results and then bind each of the input arguments
	__block int numberOfResults = 0;
	sqlite3_stmt *statementHandle = statement.statementHandle;
	[statement incrementUseCount];
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		numberOfResults = sqlite3_bind_parameter_count(statementHandle);
	});
	
	int resultIndex = 0;
	for(id argumentForColumn in arguments) {
		resultIndex++;
		[self bindObject:argumentForColumn toColumn:resultIndex inStatement:statementHandle];
	}
	
	
	// Make sure that the number of arguments matches expectations
	if(resultIndex != numberOfResults) {
		if(outError != NULL) {
			NSString *errorDescription = [NSString stringWithFormat:@"Found an unexpected number of arguments for the '%@' query. %d arguments rather than the expected %d.", query, [arguments count], numberOfResults];
			*outError = [NSError errorWithDomain:AJKSqliteDatabaseError code:5 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													errorDescription, NSLocalizedDescriptionKey,
															nil]];
		}
		
		return FALSE;
	}
	
	
	// Call sqlite3_step() to run the virtual machine
	// Assume no data will be returned since the SQL being executed is not a SELECT statement
	__block int result;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		size_t attempts = 0;
		size_t numberOfAttemptsToTry = [self numberOfAttemptsToTry];
	
		do {
			result = sqlite3_step(statementHandle);
		
			if((result == SQLITE_LOCKED) || (result == SQLITE_BUSY)) {
				usleep(20);
				attempts += 1;
			} else
				break;
		} while (attempts < numberOfAttemptsToTry);
	});
	
	
	[self decrementUsageOfStatement:statement];
	
	
	if((result == SQLITE_DONE) || (result == SQLITE_ROW))
		return TRUE;
	
	if(outError != NULL) {
		NSString *errorDescription = [NSString stringWithFormat:@"Encountered an error while calling sqlite3_step() foe the '%@' query,: %d	%@", query, result, [self lastErrorMessage]];
		*outError = [NSError errorWithDomain:AJKSqliteDatabaseError code:result userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												errorDescription, NSLocalizedDescriptionKey,
														nil]];
	}

	return FALSE;
}


- (AJKResultSet *)executequery:(NSString *)query
{
	return [self executequery:query withArguments:nil error:NULL];
}


- (AJKResultSet *)executequery:(NSString *)query withArguments:(NSArray *)arguments error:(NSError **)outError
{
	AJKSqliteStatement *statement = [self statementForquery:query error:outError];
	if(!statement)
		return nil;
	
	
	// Retrieve the number of results and then bind each of the input arguments
	__block int numberOfResults = 0;
	[statement incrementUseCount];
	sqlite3_stmt *statementHandle = statement.statementHandle;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		numberOfResults = sqlite3_bind_parameter_count(statementHandle);
	});
	
	int resultIndex = 0;
	for(id argumentForColumn in arguments) {
		resultIndex++;
		[self bindObject:argumentForColumn toColumn:resultIndex inStatement:statementHandle];
	}
	
	
	// Make sure that the number of arguments matches expectations
	if(resultIndex != numberOfResults) {
		if(outError != NULL) {
			NSString *errorDescription = [NSString stringWithFormat:@"Found an unexpected number of arguments for the '%@' query. %d arguments rather than the expected %d.", query, [arguments count], numberOfResults];
			*outError = [NSError errorWithDomain:AJKSqliteDatabaseError code:5 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													errorDescription, NSLocalizedDescriptionKey,
															nil]];
		}
		
		return FALSE;
	}
	
	AJKResultSet *resultSet = [AJKResultSet resultSetWithStatement:statement forQueryString:query inDatabase:self];
	[self addResultSet:resultSet];
	return resultSet;
}



- (BOOL)rollback {
	return [self executeUpdate:@"ROLLBACK TRANSACTION;" withArguments:nil error:NULL];
}

- (BOOL)commit {
	return [self executeUpdate:@"COMMIT TRANSACTION;" withArguments:nil error:NULL];
}

- (BOOL)beginTransaction {
	return [self executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION;" withArguments:nil error:NULL];
}

- (BOOL)beginDeferredTransaction {
	return [self executeUpdate:@"BEGIN DEFERRED TRANSACTION;" withArguments:nil error:NULL];
}


- (void)bindObject:(id)objectToBind toColumn:(int)columnIndex inStatement:(sqlite3_stmt *)statement
{
	// Someday check the return codes on these bindings
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		if ((!objectToBind) || ((NSNull *)objectToBind == [NSNull null]))
			sqlite3_bind_null(statement, columnIndex);
		else if ([objectToBind isKindOfClass:[NSData class]])
			sqlite3_bind_blob(statement, columnIndex, [objectToBind bytes], (int)[objectToBind length], SQLITE_STATIC);
		else if ([objectToBind isKindOfClass:[NSDate class]])
			sqlite3_bind_double(statement, columnIndex, [objectToBind timeIntervalSince1970]);
		else if ([objectToBind isKindOfClass:[NSNumber class]]) {
			if (strcmp([objectToBind objCType], @encode(BOOL)) == 0)
				sqlite3_bind_int(statement, columnIndex, ([objectToBind boolValue] ? 1 : 0));
			else if (strcmp([objectToBind objCType], @encode(int)) == 0)
				sqlite3_bind_int64(statement, columnIndex, [objectToBind longValue]);
			else if (strcmp([objectToBind objCType], @encode(long)) == 0)
				sqlite3_bind_int64(statement, columnIndex, [objectToBind longValue]);
			else if (strcmp([objectToBind objCType], @encode(long long)) == 0)
				sqlite3_bind_int64(statement, columnIndex, [objectToBind longLongValue]);
			else if (strcmp([objectToBind objCType], @encode(float)) == 0)
				sqlite3_bind_double(statement, columnIndex, [objectToBind floatValue]);
			else if (strcmp([objectToBind objCType], @encode(double)) == 0)
				sqlite3_bind_double(statement, columnIndex, [objectToBind doubleValue]);
			else
				sqlite3_bind_text(statement, columnIndex, [[objectToBind description] UTF8String], -1, SQLITE_STATIC);
		} else
			sqlite3_bind_text(statement, columnIndex, [[objectToBind description] UTF8String], -1, SQLITE_STATIC);
	});
}




#pragma mark -
#pragma mark Manage statements

- (AJKSqliteStatement *)statementForquery:(NSString *)query error:(NSError **)outError {
	// Look for an existing statement matching the query
	__block AJKSqliteStatement *statement = nil;
	@synchronized(self) {
		statement = (AJKSqliteStatement *)[cachedStatements_ objectForKey:query];
	}
	
	if([statement isKindOfClass:[AJKSqliteStatement class]])
		return statement;
	else
		statement = nil;
	
	// Otherwise ask sqlite for a handle for the
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		size_t numberOfAttemptsToTry = [self numberOfAttemptsToTry];
		size_t attempts = 0;
		
		int result = 0;
		sqlite3_stmt *statementHandle = nil;
		
		do {
			result = sqlite3_prepare_v2(database, [query UTF8String], -1, &statementHandle, 0);
			
			if((result == SQLITE_LOCKED) || (result == SQLITE_BUSY)) {
				usleep(20);
				attempts += 1;
			} else {
				break;
			}
		} while (attempts < numberOfAttemptsToTry);
		
		if(result == SQLITE_OK) {
			// AJKSqliteStatement will call sqlite3_finalize() with the statement handle when it's dealloced
			statement = [[AJKSqliteStatement alloc] initForquery:query withHandle:statementHandle];
			[statement incrementUseCount];
			
			@synchronized(self) {
				[cachedStatements_ setObject:statement forKey:query];
			}
		} else {
			// Clear up the statement handle if necessary
			if(statementHandle != NULL) {
				sqlite3_finalize(statementHandle);
				statementHandle = NULL;
			}
			
			if(outError != NULL) {
				NSString *errorDescription = [NSString stringWithFormat:@"Couldn't create sql statement from the '%@' query. found an error:(%d) %@", query, [self lastErrorCode], [self lastErrorMessage]];
				*outError = [NSError errorWithDomain:AJKSqliteDatabaseError code:result userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
														errorDescription, NSLocalizedDescriptionKey,
																nil]];
			}
		}
	});
	
	return statement;
}


- (void)decrementUsageOfStatement:(AJKSqliteStatement *)statement
{
	@synchronized(self) {
		if([[cachedStatements_ allValues] containsObject:statement]) {
			[statement decrementUseCount];
			
			// If no other result sets reference this statement then remove it from the 
			// For now just leave it to the programer to call - (void)removeUnusedCachedStatements if they think its ytnecessary
			//		if([statement useCount] <= 0)
			//			[cachedStatements_ setObject:nil forKey:query];
		}
	}
}


- (void)removeUnusedCachedStatements
{
	@synchronized(self) {
		[[cachedStatements_ copy]  enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			AJKSqliteStatement *statement = (AJKSqliteStatement *)obj;
			if([statement useCount] <= 0)
				[cachedStatements_ removeObjectForKey:key];
		}];
	}
}



#pragma mark -
#pragma mark Manage result sets

- (void)addResultSet:(AJKResultSet *)resultSet
{
	if(!resultSet)
		return;
	
	@synchronized(self) {
		[activeResultsSets_ setObject:resultSet forKey:[resultSet query]];
	}
}


- (void)finishedUsingResultSet:(AJKResultSet *)resultSet
{
	if(!resultSet)
		return;
		
	@synchronized(self) {
		NSString *query = [resultSet query];
		if(query)
			[activeResultsSets_ removeObjectForKey:query];
	}
}



#pragma mark -
#pragma mark querying the status of the database


- (int64_t)identifierOfLastInsert {
	__block int64_t identifierOfLastInsert = 0;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		identifierOfLastInsert = sqlite3_last_insert_rowid(database);
	});
	
	return identifierOfLastInsert;
}


- (int)numberOfChanges {
	__block int numberOfChanges = 0;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		numberOfChanges = sqlite3_changes(database);
	});
	
	return numberOfChanges;
}


- (BOOL)hasEncounteredError {
	int lastErrorCode = [self lastErrorCode];
	return (lastErrorCode > SQLITE_OK && lastErrorCode < SQLITE_ROW);
}


- (int)lastErrorCode {
	__block int error = 0;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		error = sqlite3_errcode(database);
	});

	return error;
}


- (NSString *)lastErrorMessage {
	__block NSString *errorMessage = nil;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		errorMessage = [NSString stringWithUTF8String:sqlite3_errmsg(database)];
	});
	
	return errorMessage;
}


/*
#pragma mark -
#pragma mark Help methods


- (BOOL)validateSQL:(NSString *)sqlquery error:(NSError **)outError
{
	int numberOfAttemptsToTry = [self numberOfAttemptsToTry];
	__block int result = 0;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		int numberOfAttempts = 0;
		sqlite3_stmt *statementHandle = NULL;
		
		do {
			result = sqlite3_prepare_v2(database, [sqlquery UTF8String], -1, &statementHandle, 0);
			
			if(result == SQLITE_BUSY || result == SQLITE_LOCKED) {
				usleep(20);
			} else {
				break;
			}
		} while(numberOfAttempts++ <= numberOfAttemptsToTry);
		
		sqlite3_finalize(statementHandle);
	});
	
	
	if(result == SQLITE_OK)
		return TRUE;
	else if(result == SQLITE_BUSY || result == SQLITE_LOCKED)
		NSLog(@"Couldn't validate the '%@' query because the '%@' database was busy", sqlquery, [[self databaseURL] path]);
	
	if(outError != NULL) {
		NSDictionary *errorDictionary = [NSDictionary dictionaryWithObject:[self lastErrorMessage] forKey:NSLocalizedDescriptionKey];
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:[self lastErrorCode] userInfo:errorDictionary];
	}
	
	return FALSE;
}
*/


@end