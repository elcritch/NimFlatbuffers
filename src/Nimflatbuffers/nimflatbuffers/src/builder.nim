import math
import table


const MAX_BUFFER_SIZE* = 2^31


type Builder*[V] = ref object of RootObj
   bytes*: seq[byte]
   minalign*: int
   current_vtable*: seq[uoffset]
   objectEnd*: uoffset
   vtables*: seq[uoffset] #?
   head*: uoffset
   nested*: bool
   finished*: bool

using this: var Builder

func newBuilder*[T](typ: typedesc[T], size: int): Builder[T] =
   result = new Builder[T]()
   result.bytes.setLen(size)
   result.minalign = 1
   result.head = size.uoffset
   #result.vtables.setLen(16)# = newSeq[uoffset](16)
   result.nested = false
   result.finished = false

proc finishedBytes*[T, V](this: Builder[T]): seq[byte] =
   if not this.finished:
      quit("Builder not finished, Incorrect use of FinishedBytes(): must call 'Finish' first.")
   result = this.bytes[this.head..^1]

proc output*[T, V](this: Builder[T]): seq[byte] =
   if not this.finished:
      quit("Builder not finished, Incorrect use of Output(): must call 'Finish' first.")

   result = this.bytes[this.head..^1]

func offset*[T, V](this: Builder[T]): uoffset =
   result = this.bytes.len.uoffset - this.head

proc startObject*[T, V](this: var Builder[T]; numfields: int) =
   if this.nested:
      quit("builder is nested")

   if this.current_vtable.len < numfields or this.current_vtable.len == 0:
      this.current_vtable.setLen(numfields)
   else:
      this.current_vtable = this.current_vtable[0..<numfields]
      for i in this.current_vtable.mitems():
         i = 0

   this.objectEnd = this.offset()
   this.nested = true

proc growByteBuffer*[T, V](this: Builder[T]) =
   if this.bytes.len == MAX_BUFFER_SIZE:
      quit("flatbuffers: cannot grow buffer beyond 2 gigabytes")
   var newLen = min(this.bytes.len * 2, MAX_BUFFER_SIZE)
   if newLen == 0:
      newLen = 1
   #[var bytes2: seq[byte]
   bytes2.setLen newSize
   bytes2[newSize-this.bytes.len..^1] = this.bytes
   this.bytes = bytes2]#
   if this.bytes.len >= newLen:
      this.bytes = this.bytes[0..<newLen]
   else:
      let extension: seq[byte] = newSeq[byte](newLen - this.bytes.len)
      this.bytes.add extension

   let middle = newLen div 2

   let
      #firstHalf = this.bytes[0..<middle]
      secondHalf = this.bytes[middle..^1]

   this.bytes = secondHalf

proc place*[T, V](this: var Builder[T]; x: V) =
   this.head -= uoffset x.sizeof
   writeVal(this.bytes.toOpenArray(this.head.int, this.bytes.len - 1), x)

func pad*[T, V](this: var Builder[T]; n: int) =
   for i in 0..<n:
      this.place(0.byte)

proc prep*[T, V](this: var Builder[T]; size: int, additionalBytes: int) =
   if size > this.minalign:
      this.minalign = size
   var alignsize = (not this.bytes.len - this.head.int + additionalBytes) + 1
   alignsize = alignsize and size - 1

   while this.head.int <= alignsize + size + additionalBytes:
      let oldbufSize = this.bytes.len
      this.growByteBuffer()
      this.head += (this.bytes.len - oldbufSize).uoffset
   this.pad(alignsize)

proc prependOffsetRelative*[V: Offsets](this; off: V) =
   when V is voffset:
      this.prep(V.sizeof, 0)
      if not off.uoffset <= this.offset:
            quit("flatbuffers: Offset arithmetic error.")
      this.place(off)
   else:
      this.prep(V.sizeof, 0)
      if not off.uoffset <= this.offset:
         quit("flatbuffers: Offset arithmetic error.")
      let off2: V = this.offset.V - off + sizeof(V).V
      this.place(off2)


proc prepend*[T, V](this: var Builder[T]; x: V) =
   this.prep(x.sizeof, 0)
   this.place(x)

proc slot*[T, V](this: var Builder[T]; slotnum: int) =
   this.current_vtable[slotnum] = this.offset

proc prependSlot*[T, V](this: var Builder[T]; o: int, x, d: V) =
   if x != d:
      this.prepend(x)
      this.slot(o)

proc add*[T, V](this: var Builder[T]; n: V) =
   this.prep(V.sizeof, 0)
   writeVal(this.bytes.toOpenArray(this.head.int, this.bytes.len - 1), n)

proc vtableEqual*(a: seq[uoffset], objectStart: uoffset, b: seq[byte]): bool =
   if a.len * voffset.sizeof != b.len:
      return false

   var i = 0
   while i < a.len:
      var seq = b[i * voffset.sizeof..<(i + 1) * voffset.sizeof]
      let x = getVal[voffset](addr seq)

      if x == 0 and a[i] == 0:
         inc i
         continue

      let y = objectStart.soffset - a[i].soffset
      if x.soffset != y:
         return false
      inc i
   return true

proc writeVtable*[T, V](this: Builder[T]): uoffset =
   this.prependOffsetRelative(0.soffset)

   let objectOffset = this.offset
   var existingVtable = uoffset 0

   var i = this.current_vtable.len - 1
   while i >= 0 and this.current_vtable[i] == 0: dec i

   this.current_vtable = this.current_vtable[0..i]

   for i in countdown(this.vtables.len - 1, 0):
      let
         vt2Offset: uoffset = this.vtables[i]
         vt2Start: int = this.bytes.len - int vt2Offset

      var seq = this.bytes[vt2Start..<this.bytes.len]
      let
         vt2Len = getVal[voffset](addr seq)
         metadata = 2 * voffset.sizeof # VtableMetadataFields * SizeVOffsetT
         vt2End = vt2Start + vt2Len.int
         vt2 = this.bytes[this.bytes.len - vt2Offset.int + metadata..<vt2End]

      if vtableEqual(this.current_vtable, objectOffset, vt2):
         existingVtable = vt2Offset
         break

   if existingVtable == 0:
      for i in countdown(this.current_vtable.len - 1, 0):
         var off: uoffset
         if this.current_vtable[i] != 0:
            off = objectOffset - this.current_vtable[i]

         this.prependOffsetRelative(off.voffset)

      let objectSize = objectOffset - this.objectEnd
      this.prependOffsetRelative(objectSize.voffset)

      let vBytes = (this.current_vtable.len + 2) * voffset.sizeof
      this.prependOffsetRelative(vBytes.voffset)

      let objectStart = (this.bytes.len.soffset - objectOffset.soffset)
      writeVal(this.bytes.toOpenArray(objectStart.int, this.bytes.len - 1), (this.offset - objectOffset).soffset)

      this.vtables.add this.offset
   else:
      let objectStart = this.bytes.len.soffset - objectOffset.soffset
      this.head = uoffset objectStart

      writeVal(this.bytes.toOpenArray(this.head.int, this.bytes.len - 1),
         (existingVtable - objectOffset).soffset)

      this.current_vtable = @[]
   result = objectOffset

proc endObject*[T, V](this: Builder[T]): uoffset =
   if not this.nested:
      quit("builder is not nested")
   result = this.writeVtable()
   this.nested = false

proc ends*[T, V](this: var Builder[T]): uoffset =
   result = this.endObject()

proc startVector*[T, V](this: var Builder[T]; elemSize: int, numElems: int, alignment: int): uoffset =
   if this.nested:
      quit("builder is nested")
   this.nested = true
   this.prep(sizeof(uint32), elemSize * numElems)
   this.prep(alignment, elemSize * numElems)
   result = this.offset

proc endVector*[T, V](this: var Builder[T]; vectorNumElems: int): uoffset =
   if not this.nested:
      quit("builder is not nested")
   this.nested = false
   this.place(vectorNumElems)
   result = this.offset

proc getChars*(str: seq[byte]): string =
   var bytes = str
   result = getVal[string](addr bytes)

proc getBytes*(str: string | cstring): seq[byte] =
   for chr in str:
      result.add byte chr

proc create*[T, V](this: var Builder[T]; s: V): uoffset = #Both CreateString and CreateByteVector functionality
   if this.nested:
      quit("builder is nested")
   this.nested = true

   this.prep(uoffset.sizeof, s.len + 1 * byte.sizeof)
   this.place(0.byte)

   let l = s.len.uoffset

   this.head -= l
   when V is cstring or V is string:
      this.bytes[this.head.int..this.head.int + 1] = s.getBytes()
   else:
      this.bytes[this.head.int..this.head.int + 1] = s
   result = this.endVector(s.len)

proc finish*[T, V](this: var Builder[T]; rootTable: uoffset) =
   if this.nested:
      quit("builder is nested")
   this.nested = true

   this.prep(this.minalign, uoffset.sizeof)
   this.prependOffsetRelative(rootTable)
   this.finished = true
