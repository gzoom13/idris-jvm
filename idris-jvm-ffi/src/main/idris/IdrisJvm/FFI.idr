module IdrisJvm.FFI

%access public export

data JVM_NativeTy = Class String
                  | Interface String

data JVM_Native  : JVM_NativeTy -> Type where
  MkJVMNative : (ty : JVM_NativeTy) -> JVM_Native ty

ThrowableClass : JVM_NativeTy
ThrowableClass = Class "java/lang/Throwable"

Throwable : Type
Throwable = JVM_Native ThrowableClass

JVM_Throwable : Type -> Type
JVM_Throwable t = Either Throwable t

mutual
    data AnnotationValue = AnnInt String -- FFI Descriptor can only take String
                         | AnnBoolean String
                         | AnnByte String
                         | AnnChar String
                         | AnnShort String
                         | AnnLong String
                         | AnnFloat String
                         | AnnDouble String
                         | AnnEnum String String
                         | AnnClass String
                         | AnnAnnotation Annotation
                         | AnnArray (List AnnotationValue)

    data Annotation = Ann String (List (String, AnnotationValue))

mutual
  data JVM_FfiFn = Static JVM_NativeTy String
                 | GetStaticField JVM_NativeTy String
                 | SetStaticField JVM_NativeTy String
                 | Lambda JVM_NativeTy String
                 | Constructor
                 | New
                 | NewArray
                 | GetArray
                 | SetArray
                 | MultiNewArray
                 | ArrayLength
                 | ClassLiteral String
                 | Instance String
                 | GetInstanceField String
                 | SetInstanceField String
                 | Super String
                 | InstanceOf String
                 | ExportStaticField String
                 | ExportInstanceField String
                 | ExportStatic String
                 | ExportInstance String
                 | ExportDefault -- Export an instance method with idris function name
                 | Anns (List Annotation)

                 -- Export a static method with method annotations and parameter annotations
                 | ExportStaticWithAnn String (List Annotation) (List (List Annotation))

                 -- Export an instance method with method annotations and parameter annotations
                 | ExportInstanceWithAnn String (List Annotation) (List (List Annotation))

  data JVM_IntTypes : Type -> Type where
      JVM_IntChar   : JVM_IntTypes Char
      JVM_IntNative : JVM_IntTypes Int
      JVM_IntBits8  : JVM_IntTypes Bits8
      JVM_IntBits16 : JVM_IntTypes Bits16
      JVM_IntBits32 : JVM_IntTypes Bits32
      JVM_IntBits64 : JVM_IntTypes Bits64

  data JFloat : Type where
      Float : (d : Double) -> JFloat

  ||| Supported JVM function types
  data JVM_FnTypes : Type -> Type where
      JVM_Fn : JVM_Types s -> JVM_FnTypes t -> JVM_FnTypes (s -> t)
      JVM_FnIO : JVM_Types t -> JVM_FnTypes (JVM_IO t)
      JVM_FnBase : JVM_Types t -> JVM_FnTypes t

  data JVM_FunctionalObject : Type -> Type where
    MkJVMFunctionalObject : (lambdaFunctionTy : t) -> JVM_FunctionalObject t

  ||| Supported JVM foreign types
  data JVM_Types : Type -> Type where
      JVM_Bool        : JVM_Types Bool
      JVM_Str         : JVM_Types String
      JVM_Double      : JVM_Types Double
      JVM_Float       : JVM_Types JFloat
      JVM_BigInteger  : JVM_Types Integer
      JVM_Unit        : JVM_Types ()
      JVM_NativeT     : JVM_Types (JVM_Native a)
      JVM_IntT        : JVM_IntTypes i -> JVM_Types i
      JVM_ArrayT      : JVM_Types t -> JVM_Types (JVM_Array t)
      JVM_ThrowableT  : JVM_Types t -> JVM_Types (JVM_Throwable t)
      JVM_FnT         : JVM_FnTypes t -> JVM_Types (JVM_FunctionalObject t)

  data JVM_Array : Type -> Type where
    MkJvmTypesArray : JVM_Types t -> JVM_Array t

  ||| A descriptor for the JVM FFI. See the constructors of `JVM_Types`
  ||| and `JVM_IntTypes` for the concrete types that are available.
  FFI_JVM : FFI
  FFI_JVM = MkFFI JVM_Types JVM_FfiFn String

  JVM_IO : Type -> Type
  JVM_IO = IO' FFI_JVM

Show JFloat where
  show (Float d) = show d

%used MkJVMFunctionalObject lambdaFunctionTy

%used Float d

%inline
javacall : (fname : JVM_FfiFn) -> (ty : Type) ->
           {auto fty : FTy FFI_JVM [] ty} -> ty
javacall fname ty = foreign FFI_JVM fname ty

%inline
jcall : (fname : JVM_FfiFn) -> (ty : Type) ->
           {fty : FTy FFI_JVM [] ty} -> ty
jcall fname ty = foreign FFI_JVM fname ty

javaClass : String -> Type
javaClass = JVM_Native . Class

javaInterface : String -> Type
javaInterface = JVM_Native . Interface

%inline
invokeInstance : String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
invokeInstance method = javacall (Instance method)

%inline
invokeStatic : JVM_NativeTy -> String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
invokeStatic klass method = javacall (Static klass method)

interface Inherits a b where {}

Inherits (JVM_Native t) (JVM_Native t) where {}

IdrisObject : Type
IdrisObject = javaClass "io/github/mmhelloworld/idrisjvm/runtime/IdrisObject"

namespace Object
  ObjectClass : JVM_NativeTy
  ObjectClass = Class "java/lang/Object"

  Object : Type
  Object = JVM_Native ObjectClass

  ObjectArray : Type
  ObjectArray = JVM_Array Object

  ObjectArray2d : Type
  ObjectArray2d = JVM_Array (JVM_Array Object)

  toString : Object -> JVM_IO String
  toString obj = invokeInstance "toString" (Object -> JVM_IO String) obj

Inherits Object String where {}
Inherits Object (Maybe String) where {}

Inherits Object Integer where {}

Inherits Object (JVM_Native t) where {}
Inherits Object (Maybe (JVM_Native t)) where {}

Inherits ObjectArray (JVM_Array t) where {}

implicit subtyping : Inherits (JVM_Native t) (JVM_Native s) => JVM_Native s -> JVM_Native t
subtyping = believe_me

implicit subtypingInIo : Inherits (JVM_Native super) (JVM_Native sub) => JVM_IO (JVM_Native sub) -> JVM_IO (JVM_Native super)
subtypingInIo sub = believe_me <$> sub

implicit stringIsAnObject : String -> Object
stringIsAnObject = believe_me

decl syntax [sub] inherits [super] = Inherits (JVM_Native (super)) (JVM_Native (sub)) where {}

isNull : JVM_Native t -> Bool
isNull obj = unsafePerformIO $ invokeStatic (Class "java/util/Objects") "isNull" (Object -> JVM_IO Bool) (believe_me obj)

isNullString : String -> Bool
isNullString obj = unsafePerformIO $ invokeStatic (Class "java/util/Objects") "isNull" (Object -> JVM_IO Bool) (believe_me obj)

implicit nullableToMaybe : JVM_Native a -> Maybe (JVM_Native a)
nullableToMaybe t = if isNull t then Nothing else Just t

nullableStringToMaybe : String -> Maybe String
nullableStringToMaybe str = if isNullString str then Nothing else Just str

implicit maybeToNullable : Maybe (JVM_Native t) -> JVM_Native t
maybeToNullable (Just t) = t
maybeToNullable Nothing = believe_me prim__null

maybeToNullableString : Maybe String -> String
maybeToNullableString (Just t) = t
maybeToNullableString Nothing = believe_me prim__null

%inline
javalambda : String
        -> (interfaceFnTy: Type)
        -> {auto interfaceFnJvmTy: JVM_FnTypes interfaceFnTy}
        -> lambdaTy
        -> {auto lambdaJvmTy: JVM_FnTypes lambdaTy}
        -> JVM_Native nativeTy
javalambda {nativeTy} {lambdaTy} fname interfaceFnTy lambda = unsafePerformIO $
  javacall
    (Lambda nativeTy fname)
    (JVM_FunctionalObject interfaceFnTy -> JVM_FunctionalObject lambdaTy -> JVM_IO (JVM_Native nativeTy))

    {- This value is not used. This is here so that the corresponding type can provide the interface method signature
     - which can be different from the actual lambda signature
     -}
    (believe_me "")

    (MkJVMFunctionalObject lambda)

%inline
new : (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
new ty = javacall New ty

%inline
total
newArray : (elemTy: Type) -> {auto jvmElemTy: JVM_Types elemTy} -> Nat -> JVM_IO (JVM_Array elemTy)
newArray elemTy size = assert_total $ javacall NewArray (Int -> JVM_IO $ JVM_Array elemTy) (cast size)

%inline
setArray : (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
setArray ty = javacall SetArray ty

%inline
arrayLength : {auto ft: JVM_Types elemTy} -> JVM_Array elemTy -> JVM_IO Nat
arrayLength {elemTy} arr = cast <$> javacall ArrayLength (JVM_Array elemTy -> JVM_IO Int) arr

%inline
getArray : (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
getArray ty = javacall GetArray ty

%inline
newMultiArray : (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
newMultiArray = javacall MultiNewArray

%inline
getInstanceField : String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
getInstanceField fieldName = javacall (GetInstanceField fieldName)

%inline
setInstanceField : String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
setInstanceField fieldName = javacall (SetInstanceField fieldName)

%inline
getStaticField : JVM_NativeTy -> String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
getStaticField klass fieldName = javacall (GetStaticField klass fieldName)

%inline
setStaticField : JVM_NativeTy -> String -> (ty : Type) -> {auto fty : FTy FFI_JVM [] ty} -> ty
setStaticField klass fieldName = javacall (SetStaticField klass fieldName)

%inline
jcallInstance : String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallInstance method ty fty = jcall (Instance method) ty {fty=fty}

%inline
jcallStatic : JVM_NativeTy -> String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallStatic klass method ty fty = jcall (Static klass method) ty {fty=fty}

%inline
jcallNew : (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallNew ty fty = jcall New ty {fty=fty}

%inline
jcallGetInstanceField : String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallGetInstanceField fieldName ty fty = jcall (GetInstanceField fieldName) ty {fty = fty}

%inline
jcallSetInstanceField : String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallSetInstanceField fieldName ty fty = jcall (SetInstanceField fieldName) ty {fty = fty}

%inline
jcallGetStaticField : JVM_NativeTy -> String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallGetStaticField klass fieldName ty fty = jcall (GetStaticField klass fieldName) ty {fty = fty}

%inline
jcallSetStaticField : JVM_NativeTy -> String -> (ty : Type) -> FTy FFI_JVM [] ty -> ty
jcallSetStaticField klass fieldName ty fty = jcall (SetStaticField klass fieldName) ty {fty=fty}

%inline
instanceOf : Inherits Object obj => JVM_NativeTy -> obj -> Bool
instanceOf (Class className) obj = unsafePerformIO $ javacall (InstanceOf className) (Object -> JVM_IO Bool) (believe_me obj)
instanceOf (Interface className) obj = unsafePerformIO $ javacall (InstanceOf className) (Object -> JVM_IO Bool) (believe_me obj)

namespace Class

  ClassClass : JVM_NativeTy
  ClassClass = Class "java/lang/Class"

  JClass : Type
  JClass = JVM_Native ClassClass

  forName : String -> JClass
  forName className = unsafePerformIO $ invokeStatic ClassClass "forName" (String -> JVM_IO JClass) className

  isInstance : Inherits Object (JVM_Native t) => JClass -> JVM_Native t -> Bool
  isInstance clazz obj = unsafePerformIO $ invokeInstance "isInstance" (JClass -> Object -> JVM_IO Bool) clazz (believe_me obj)

%inline
classLit : String -> JClass
classLit s = unsafePerformIO $ javacall (ClassLiteral s) (JVM_IO JClass)

RuntimeClass : JVM_NativeTy
RuntimeClass = Class "io/github/mmhelloworld/idrisjvm/runtime/Runtime"

jthrow : Inherits Throwable t => t -> JVM_IO a
jthrow t = believe_me $ invokeStatic RuntimeClass "rethrow" (Throwable -> JVM_IO Object) (believe_me t)

VirtualMachineErrorClass : JVM_NativeTy
VirtualMachineErrorClass = Class "java/lang/VirtualMachineError"

ThreadDeathClass : JVM_NativeTy
ThreadDeathClass = Class "java/lang/ThreadDeath"

LinkageErrorClass : JVM_NativeTy
LinkageErrorClass = Class "java/lang/LinkageError"

InterruptedExceptionClass : JVM_NativeTy
InterruptedExceptionClass = Class "java/lang/InterruptedException"

VirtualMachineErrorClass inherits ThrowableClass
ThreadDeathClass inherits ThrowableClass
InterruptedExceptionClass inherits ThrowableClass
LinkageErrorClass inherits ThrowableClass

term syntax jcatch [clazz] = \t => instanceOf clazz t

try : JVM_IO (JVM_Throwable a) -> List (List (Throwable -> Bool), Throwable -> JVM_IO a) -> JVM_IO a
try action handlers = do
    value <- action
    either (go handlers) pure value
  where
    go : List (List (Throwable -> Bool), Throwable -> JVM_IO a) -> Throwable -> JVM_IO a
    go [] t = jthrow t
    go ((ps, handler) :: handlers) t =
      if any (\p => p t) ps then
        handler t
      else
        go handlers t

export
Show Throwable where
  show throwable = unsafePerformIO $ invokeStatic RuntimeClass "showThrowable"
                     (Throwable -> JVM_IO String) throwable

-- Inspired by Scala's NonFatal
catchNonFatal : Throwable -> Bool
catchNonFatal t = not (instanceOf VirtualMachineErrorClass t
                 && instanceOf ThreadDeathClass t
                 && instanceOf InterruptedExceptionClass t
                 && instanceOf LinkageErrorClass t)

term syntax "<@>" [name] [attrs] = Ann name attrs
term syntax "<@s>" [value] = AnnString value
term syntax "<@i>" [value] = AnnInt value
term syntax "<@by>" [value] = AnnByte value
term syntax "<@b>" [value] = AnnBoolean value
term syntax "<@ch>" [value] = AnnChar value
term syntax "<@sh>" [value] = AnnShort value
term syntax "<@l>" [value] = AnnLong value
term syntax "<@f>" [value] = AnnFloat value
term syntax "<@d>" [value] = AnnDouble value
term syntax "<@c>" [value] = AnnClass value
term syntax "<@enum>" [ty] [value] = AnnEnum ty value
term syntax "<@..>" [values] = AnnArray values
term syntax "<@@>" [ann] = AnnAnnotation ann
term syntax [name] "<@:>" [value] = (name, value)
