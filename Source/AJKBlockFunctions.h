// Note that this doesn't make it impossible to walk into deadlocks, it just makes the simple case easier
void dispatch_sync_avoiding_deadlocks(dispatch_queue_t queue, dispatch_block_t block);