# IndexSet

A fun idea for a datastructure that I've had for a while, and thanks to recently learning Zig I now have an excuse to implement and benchmark it
as my first project. Be warned however, the source-code is quite cursed. Note also that this isn't a set in the mathematical sense.

## Installing

TODO

## Usage

TODO

## Purpose

This datastructure is useful for when you need:
- Order and position independant insertion (but once inserted the position + order remains fixed unless explicitly changed)
- Constant-time (fast) insertion at given index (if that index is free, otherwise other points are violated)
- Constant-time (fast) removal at given index
- Fast iteration over the (active) elements
- Backing store is contigious memory
- Dynamically sizable

An example for where this could be useful is when you have an event-loop of sorts where each frame you need
to process a set of elements. The set of elements can grow/shrink, and each element must be processed once
every frame, so that we want to iterate over the entire set. Elements can finish processing out-of-order and
need to be removed from the set. New elements should be inserted at first available index to avoid fragmentation.
In theory a LinkedList should be perfectly suited for this use-case, but sadly LinkedLists are just
bad on most modern computers due to cache-misses they incur, and what led me to explore this option.

## Benchmarks

Results aquired on an x86_64 Intel Linux machine, CPU N3350 @ 1.10GHz.
Benchmarks compiled with `zig build bench -Doptimize=ReleaseFast`, so are optimised. Measures are taken to prevent benchmark-relevant
code from being optimized away.

ArrayList and IndexSet are pre-allocated with 2048 capacity and no allocation/deallocation is
timed in the benchmarks. LinkedList allocates/deallocates in the benchmarks where elements are added/removed,
and allocation/deallocation is part of the timings.

Glossary:
- **IS**: IndexSet
- **AL**: std.ArrayList
- **LL**: std.SinglyLinkedList
- **Empty/full**: The data-structure starts out empty/full
- **Fragmented**: Either the data-structure has "holes" (empty/invalid indices) or the operations will be performed in the middle of the data-structure
- **Insert/append/pop/iter**: The respective operations to be performed
  (**iter** alone means we are using the `Iterator` interface, while **manual_iter** means we use a for-loop)
- **[number at the end of the name]**: Amount of operations performed *per run*

### IndexSet vs std.ArrayList vs std.SinglyLinkedList

```yaml
benchmark (T = i128)      runs     time (avg ± σ)         (min ............. max)      p75        p99        p995      
---------------------------------------------------------------------------------------------------------------------
IS empty-insert-2048      2000     79.953µs ± 4.286µs     (79.114µs ... 154.88µs)      79.193µs   101.435µs  104.585µs 
AL empty-insert-2048      2000     5.312µs ± 1.600µs      (5.164µs ... 40.977µs)       5.187µs    5.415µs    19.524µs  
LL empty-insert-2048      2000     205.693µs ± 13.335µs   (193.834µs ... 349.237µs)    205.381µs  261.307µs  267.109µs 
IS empty-append-2048      2000     71.547µs ± 3.517µs     (70.925µs ... 137.83µs)      70.972µs   91.838µs   93.947µs  
AL empty-append-2048      2000     4.462µs ± 1.378µs      (4.308µs ... 25.695µs)       4.326µs    4.517µs    19.796µs  
IS full-pop-2048          2000     33.290µs ± 2.766µs     (32.854µs ... 74.116µs)      32.868µs   52.405µs   54.392µs  
AL full-pop-2048          2000     3.73µs ± 1.44µs        (2.989µs ... 36.704µs)       3.6µs      3.166µs    3.220µs   
LL full-pop-2048          2000     452.707µs ± 96.185µs   (294.828µs ... 1.428ms)      464.397µs  866.164µs  888.512µs 
IS full-iter-2048         2000     6.891µs ± 21.450µs     (6.104µs ... 737.432µs)      6.127µs    6.424µs    13.40µs   
AL full-iter-2048         2000     4.175µs ± 8.59µs       (3.834µs ... 358.101µs)      3.887µs    4.59µs     19.48µs   
LL full-iter-2048         2000     12.935µs ± 1.676µs     (11.588µs ... 43.142µs)      12.793µs   13.453µs   28.651µs  

IS fragmented-insert-512  2000     20.738µs ± 10.47µs     (20.186µs ... 396.328µs)     20.223µs   25.796µs   41.884µs  
AL fragmented-insert-512  2000     311.310µs ± 15.276µs   (309.144µs ... 833.896µs)    309.165µs  351.300µs  361.148µs 
LL fragmented-insert-512  2000     58.518µs ± 10.597µs    (53.835µs ... 347.559µs)     57.906µs   96.908µs   107.997µs 
IS fragmented-pop-512     2000     3.208µs ± 3.505µs      (2.858µs ... 150.75µs)       3.66µs     3.233µs    7.709µs   
AL fragmented-pop-512     2000     479.985µs ± 16.46µs    (475.724µs ... 831.825µs)    475.993µs  526.309µs  540.753µs 
LL fragmented-pop-512     2000     98.835µs ± 37.181µs    (49.10µs ... 1.177ms)        110.327µs  168.737µs  209.150µs 
IS fragmented-iter-512    2000     4.730µs ± 1.407µs      (4.507µs ... 54.257µs)       4.718µs    4.734µs    4.758µs   

IS full-iter-1024         2000     3.172µs ± 2.871µs      (3.28µs ... 121.700µs)       3.41µs     3.179µs    6.268µs   
IS full-iter-4096         2000     12.357µs ± 1.917µs     (12.98µs ... 46.792µs)       12.161µs   17.549µs   28.349µs  
IS full-iter-16384        2000     49.84µs ± 7.758µs      (48.317µs ... 317.479µs)     48.512µs   66.654µs   69.284µs  
IS full-manual_iter-1024  2000     2.332µs ± 1.781µs      (2.221µs ... 52.934µs)       2.232µs    2.330µs    2.613µs   
IS full-manual_iter-4096  2000     8.987µs ± 6.216µs      (8.659µs ... 276.76µs)       8.698µs    12.359µs   24.303µs  
IS full-manual_iter-16384 2000     35.66µs ± 2.713µs      (34.426µs ... 87.405µs)      34.721µs   51.799µs   56.99µs   

benchmark (T = [8]i128)   runs     time (avg ± σ)         (min ............. max)      p75        p99        p995      
---------------------------------------------------------------------------------------------------------------------
IS full-iter-2048         2000     16.242µs ± 2.925µs     (15.768µs ... 75.662µs)      15.837µs   33.389µs   36.180µs  
IS full_manual-iter-2048  2000     15.645µs ± 3.179µs     (15.308µs ... 102.1µs)       15.353µs   24.774µs   35.108µs  
AL full-iter-2048         2000     15.158µs ± 6.47µs      (14.725µs ... 261.991µs)     14.780µs   30.625µs   35.590µs  
LL full-iter-2048         2000     29.836µs ± 6.682µs     (29.287µs ... 229.937µs)     29.300µs   45.418µs   50.890µs  
IS empty-insert-2048      2000     80.575µs ± 11.958µs    (79.327µs ... 421.358µs)     79.369µs   102.153µs  111.942µs 
AL empty-insert-2048      2000     8.298µs ± 10.112µs     (7.481µs ... 316.86µs)       7.719µs    14.240µs   30.236µs  
LL empty-insert-2048      2000     1.268ms ± 168.74µs     (1.175ms ... 5.216ms)        1.274ms    1.745ms    2.153ms   
IS full-pop-2048          2000     55.897µs ± 12.127µs    (52.768µs ... 266.494µs)     55.129µs   97.41µs    152.376µs 
AL full-pop-2048          2000     23.840µs ± 7.534µs     (23.56µs ... 267.312µs)      23.100µs   43.91µs    48.946µs  
LL full-pop-2048          1484     2.21ms ± 282.957µs     (1.736ms ... 3.323ms)        1.992ms    2.960ms    3.157ms
```

First part of the benchmark stores a datatype of size 16-bytes (i128) in each container benchmarked, second
part stores a datatype of size 128-bytes ([8]i128).

Assuming our benchmarks are accurate, we can conclude that:
1. std.SinglyLinkedList is never the best option
2. As expected, std.ArrayList is much better when fragmentation (insertion/deletion in the middle) is not a
   possibility
3. Cost of iteration over IndexSet is very close to iteration over std.ArrayList
4. As expected, cost of iteration over IndexSet scales linearly
5. Manual iteration over a IndexSet is slightly faster than using the iterator functionality

TODO: Do more scaling benchmarks

## Running tests and benchmarks

You can run the benchmarks with `zig build bench`. It's recommended to pass the flag `-Doptimize=ReleaseFast`

You can run the unit-tests with `zig build test`

## Compatability

Tested on 0.12.0-dev.2076+8fd15c6ca (earlier version will cause breakage in `build.zig`)

## License

[MIT Licence](LICENSE.txt)
