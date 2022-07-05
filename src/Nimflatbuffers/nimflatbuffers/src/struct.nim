import table


type FlatObj* {.inheritable.} = object
   tab*: Vtable

func table*(this: var FlatObj): Vtable = this.tab

func init*(this: var FlatObj; buf: seq[byte]; i: uoffset) =
   this.tab.bytes = buf
   this.tab.pos = i

# Cant define it in table.nim since it needs FlatObj and Init
func getUnion*[T: FlatObj](this: var Vtable; off: uoffset): T =
   result.init(this.bytes, this.indirect(off))

func `getRootAs`*(result: var FlatObj; buf: seq[byte]; offset: uoffset) =
   var
      vtable = Vtable(bytes: buf[offset..^1], pos: offset)
      n = get[uoffset](vtable, offset)
   result.init(buf, n+offset)

func `getRootAs`*(result: var FlatObj; buf: string; offset: uoffset) =
   var
      vtable = Vtable(bytes: cast[seq[byte]](buf)[offset..^1], pos: offset)
      n = get[uoffset](vtable, offset)
   result.init(cast[seq[byte]](buf), n+offset)
