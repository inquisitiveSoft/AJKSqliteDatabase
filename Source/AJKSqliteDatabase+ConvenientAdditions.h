#import "AJKSqliteDatabase.h"


@interface AJKSqliteDatabase (AJKConvenientAdditions)

- (NSInteger)largestIntegerForColumn:(NSString *)columnName inTable:(NSString *)tableName;
- (double)largestDoubleForColumn:(NSString *)columnName inTable:(NSString *)tableName;


@end