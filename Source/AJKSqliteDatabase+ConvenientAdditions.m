#import "AJKSqliteDatabase+ConvenientAdditions.h"
#import "AJKResultSet.h"


@implementation AJKSqliteDatabase (AJKConvenientAdditions)


- (NSInteger)largestIntegerForColumn:(NSString *)columnName inTable:(NSString *)tableName
{
	NSError *error = nil;
	NSString *query = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@", columnName, tableName];
	AJKResultSet *results = [self executeQuery:query withArguments:nil error:&error];
		
	NSInteger integerResult = 0;
	if([results nextRow]) {
			// Currently just assuming that the result is actually an integer
			NSString *maxColumnName = [NSString stringWithFormat:@"MAX(%@)", columnName];
			int columnIndex = [results indexOfColumn:maxColumnName caseSensitive:TRUE];
			integerResult = [results int64ForColumnAtIndex:columnIndex];
	} else if(error)
		NSLog(@"Couldn't retrieve the maximum integer value for the '%@' column: %@", columnName, error);
	
	return integerResult;
}


- (double)largestDoubleForColumn:(NSString *)columnName inTable:(NSString *)tableName
{
	NSError *error = nil;
	NSString *query = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@", columnName, tableName];
	AJKResultSet *results = [self executeQuery:query withArguments:nil error:&error];
	
	double doubleResult = 0.0;
	if([results nextRow]) {
		// Currently just assuming that the result is actually an integer
		NSString *maxColumnName = [NSString stringWithFormat:@"MAX(%@)", columnName];
		int columnIndex = [results indexOfColumn:maxColumnName caseSensitive:TRUE];
		doubleResult = [results doubleForColumnAtIndex:columnIndex];
	} else if(error)
		NSLog(@"Couldn't retrieve the maximum double value for the '%@' column in the '%@' table: %@", columnName, tableName, error);
	
	return doubleResult;
}


@end