import endian


type
   uoffset* = uint32                ## offset in to the buffer
   soffset* = int32                  ## offset from start of table, to a vtable
   voffset* = uint16                ## offset from start of table to value

type Offsets* = uoffset | soffset | voffset

type Vtable* = object
   bytes*: seq[byte]
   pos*: uoffset


using this: Vtable


proc getVal*[T](b: ptr seq[byte]): T =
   echo "BYTES:getVal: ", repr(b)
   when T is float64:
      result = cast[T](getVal[uint64](b))
   elif T is float32:
      result = cast[T](getVal[uint32](b))
   elif T is string:
      result = cast[T](b[])
   else:
      if b[].len < T.sizeof:
         b[].setLen T.sizeof
      result = cast[ptr T](unsafeAddr b[][0])[]


proc get*[T](this: VTable; off: uoffset, typ: typedesc[T]): T =
   echo "GET:uoffset: ", repr(off), " bytes: ", repr(this.bytes)
   var b = this.bytes[off..^1]
   getVal[T](addr b)

proc get*[T](this: VTable; off: soffset, typ: typedesc[T]): T =
   echo "GET:soffset: ", repr(off), " bytes: ", repr(this.bytes)
   var b = this.bytes[off..^1]
   getVal[T](addr b)

proc get*[T](this: VTable; off: voffset, typ: typedesc[T]): T =
   echo "GET:voffset: ", repr(off), " bytes: ", repr(this.bytes)
   var b = this.bytes[off..^1]
   getVal[T](addr b)

proc getOffsetAt*(this: VTable; off: uoffset): uoffset =
   var seq = this.bytes[off..^1]
   getVal[uoffset](addr seq)

proc getTableAt*(this: VTable; off: voffset): voffset =
   var seq = this.bytes[off..^1]
   getVal[voffset](addr seq)

proc writeVal*[T: not SomeFloat](b: var openArray[byte], n: T) {.inline.} =
   when sizeof(T) == 8:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 4:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 2:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 1:
      b[0] = n.uint8
   else:
      discard
      #littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
      #{.error:"shouldnt appear".}

proc writeVal*[T: not SomeFloat](b: var seq[byte], n: T) {.inline.} =
   when sizeof(T) == 8:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 4:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 2:
      littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
   elif sizeof(T) == 1:
      b[0] = n.uint8
   else:
      discard
      #littleEndianX(addr b[0], unsafeAddr n, T.sizeof)
      #{.error:"shouldnt appear".}

proc writeVal*[T: SomeFloat](b: var openArray[byte], n: T) {.inline.} =
   when T is float64:
      writeVal(b, cast[uint64](n))
   elif T is float32:
      writeVal(b, cast[uint32](n))

proc writeVal*[T: SomeFloat](b: var seq[byte], n: T) {.inline.} =
   when T is float64:
      writeVal(b, cast[uint64](n))
   elif T is float32:
      writeVal(b, cast[uint32](n))

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
   var newseq = this.bytes[newoff..^1]
   debugEcho newseq
   let
      length = getVal[uoffset](addr newseq)
   debugEcho length
   result = this.bytes[start..start+length]

proc toString*(this; off: uoffset): string =
   var seq = this.byteVector(off)
   result = getVal[string](addr seq)

using this: var Vtable

proc mutate*[T](this; off: uoffset, n: T): bool =
   var seq = this.bytes[off.int..^1]
   writeVal(seq, n)
   this.bytes = seq
   return true

proc mutateSlot*[T](this; slot: voffset, n: T): bool =
   let off: voffset = this.offset(slot)
   if off != 0:
      discard this.mutate(this.pos + off.uoffset, n)
      return true
   return false
