#import "AJKDispatchQueueFunctions.h"


void dispatch_sync_avoiding_deadlocks(dispatch_queue_t queue, dispatch_block_t block) {
	// Check if we're already running on the desired queue
	if(dispatch_get_current_queue() == queue) {
		// If so, just execute the block in place
		block();
	} else {
		// Otherwise, dispatch it as normal
		dispatch_sync(queue, block);
	}
}