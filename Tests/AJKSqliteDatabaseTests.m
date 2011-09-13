#import "AJKSqliteDatabaseTests.h"
#import "AJKSqliteDatabase.h"
#import "AJKResultSet.h"


@interface AJKSqliteDatabaseTests () {
	AJKSqliteDatabase *database;
	NSURL *databaseURL;
}

@end



@implementation AJKSqliteDatabaseTests



- (void)setUpClass {
	// Run at start of all tests in the class
}

- (void)tearDownClass {
	// Run at end of all tests in the class
}


- (void)setUp {
	// Run before each test method
}

- (void)tearDown {
	// Run after each test method
}


- (void)testCreateTemporaryDatabase {
	databaseURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"Test Database.sqlite"];
	GHTestLog(@"%@", [databaseURL path]);
	
	database = [[AJKSqliteDatabase alloc] initWithURL:databaseURL];
	GHTestLog(@"Successfully created database: %@", database);
	
	database.shouldLog = TRUE;
}


- (void)testBadUpdate {
	NSError *error = nil;
	GHAssertFalse([database executeUpdate:@"blah blah blah" withArguments:nil error:&error], @"This update should fail");
   
	GHTestLog(@"%@", error);
	GHAssertTrue([database hasEncounteredError], @"%@", error);
}


- (void)testCreateTable {
	NSError *error = nil;
	BOOL success = [database executeUpdate:@"create table trees (name text, description text, awesomeness integer, height double, age double)" withArguments:nil error:&error];
	if(!success) {
		GHFail(@"Couldn't create table: %@", error);
	}
}

- (void)testRecreateTableWithIdenticalName {
	NSError *error = nil;
	BOOL success = [database executeUpdate:@"create table trees (name text, seed text)" withArguments:nil error:&error];
	GHAssertFalse(success, @"Shouldn't be able to create table: %@", error);
	GHTestLog(@"%@", error);
}


- (void)testBasicInsertingAndSelecting {
	[database beginTransaction];
	NSError *error = nil;
	
	NSString *inputName = @"Oak";
	NSString *inputDescription = @"There's something quintessentially British about Oak trees. In the Welsh language it's called Y Derwen";
	
	NSArray *inputArguments = [NSArray arrayWithObjects:	inputName, inputDescription,
																			[NSNumber numberWithInt:12],
																			[NSNumber numberWithFloat:35.6],
																			[NSDate date],
																					nil];
	
	GHTestLog(@"Input: %@\n\n", inputArguments);
	BOOL result = [database executeUpdate:@"insert into trees (name, description, awesomeness, height, age) values (?, ?, ?, ?, ?)" withArguments:inputArguments error:&error];
	GHAssertTrue(result, @"Failed to insert a row into the trees table");
	
	error = nil;
	AJKResultSet *resultSet = [database executequery:@"select * from trees" withArguments:nil error:&error];
	GHAssertTrue((BOOL)resultSet, @"select * from trees, failed, %@", error);
	
	error = nil;
	NSArray *results = [resultSet resultsWithError:&error];
	GHAssertTrue([results count] == 1, @"select * from trees, should return one result rather than '%d', %@", [results count], error);
	GHTestLog(@"Output:\n%@\n\n", results);
	
	NSString *resultName = [resultSet stringForColumn:@"name"];
	GHAssertTrue([resultName isEqualToString:inputName], @"The value returned for the name column '%@' should be equal to '%@'", resultName, inputName);
	
	GHTestLog(@"name:				%@", resultName);
	GHTestLog(@"description:		%@", [resultSet objectForColumn:@"description"]);
	GHTestLog(@"awesomeness:		%ld", [resultSet integerForColumn:@"awesomeness"]);
	GHTestLog(@"height:				%@", [resultSet dateForColumn:@"height"]);
	GHTestLog(@"age:				%@", [resultSet dateForColumn:@"age"]);
}





- (void)testRemoveTemporaryDatabase {
	database = nil;
	
	NSError *error = nil;
	GHAssertTrue([[NSFileManager defaultManager] removeItemAtURL:databaseURL error:&error], @"Couldn't delete the temporary database file: %@", error);
}



@end