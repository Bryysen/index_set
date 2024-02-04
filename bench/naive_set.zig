pub fn NaiveIndexSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const Allocator = @import("std").mem.Allocator;
        const math = @import("std").math;

        const WORD_BITLEN: usize = 64;

        alloc: Allocator,
        store: []?T,
        len: usize,

        fn upsize(self: *Self) !void {
            const new_cap = math.ceilPowerOfTwo(usize, self.store.len + 2) catch return Allocator.Error.OutOfMemory;
            var new_store = try self.alloc.alloc(?T, new_cap);
            @memcpy(new_store[0..self.store.len], self.store);
            @memset(new_store[self.store.len..], null);

            self.alloc.free(self.store);
            self.store = new_store;
        }

        fn first_empty(self: *const Self, set_full: bool) ?usize {
            for (self.store, 0..) |item, idx| if (item == null) return idx;
            _ = set_full;
            return null;
        }

        fn last_full(self: *const Self, set_empty: bool) ?usize {
            var i: usize = self.store.len - 1;
            _ = set_empty;
            while (true) : (i -= 1) {
                if (self.store[i] != null) return i;
                if (i == 0) return null;
            }
        }

        /// Safety: Caller must ensure`idx` < the maps' capacity.
        fn set_index_empty(self: *Self, idx: usize) void {
            self.store[idx] = null;
        }

        /// Returns true if the slot at `idx` is full.
        /// Safety: Caller must ensure`idx` < the maps' capacity.
        pub fn index_full(self: *const Self, idx: usize) bool {
            if (self.store[idx] != null) return true else return false;
        }

        pub fn init(alloc: Allocator, with_capacity: usize) !Self {
            const store = try alloc.alloc(?T, with_capacity);
            @memset(store, null);
            return Self{ .alloc = alloc, .store = store, .len = 0 };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.store);
        }

        /// Inserts a value into the first empty slot and returns the index
        pub fn insert(self: *Self, val: T) !usize {
            const idx = if (self.first_empty(true)) |idx| idx else blk: {
                try self.upsize();
                break :blk self.first_empty(true).?;
            };

            self.store[idx] = val;
            self.len += 1;

            return idx;
        }

        /// Removes and returns the element and index of the element with the highest index
        pub fn pop(self: *Self) ?struct { T, usize } {
            if (self.store.len == 0) return null;
            const ret = if (self.last_full(true)) |idx| .{ self.store[idx].?, idx } else return null;
            self.set_index_empty(ret[1]);
            self.len -= 1;

            return ret;
        }

        /// Removes and returns the element at the given index
        /// Safety: Caller must ensure`idx` < the maps' capacity.
        pub fn pop_at(self: *Self, idx: usize) ?T {
            if (self.index_full(idx)) {
                const ret = self.store[idx].?;
                self.set_index_empty(idx);
                self.len -= 1;

                return ret;
            } else {
                return null;
            }
        }
    };
}

test "naive indexmap init" {
    var map = try NaiveIndexSet(u8).init(test_alloc, 12);
    defer map.deinit();

    try assert(map.store.len == 12 and map.len == 0);

    var map2 = try NaiveIndexSet(u8).init(test_alloc, 64);
    defer map2.deinit();

    try assert(map2.store.len == 64 and map2.len == 0);

    var map3 = try NaiveIndexSet(u8).init(test_alloc, 65);
    defer map3.deinit();

    try assert(map3.store.len == 65 and map3.len == 0);
}

test "naive indexmap find first empty slot" {
    var map = try NaiveIndexSet(u8).init(test_alloc, 65);
    defer map.deinit();

    var i: u6 = 0;
    while (true) {
        try assert(map.first_empty(false).? == i);
        map.store[i] = i;

        if (i == 63) break;
        i += 1;
    }

    try assert(map.first_empty(false).? == 64);

    map.store[64] = 64;
    try assert(map.first_empty(false) == null);
}

test "naive indexmap find last full slot" {
    var map = try NaiveIndexSet(u8).init(test_alloc, 65);
    defer map.deinit();

    try assert(map.last_full(false) == null);

    var i: u6 = 0;
    while (true) {
        if (i == 63) break;

        map.store[i] = i;
        try assert(map.last_full(false).? == i);

        i += 1;
    }

    map.store[64] = 64;
    try assert(map.last_full(false).? == 64);
}

test "naive indexmap index full" {
    var map = try NaiveIndexSet(u8).init(test_alloc, 65);
    defer map.deinit();

    map.store[0] = 0;
    map.store[64] = 1;

    try assert(map.index_full(0) == true);
    try assert(map.index_full(64) == true);
    for (1..64) |i| {
        try assert(map.index_full(i) == false);
    }
}

test "naive indexmap upsize" {
    var map = try NaiveIndexSet(u8).init(test_alloc, 32);
    defer map.deinit();

    try map.upsize();
    try assert(map.store.len == 64);

    try map.upsize();
    try assert(map.store.len == 128);
}

test "naive indexmap insert" {
    var map = try NaiveIndexSet(usize).init(test_alloc, 63);
    defer map.deinit();

    for (0..63) |i| {
        try assert(map.len == i);
        const idx = try map.insert(i);
        try assert(idx == i);
        try assert(map.store[i] == i);
    }

    try assert(try map.insert(420) == 63);
    try assert(map.store.len == 128);
    try assert(map.len == 64);
    try assert(map.store[63] == 420);
}

test "naive indexmap pop" {
    var map = try NaiveIndexSet(usize).init(test_alloc, 65);
    defer map.deinit();

    for (0..65) |i| _ = try map.insert(i);

    const computed = map.pop().?;
    try assert(computed[0] == 64 and computed[1] == 64);
    try assert(map.len == 64 and map.store.len == 65);
    try assert(map.first_empty(false).? == 64);

    try assert(map.pop_at(0).? == 0);
    try assert(map.len == 63);
    try assert(map.first_empty(false).? == 0);

    try assert(try map.insert(420) == 0);
    try assert(map.len == 64 and map.first_empty(false).? == 64);

    try assert(map.pop_at(64) == null);
    try assert(map.len == 64 and map.first_empty(false).? == 64);

    try assert(map.pop_at(63).? == 63);
    try assert(map.len == 63 and map.first_empty(false).? == 63);
}

test "naive indexmap zero-sized" {
    var map = try NaiveIndexSet(usize).init(test_alloc, 0);
    defer map.deinit();

    try assert(map.pop() == null);
    try assert(map.first_empty(false) == null);
    try assert(map.store.len == 0 and map.len == 0);

    var map2 = try NaiveIndexSet(usize).init(test_alloc, 0);
    defer map2.deinit();

    try assert(try map2.insert(420) == 0);
    try assert(map2.store.len == 2 and map2.len == 1);
    try assert(map2.first_empty(false).? == 1);
    try assert(try map2.insert(69) == 1);
    try assert(map2.first_empty(false) == null);
}
