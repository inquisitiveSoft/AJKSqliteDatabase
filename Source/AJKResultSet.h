@class AJKSqliteDatabase, AJKSqliteStatement;

extern NSString *const AJKResultSetError;

@interface AJKResultSet : NSObject {
	
}

@property (copy, readonly) NSString *query;
@property (assign, readonly) AJKSqliteStatement *statement;
@property (weak, readonly) AJKSqliteDatabase *database;

@property (retain, readonly) NSArray *columnNames;


+ (id)resultSetWithStatement:(AJKSqliteStatement *)statement forQueryString:(NSString *)query inDatabase:(AJKSqliteDatabase *)database;
- (void)close;

- (void)reset;
- (BOOL)nextRow;

- (NSArray *)resultsWithError:(NSError **)outError;
- (NSDictionary *)allValuesForCurrentRowWithError:(NSError **)outError;	// Useful for logging

- (int)numberOfColumns;
- (int)indexOfColumn:(NSString *)columnName;
- (int)indexOfColumn:(NSString *)columnName caseSensitive:(BOOL)caseSensitive;
- (NSString *)columnNameAtIndex:(int)columnIndex;

- (BOOL)columnIsNull:(NSString *)columnName;
- (BOOL)columnAtIndexIsNull:(int)columnIndex;

// Accessing column attributes
- (BOOL)boolForColumn:(NSString *)columnName;
- (NSInteger)integerForColumn:(NSString *)columnName;
- (int32_t)int32ForColumn:(NSString *)columnName;
- (int64_t)int64ForColumn:(NSString *)columnName;
- (double)doubleForColumn:(NSString *)columnName;

// Retreving object values
- (NSString *)stringForColumn:(NSString *)columnName;
- (NSDate*)dateForColumn:(NSString *)columnName;
- (NSData *)dataForColumn:(NSString *)columnName;
- (id)objectForColumn:(NSString *)columnName;

// Accessing number attributes by column index
- (int32_t)int32ForColumnAtIndex:(int)columnIndex;
- (int64_t)int64ForColumnAtIndex:(int)columnIndex;
- (double)doubleForColumnAtIndex:(int)columnIndex;

// Accessing object attributes by column index
- (NSString *)stringForColumnAtIndex:(int)columnIndex;
- (NSData *)dataForColumnAtIndex:(int)columnIndex;
- (NSData *)dataForColumnAtIndex:(int)columnIndex shouldCopy:(BOOL)shouldCopy;
- (id)objectForColumnAtIndex:(int)columnIndex;


@end