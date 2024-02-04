const std = @import("std");
const print = std.debug.print;
const math = std.math;
const expect = std.testing.expect;
const blackBox = std.mem.doNotOptimizeAway;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const LinkedList = std.SinglyLinkedList;

const zbench = @import("zbench");
const IndexSet = @import("index_set").IndexSet;

fn ISFullIter(comptime N: usize) type {
    return struct {
        const Self = @This();
        const name = std.fmt.comptimePrint("IS full-iter-{d}", .{N});

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, N),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |val_idx|
                blackBox(val_idx[0].*);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.* += 1;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    };
}

fn ISFullManualIter(comptime N: usize) type {
    return struct {
        const Self = @This();
        const name = std.fmt.comptimePrint("IS full-manual_iter-{d}", .{N});

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, N),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var i: usize = 0;
            while (i < self.map.capacity) : (i += 1) {
                if (self.map.isFull(i))
                    blackBox(self.map.items[i]);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.* += 1;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    };
}

const empty_full_runners = .{
    struct {
        const Self = @This();
        const name = "IS empty-insert-2048";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i|
                blackBox(self.map.insert(i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
            if (self.map.capacity > 2048)
                print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL empty-insert-2048";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i|
                blackBox(self.map.insert(i, i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL empty-insert-2048";

        alloc: Allocator,
        map: LinkedList(i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList(i128){};
            list.first = try alloc.create(LinkedList(i128).Node);

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i| {
                const new_node = self.alloc.create(LinkedList(i128).Node) catch @panic("Node-allocation failed!");
                new_node.*.data = i;
                self.map.prepend(new_node);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.first = self.alloc.create(LinkedList(i128).Node) catch @panic("Node-allocation failed!");

            // var it: ?*LinkedList(i128).Node = self.map.first;
            // while (true) {
                // const curr: *LinkedList(i128).Node = it orelse break;
                // it = curr.*.next;
                // self.alloc.destroy(curr);
            // }
        }
    },
    struct {
        const Self = @This();
        const name = "IS empty-append-2048";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i|
                blackBox(self.map.append(i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL empty-append-2048";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i|
                blackBox(self.map.append(i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "IS full-pop-2048";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            while (self.map.pop()) |idx_val|
                blackBox(idx_val[0]);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.* += 1;

            @memset(self.map.bitarray[0..self.map.bitarrayCap()], 0);

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL full-pop-2048";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };

            ret.map.items.len = 2048;

            return ret;
        }

        pub fn run(self: *Self) void {
            while (self.map.popOrNull()) |elem|
                blackBox(elem);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.items.len = 2048;
            for (self.map.items) |*item| item.* += 1;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL full-pop-2048";

        alloc: Allocator,
        map: LinkedList(i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList(i128){};

            for (0..2048) |i| {
                const new_node = try alloc.create(LinkedList(i128).Node);
                new_node.*.data = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |_| {
                const first = self.map.first.?;

                self.map.first = first.*.next;
                blackBox(first.*.data);
                self.alloc.destroy(first);
            }
        }
    },
    struct {
        const Self = @This();
        const name = "IS full-iter-2048";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |val_idx|
                blackBox(val_idx[0].*);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.* += 1;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL full-iter-2048";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };

            ret.map.items.len = 2048;

            return ret;
        }

        pub fn run(self: *Self) void {
            for (self.map.items) |elem|
                blackBox(elem);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items) |*item| item.* += 1;
            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL full-iter-2048";

        alloc: Allocator,
        map: LinkedList(i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList(i128){};

            for (0..2048) |i| {
                const new_node = try alloc.create(LinkedList(i128).Node);
                new_node.*.data = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            var it = self.map.first;
            while (it) |n| {
                blackBox(n.*.data);
                it = n.*.next;
            }
        }

        pub fn reset(self: *Self) void {
            var it = self.map.first;
            while (it) |n| {
                n.*.data += 1;
                it = n.*.next;
            }
        }
    },
};

const fragmented_runners = .{
    struct {
        const Self = @This();
        const name = "IS fragmented-insert-512";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret = Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };

            // Set every 4th position as free, the rest occupied
            for (ret.map.bitarray[0..ret.map.bitarrayCap()]) |*bm|
                bm.* = 0x1111_1111_1111_1111;

            return ret;
        }

        pub fn run(self: *Self) void {
            for (0..512) |i|
                blackBox(self.map.insert(i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.bitarray[0..self.map.bitarrayCap()]) |*bm|
                bm.* = 0x1111_1111_1111_1111;

            // print("Capacity: {d} | len: {d}\n", .{ self.map.capacity, self.map.count() });
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL fragmented-insert-512";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret = Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };

            try ret.map.resize(6*256);
            return ret;
        }

        pub fn run(self: *Self) void {
            var i: usize = 0;
            // Insert for every 4 elements, total of 512 inserts
            while (i < 2048) : (i += 4)
                blackBox(self.map.insert(i, i) catch unreachable);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.resize(6*256) catch unreachable;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.items.len});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL fragmented-insert-512";

        alloc: Allocator,
        map: LinkedList(i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList(i128){};

            for (0..3*512) |i| {
                const new_node = try alloc.create(LinkedList(i128).Node);
                new_node.*.data = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            var it = self.map.first;
            var i: usize = 0;
            // Insert for every 4 elements, a total of 512 inserts
            while (i < 2048) : (i += 4) {
                const new_node = self.alloc.create(LinkedList(i128).Node) catch @panic("Node-allocation failed!");
                new_node.*.next = it.?.*.next;
                it.?.next = new_node;

                it = it.?.*.next;
                it = it.?.*.next;
                it = it.?.*.next;
                it = it.?.*.next;
            }
        }
    },
    struct {
        const Self = @This();
        const name = "IS fragmented-pop-512";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var i: usize = 0;
            // Remove every 4th element, total of 512 elements
            while (i < 2048) : (i += 4)
                blackBox(self.map.popAt(i));
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.* += 1;

            @memset(self.map.bitarray[0..self.map.bitarrayCap()], 0);

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL fragmented-pop-512";

        alloc: Allocator,
        map: ArrayList(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try ArrayList(i128).initCapacity(alloc, 2048),
            };

            ret.map.expandToCapacity();

            return ret;
        }

        pub fn run(self: *Self) void {
            var i: usize = 0;
            // Remove every 4th element, total of 512 elements
            while (i < 6*256) : (i += 3) {
                blackBox(self.map.orderedRemove(i));
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.expandToCapacity();
            for (self.map.items) |*item| item.* += 1;

            // print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL fragmented-pop-512";

        alloc: Allocator,
        map: LinkedList(i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList(i128){};

            for (0..2048) |i| {
                const new_node = try alloc.create(LinkedList(i128).Node);
                new_node.*.data = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            var it = self.map.first;
            var i: usize = 0;
            // Remove for every 4 elements, a total of 512 inserts
            while (i < 2048) : (i += 4) {
                const next = it.?.*.next.?;
                it.?.next = next.*.next;

                blackBox(next.*.data);
                self.alloc.destroy(next);

                it = it.?.*.next;
                it = it.?.*.next;
                it = it.?.*.next;
            }
        }
    },
    struct {
        const Self = @This();
        const name = "IS fragmented-iter-512";

        alloc: Allocator,
        map: IndexSet(i128),

        pub fn init(alloc: Allocator) !Self {
            var ret = Self {
                .alloc = alloc,
                .map = try IndexSet(i128).initCapacity(alloc, 2048),
            };

            // Set every 4th position as occupied, the rest free
            for (ret.map.bitarray[0..ret.map.bitarrayCap()]) |*bm|
                bm.* = 0xEEEE_EEEE_EEEE_EEEE;

            return ret;
        }

        pub fn run(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |val_idx|
                blackBox(val_idx[0].*);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.bitarray[0..self.map.bitarrayCap()]) |*bm|
                bm.* = 0xEEEE_EEEE_EEEE_EEEE;

            // print("Capacity: {d} | len: {d}\n", .{ self.map.capacity, self.map.count() });
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
};


const scaling_iter_runners = .{
    ISFullIter(1024),
    ISFullIter(4096),
    ISFullIter(16384),
};

const scaling_manual_iter_runners = .{
    ISFullManualIter(1024),
    ISFullManualIter(4096),
    ISFullManualIter(16384),
};

const big_iter_runners = .{
    struct {
        const Self = @This();
        const name = "IS full-iter-2048";

        alloc: Allocator,
        map: IndexSet([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet([8]i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var it = self.map.iterator();
            while (it.next()) |val_idx|
                blackBox(val_idx[0].*);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.*[0] += 1;
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "IS full_manual-iter-2048";

        alloc: Allocator,
        map: IndexSet([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet([8]i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            var i: usize = 0;
            while (i < self.map.capacity) : (i += 1) {
                if (self.map.isFull(i))
                    blackBox(self.map.items[i]);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.*[0] += 1;
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL full-iter-2048";

        alloc: Allocator,
        map: ArrayList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try ArrayList([8]i128).initCapacity(alloc, 2048),
            };

            ret.map.items.len = 2048;

            return ret;
        }

        pub fn run(self: *Self) void {
            for (self.map.items) |elem|
                blackBox(elem);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items) |*item| item.*[0] += 1;
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL full-iter-2048";

        alloc: Allocator,
        map: LinkedList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList([8]i128){};

            for (0..2048) |i| {
                const new_node = try alloc.create(LinkedList([8]i128).Node);
                new_node.*.data[0] = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            var it = self.map.first;
            while (it) |n| {
                blackBox(n.*.data);
                it = n.*.next;
            }
        }

        pub fn reset(self: *Self) void {
            var it = self.map.first;
            while (it) |n| {
                n.*.data[0] += 1;
                it = n.*.next;
            }
        }
    },
    struct {
        const Self = @This();
        const name = "IS empty-insert-2048";

        alloc: Allocator,
        map: IndexSet([8]i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try IndexSet([8]i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i| {
                var item: [8]i128 = undefined;
                item[0] = i;
                blackBox(self.map.insert(item) catch unreachable);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
            if (self.map.capacity > 2048)
                print("Capacity: {d} | len: {d}\n", .{self.map.capacity, self.map.count()});
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL empty-insert-2048";

        alloc: Allocator,
        map: ArrayList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            return Self {
                .alloc = alloc,
                .map = try ArrayList([8]i128).initCapacity(alloc, 2048),
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i| {
                var item: [8]i128 = undefined;
                item[0] = i;
                blackBox(self.map.insert(i, item) catch unreachable);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.clearRetainingCapacity();
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL empty-insert-2048";

        alloc: Allocator,
        map: LinkedList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList([8]i128){};
            list.first = try alloc.create(LinkedList([8]i128).Node);

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |i| {
                const new_node = self.alloc.create(LinkedList([8]i128).Node) catch @panic("Node-allocation failed!");

                new_node.*.data[0] = i;
                self.map.prepend(new_node);
            }
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.first = self.alloc.create(LinkedList([8]i128).Node) catch @panic("Node-allocation failed!");
        }
    },
    struct {
        const Self = @This();
        const name = "IS full-pop-2048";

        alloc: Allocator,
        map: IndexSet([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try IndexSet([8]i128).initCapacity(alloc, 2048),
            };

            @memset(ret.map.bitarray[0..ret.map.bitarrayCap()], 0);

            return ret;
        }

        pub fn run(self: *Self) void {
            while (self.map.pop()) |idx_val|
                blackBox(idx_val[0]);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            for (self.map.items[0..self.map.capacity]) |*item| item.*[0] += 1;

            @memset(self.map.bitarray[0..self.map.bitarrayCap()], 0);
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "AL full-pop-2048";

        alloc: Allocator,
        map: ArrayList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var ret =  Self {
                .alloc = alloc,
                .map = try ArrayList([8]i128).initCapacity(alloc, 2048),
            };

            ret.map.items.len = 2048;

            return ret;
        }

        pub fn run(self: *Self) void {
            while (self.map.popOrNull()) |elem|
                blackBox(elem);
        }

        pub fn reset(self: *Self) void {
            blackBox(self.map);
            self.map.items.len = 2048;
            for (self.map.items) |*item| item.*[0] += 1;
        }

        pub fn deinit(self: Self) void {
            self.map.deinit();
        }
    },
    struct {
        const Self = @This();
        const name = "LL full-pop-2048";

        alloc: Allocator,
        map: LinkedList([8]i128),

        pub fn init(alloc: Allocator) !Self {
            var list = LinkedList([8]i128){};

            for (0..2048) |i| {
                const new_node = try alloc.create(LinkedList([8]i128).Node);
                new_node.*.data[0] = i;

                list.prepend(new_node);
            }

            return Self {
                .alloc = alloc,
                .map = list,
            };
        }

        pub fn run(self: *Self) void {
            for (0..2048) |_| {
                const first = self.map.first.?;

                self.map.first = first.*.next;
                blackBox(first.*.data);
                self.alloc.destroy(first);
            }
        }
    },
};

pub fn prettyPrintHeader(name: []const u8) void {
    std.debug.print("{s:<25} {s:<8} {s:<22} {s:<28} {s:<10} {s:<10} {s:<10}\n", .{ name, "runs", "time (avg ± σ)", "(min ............. max)", "p75", "p99", "p995" });
    std.debug.print("---------------------------------------------------------------------------------------------------------------------\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var bench = try zbench.Benchmark.init(3_000_000_000, 2000, gpa.allocator());
    defer bench.deinit();

    // Empty/full benches
    prettyPrintHeader("benchmark (T = i128)");
    inline for (empty_full_runners) |Runner|
        try (try bench.run(Runner, Runner.name)).prettyPrint(false);

    // Fragmented benches
    _ = try std.io.getStdOut().write("\n");
    inline for (fragmented_runners) |Runner|
        try (try bench.run(Runner, Runner.name)).prettyPrint(false);

    // Scaling benches
    _ = try std.io.getStdOut().write("\n");
    inline for (scaling_iter_runners) |Runner|
        try (try bench.run(Runner, Runner.name)).prettyPrint(false);

    inline for (scaling_manual_iter_runners) |Runner|
        try (try bench.run(Runner, Runner.name)).prettyPrint(false);

    // Large-T benches
    _ = try std.io.getStdOut().write("\n");
    prettyPrintHeader("benchmark (T = [8]i128)");
    inline for (big_iter_runners) |Runner|
        try (try bench.run(Runner, Runner.name)).prettyPrint(false);
}
