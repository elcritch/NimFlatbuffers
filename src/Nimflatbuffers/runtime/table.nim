import std/endians

type
   uoffset* = uint32                ## offset in to the buffer
   soffset* = int32                  ## offset from start of table, to a vtable
   voffset* = uint16                ## offset from start of table to value

type Offsets* = uoffset | soffset | voffset

type Vtable* = object
   bytes*: seq[byte]
   pos*: uoffset


using this: Vtable

proc getVal*[T](bytes: seq[byte], offset: int, typ: typedesc[T]): T =
   # assert off.int + sizeof(T) <= bytes.len()
   copyMem(result.addr, bytes[offset].unsafeAddr, sizeof(T))

proc get*[T](this: VTable; off: uoffset, typ: typedesc[T]): T =
   echo "GET:uoffset: ", repr(off), " bytes: ", repr(this.bytes)
   # assert off.int + sizeof(T) <= this.bytes.len()
   copyMem(result.addr, this.bytes[off].unsafeAddr, sizeof(T))

proc get*[T](this: VTable; off: soffset, typ: typedesc[T]): T =
   echo "GET:soffset: ", repr(off), " bytes: ", repr(this.bytes)
   # assert off.int + sizeof(T) <= this.bytes.len()
   copyMem(result.addr, this.bytes[off].unsafeAddr, sizeof(T))

proc get*[T](this: VTable; off: voffset, typ: typedesc[T]): T =
   echo "GET:voffset: ", repr(off), " bytes: ", repr(this.bytes)
   # assert off.int + sizeof(T) <= this.bytes.len()
   copyMem(result.addr, this.bytes[off].unsafeAddr, sizeof(T))

proc getOffsetAt*(this: VTable; off: uoffset): uoffset =
   result = this.get(off, uoffset)

proc getTableAt*(this: VTable; off: voffset): voffset =
   result = this.get(off, voffset)

proc writeVal*[T](b: var openArray[byte], index: uint, n: T) {.inline.} =
   when sizeof(T) == 8:
      littleEndian64(addr b[index], unsafeAddr n)
   elif sizeof(T) == 4:
      littleEndian32(addr b[index], unsafeAddr n)
   elif sizeof(T) == 2:
      littleEndian16(addr b[index], unsafeAddr n)
   elif sizeof(T) == 1:
      b[0] = n.uint8
   else:
      {.error: "write of invalid size: " & sizeof(T).}
   echo "writeVal: index:", index, " size:", sizeof(T), " val: ", repr(n), " buff:", b[index ..< index + sizeof(T).uint], " => ", b[index ..< index + sizeof(T).uint]
   echo ""

proc offset*(this; off: voffset): voffset =
   let vtable: voffset = (this.pos - this.getOffsetAt(this.pos)).voffset
   let vtableEnd: voffset = this.getTableAt(vtable)
   if off < vtableEnd:
      return this.getTableAt(vtable + off)
   return 0


proc indirect*(this; off: uoffset): uoffset =
   debugEcho this.bytes[off..^1]
   result = off + this.getOffsetAt(off)

proc vectorLen*(this; off: uoffset): int =
   var newoff: uoffset = off + this.pos
   newoff += this.getOffsetAt(off)
   return this.getOffsetAt(newoff).int

proc vector*(this; off: uoffset): uoffset =
   let newoff: uoffset = off + this.getOffsetAt(off)
   var x = newoff + this.getOffsetAt(off)
   x += (uoffset.sizeof).uoffset
   result = x

proc union*(this; t2: var Vtable, off: uoffset) =
   let newoff: uoffset = off + this.getOffsetAt(off)
   t2.pos = newoff + this.getOffsetAt(off)
   t2.bytes = this.bytes

proc getSlot*[T](this; slot: voffset, d: T): T =
   let off = this.Offset(slot)
   if off == 0:
      return d
   return this.Get[T](this.pos + off)

proc getOffsetSlot*[T: Offsets](this; slot: voffset, d: T): T =
   let off = this.Offset(slot)
   if off == 0:
      return d
   return off

proc byteVector*(this; off: uoffset): seq[byte] =
   let
      newoff: uoffset = off + this.getOffsetAt(off)
      start = newoff + (uoffset.sizeof).uoffset
      length = this.get(newoff, uoffset)
   debugEcho length
   result = this.bytes[start..start+length]

proc toString*(this; off: uoffset): string =
   var str = this.byteVector(off)
   result = $str

using this: var Vtable

proc mutate*[T](this; off: uoffset, n: T): bool =
   writeVal(this.bytes, off.uint, n)
   return true

proc mutateSlot*[T](this; slot: voffset, n: T): bool =
   let off: voffset = this.offset(slot)
   if off != 0:
      discard this.mutate(this.pos + off.uoffset, n)
      return true
   return false
