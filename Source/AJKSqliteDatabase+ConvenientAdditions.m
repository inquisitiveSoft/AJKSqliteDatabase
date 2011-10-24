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
			integerResult = [results integerForColumn:columnName];
	} else if(error)
		NSLog(@"Couldn't retrieve the maximum integer value for the '%@' column: %@", columnName, error);
	
	return integerResult;
}


- (double)doubleForColumn:(NSString *)columnName inTable:(NSString *)tableName
{
	NSError *error = nil;
	NSString *query = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@", columnName, tableName];
	AJKResultSet *results = [self executeQuery:query withArguments:nil error:&error];
	
	double doubleResult = 0;
	if([results nextRow]) {
		// Currently just assuming that the result is actually an integer
		doubleResult = [results doubleForColumn:columnName];
	} else if(error)
		NSLog(@"Couldn't retrieve the maximum double value for the '%@' column in the '%@' table: %@", columnName, tableName, error);
	
	return doubleResult;
}


@end