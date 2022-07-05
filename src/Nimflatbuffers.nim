import
   Nimflatbuffers/[
      flatn/codegen,
      nimflatbuffers/nimflatbuffers
   ]
export builder, table, struct


template generateCode*(file: static[string], outputDir: static[string] = "output", abs: static[bool] = false) =
   generateCodeImpl(instantiationInfo(-1, fullPaths = true).filename, file, outputDir, abs)

proc basicTableGetter*[F: FlatObj, V](this: F, offset: voffset, typ: typedesc[V]): V =
  var o = this.tab.Offset(offset)
  if o != 0:
    result = Get[V](this.tab, o + this.tab.Pos)
  else:
    result = default(type(result))

proc tableArrayGetter*[F: FlatObj, V](this: F, inlineSize: int): V =
  let j: int
  var o = this.tab.Offset($off)
  if o != 0:
    var x = this.tab.Vector(o)
    x += j.uoffset * inlineSize.uoffset
    result = this.tab.Get[:" & typ & "](o + this.tab.Pos)
  else:
    discard