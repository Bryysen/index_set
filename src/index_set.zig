const math = @import("std").math;
const Allocator = @import("std").mem.Allocator;

const WORD_BITLEN: usize = @sizeOf(usize) * 8;

/// Forward iterator over an IndexSet
/// Safety: If the parent IndexSet re-allocates then the belonging iterator gets invalid
pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: [*]align(@sizeOf(usize))T,
        bitarray: [*]usize,
        idx: u32 = 0,
        cap: u32,

        pub fn next(self: *Self) ?(struct {*align(@sizeOf(usize))T, usize}) {
            while (self.idx < self.cap) {
                const q = math.divFloor(usize, self.idx, WORD_BITLEN) catch unreachable;
                const r = math.mod(usize, self.idx, WORD_BITLEN) catch unreachable;

                if (self.bitarray[q] & math.shl(usize, 1, r) == 0) {
                    const ret = .{&self.items[@intCast(self.idx)], @as(usize, self.idx)};
                    self.idx += 1;

                    return ret;
                }

                self.idx += 1;
            }

            return null;
        }
    };
}

// TODO: Test and make sure this datastructure works when `T` is packed
pub fn IndexSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const WORD_LEN: usize = @sizeOf(usize);

        alloc: Allocator,
        /// Backing storage, has length `Self.capacity`. Indices in that range are not guaranteed to
        /// be initialised!
        items: [*]align(WORD_LEN)T,
        /// Tracks which indices are initialised. The nth 0 bit indicates that the nth index is full
        bitarray: [*]usize,
        /// Capacity of the item-pointer
        capacity: usize,

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .items = undefined,
                .capacity = 0,
                .bitarray = undefined,
            };
        }

        pub fn initCapacity(alloc: Allocator, with_capacity: usize) !Self {
            var ret = Self {
                .alloc = alloc,
                .items = undefined,
                .capacity = with_capacity,
                .bitarray = undefined
            };

            const bit_cap = ret.bitarrayCap();

            const slice = try alloc.alloc(usize, bit_cap + ret.allocCap());

            @memset(slice[0..bit_cap], math.maxInt(usize));

            ret.bitarray = slice.ptr;
            ret.items = @ptrCast(slice[bit_cap..].ptr);

            return ret;
        }

        /// Loop through and count the number of active elements
        /// in the map. This is a linear-complexity operation.
        pub fn count(self: Self) usize {
            var i: usize = 0;
            var len: usize = 0;
            while (i < self.capacity) : (i += 1) {
                if (self.isFull(i))
                    len += 1;
            }

            return len;
        }

        /// Returns the capacity of the bitarray slice
        pub fn bitarrayCap(self: *const Self) usize {
            return math.divCeil(usize, self.capacity, WORD_BITLEN) catch unreachable;
        }

        /// Resize the dynamically-allocated array of the map
        /// Note: This function does not try to be clever; it will ALWAYS
        /// re-allocate to a new items-slice of length `new_capacity`.
        pub fn resize(self: *Self, new_capacity: usize) !void {
            const highest_idx = if (self.lastFull(false)) |idx|
                @min(idx + 1, new_capacity)
            else
                0;

            const old_bcap = math.divCeil(usize, self.capacity, WORD_BITLEN) catch unreachable;
            const new_bcap = math.divCeil(usize, new_capacity, WORD_BITLEN) catch unreachable;
            const alloc_cap =
                math.divCeil(usize, new_capacity * @sizeOf(T), WORD_LEN) catch unreachable;

            const min_bcap = @min(new_bcap, old_bcap);

            const slice = try self.alloc.alloc(usize, new_bcap + alloc_cap);
            var new_items: [*]align(@sizeOf(usize))T = @ptrCast(slice[new_bcap..].ptr);

            @memcpy(new_items[0..highest_idx], self.items[0..highest_idx]);
            @memcpy(slice[0..min_bcap], self.bitarray[0..min_bcap]);

            const r = math.mod(usize, new_capacity, WORD_BITLEN) catch unreachable;
            if (old_bcap < new_bcap)
                @memset(slice[old_bcap..new_bcap], math.maxInt(usize))
            else if (r != 0 and old_bcap == new_bcap)
                // This step is important because the bits representing
                // uninitialised memory should not be 0 as that would trip
                // other functions into thinking there are valid elements
                // in out-of-bounds indices
                slice[new_bcap - 1] |= math.shl(usize, 0xFFFF_FFFF_FFFF_FFFF, r);

            self.deinit();
            self.capacity = new_capacity;
            self.items = new_items;
            self.bitarray = slice.ptr;
        }

        /// Returns true if the index at `idx` is full (contains valid element).
        /// Safety: Caller must ensure `idx < [instance].capacity`
        pub fn isFull(self: *const Self, idx: usize) bool {
            const q = math.divFloor(usize, idx, WORD_BITLEN) catch unreachable;
            const r = math.mod(usize, idx, WORD_BITLEN) catch unreachable;

            return self.bitarray[q] & math.shl(usize, 1, r) == 0;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            @memset(self.bitarray[0..self.bitarrayCap()], math.maxInt(usize));
        }

        pub fn deinit(self: Self) void {
            const bit_cap = self.bitarrayCap();

            self.alloc.free(self.bitarray[0..self.allocCap() + bit_cap]);
        }

        /// Inserts a value into the first empty index and returns the index
        pub fn insert(self: *Self, val: T) !usize {
            const idx = if (self.firstEmpty(true)) |idx|
                idx
            else b: {
                const ret = self.capacity;
                try self.upsize();

                self.setIndexFull(ret);
                break :b ret;
            };

            self.items[idx] = val;

            return idx;
        }

        /// Places the given value at the next index of the last full index
        pub fn append(self: *Self, val: T) !usize {
            const idx = if (self.lastFull(false)) |idx| idx + 1 else 0;
            if (idx == self.capacity) try self.upsize();

            self.items[idx] = val;
            self.setIndexFull(idx);

            return idx;
        }

        /// Removes and returns the element and index of the element with the highest index
        pub fn pop(self: *Self) ?struct { T, usize } {
            const ret = if (self.lastFull(true)) |idx|
                .{ self.items[idx], idx }
            else
                return null;

            return ret;
        }

        /// Set value `val` at index `idx`. Clobbers any existing value at `idx`
        /// Safety: Caller must ensure `idx < [instance].capacity`
        pub fn put(self: *Self, idx: usize, val: T) void {
            self.items[idx] = val;
            if (!self.isFull(idx))
                self.setIndexFull(idx);
        }

        /// Removes and returns the element at the given index
        /// Safety: Caller must ensure `idx < [instance].capacity`
        pub fn popAt(self: *Self, idx: usize) ?T {
            const ret = if (self.isFull(idx)) self.items[idx] else return null;
            self.setIndexEmpty(idx);

            return ret;
        }

        pub fn clone(self: Self) !Self{
            const bit_cap = self.bitarrayCap();

            const slice = try self.alloc.alloc(usize, bit_cap + self.allocCap());
            // TODO: We can be more efficient here and only memcpy up to the
            // largest element, as anything beyond that is garbage data
            @memcpy(slice, self.bitarray[0..self.allocCap() + bit_cap]);

            return Self {
                .alloc = self.alloc,
                .items = @ptrCast(slice[bit_cap..].ptr),
                .capacity = self.capacity,
                .bitarray = slice[0..bit_cap].ptr,
            };
        }

        pub fn iterator(self: *Self) Iterator(T) {
            return Iterator(T) {
                .items = self.items,
                .bitarray = self.bitarray,
                .cap = @intCast(self.capacity),
            };
        }

        fn firstEmpty(self: *const Self, set_full: bool) ?usize {
            const bcap = self.bitarrayCap();

            var q: usize = 0;
            while (true) {
                if (q == bcap) return null;

                // Use this to find the first 1-bit
                const trail_zeros = @ctz(self.bitarray[q]);
                if (trail_zeros < WORD_BITLEN) {
                    const ret = trail_zeros + q * WORD_BITLEN;
                    if (ret >= self.capacity) return null;

                    const bit = @as(usize, @intFromBool(set_full));
                    self.bitarray[q] &= ~math.shl(usize, bit, trail_zeros);

                    return ret;
                }

                q += 1;
            }
        }

        fn lastFull(self: Self, set_empty: bool) ?usize {
            var q = self.bitarrayCap();

            while (true) {
                if (q == 0) return null;
                q -= 1;

                // Use this to find the last 0-bit
                const lead_ones = @clz(~self.bitarray[q]);
                if (lead_ones < WORD_BITLEN) {
                    const last_zero = WORD_BITLEN - lead_ones - 1;
                    const ret = last_zero + q * WORD_BITLEN;

                    const bit = @as(usize, @intFromBool(set_empty));
                    self.bitarray[q] |= math.shl(usize, bit, last_zero);

                    return ret;
                }
            }
        }

        /// Safety: Caller must ensure `idx < [instance].capacity`
        fn setIndexEmpty(self: *Self, idx: usize) void {
            const q = math.divFloor(usize, idx, WORD_BITLEN) catch unreachable;
            const r = math.mod(usize, idx, WORD_BITLEN) catch unreachable;

            self.bitarray[q] |= math.shl(usize, 1, r);
        }

        /// Safety: Caller must ensure `idx < [instance].capacity`
        fn setIndexFull(self: *Self, idx: usize) void {
            const q = math.divFloor(usize, idx, WORD_BITLEN) catch unreachable;
            const r = math.mod(usize, idx, WORD_BITLEN) catch unreachable;

            self.bitarray[q] &= ~math.shl(usize, 1, r);
        }

        fn upsize(self: *Self) !void {
            const new_cap = math.ceilPowerOfTwo(usize, self.capacity + 2)
                catch return Allocator.Error.OutOfMemory;

            try self.resize(math.clamp(new_cap, 0, self.capacity + 1024));
        }

        fn allocCap(self: Self) usize {
            return math.divCeil(usize, self.capacity * @sizeOf(T), WORD_LEN) catch unreachable;
        }
    };
}

// --- Unit tests --- //
const assert = @import("std").testing.expect;
const test_alloc = @import("std").testing.allocator;
const print = @import("std").debug.print;

test "IndexSet init" {
    var map = try IndexSet(u8).initCapacity(test_alloc, 12);
    defer map.deinit();

    try assert(map.capacity == 12 and map.count() == 0);

    var map2 = try IndexSet(u8).initCapacity(test_alloc, 64);
    defer map2.deinit();

    try assert(map2.capacity == 64 and map2.count() == 0);

    var map3 = try IndexSet(u8).initCapacity(test_alloc, 65);
    defer map3.deinit();

    try assert(map3.capacity == 65 and map3.count() == 0);
}

test "IndexSet find first empty index" {
    var map = try IndexSet(u8).initCapacity(test_alloc, 65);
    defer map.deinit();

    var i: u6 = 0;
    while (true) {
        // print("Computed: {} | Expected: {} | Bitmap: {X}\n", .{ map.firstEmpty().?, i, map.bitarray[0] });
        try assert(map.firstEmpty(false).? == i);
        map.bitarray[0] &= ~(@as(usize, 1) << i);

        if (i == 63) break;
        i += 1;
    }

    try assert(map.firstEmpty(false).? == 64);

    map.bitarray[1] &= ~@as(usize, 1);
    try assert(map.firstEmpty(false) == null);
}

test "IndexSet find last full index" {
    var map = try IndexSet(u8).initCapacity(test_alloc, 65);
    defer map.deinit();

    try assert(map.lastFull(false) == null);

    var i: u6 = 0;
    while (true) {
        if (i == 63) break;

        map.bitarray[0] &= ~(@as(usize, 1) << i);
        //print("Bitmap: {X}\n", .{map.bitarray[0]});
        try assert(map.lastFull(false).? == i);

        i += 1;
    }

    map.bitarray[1] &= ~(@as(usize, 1));
    try assert(map.lastFull(false).? == 64);
}

test "IndexSet index full" {
    var map = try IndexSet(u8).initCapacity(test_alloc, 65);
    defer map.deinit();

    map.bitarray[0] &= ~@as(usize, 1);
    map.bitarray[1] &= ~@as(usize, 1);

    try assert(map.isFull(0) == true);
    try assert(map.isFull(64) == true);
    for (1..64) |i| {
        try assert(map.isFull(i) == false);
    }
}

test "IndexSet resize" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 65);
    defer map.deinit();

    for (0..65) |i| {
        _ = map.insert(i) catch unreachable;
    }
    try map.resize(64);
    for (map.items, 0..64) |item, i|
        try assert (item == i);

    try map.resize(128);
    for (map.items, 0..64) |item, i|
        try assert (item == i);

    try map.resize(0);
    try map.resize(1024);
}

test "IndexSet upsize" {
    var map = try IndexSet(u8).initCapacity(test_alloc, 32);
    defer map.deinit();

    try map.upsize();
    try assert(map.capacity == 64 and map.bitarrayCap() == 1);

    try map.upsize();
    try assert(map.capacity == 128 and map.bitarrayCap() == 2);

    try map.resize(1024);

    try map.upsize();
    try assert(map.capacity == 2048 and map.bitarrayCap() == 32);

    try map.upsize();
    try assert(map.capacity == 3072 and map.bitarrayCap() == 48);
}

test "IndexSet insert" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 63);
    defer map.deinit();

    for (0..63) |i| {
        try assert(map.count() == i);
        const idx = try map.insert(i);
        //print("Computed: {} | Expected: {} | Bitmap: {X}\n", .{ idx, i, map.bitarray[0] });
        try assert(idx == i);
        try assert(map.items[i] == i);
    }

    try assert(try map.insert(420) == 63);
    //print("Capacity {} | Bitmap capacity: {}\n", .{ map.capacity, map.bitarrayCap() });
    try assert(map.capacity == 128 and map.bitarrayCap() == 2);
    try assert(map.count() == 64);
    try assert(map.items[63] == 420);
}

test "IndexSet pop" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 65);
    defer map.deinit();

    for (0..65) |i| _ = try map.insert(i);

    const computed = map.pop().?;
    try assert(computed[0] == 64 and computed[1] == 64);
    try assert(map.count() == 64 and map.capacity == 65);

    try assert(map.popAt(0).? == 0);
    try assert(map.count() == 63 and map.firstEmpty(false).? == 0);

    try assert(try map.insert(420) == 0);
    //print("Len {} | First empty: {}\n", .{ map.count(), map.firstEmpty(false).? });
    try assert(map.count() == 64 and map.firstEmpty(false).? == 64);

    try assert(map.popAt(64) == null);
    try assert(map.count() == 64 and map.firstEmpty(false).? == 64);

    try assert(map.popAt(63).? == 63);
    try assert(map.count() == 63 and map.firstEmpty(false).? == 63);

    var map_empty = try IndexSet(usize).initCapacity(test_alloc, 0);
    try assert(map_empty.pop() == null);
}

test "IndexSet zero-sized" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 0);
    defer map.deinit();

    try assert(map.pop() == null);
    try assert(map.firstEmpty(false) == null);
    try assert(map.bitarrayCap() == 0 and map.capacity == 0 and map.count() == 0);

    var map2 = try IndexSet(usize).initCapacity(test_alloc, 0);
    defer map2.deinit();

    try assert(try map2.insert(420) == 0);
    try assert(map2.bitarrayCap() == 1 and map2.capacity == 2 and map2.count() == 1);
    try assert(map2.firstEmpty(false).? == 1);
    try assert(try map2.insert(69) == 1);
    try assert(map2.firstEmpty(false) == null);
}

test "IndexSet clone" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 65);
    defer map.deinit();

    for (0..65) |i| _ = try map.insert(i);

    const mapc = try map.clone();
    defer mapc.deinit();

    for (0..65) |i| {
        map.items[i] = 0;
        try assert(mapc.items[i] == i);
    }

    try assert(mapc.count() == map.count());
    try assert(mapc.capacity == map.capacity);
    try assert(mapc.bitarrayCap() == map.bitarrayCap());
}

test "IndexSet append" {
    var map = try IndexSet(usize).init(test_alloc);
    defer map.deinit();

    try assert(try map.append(42) == 0);
    try assert(map.count() == 1);
    try assert(map.bitarrayCap() == 1);
    try assert(map.items[0] == 42);

    try assert(try map.append(13) == 1);
    try assert(map.count() == 2);
    try assert(map.bitarrayCap() == 1);
    try assert(map.items[1] == 13);

    try assert(try map.append(11) == 2);
    try assert(map.count() == 3);
    try assert(map.bitarrayCap() == 1);
    try assert(map.items[2] == 11);

    _ = map.popAt(1).?;

    try assert(try map.append(7) == 3);
    try assert(map.count() == 3);
    try assert(map.bitarrayCap() == 1);
    try assert(map.items[3] == 7);
}

test "IndexSet iterate" {
    var map = try IndexSet(usize).initCapacity(test_alloc, 65);
    defer map.deinit();

    map.put(1, 2);
    map.put(3, 4);
    map.put(10, 11);
    map.put(63, 64);
    map.put(64, 65);

    var it = map.iterator();
    const tup1 = it.next().?;
    try assert(tup1[1] == 1 and tup1[0].* == 2);

    const tup2 = it.next().?;
    try assert(tup2[1] == 3 and tup2[0].* == 4);

    const tup3 = it.next().?;
    try assert(tup3[1] == 10 and tup3[0].* == 11);

    const tup4 = it.next().?;
    try assert(tup4[1] == 63 and tup4[0].* == 64);

    const tup5 = it.next().?;
    try assert(tup5[1] == 64 and tup5[0].* == 65);

    try assert(it.next() == null);
}

// Test various methods all at once
test "IndexSet composite" {
    var map = try IndexSet(@Vector(2, u64)).initCapacity(test_alloc, 0);
    defer map.deinit();

    try assert(map.count() == 0 and map.capacity == 0);
    try assert(try map.insert(.{1, 2}) == 0);

    map.put(0, .{33, 44});
    // print("Cap {d} | len {d} | bcap {d} | 0full {any} | 1full {any}\n", .{map.capacity, map.count(), map.bitarrayCap(), map.isFull(0), map.isFull(1)});
    try assert(map.count() == 1 and map.capacity == 2 and map.bitarrayCap() == 1);

    try map.resize(70);
    try assert(map.count() == 1 and map.capacity == 70 and map.bitarrayCap() == 2);

    map.put(map.capacity - 1, .{69, 0});
    try assert(map.count() == 2 and map.capacity == 70 and map.bitarrayCap() == 2);

    var i: usize = 0;
    var active: usize = 0;
    while (i < map.capacity) : (i += 1) {
        if (map.isFull(i)) {
            try assert(map.items[i][0] == 33 or map.items[i][0] == 69 and map.items[i][1] == 44 or map.items[i][1] == 0);
            active += 1;
        }
    }

    try assert(active == 2);

    active = 0;
    try assert (try map.insert(.{1, 2}) == 1);
    try assert (try map.insert(.{2, 3}) == 2);
    map.items[map.capacity - 1] = .{3, 4};
    try assert(map.popAt(0).?[0] == 33);

    var it = map.iterator();
    while (it.next()) |v| {
        active += 1;
        try assert(v[0].*[0] == active);
        try assert(v[0].*[1] == active+1);
    }

    try assert(active == map.count() and active == 3 and map.capacity == 70);

    map.put(63, .{0, 0});
    var map2 = try map.clone();
    defer map2.deinit();
    try map2.resize(64);

    active = 0;
    var it2 = map2.iterator();
    while (it2.next()) |_| {
        active += 1;
    }

    try assert(active == map2.count() and active == 3 and map2.capacity == 64 and map2.bitarrayCap() == 1);
}
