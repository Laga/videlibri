xquery version "3.1-xidel";
module namespace ig="ig";

declare function ig:parent($e){
  $e/@extends[. ne "FastInterfacedObject"]
};

declare function ig:ancestors($e){
  let $parent-id := ig:parent($e)
  let $parent := $e/root()//class[@id = $parent-id]
  where $parent
  return (ig:ancestors($parent), $parent)
};


declare function ig:jni-name($c){
  typeswitch ($c)
    case element(class) return "de/benibela/videlibri/jni/"||$c/@id
    case element(string) return "java/lang/String"
    case element(classref) return "de/benibela/videlibri/jni/"||$c/@ref
    default return 
      "de/benibela/videlibri/jni/"||$c
};



declare function ig:pascal-make-class($s){
$s/(let $virtual := if (ig:parent(.)) then "override;" else "virtual;" return x"
type T{@id} = class{@extends!concat("(T",.,")")}
  {join(( if (./string) then join(./string/@name, ", ") || ": string;" else (),
  ./array/x"{@name}: array of {(classref/@ref!concat("T",.), string!"string")};",
  if (not(ig:parent(.))) then "procedure toJSON(var builder: TJSONXHTMLStrBuilder);
  function toJSON(): string;" else (),
  if (.//classref) then "destructor destroy; override;" else ()), "&#x0A;  ")
  }
  class function fromJSON(json: string): T{@id};
  class function fromJSON(json: TJSONScanner): T{@id};
protected
  procedure appendToJSON(var builder: TJSONXHTMLStrBuilder); {$virtual}
  class function readTypedObject(scanner: TJSONScanner): T{@id}; //['type', {{obj}}]
  class function readObject(obj: T{@id}; scanner: TJSONScanner): T{@id};
  procedure readProperty(scanner: TJSONScanner);  {$virtual}
  class function typeId: string; {$virtual}
public
  {{$ifdef android}}
  function toJava: jobject; {$virtual}
  {{$endif}}
end;")
};
declare function ig:pascal-make($r){
x"unit commoninterface;
{{$mode objfpc}}{{$H+}}
{{$ModeSwitch typehelpers}}{{$ModeSwitch advancedrecords}}{{$ModeSwitch autoderef}}
interface
 uses sysutils, simplexmlparser, xquery.internals.common, jsonscanner, jsonscannerhelper {{$ifdef android}}, jni, bbjniutils{{$endif}};
 type EVideLibriInterfaceException = class(Exception);
 { let $arrayrefs := distinct-values($r/api//array/classref/@ref)
   where exists($arrayrefs)
   return ("type " || join($arrayrefs ! x"T{.} = class; T{.}Array = array of T{.}; "))
 }
 { $r/api/class/ig:pascal-make-class(.) }
 {{$ifdef android}}
 procedure initBridge;
 {{$endif}}
implementation
uses bbutils, math;


type TStringArray = array of string;
procedure readArray(var sa: TStringArray; scanner: TJSONScanner); overload;
var temp: TStringArrayList;
  pname: String;
begin
  scanner.fetchNonWSToken; scanner.expectCurrentToken(tkSquaredBraceOpen);
  temp.init;
  while true do begin
    case scanner.fetchNonWSToken of
      tkString: temp.add(scanner.CurTokenString);
      tkComma:;
      tkSquaredBraceClose: break;
      else scanner.raiseUnexpectedError();
    end;
  end;

  sa := temp.toSharedArray;
end;        

type TStringHelper = type helper for string
  procedure toJSON(var builder: TJSONXHTMLStrBuilder);
end;
procedure TStringHelper.toJSON(var builder: TJSONXHTMLStrBuilder);
begin
  builder.appendJSONString(self);
end;

{let $arrayrefs := distinct-values($r/api//array/classref/@ref)
   where exists($arrayrefs)
return $arrayrefs!x"
type T{.}ArrayList = specialize TCopyingPtrArrayList<T{.}>;
procedure readArray(var p: T{.}Array; scanner: TJSONScanner); overload;
var temp: T{.}ArrayList;
begin
  scanner.fetchNonWSToken; scanner.expectCurrentToken(tkSquaredBraceOpen);
  temp.init;
  while true do begin
    case scanner.fetchNonWSToken of
      tkString: temp.add(T{.}.readTypedObject(scanner));
      tkComma: ;
      tkSquaredBraceClose: break;
      tkCurlyBraceOpen: temp.add(T{.}.readObject(T{.}.create, scanner));
      else scanner.raiseUnexpectedError();
    end;
  end;

  p := temp.toSharedArray;
end;"}        

{
$r/api/class/(
.[not(ig:parent(.))]!
x"procedure T{@id}.toJSON(var builder: TJSONXHTMLStrBuilder);
begin
  with builder do begin
    appendJSONObjectStart;
    self.appendToJSON(builder);
    appendJSONObjectEnd;
  end;
end;

function T{@id}.toJSON(): string;
var b:  TJSONXHTMLStrBuilder;
begin
  b.init(@result);
  toJSON(b);
  b.final;
end;

",

x"procedure T{@id}.appendToJSON(var builder: TJSONXHTMLStrBuilder);{if (./array) then "&#x0A;var i: sizeint;" else ()}
begin{ig:parent(.)!"
  inherited;
  builder.appendJSONObjectComma;"
  }
  with builder do begin    
    {join(./*/(typeswitch(.) 
      case element(string) return x"appendJSONObjectKeyColon('{@name}'); appendJSONString(self.{@name});"
      case element(array) return x"appendJSONObjectKeyColon('{@name}'); appendJSONArrayStart();
    if length({@name}) > 0 then begin{
      if (classref) then x"
      appendJSONString({@name}[0].typeId);
      appendJSONArrayComma();
      " else ()}
      {@name}[0].toJSON(builder);
    end;
    for i := 1 to high({@name}) do begin
      appendJSONArrayComma();
      {if (classref) then x"
      appendJSONString({@name}[i].typeId);
      appendJSONArrayComma();
      " else ()}
      {@name}[i].toJSON(builder);
    end;
    appendJSONArrayEnd();"
      default return ()), " appendJSONObjectComma;&#x0A;    " )}
    
  end;
end;

class function T{@id}.fromJSON(json: string): T{@id};
var scanner: TJSONScanner;
begin
  scanner := TJSONScanner.Create(json, [joUTF8, joIgnoreTrailingComma]);
  scanner.fetchNonWSToken;
  result := fromJSON(scanner);
  scanner.free;
end;
class function T{@id}.fromJSON(json: TJSONScanner): T{@id};
begin
  result := readObject(T{@id}.create, json);
end;

class function T{@id}.readObject(obj: T{@id}; scanner: TJSONScanner): T{@id};
begin
  result := obj;
  scanner.expectCurrentToken(tkCurlyBraceOpen); scanner.fetchNonWSToken;
  while true do begin    
    case scanner.curtoken of
      tkString: result.readProperty(scanner);
      tkEOF: exit;
      tkCurlyBraceClose: exit;
      tkComma: scanner.fetchNonWSToken;
      else scanner.raiseUnexpectedError();
    end;
  end;
end;

class function T{@id}.readTypedObject(scanner: TJSONScanner): T{@id}; 
var additionalArray: boolean;
begin
  additionalArray := scanner.curtoken = tkSquaredBraceOpen;
  if additionalArray  then scanner.fetchNonWSToken;
  scanner.expectCurrentToken(tkString);
  case scanner.CurTokenString of
  {let $id := @id return (., /api/class[$id = ig:ancestors(.)/@id])!x"
    '{@id}': result := T{@id}.create;"}
  else scanner.raiseUnexpectedError();
  end;
  scanner.fetchNonWSToken; scanner.expectCurrentToken(tkComma);
  scanner.fetchNonWSToken;
  result := readObject(result, scanner);
  if additionalArray then begin
    scanner.fetchNonWSToken; scanner.expectCurrentToken(tkSquaredBraceClose);
  end;
end;

procedure T{@id}.readProperty(scanner: TJSONScanner);
begin
  case scanner.CurTokenString of
    {join(*/(typeswitch (.) 
      case element(string) return x"'{@name}': begin
        scanner.fetchNonWSToken; scanner.expectCurrentToken(tkColon); 
        scanner.fetchNonWSToken; scanner.expectCurrentToken(tkString); 
        {@name} := scanner.CurTokenString;
        scanner.fetchNonWSToken;
      end;"
      case element(array) return x"'{@name}': begin
        scanner.fetchNonWSToken; scanner.expectCurrentToken(tkColon); 
        readArray({@name}, scanner);
        scanner.fetchNonWSToken;
      end;"
      default return ()
    ), "&#x0A;    ")
    }
    else {if (ig:parent(.)) then "inherited;" else "scanner.skipObjectPropertyValue();"
    }
  end;
end;

class function T{@id}.typeId: string;
begin
  result := '{@id}'
end;

", .[.//classref]/(
x"destructor T{@id}.destroy;{if (./array[classref]) then "&#x0A;var i: integer;" else ()}
begin {./array[classref]/x"&#x0A;  for i := 0 to high({@name}) do {@name}[i].free;"}
  inherited;
end;"
))
}

{{$ifdef android}}
var {$r/api/class/x"
  {@id}Class: jclass;
  {@id}ClassInit: jmethodID;
"}

{ distinct-values($r/api//array/classref/@ref)!x"
function arrayToJArray(const a: T{.}Array): jobject; overload;
var
  i: Integer;
begin
  with j do begin
    result := newObjectArray(length(a), {.}Class, nil);
    for i := 0 to high(a) do
      setObjectArrayElementAndDelete(result, i, a[i].toJava);
  end;
end;
" }
function arrayToJArray(const a: array of string): jobject; overload;
begin;
  result := j.arrayToJArray(a);
end;

{ $r/api/class/(let $allprops := (ig:ancestors(.),.)/* return x"
function T{@id}.toJava: jobject;
var temp: array[0..{count($allprops) - 1}] of jvalue;
begin
 {for $p at $i1 in $allprops let $i := $i1 - 1 return 
   typeswitch ($p) 
     case element(string) return x"   temp[{$i}].l := j.stringToJString(self.{$p/@name});&#x0A;"
     case element(array) return x"   temp[{$i}].l := arrayToJArray(self.{$p/@name});&#x0A;"
     default return ()
   }
  with j do begin
    result := newObject({@id}Class, {@id}ClassInit, @temp[0]); 
 {for $p at $i in $allprops return x"   deleteLocalRef(temp[{$i - 1}].l);&#x0A;"}
 end;
end;
")
}


procedure initBridge;
begin
  with needJ do begin {$r/api/class/x"
    {@id}Class := newGlobalRefAndDelete(getclass('{ig:jni-name(.)}'));
    {@id}ClassInit := getmethod({@id}Class, '<init>', '({join((ig:ancestors(.),.)/*/(typeswitch(.)
      case element(string) return "Ljava/lang/String;" 
      case element(array) return concat("[L", ig:jni-name(*), ";")
      default return ())
      , "")})V');"}
  end;
end;
{{$endif}}
end.
"
};

declare function ig:kotlin-make-prop($s){
  $s/(typeswitch (.) 
    case element(string) return @name || ": String" 
    case element(array) return x"{@name}: Array<{(classref/@ref, string!"String")}>" 
    default return () 
  )
};

declare function ig:kotlin-make-class($s){
  let $a := ig:ancestors($s)
  let $aprops := $a/*
  return
  $s/(x"
  open class {@id}( 
    { join ((
    $aprops!ig:kotlin-make-prop(.),
    */ig:kotlin-make-prop(.)!concat("val ",.)
  ), ",&#x0A;    ") 
  }
  ) {ig:parent(.)!x": {.}({join($aprops!@name, ", ")})"}  {{
    override fun equals(other: Any?): Boolean =
       other != null &amp;&amp; {join(("javaClass == other.javaClass", "other is " || @id, (*,$aprops)/(
         typeswitch (.)
           case element(string) return concat(@name, " == other.", @name)
           case element(array) return concat(@name, ".contentEquals(other.", @name,")")
           default return ()
       )), " &amp;&amp; ")}

  }}")
};
declare function ig:kotlin-make($r){
  x"@file:Suppress(""EqualsOrHashCode"")
package de.benibela.videlibri.jni;
class PropertyArray(val names: Array<String>, values: Array<String>)
{ $r/api/class/ig:kotlin-make-class(.)} "
};


 