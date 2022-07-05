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


func getVal*[T](b: ptr seq[byte]): T {.inline.} =
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


template get*[T](this; off: uoffset): T =
   var b = this.bytes[off..^1]
   getVal[T](addr b)

template get*[T](this; off: soffset): T =
   var b = this.bytes[off..^1]
   getVal[T](addr b)

template get*[T](this; off: voffset): T =
   var b = this.bytes[off..^1]
   getVal[T](addr b)

template getOffsetAt*(this; off: uoffset): uoffset =
   var seq = this.bytes[off..^1]
   getVal[uoffset](addr seq)

template getTableAt*(this; off: voffset): voffset =
   var seq = this.bytes[off..^1]
   getVal[voffset](addr seq)

func writeVal*[T: not SomeFloat](b: var openArray[byte], n: T) {.inline.} =
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

func writeVal*[T: not SomeFloat](b: var seq[byte], n: T) {.inline.} =
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

func writeVal*[T: SomeFloat](b: var openArray[byte], n: T) {.inline.} =
   when T is float64:
      writeVal(b, cast[uint64](n))
   elif T is float32:
      writeVal(b, cast[uint32](n))

func writeVal*[T: SomeFloat](b: var seq[byte], n: T) {.inline.} =
   when T is float64:
      writeVal(b, cast[uint64](n))
   elif T is float32:
      writeVal(b, cast[uint32](n))

func offset*(this; off: voffset): voffset =
   let vtable: voffset = (this.pos - this.getOffsetAt(this.pos)).voffset
   let vtableEnd: voffset = this.get[:voffset](vtable)
   if off < vtableEnd:
      return this.get[:voffset](vtable + off)
   return 0


func indirect*(this; off: uoffset): uoffset =
   debugEcho this.bytes[off..^1]
   result = off + this.getOffsetAt(off)

func vectorLen*(this; off: uoffset): int =
   var newoff: uoffset = off + this.pos
   newoff += this.getOffsetAt(off)
   return this.getOffsetAt(newoff).int

func vector*(this; off: uoffset): uoffset =
   let newoff: uoffset = off + this.getOffsetAt(off)
   var x = newoff + this.getOffsetAt(off)
   x += (uoffset.sizeof).uoffset
   result = x

func union*(this; t2: var Vtable, off: uoffset) =
   let newoff: uoffset = off + this.getOffsetAt(off)
   t2.pos = newoff + this.getOffsetAt(off)
   t2.bytes = this.bytes

func getSlot*[T](this; slot: voffset, d: T): T =
   let off = this.Offset(slot)
   if off == 0:
      return d
   return this.Get[T](this.pos + off)

func getOffsetSlot*[T: Offsets](this; slot: voffset, d: T): T =
   let off = this.Offset(slot)
   if off == 0:
      return d
   return off

func byteVector*(this; off: uoffset): seq[byte] =
   let
      newoff: uoffset = off + this.getOffsetAt(off)
      start = newoff + (uoffset.sizeof).uoffset
   var newseq = this.bytes[newoff..^1]
   debugEcho newseq
   let
      length = getVal[uoffset](addr newseq)
   debugEcho length
   result = this.bytes[start..start+length]

func toString*(this; off: uoffset): string =
   var seq = this.byteVector(off)
   result = getVal[string](addr seq)

using this: var Vtable

proc mutate*[T](this; off: uoffset, n: T): bool =
   var seq = this.bytes[off.int..^1]
   writeVal(seq, n)
   this.bytes = seq
   return true

func mutateSlot*[T](this; slot: voffset, n: T): bool =
   let off: voffset = this.Offset(slot)
   if off != 0:
      discard this.Mutate(this.pos + off.uoffset, n)
      return true
   return false
