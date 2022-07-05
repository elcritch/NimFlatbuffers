import
  Nimflatbuffers/[
    nimflatbuffers/nimflatbuffers
  ]
export builder, table, struct


# template generateCode*(file: static[string], outputDir: static[string] = "output", abs: static[bool] = false) =
#   generateCodeImpl(instantiationInfo(-1, fullPaths = true).filename, file, outputDir, abs)

proc basicTableGetter*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  var o = this.tab.offset(offset)
  if o != 0:
    result = get(this.tab, o + this.tab.pos, typ)
  else:
    result = default(type(result))

proc basicTableGetterS*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  var o = this.tab.offset(offset)
  if o != 0:
    var x = o + this.tab.pos
    result.init(this.tab.bytes, x)
  else:
    result = default(type(result))

proc basicTableGetterT*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  var o = this.tab.offset(offset)
  if o != 0:
    var x = this.tab.indirect(o + this.tab.pos)
    result.init(this.tab.bytes, x)
  else:
    result = default(type(result))

proc basicTableStringGetter*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  var o = this.tab.offset(offset)
  if o != 0:
    result = this.tab.toString(o)
  else:
    result = default(type(result))

proc structGetter*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  let idx = this.tab.pos + offset + 4
  result = this.tab.get(idx, typ)

proc structSetter*[F, V](this: var F, offset: voffset, n: V) =
  let off = this.tab.pos + 4
  discard this.tab.mutate(off, n)

proc tableArrayGetter*[F: FlatObj, V](this: F, inlineSize: int): V =
  let j: int
  var o = this.tab.offset($off)
  if o != 0:
    var x = this.tab.vector(o)
    x += j.uoffset * inlineSize.uoffset
    result = this.tab.get[:V](o + this.tab.pos)
  else:
    discard