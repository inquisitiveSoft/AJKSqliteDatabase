

// Note that this doesn't make it impossible to walk into deadlocks
// it's just a convenience for the simple case
void dispatch_sync_avoiding_deadlocks(dispatch_queue_t queue, dispatch_block_t block);