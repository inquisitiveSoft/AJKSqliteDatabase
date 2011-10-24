#import "AJKResultSet.h"
#import "AJKSqliteDatabase.h"
#import "AJKSqliteStatement.h"

#import "sqlite3.h"
#import "AJKBlockFunctions.h"


NSString *const AJKResultSetError = @"AJKResultSetError";

@interface AJKResultSet () {
}

@property (readwrite, copy) NSString *query;
@property (readwrite, weak) AJKSqliteDatabase *database;
@property (readwrite, assign) AJKSqliteStatement *statement;
@property (retain, readwrite) NSArray *columnNames;
@property (retain, readwrite) NSDictionary *columnNamesForIndexes;

- (void)readColumnNames;
- (void)updateKeyValues;

@end


@implementation AJKResultSet
@synthesize database = database_, statement = statement_, query = query_, columnNames = columnNames_, columnNamesForIndexes = columnNamesForIndexes_;


+ (id)resultSetWithStatement:(AJKSqliteStatement *)statement forQueryString:(NSString *)query inDatabase:(AJKSqliteDatabase *)database
{
	AJKResultSet *resultSet = [[AJKResultSet alloc] init];
	resultSet.query = query;
	resultSet.statement = statement;
	resultSet.database = database;
	
	[resultSet readColumnNames];
	return resultSet;
}


- (void)readColumnNames
{
	int numberOfColumns = [self numberOfColumns];
	NSMutableDictionary *columnNamesForIndexes = [[NSMutableDictionary alloc] initWithCapacity:numberOfColumns];
	NSMutableArray *columnNames = [[NSMutableArray alloc] initWithCapacity:numberOfColumns];

	for(int columnIndex = 0; columnIndex < numberOfColumns; columnIndex++) {
		NSString *columnName = [self columnNameAtIndex:columnIndex];
		
		if(columnName) {
			[columnNames addObject:columnName];
			
			NSNumber *columnIndexValue = [NSNumber numberWithInt:columnIndex];
			[columnNamesForIndexes setObject:columnIndexValue forKey:columnName];
		}
	}
		
	// Assign immutable copies
	self.columnNames = [columnNames copy];
	self.columnNamesForIndexes = [columnNamesForIndexes copy];
}


- (void)updateKeyValues
{
	int columnCount = [self numberOfColumns];
	
	for(int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
		NSString *columnName = [self columnNameAtIndex:columnIndex];
		NSString *stringForColumn = [self stringForColumnAtIndex:columnIndex];
		
		if(columnName && stringForColumn)
			[self setValue:stringForColumn forKey:columnName];
	}
}


- (NSArray *)resultsWithError:(NSError **)outError
{
	[[self statement] reset];
	
	NSMutableArray *combinedResults = [[NSMutableArray alloc] init];
	while([self nextRow]) {
		// Read the values for each row in turn
		NSLog(@"objectForColumn:name: %@", [self objectForColumn:@"name"]);
		NSDictionary *rowValues = [self allValuesForCurrentRowWithError:outError];
		if(rowValues)
			[combinedResults addObject:rowValues];
		else
			return nil;
	}
	
	[[self statement] reset];
	
	return [combinedResults copy];
}


- (NSDictionary *)allValuesForCurrentRowWithError:(NSError **)outError
{
	NSDictionary *columnNamesForIndexes = [self columnNamesForIndexes];
	
	int numberOfColumns = (int)[columnNamesForIndexes count];
	if(numberOfColumns <= 0) {
		if(outError != NULL) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
								NSLocalizedString(@"This %@ set doesn't contain any columns", AJKResultSetError), NSLocalizedDescriptionKey,
														nil];
			
			*outError = [NSError errorWithDomain:AJKResultSetError code:0 userInfo:errorDictionary];
		}
		
		return nil;
	}
	
	
	NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:numberOfColumns];
	[columnNamesForIndexes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSString *columnName = (NSString *)key;
		if([columnName isKindOfClass:[NSString class]]) {
			id value = [self objectForColumn:columnName];
			[results setValue:value forKey:columnName];
		}
	}];
	
	return results;
}


- (void)reset
{
	[[self statement] reset];
}


- (BOOL)nextRow {
	int numberOfAttemptsToTry = [[self database] numberOfAttemptsToTry];
	__block int result = 0;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		int attempts = 0;
		
		do {
			result = sqlite3_step([[self statement] statementHandle]);
			
			if((result == SQLITE_LOCKED) || (result == SQLITE_BUSY)) {
				if(result == SQLITE_LOCKED) {
					result = sqlite3_reset([[self statement] statementHandle]);
					NSAssert1(result != SQLITE_LOCKED, @"sqlite3_reset() failed: %d", result);
				}
				
				usleep(20);
				attempts += 1;
			} else
				break;
		} while (attempts < numberOfAttemptsToTry);
	});
	
	
	if(result == SQLITE_ROW)
		return TRUE;
	
	[self close];
	return FALSE;
}


- (BOOL)hasAnotherRow {
	__block BOOL result = FALSE;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		result = sqlite3_errcode([[self database] database]) == SQLITE_ROW;
	});
	
	return result;
}


- (void)finalize {
	[self close];
	[super finalize];
}

- (void)dealloc {
	[self close];
}

- (void)close {
	[[self statement] reset];
	[[self database] decrementUsageOfStatement:[self statement]];
	self.statement = nil;
	
	[[self database] finishedUsingResultSet:self];
	self.database = nil;
}



#pragma mark -
#pragma mark -


- (int)numberOfColumns {
	__block int numberOfColumns = 0;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		numberOfColumns = sqlite3_column_count([[self statement] statementHandle]);
	});
	
	return numberOfColumns;
}


- (int)indexOfColumn:(NSString *)columnName
{
	@synchronized(self) {
		NSNumber *columnNumber = [[self columnNamesForIndexes] objectForKey:[columnName lowercaseString]];
		if(columnNumber)
			return [columnNumber intValue];
	}
	
	NSLog(@"Couldn't find a column named '%@'.", [columnName lowercaseString]);
	return -1;
}


- (NSString *)columnNameAtIndex:(int)columnIndex
{
	if((columnIndex >= 0) && (columnIndex < [self numberOfColumns])) {
		__block NSString *columnName = [[self columnNames] objectAtIndex:columnIndex];
		if(columnName)
			return columnName;
		
		dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
			columnName = [NSString stringWithUTF8String:sqlite3_column_name([[self statement] statementHandle], columnIndex)];
		});
		
		return columnName;
	}
	
	return nil;
}


- (BOOL)columnIsNull:(NSString *)columnName {
	return [self columnAtIndexIsNull:[self indexOfColumn:columnName]];
}


- (BOOL)columnAtIndexIsNull:(int)columnIndex {
	__block BOOL columnIsNull = FALSE;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		columnIsNull = (sqlite3_column_type([[self statement] statementHandle], columnIndex) == SQLITE_NULL);
	});
	
	return columnIsNull;
}


#pragma mark -
#pragma mark Accessing column attributes


- (BOOL)boolForColumn:(NSString *)columnName {
	return ([self int32ForColumn:columnName] > 0);
}


- (NSInteger)integerForColumn:(NSString *)columnName {
	if(NSIntegerMax > LONG_MAX)
		return [self int64ForColumnAtIndex:[self indexOfColumn:columnName]];

	return [self int32ForColumnAtIndex:[self indexOfColumn:columnName]];
}


- (int32_t)int32ForColumn:(NSString *)columnName {
	return [self int32ForColumnAtIndex:[self indexOfColumn:columnName]];
}

- (int64_t)int64ForColumn:(NSString *)columnName {
	return [self int64ForColumnAtIndex:[self indexOfColumn:columnName]];
}

- (double)doubleForColumn:(NSString *)columnName {
	return [self doubleForColumnAtIndex:[self indexOfColumn:columnName]];
}


#pragma mark -
#pragma mark Accessing object values

- (NSString *)stringForColumn:(NSString *)columnName {
	return [self stringForColumnAtIndex:[self indexOfColumn:columnName]];
}


- (NSDate *)dateForColumn:(NSString *)columnName {
	int columnIndex = [self indexOfColumn:columnName];
	if((columnIndex < 0) || [self columnAtIndexIsNull:columnIndex])
		return nil;
	
	__block NSDate *date = nil;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		date = [NSDate dateWithTimeIntervalSince1970:[self doubleForColumnAtIndex:columnIndex]];
   });
	
	return date;
}

- (NSData *)dataForColumn:(NSString *)columnName {
	return [self dataForColumnAtIndex:[self indexOfColumn:columnName]];
}


- (id)objectForColumn:(NSString *)columnName {
	return [self objectForColumnAtIndex:[self indexOfColumn:columnName]];
}



#pragma mark -
#pragma mark Underlying methods for accessing column attributes by column index


- (int32_t)int32ForColumnAtIndex:(int)columnIndex {
	__block int32_t result = 0;
	if(columnIndex < 0)
		return result;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		result = (int32_t)sqlite3_column_int([[self statement] statementHandle], (int)columnIndex);
	});
	
	return result;
}


- (int64_t)int64ForColumnAtIndex:(int)columnIndex {
	__block int64_t result = 0;
	if(columnIndex < 0)
		return result;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		result = (int64_t)sqlite3_column_int64([[self statement] statementHandle], (int)columnIndex);;
	});
	
	return result;
}


- (double)doubleForColumnAtIndex:(int)columnIndex {
	__block CGFloat result = 0.0;
	if(columnIndex < 0)
		return result;
	
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		result = sqlite3_column_double([[self statement] statementHandle], (int)columnIndex);
	});
	
	return result;
}


- (NSString *)stringForColumnAtIndex:(int)columnIndex
{
	if((columnIndex < 0) || [self columnAtIndexIsNull:columnIndex])
		return nil;

	__block NSString *result = nil;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		const char *cString = (const char *)sqlite3_column_text([[self statement] statementHandle], columnIndex);
		
		if(cString)
			result = [NSString stringWithUTF8String:cString];
	});
	
	return result;
}


- (NSData *)dataForColumnAtIndex:(int)columnIndex {
	if((columnIndex < 0) || [self columnAtIndexIsNull:columnIndex])
		return nil;
	
	__block NSMutableData *data = nil;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		int dataSize = sqlite3_column_bytes([[self statement] statementHandle], columnIndex);
		data = [NSMutableData dataWithLength:dataSize];
		memcpy([data mutableBytes], sqlite3_column_blob([[self statement] statementHandle], columnIndex), dataSize);
	});
	
	return data;
}


- (NSData *)dataForColumnAtIndex:(int)columnIndex shouldCopy:(BOOL)shouldCopy {
	if((columnIndex < 0) || [self columnAtIndexIsNull:columnIndex])
		return nil;
	
	__block NSData *data = nil;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		int dataSize = sqlite3_column_bytes([[self statement] statementHandle], columnIndex);
		data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob([[self statement] statementHandle], columnIndex) length:dataSize freeWhenDone:NO];
	});
	
	if(shouldCopy)
		return [data copy];
	
	return data;
}


- (id)objectForColumnAtIndex:(int)columnIndex {
	__block int columnType = 0;
	dispatch_sync_avoiding_deadlocks([AJKSqliteDatabase queue], ^{
		columnType = sqlite3_column_type([[self statement] statementHandle], columnIndex);
	});
	
	
	if(columnType == SQLITE_INTEGER)
		return [NSNumber numberWithLongLong:[self int64ForColumnAtIndex:columnIndex]] ? : [NSNull null];
	else if (columnType == SQLITE_FLOAT)
		return [NSNumber numberWithDouble:[self doubleForColumnAtIndex:columnIndex]] ? : [NSNull null];
	else if (columnType == SQLITE_BLOB) {
		NSData *data = [self dataForColumnAtIndex:columnIndex shouldCopy:FALSE];
		
		@try {
			id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			if(object)
				return object ? : [NSNull null];
		}
		
		@catch(NSException *exception) {
			// Worth a try
		}
		
		return [data copy] ? : [NSNull null];
	}
	
	// Otherwise default to a string for everything else
	return [self stringForColumnAtIndex:columnIndex];
}



@end