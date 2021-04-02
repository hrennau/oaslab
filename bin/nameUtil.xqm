(:~
 : -------------------------------------------------------------------------
 :
 : : nameUtil.xq - tools supporting the evaluation and construction of names
 :
 : -------------------------------------------------------------------------
 :)
module namespace f="http://www.oaslab.org/ns/xquery-functions/name-util";

(:~
 : Translates a URI path into an XML name.
 :)
declare function f:pathToXMLName($path as xs:string)
        as xs:string? {
    let $name1 :=
    
        $path
        (: Special edits for paths :)
                                                 (: ID='{XY}' => ID :)        
        (:              ID    =    '    {     ID    '               :)
        ! replace(., '([^_]+)_003d_0027_007b([^_]+)_007d', '$1') 
        ! replace(., '_007b(\i\c*?)_007d', '$1')  (: {Foo} => Foo :)       
        ! replace(., '_0028(.*?)_0029', '.$1.')   (: (bar) => .bar. :)
        ! replace(., '^(_0020)*_002f', '')        (: discard leading slash (optionally preceded by WS) :)
         
        (: General edits for item names :)
        ! f:jsonKeyToXMLName(.)            (: standard editing :)
    return $name1
};

(:~
 : Maps a JSON key to an XML name to be used by element declarations
 : or type definitions.
 :)
declare function f:jsonKeyToXMLName($jsonKey as xs:string)
        as xs:string {
    let $name1 :=
    
    $jsonKey
    
    (: discard leading/trailing whitespace :)    
    ! replace(., '^(_0020)+|(_0020)+$', '')
    
    (: insert underscore before leading digit  :)    
    ! replace(., '^_003(\d)', '_$1')
    ! replace(., '^(\d)', '_$1') (: Special case:
                                    if the input is not the original element name, the digit may not be encoded :)
    
    (: Removals: '$ :)
    ! replace(., '_0027', '')    (: ' :)
    ! replace(., '_0024', '')     (: $ :)    
    
    (: Removal: Whitespace followed by: - :)
    ! replace(., '(_0020)+([\-])', '$2')
    
    (: @ => _at_ :)
    ! replace(., '_0040', '_at_')
    
    (: Character references :)
    ! replace(., '_0026amp_003b', '.')   (: &amp; :)
    ! replace(., '_0026gt_003b', 'gt_')  (: &gt; :)
    ! replace(., '_0026lt_003b', 'lt_')  (: &lt; :)
    
    (: Replacements with dot: /:&? :)
    ! replace(., '_002f',  '.')          (: / :)                         
    ! replace(., '_003a',  '.')          (: : :)
    ! replace(., '_0026', '.')           (: & :)
    ! replace(., '_003f', '.')           (: ? :)

    (: Replacements with uderscore: WS{}()[]«»,=*! :)
    ! replace(., '_0020',  '_')   (: WS :)
    ! replace(., '_007b',  '_')   (: { :)
    ! replace(., '_007d',  '_')   (: } :)
    ! replace(., '_0028',  '_')   (: ( :)    
    ! replace(., '_0029',  '_')   (: ) :)
    ! replace(., '_005b',  '_')   (: [ :)    
    ! replace(., '_005d',  '_')   (: ] :)
    ! replace(., '_00ab',  '_')   (: « :)
    ! replace(., '_00bb',  '_')   (: » :)
    ! replace(., '_002c',  '_')   (: , :)
    ! replace(., '_003d',  '_')   (: = :)
    ! replace(., '_002a',  '_')   (: * :)
    ! replace(., '_0021',  '_')   (: ! :)
    
    (: Final cleanup: remove trailing and leading . :)
    let $name2 :=    
        if (string-length($name1) gt 1) then replace($name1, '\.$', '') else $name1
    let $name3 :=    
        if (string-length($name2) gt 1) then replace($name2, '^\.', '') else $name2
    (: Collapse a sequence of dots into a single dot :)
    let $name4 := replace($name3, '\.\.', '.')   
    (: Double underscore -> single underscore :)
    let $name5 := $name4 ! replace(., '__', '_')
    
    return $name5
};   

(:~
 : Maps a JSON name to an XML name. If the name is an NCName, it is retained unchanged.
 : Otherwise, the result is obtained by converting the JSON name into a JSON key and
 : translating the key to an XML name, using 'jsonKeyToXMLName()'.
 :)
declare function f:jsonNameToXMLName($jsonName as xs:string) as xs:string {
    (: NCName - retained :)
    if ($jsonName castable as xs:NCName) then $jsonName
    
    (: Otherwise: convert to key and translate :)
    else 
        let $key := convert:encode-key($jsonName)
        let $name := f:jsonKeyToXMLName($key)
        return $name
};

(:~
 : Maps a schema reference to an XSD type name. The XSD type name 
 : is the name of the XSD type definition representing the type 
 : defining schema object.
 :
 : Note that the input is an original JSON name (e.g. 'a b'), not 
 : the JSON key ('a_0020b') as constructed by BaseX when a JSON name 
 : is mapped to an element name.
 :
 : @param ref a schema reference
 : @return a type name chosen to represent the referenced schema
 :)
declare function f:refToTypeName($ref as xs:string) as xs:QName {
    let $locationPath := substring-after($ref, '#/')
    let $locationNameJSON := replace($locationPath, '.+/', '') ! replace(., '^\s+|\s+$', '')
    let $locationNameXML := f:jsonNameToXMLName($locationNameJSON) 
    return QName((), $locationNameXML)
};

(:~
 : Constructs an element name reflecting the contents of a Schema Object.
 :
 : @param schemaObject a Schema Object
 : @return an element name, or the empty string if name construction failed
 :)
declare function f:schemaObjectToXsdElemName($schemaObject as element(), 
                                             $oad as element(json))
        as xs:string? {
    ()        
};

(:
(:~
 : Maps the raw type name to a qualified name. Scalar JSON types
 : are mapped to XSD simple types, other types are mapped to a
 : type name which combines the local name with an empty
 : namespace URI. 
 :
 : @param type the type string
 : @return a qualified name
 :)
declare function f:editTypeName($type as xs:string) as xs:QName {
    let $name :=
        if ($type eq 'number') then 'xs:decimal' else    
        let $isBuiltinType := $type = ('integer', 'boolean', 'double', 'long', 'string')
        return concat('xs:'[$isBuiltinType], $type)
    return
        QName($const:URI_XSD, $name)
};
:)

(:
(:~
 : Returns the XSD type name to be used as the @base type of a type.
 :
 : Precondition: the schema object must have either a "$ref" child 
 : or a "type" child.
 :
 : @param schemaObject a schema object representing an element
 : @return a type name to be used in the @type attribute of the XSD element declaration
 :)
declare function f:baseTypeName($schemaObject as element()) 
        as xs:QName {
    let $reference := ref:getComponentReference($schemaObject)
    return
        if ($reference) then $reference/f:refToTypeName(.)
        else
            let $rawName := $schemaObject/util:getTypeOrDefaultType1(type)
            return
                if (not($rawName)) then 
                    error(QName((), 'PROGRAM_ERROR'), 
                        'This function must not be called for a schema object without type or ref.')
                else f:editTypeName($rawName)
};
:)

