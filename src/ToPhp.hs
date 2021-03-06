module ToPhp where
import Types
import Print
import Data.List (intercalate)

simpleVarName :: VariableName -> String
simpleVarName x = case x of
    InstanceVar s -> s
    StaticVar s -> s
    ClassVar s -> s
    SimpleVar s -> s

varName :: Salty -> String
varName (Variable x) = toPhp x

class ConvertToPhp a where
    toPhp :: a -> String

instance ConvertToPhp VariableName where
  toPhp (InstanceVar s) = "$this->" ++ s
  toPhp (StaticVar s) = "static::$" ++ s
  toPhp (ClassVar s) = s
  toPhp (SimpleVar s) = '$':s

instance ConvertToPhp ArgumentType where
  toPhp (ArgumentType True typ False) = "@param " ++ typ ++ "|null"
  toPhp (ArgumentType False typ False) = "@param " ++ typ
  toPhp (ArgumentType True typ True) = "@return " ++ typ ++ "|null"
  toPhp (ArgumentType False typ True) = "@return " ++ typ

instance ConvertToPhp Visibility where
  toPhp Public = "public"
  toPhp Private = "private"

instance ConvertToPhp MagicConstant where
  toPhp MCLINE = "__LINE__"
  toPhp MCFILE = "__FILE__"
  toPhp MCDIR = "__DIR__"
  toPhp MCFUNCTION = "__FUNCTION__"
  toPhp MCCLASS = "__CLASS__"
  toPhp MCTRAIT = "__TRAIT__"
  toPhp MCMETHOD = "__METHOD__"
  toPhp MCNAMESPACE = "__NAMESPACE__"

instance ConvertToPhp Argument where
  toPhp (Argument (Just (ArgumentType False typ _)) name (Just default_)) = print3 "?% $% = %" typ name default_
  toPhp (Argument (Just (ArgumentType True typ _)) name (Just default_)) = print3 "?% $% = %" typ name default_
  toPhp (Argument (Just (ArgumentType False typ _)) name Nothing) = typ ++ " $" ++ name
  toPhp (Argument (Just (ArgumentType True typ _)) name Nothing) = print2 "?% $% = null" typ name
  toPhp (Argument Nothing name (Just default_)) = print2 "$% = %" name default_
  toPhp (Argument Nothing name Nothing) = "$" ++ name

instance (ConvertToPhp a1, ConvertToPhp a2) => ConvertToPhp (Either a1 a2) where
  toPhp (Left a) = toPhp a
  toPhp (Right a) = toPhp a

instance ConvertToPhp Salty where
  toPhp (Operation x op (WithNewLine y)) = (toPhp $ Operation x op y) ++ "\n"
  toPhp (Operation x@(Variable _) Equals (HigherOrderFunctionCall obj callName func accVar)) = toPhp $ HigherOrderFunctionCall obj callName func (varName x)

  -- this is a hack -- it's the same as the statement above just w the WithNewLine added.
  -- toPhp (Operation x@(Variable _) Equals (WithNewLine (HigherOrderFunctionCall obj callName func accVar))) = toPhp $ HigherOrderFunctionCall obj callName func (varName x)
  toPhp (Operation left Equals right) = (toPhp left) ++ " = " ++ (toPhp right)
  toPhp (Operation left NotEquals right) = (toPhp left) ++ " != " ++ (toPhp right)
  toPhp (Operation left PlusEquals right) = print3 "% = % + %" (toPhp left) (toPhp left) (toPhp right)
  toPhp (Operation left MinusEquals right) = print3 "% = % - %" (toPhp left) (toPhp left) (toPhp right)
  toPhp (Operation left MultiplyEquals right) = print3 "% = % * %" (toPhp left) (toPhp left) (toPhp right)
  toPhp (Operation left DivideEquals right) = print3 "% = % / %" (toPhp left) (toPhp left) (toPhp right)
  toPhp (Operation left OrEquals right) = print3 "% = % ?? %" (toPhp left) (toPhp left) (toPhp right)
  toPhp (Operation left ArrayPush right) = print2 "% []= %" (toPhp left) (toPhp right)
  toPhp (Operation left Add right) = print2 "% + %" (toPhp left) (toPhp right)
  toPhp (Operation left Subtract right) = print2 "% - %" (toPhp left) (toPhp right)
  toPhp (Operation left Divide right) = print2 "% / %" (toPhp left) (toPhp right)
  toPhp (Operation left Modulo right) = (toPhp left) ++ " % " ++ (toPhp right)
  toPhp (Operation left Multiply right) = print2 "% * %" (toPhp left) (toPhp right)
  toPhp (Operation left OrOr right) = print2 "% || %" (toPhp left) (toPhp right)
  toPhp (Operation left AndAnd right) = print2 "% && %" (toPhp left) (toPhp right)
  toPhp (Operation left NullCoalesce right) = print2 "% ?? %" (toPhp left) (toPhp right)
  toPhp (Operation left PlusPlus right) = print2 "% . %" (toPhp left) (toPhp right)
  toPhp (Operation left ArrayMerge right) = print2 "array_merge(%, %)" (toPhp left) (toPhp right)
  toPhp (Operation left ArrayDiff right) = print2 "array_diff(%, %)" (toPhp left) (toPhp right)
  toPhp (Operation left In right) = print2 "in_array(%, %)" (toPhp left) (toPhp right)
  toPhp (Operation left KeyIn right) = print2 "array_key_exists(%, %)" (toPhp left) (toPhp right)
  toPhp (Operation left InstanceOf right) = print2 "% instanceof %" (toPhp left) (toPhp right)
  toPhp (Operation left EqualsEquals right) = print2 "% == %" (toPhp left) (toPhp right)
  toPhp (Operation left LessThan right) = print2 "% < %" (toPhp left) (toPhp right)
  toPhp (Operation left LessThanOrEqualTo right) = print2 "% <= %" (toPhp left) (toPhp right)
  toPhp (Operation left GreaterThan right) = print2 "% > %" (toPhp left) (toPhp right)
  toPhp (Operation left GreaterThanOrEqualTo right) = print2 "% >= %" (toPhp left) (toPhp right)
  toPhp (Operation left Spaceship right) = print2 "% <=> %" (toPhp left) (toPhp right)

  toPhp (Function name args body visibility) = print4 "% %(%) {\n%\n}\n" (toPhp visibility) funcName funcArgs funcBody
    where funcName = case name of
            InstanceVar str -> "function " ++ str
            StaticVar str -> "static function " ++ str
            SimpleVar str -> "function " ++ str
          funcArgs = intercalate ", " $ map toPhp args
          funcBody = case body of
                          [Braces salties] -> print2 "%\n%" (concat . map toPhp . init $ salties) (addReturn . last $ salties)
                          x -> print2 "%\n%" (concat . map toPhp . init $ x) (addReturn . last $ x)

  toPhp (SaltyNumber s) = s
  toPhp (SaltyString s) = "\"" ++ s ++ "\""

  -- functions called without an object (bare)
  toPhp (FunctionCall Nothing (Right (SimpleVar str)) args) = print2 "%(%)" str (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall Nothing (Right (InstanceVar str)) args) = print2 "$this->%(%)" str (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall Nothing (Right (StaticVar str)) args) = print2 "static::%(%)" str (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall Nothing (Right (ClassVar str)) args) = "err classvar? " ++ str

  -- builtin bare functions
  toPhp (FunctionCall Nothing (Left VarDumpShort) args) = "var_dump(" ++ (intercalate ", " . map toPhp $ args) ++ ")"

  -- functions called on an obj
  toPhp (FunctionCall (Just (Variable (SimpleVar obj))) (Right funcName) args) = print3 "$%->%(%)" obj (simpleVarName funcName) (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall (Just (Variable (InstanceVar obj))) (Right funcName) args) = print3 "$this->%->%(%)" obj (simpleVarName funcName) (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall (Just (Variable (StaticVar obj))) (Right funcName) args) = print3 "static::%->%(%)" obj (simpleVarName funcName) (intercalate ", " . map toPhp $ args)
  toPhp (FunctionCall (Just (Variable (ClassVar obj))) (Right funcName) args) = print3 "%::%(%)" obj (simpleVarName funcName) (intercalate ", " . map toPhp $ args)

  -- same as above but with parens
  toPhp (FunctionCall (Just (Parens [obj])) (Right funcName) args) = print3 "(%)->%(%)" (toPhp obj) (simpleVarName funcName) (intercalate ", " . map toPhp $ args)

  toPhp (LambdaFunction [] body) =  toPhp body
  toPhp (LambdaFunction (a:args) body) = ("$" ++ a ++ " = null;\n") ++ (toPhp $ LambdaFunction args body)

  -- each
  toPhp (HigherOrderFunctionCall obj Each (LambdaFunction (loopVar:xs) body) _)  =
                print3 "foreach (% as $%) {\n%;\n}\n" (varName obj) loopVar (toPhp body)

  -- map
  toPhp (HigherOrderFunctionCall obj Map (LambdaFunction (loopVar:[]) body) accVar) =
                print5 "% = [];\nforeach (% as $%) {\n% []= %;\n}\n" accVar (varName obj) loopVar accVar (toPhp body)

  -- select
  toPhp (HigherOrderFunctionCall obj Select (LambdaFunction (loopVar:[]) body) accVar) =
                print6 "% = [];\nforeach (% as $%) {\nif(%) {\n% []= %;\n}\n}\n" accVar (varName obj) loopVar (toPhp body) accVar loopVar

  -- any
  toPhp (HigherOrderFunctionCall obj Any (LambdaFunction (loopVar:xs) body) accVar) =
                print5 "% = false;\nforeach (% as $%) {\nif(%) {\n% = true;\nbreak;\n}\n}\n" accVar (varName obj) loopVar (toPhp body) accVar

  -- all
  toPhp (HigherOrderFunctionCall obj All (LambdaFunction (loopVar:xs) body) accVar) =
                print5 "% = true;\nforeach (% as $%) {\nif(!%) {\n% = false;\nbreak;\n}\n}\n" accVar (varName obj) loopVar (toPhp body) accVar

  toPhp Salt = "I'm salty"
  toPhp (ReturnStatement s) = "return " ++ (toPhp s) ++ ";"
  toPhp (Parens s) = "(" ++ (concat $ map toPhp s) ++ ")"
  toPhp (Braces s) = concat $ map toPhp s
  toPhp (PhpLine line) = line
  toPhp (FlagName name) = "Feature::isEnabled('" ++ name ++ "')"
  toPhp (PhpComment str) = "// " ++ str ++ "\n"
  toPhp (SaltyComment str) = ""
  toPhp (Negate s) = "!" ++ (toPhp s)
  toPhp EmptyLine = ""
  toPhp (BackTrack s) = toPhp s

  toPhp (If cond thenFork (Just elseFork)) = print3 "if (%) {\n%\n} else {\n%\n}" (toPhp cond) (toPhp thenFork) (toPhp elseFork)
  toPhp (If cond thenFork Nothing) = print2 "if (%) {\n%\n}" (toPhp cond) (toPhp thenFork)
  toPhp (While cond body) = print2 "while (%) {\n%\n}" (toPhp cond) (toPhp body)
  toPhp (Class name Nothing Nothing body) = print2 "class % {\n%\n}" (toPhp name) (toPhp body)
  toPhp (Class name (Just extendsName) Nothing body) = print3 "class % extends % {\n%\n}" (toPhp name) (toPhp extendsName) (toPhp body)
  toPhp (Class name Nothing (Just implementsName) body) = print3 "class % implements % {\n%\n}" (toPhp name) (toPhp implementsName) (toPhp body)
  toPhp (Class name (Just extendsName) (Just implementsName) body) = print4 "class % extends % implements % {\n%\n}" (toPhp name) (toPhp extendsName) (toPhp implementsName) (toPhp body)
  toPhp (New name args) = print2 "new %(%)" (toPhp name) (intercalate "," . map toPhp $ args)

  toPhp (Variable x) = toPhp x
  toPhp (WithNewLine s) = (toPhp s) ++ "\n"
  toPhp (HashLookup h k) = print2 "%[%]" (toPhp h) (toPhp k)
  toPhp (FunctionTypeSignature n types) = "/**\n" ++ (concat $ map showType types) ++ " */\n"
    where showType t = " * " ++ (toPhp t) ++ "\n"

  toPhp (Constant vis name val) = print3 "% const % = %" (toPhp vis) name (toPhp val)
  toPhp (HashTable nameValuePairs) = "[\n" ++ hashBody ++ "\n]"
    where kvtoPhp (name, val) = print2 "    \"%\" => %" name (toPhp val)
          hashBody = intercalate ",\n" $ map kvtoPhp nameValuePairs

  toPhp (ArraySlice obj start Nothing) = print2 "array_slice(%, %)" (toPhp obj) (toPhp start)
  toPhp (ArraySlice obj (SaltyNumber start) (Just (SaltyNumber end))) = print3 "array_slice(%, %, %)" (toPhp obj) start newEnd
    where newEnd = show $ (read end :: Integer) - (read start :: Integer)
  toPhp (ArraySlice obj start (Just end)) = print4 "array_slice(%, %, % - %)" (toPhp obj) (toPhp start) (toPhp end) (toPhp start)
  toPhp (AttrAccess (Variable (ClassVar obj)) attrName) = print2 "%::%" obj attrName
  toPhp (AttrAccess obj attrName) = print2 "%->%" (toPhp obj) attrName
  toPhp (MultiAssign vars value) = (intercalate "\n" . map (\var -> print2 "% = %" (toPhp var) (toPhp value)) $ vars)
  -- toPhp (AttrAccess (Variable (InstanceVar obj)) attrName) = print2 "$this->%->%" obj attrName
  -- toPhp (AttrAccess (Variable (StaticVar obj)) attrName) = print2 "static::$%->%" obj attrName
  toPhp (Array salties) = "[" ++ (intercalate ", " . map toPhp $ salties) ++ "]"
  toPhp (SaltyBool TRUE) = "true"
  toPhp (SaltyBool FALSE) = "false"
  toPhp SaltyNull = "null"
  toPhp (SaltyMagicConstant c) = toPhp c
  toPhp (Keyword (KwUse var)) = "use " ++ (toPhp var)
  toPhp (Keyword (KwThrow salty)) = "throw " ++ (toPhp salty)
  toPhp (Keyword (KwRequire salty)) = "require " ++ (toPhp salty)
  toPhp (Keyword (KwRequireOnce salty)) = "require_once " ++ (toPhp salty)
  toPhp (Keyword (KwNamespace salty)) = "namespace " ++ (toPhp salty)
  toPhp (Keyword x) = "keyword not implemented yet: " ++ (show x)
  toPhp x = "not implemented yet: " ++ (show x)


addReturn :: Salty -> String
addReturn x@(ReturnStatement _) = toPhp x
addReturn x@(Operation var@(Variable _) Equals h@(HigherOrderFunctionCall obj callName func accVar)) = addReturn (HigherOrderFunctionCall obj callName func (varName var))
addReturn x@(Operation var@(Variable _) Equals (WithNewLine(h@(HigherOrderFunctionCall obj callName func accVar)))) = addReturn (HigherOrderFunctionCall obj callName func (varName var))
addReturn x@(Operation _ Equals _) = toPhp x
addReturn x@(Operation _ ArrayPush _) = toPhp x
addReturn x@(Operation left OrEquals _) = (toPhp x) ++ "\nreturn " ++ (toPhp left) ++ ";"
addReturn x@(Operation _ _ _) = "return " ++ (toPhp x)
addReturn (If cond thenFork (Just elseFork)) = print3 "if (%) {\n%\n} else {\n%\n}" (toPhp cond) (addReturn thenFork) (addReturn elseFork)
addReturn (If cond thenFork Nothing) = print2 "if (%) {\n%\n}" (toPhp cond) (addReturn thenFork)
addReturn (Braces s) = (concat . map toPhp . init $ s) ++ "\n" ++ (addReturn . last $ s)
addReturn (Variable s) = "return " ++ (toPhp s)
addReturn (WithNewLine x) = (addReturn x) ++ "\n"
addReturn p@(Parens x) = "return " ++ (toPhp p)
addReturn f@(FunctionCall o n a) = "return " ++ (toPhp f)
addReturn h@(HashTable kv) = "return " ++ (toPhp h)
addReturn a@(Array xs) = "return " ++ (toPhp a)
addReturn f@(HigherOrderFunctionCall _ Each _ _) = toPhp f
addReturn f@(HigherOrderFunctionCall _ _ _ accVar) = (toPhp f) ++ "\nreturn " ++ accVar
addReturn a@(AttrAccess _ _) = "return " ++ (toPhp a)
addReturn x@(SaltyNumber _) = "return " ++ (toPhp x)
addReturn x@(SaltyString _) = "return " ++ (toPhp x)
addReturn x = toPhp x
