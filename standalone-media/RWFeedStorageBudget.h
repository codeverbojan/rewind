// All temporary title feeds share this cap. The reserve includes SQLite's
// rollback journal and its headers, so a ratings import cannot use that room.
static const unsigned long long RWFeedDiskBudgetBytes=3ULL*1024*1024;
static const unsigned long long RWFeedStorageReserveBytes=2*RWFeedDiskBudgetBytes+128*1024;
