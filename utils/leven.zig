// zig fmt: off

const mem = @import("std").mem;
const heap = @import("std").heap;


fn prefixLen(comptime T: type, a: []const T, b: []const T) usize {
  if (a.len == 0 or b.len == 0) return 0;
  var i: usize = 0;
  while (a[i] == b[i]) : (i += 1) {}
  return i;
}

fn suffixLen(comptime T: type, a: []const T, b: []const T) usize {
  if (a.len == 0 or b.len == 0) return 0;
  var i: usize = 0;
  while (a[a.len - 1 - i] == b[b.len - 1 - i]) : (i += 1) {}
  return i;
}

pub fn leven(comptime T: type, allocatorFallback: mem.Allocator, a: []const T, b: []const T, max: ?usize) !usize {
  if (mem.eql(T, a, b)) return 0;

  var left = a;
  var right = b;

  if (left.len > right.len) {
    left = b;
    right = a;
  }

  var ll = left.len;
  var rl = right.len;

  if (max != null and rl - ll >= max.?) {
    return max.?;
  }

  {
    const sl = suffixLen(T, a, b);
    ll -= sl;
    rl -= sl;
  }

  const start = prefixLen(T, a, b);
  ll -= start;
  rl -= start;

  if (ll == 0) return rl;

  var result: usize = 0;

  var sfa = heap.stackFallback(4096, allocatorFallback);
  const alloc = sfa.get();

  const charCodeCache = try alloc.alloc(T, ll);
  defer alloc.free(charCodeCache);

  const array = try alloc.alloc(usize, ll);
  defer alloc.free(array);

  for (0..ll) |i| {
    charCodeCache[i] = left[start + i];
    array[i] = i + 1;
  }

  for (0..rl) |j| {
    const bCharCode = right[start + j];
    var temp = j;
    result = j + 1;

    for (0..ll) |i| {
      const temp2 = if (bCharCode == charCodeCache[i]) temp else temp + 1;
      temp = array[i];
      array[i] = if (temp > result) (if (temp2 > result) result + 1 else temp2) else (if (temp2 > temp) temp + 1 else temp2);
      result = array[i];
    }
  }

  if (max != null and result >= max.?) return max.?;
  return result;
}