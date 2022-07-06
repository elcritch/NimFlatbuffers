import Nimflatbuffers

type
  Color* {.pure.} = enum
    Red = 0.int8, Green = 1.int8, Blue = 2.int8


type
  EquipmentType* {.pure.} = enum
    Weapon = 0'u8

type
  Equipment* = object of FlatObj

type
  Vec3* = object of FlatObj


proc x*(this: Vec3): float32 =
  structGetter(this, 0, float32)
proc `x=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 0, n)

proc y*(this: Vec3): float32 =
  structGetter(this, 4, float32)
proc `y=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 4, n)

proc z*(this: Vec3): float32 =
  structGetter(this, 8, float32)
proc `z=`*(this: var Vec3; n: float32; ) =
  structSetter(this, 8, n)

proc createVec3*(this: var B; x: float32; y: float32; z: float32): uoffset =
  this.prep(4, 12)
  this.prepend(z)
  this.prepend(y)
  this.prepend(x)
  result = this.offset()


type
  Monster* = object of FlatObj


proc pos*(this: Monster): Vec3 =
  basicTableGetterT(this, 4, Vec3)

proc mana*(this: Monster): int16 =
  basicTableGetter(this, 6, int16)

proc `mana=`*(this: var Monster; n: int16) =
  discard this.tab.mutateSlot(6, n)

proc hp*(this: Monster): int16 =
  basicTableGetter(this, 8, int16)

proc `hp=`*(this: var Monster; n: int16) =
  discard this.tab.mutateSlot(8, n)
proc name*(this: Monster): string =
  basicTableStringGetter(this, 10, string)

proc friendly*(this: Monster): bool =
  basicTableGetter(this, 12, bool)

proc `friendly=`*(this: var Monster; n: bool) =
  discard this.tab.mutateSlot(12, n)

proc monsterStart*[B: Builder](this: var B) =
  this.startObject(5)

proc monsterAddPos*[B: Builder](this: var B; pos: uoffset) =
  this.prependSlot(0, pos, default(uoffset))

proc monsterAddMana*[B: Builder](this: var B; mana: uoffset) =
  this.prependSlot(1, mana, default(uoffset))

proc monsterAddHp*[B: Builder](this: var B; hp: uoffset) =
  this.prependSlot(2, hp, default(uoffset))

proc monsterAddName*[B: Builder](this: var B; name: uoffset) =
  this.prependSlot(4, name, default(uoffset))

proc monsterAddFriendly*[B: Builder](this: var B; friendly: uoffset) =
  this.prependSlot(4, friendly, default(uoffset))

proc monsterEnd*[T](this: var Builder[T]): uoffset =
  result = this.endObject()


type
  Weapon* = object of FlatObj

proc name*(this: Weapon): string =
  basicTableStringGetter(this, 4, string)

proc damage*(this: Weapon): int16 =
  basicTableGetter(this, 6, int16)

proc `damage=`*(this: var Weapon; n: int16) =
  discard this.tab.mutateSlot(6, n)

proc weaponStart*[B: Builder](this: var B) =
  this.startObject(2)

proc weaponAddName*[B: Builder](this: var B; name: uoffset) =
  this.prependSlot(1, name, default(uoffset))

proc weaponAddDamage*[B: Builder](this: var B; damage: int16) =
  this.prependSlot(1, damage, default(int16))

proc weaponEnd*[T](this: var Builder[T]): uoffset =
  result = this.endObject()
