(:
 : -------------------------------------------------------------------------
 :
 : schemaPattern.xqm - functions analyzing schema patterns
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/schema-pattern";

import module namespace foxf="http://www.foxpath.org/ns/fox-functions"
at "tt/_foxpath-fox-functions.xqm";

import module namespace name="http://www.oaslab.org/ns/xquery-functions/name-util" 
at "nameUtil.xqm";

import module namespace ref="http://www.oaslab.org/ns/xquery-functions/ref" 
at "ref.xqm";

declare namespace z="http://www.ttools.org/businesshub/ns/structure";

(:~
 : Returns a node name for a message schema, along with optional information
 : "operationId" and "HTTP method". The rationale behind the optional
 : information is that there are cases when the schema-derived name
 : is regarded as inferior to a name based on the actual operation.
 : This is namely the case when the message type is a built-in type
 : like "string" or "integer array".
 :
 : The return value is a map with the fields:
 : - msgNodeName: proposed name for the message root node
 : - type: a compact textual representation of the schema content
 : - pattern: a string identifying a pattern of schema structure
 : - warning: an optional warning
 :
 : When a message node name could not be derived, the field 'msgNodeName'
 : is not added.
 :
 : @param schema the JSON Schema describing the message
 : @param operationId the operation Id from the OpenAPI document
 : @param uriPath the URI path associated with the operation
 : @param httpMethod the HTTP method of the operation
 : @param msgRole the message role - e.g. "input", "output", "fault", "output-203", "fault-400"
 : @return a proposal for the root node name
 :) 
declare function f:msgNodeName($schema as element(),
                               $operationId as xs:string?,
                               $uriPath as xs:string?, 
                               $httpMethod as xs:string?,
                               $msgRole as xs:string?,
                               $useArraySuffix as xs:boolean?)
        as map(xs:string, item()*) {
    let $schemaDescription := f:schemaDescription($schema)
    let $arraySuffix := 'Instances'[$useArraySuffix]
    let $msgNodeName :=
        switch($schemaDescription?pattern)
        
        (: named-type # node-name = type-name :)
        case 'named-type' return $schemaDescription?type
                
        (: named-type-array # node-name = type-name :)
        (: Note: no suffix, as the elements are wrapped in a
                 root element with name: item-name + 'Instances' :)
        case 'named-type-array' return $schemaDescription?type
               
        (: named-type-pseudo-allof # node-name = type-name :)
        case 'named-type-pseudo-allof' return $schemaDescription?type
                
        (: simple-type # perfer operation-derived node-name; if not available: node-name = type-name :)
        case 'simple-type' return
            let $operationDerived := 
                f:msgNodeNameDerivedFromOperation($operationId, $uriPath, $httpMethod, $msgRole)
            return
                if ($operationDerived) then $operationDerived
                else $schemaDescription?type ! replace(., '^#', '')
                
        (: simple-type # perfer operation-derived node-name; if not available: node-name = item type-name :)
        (: Note: no suffix, as the elements are wrapped in a
                 root element with name: item-name + 'Instances' :)
        case 'simple-type-array' return
            let $operationDerived :=
                f:msgNodeNameDerivedFromOperation($operationId, $uriPath, $httpMethod, $msgRole)
            return
                if ($operationDerived) then $operationDerived
                else $schemaDescription?type ! replace(., '^#|\*$', '')
                
        (: named-property-item-type # node-name = type-name ___items 
                                                  or
                                                  type-name -array-property- property-name :)
        case 'named-property-item-type' return
            let $type := $schemaDescription?type
            return
                if ($type) then
                    if (matches($type, '^.*\{value\*\}')) then
                        replace($type, '^(.*)\{.*', '$1-items')
                    else
                        replace($type, '^(.*)\{(.*)\*\}', '$1-array-property-$2')
                else ()
         
        (: named-property-type-pair # node-name = type-name1 ---and--- type-name2 :)
        case 'named-property-type-pair' return
            let $type := $schemaDescription?type
            return
                if ($type) then replace($type, '^.*\{(.*?)\}.*\{(.*?)\}', '$1---and---$2')
                else () 
            
        (: named-property-type # node-name = type-name -item :
                                             or
                                             type-name -property- property-name :)
        case 'named-property-type' return
            let $type := $schemaDescription?type
            return
                if ($type) then 
                    (: property name = 'd' :)
                    if (matches($type, '^.*\{d\}')) then
                        replace($type, '^(.*)\{(.*?)\}', '$1-item')
                    else
                        replace($type, '^(.*)\{(.*?)\}', '$1-property-$2')
                else ()
                
        (: simple-type-single-property # node-name = xsd_ type-name -property- property-name:)
        case 'simple-type-single-property' return
            $schemaDescription?type ! replace(., '#(.*?)\{(.*?)\}', '$1-property-$2')

        (: named-property-chain-item-type # node-name = type-name -results :)
        case 'named-property-chain-item-type' return
            $schemaDescription?type ! replace(., '\{.*', '-results')
                
        (: empty-object # node-name = empty-object :)
        case 'empty-object' return
            'empty-object'
            
        default return f:msgNodeNameDerivedFromOperation($operationId, $uriPath, $httpMethod, $msgRole)

    let $msgNodeName :=
        let $isArray := $schemaDescription?isArray eq 'true'
        let $prefix := 
            if (matches($msgNodeName, '^(opid|oppm):')) then ()
            else if ($isArray) then 'nams:'
            else 'name:'
        let $suffix := if (not($isArray)) then () else 'Instances'
        return $prefix || $msgNodeName || $suffix
    (: Add description entry: msgNodeName :)
    let $schemaDescription :=    
        if ($msgNodeName) then map:put($schemaDescription, 'msgNodeName', $msgNodeName)
        else $schemaDescription
    (: Add description entry: msgRootNodeName :)        
    let $schemaDescription :=
        if ($schemaDescription?isArray eq 'true') then
            map:put($schemaDescription, 'msgRootNodeName', $msgNodeName || 'Instances')
        else $schemaDescription
    return
        $schemaDescription
};

(:~
 : Returns a message root element name dependent on the operation,
 : disregarding the message schema. This function is intended to
 : be called by `msgNodeName` in cases when a schema-derived
 : name cannot be determined or would be regarded as inferior
 : to an operation-derived name.
 :
 : @param operationId the operation Id from the OpenAPI document
 : @param uriPath the URI path associated with the operation
 : @param httpMethod the HTTP method of the operation
 : @param msgRole the message role - e.g. "input", "output", "fault", "output-203", "fault-400"
 : @return an element name
 :)
declare function f:msgNodeNameDerivedFromOperation(
                               $operationId as xs:string?,
                               $uriPath as xs:string?,                               
                               $httpMethod as xs:string?,
                               $msgRole as xs:string?)
        as xs:string? {
    if (not($msgRole)) then () else        
    (
    if ($operationId[. castable as xs:NCName]) then 'opid:' || $operationId
    else if ($uriPath) then
        'oppm:' || (
        $uriPath 
        ! convert:encode-key(.) 
        ! name:pathToXMLName(.) 
        || '-' || lower-case($httpMethod))
    else ()
    ) ! concat(., '-', lower-case($msgRole))
};        

(:~
 : Maps a Schema Object to a description. This is a map with
 : fields ...
 : - type: a compact textual representation of the schema content
 : - pattern: a string identifying a pattern of schema structure
 : - warning: an optional warning
 :
 : Possible values of 'pattern':
 : * array-single-property 
 : * empty-object
 : * empty-object-array
 : * local-object
 : * local-object-array 
 : * local-object-array-single-property 
 : * local-object-additional-properties
 : * local-object-single-property
 : * named-property-chain-item-type
 : * named-property-item-type 
 : * named-property-type
 : * named-property-type-pair 
 : * named-type                              # the schema references a named type
 : * named-type-array                        # the item schema references a named type 
 : * named-type-etc-allof 
 : * named-type-pseudo-allof
 : * not-recognized-type-array
 : * other-type 
 : * simple-type
 : * simple-type-array
 : * simple-type-array-single-property 
 : * simple-type-property-chain
 : * simple-type-single-property
 : * single-property-array
 : * status-and-message
 : * $itemType-array-single-property
 : * $propertyType || '-single-property' 
 :)
declare function f:schemaDescription($schema as element())
        as map(xs:string, xs:string) {
    let $oas := $schema/ancestor::*[last()]
    let $typeSchema := $schema/_0024ref/foxf:resolveJsonRef(., $oas, 'recursive')
    let $itemTypeSchema := $schema/items/_0024ref/foxf:resolveJsonRef(., $oas, 'recursive')
    let $children := $schema/(* except (description, example))[not(starts-with(name(), 'x-'))]
    let $itemsChildren := $schema/items/(* except (description, example))[not(starts-with(name(), 'x-'))]    
    return
    
    (: named-type :)
    if ($schema/_0024ref) then 
        let $pattern := 'named-type'
        return
            if ($typeSchema) then
                let $warning :=
                    if (count($children) gt 1) then 
                        'Schema ref plus additional content; child names: ' || string-join($schema/*/name(), ', ')
                    else ()
                return
                    map:merge((
                        map:entry('type', $typeSchema/local-name(.)),
                        map:entry('pattern', $pattern),
                        $warning ! map:entry('warning', .)))
        else
            map{'warning': concat('REF_NOT_RESOLVABLE=', $schema/_0024ref),
                'pattern': $pattern}
                    
    (: named-type-array :)    
    else if ($schema/items/_0024ref) then 
        let $pattern := 'named-type-array'
        return
            if ($itemTypeSchema) then
                let $warning :=
                    if (count($itemsChildren) gt 1) then 
                        'Schema ref plus additional content; child names: ' 
                        || string-join($schema/items/*/name(), ', ')
                    else ()
                return
                    map:merge((
                        map:entry('type', $itemTypeSchema/local-name(.)),
                        map:entry('pattern', $pattern),
                        map:entry('isArray', 'true'),
                        $warning ! map:entry('warning', .)))
            else
                map{'warning': concat('ITEM_TYPE_REF_NOT_RESOLVABLE=', $schema/items/_0024ref),
                    'pattern': $pattern}
                
            (: Omitted - analysis if the $ref has siblings :)
            
    (: named-type-pseudo-allof (allOf consisting of a single named type) :)
    else if ($schema/allOf[count(*) eq 1]/_/_0024ref) then
        let $memberSchema := $schema/allOf/_/_0024ref/foxf:resolveJsonRef(., $oas, 'recursive')
        let $pattern := 'named-type-pseudo-allof'
        return
            if ($memberSchema) then
                map{'type': $memberSchema/local-name(.),
                    'pattern': $pattern}
            else
                map{'warning': concat('ALL_OF_MEMBER_TYPE_REF_NOT_RESOLVABLE=', $schema/items/_0024ref),
                    'pattern': $pattern}
            
    (: named-type-etc-allof (allOf including named type) :)
    else if ($schema/allOf/_/_0024ref) then
        let $memberSchemas := $schema/allOf/_/_0024ref/foxf:resolveJsonRef(., $oas, 'recursive')
        return
            map{'type': string-join(($memberSchemas/local-name(.) => string-join(', '), 
                                     $schema/allOf/_[not(_0024ref)]/'#local-type')
                        , '+') || '~(ALLOF)',
                'pattern': 'named-type-etc-allof'}
                
    (: simple-type :)
    else if ($schema/type = ('file', 'string', 'boolean', 'integer', 'number')) then
        map{'type': '#' || $schema/type,
            'pattern': 'simple-type'}
                
    (: simple-type-array :)
    else if ($schema/items/type[. = ('file', 'string', 'boolean', 'integer', 'number')]) then
        map{'type': '#' || $schema/items/type || '*',
            'isArray': 'true',
            'pattern': 'simple-type-array'}
                    
    (: empty-object :)
    else if ($schema/type = 'object' and count($children) eq 1) then
        map{'type': '#empty-object',
            'pattern': 'empty-object'}
                
    (: empty-object-array :)
    else if ($schema/items/type = 'object' and count($itemsChildren) eq 1) then
        map{'type': '#empty-object*',
            'isArray': 'true',
            'pattern': 'empty-object-array'}
                
    (: not-recognized-type-array :)
    else if ($schema/items/type[not(. = ('object', 'array'))]) then
        map{'type': '#' || $schema/items/type || '*' || '~(UNEXPECTED_TYPE)',
            'isArray': 'true',
            'pattern': 'not-recognized-type-array'}
                
    (: Object with additional properties :)
    else if ($schema[not(properties)]/additionalProperties/type) then
        map{'type': '#object-with-additional-properties(' || $schema/additionalProperties/type || ')',
            'pattern': 'local-object-additional-properties'}

    (: named-property-type-pair :)
    else if ($schema/properties[count(*) eq 2]
                     [*[1]/_0024ref]
                     [*[2]/_0024ref]) then
        let $types := 
            <properties>{            
                for $p at $pos in $schema/properties/* 
                let $tname := $p/_0024ref/ref:refValueName(.)
                return <property name="{$p/name()}" type="{$tname}"/>
            }</properties>
        let $typeLabel := concat(
            $types/property[1]/concat(@type, '{', @name, '}'),
                 '+',
            $types/property[2]/concat(@type, '{', @name, '}'))                 
        return
            map{'type': $typeLabel,
                'pattern': 'named-property-type-pair'}
                
    (: named-property-type   (object type with single property 
                              with a named type) :)
    else if ($schema/properties[count(*) eq 1]/*/_0024ref) then 
        let $p := $schema/properties/*
        let $pname := $p/name()        
        let $tname := $p/_0024ref/ref:refValueName(.)
        let $postfix := if ($pname eq 'd') then '#d' else ()
        return
            map{'type': $tname || '{' || $pname || '}',
                'pattern': 'named-property-type' || $postfix}
                
    (: named-property-item-type   (object type with single property 
                                   with a named item type) :)
    else if ($schema/properties[count(*) eq 1]/*/items/_0024ref) then
        let $p := $schema/properties/*    
        let $pname := $p/name()
        let $tname := $p/items/_0024ref/ref:refValueName(.)
        return
            map{'type': $tname || '{' || $pname || '*}',
                'pattern': 'named-property-item-type'}
                
    (: named-property-chain-item-type   (object with a single property 'd', 
                                         object with a single property 'results' 
                                         with a named item type) :)
    else if ($schema/properties[count(*) eq 1]/d
                    /properties[count(*) eq 1]/results
             /items/_0024ref) then
        let $tname := $schema/properties/d/properties/results/items/_0024ref/ref:refValueName(.) 
        return
            map{'type':  $tname || '{d,results*}',
                'pattern': 'named-property-chain-item-type'}
                
    (: simple-type-property-chain   (object with a single property, 
                                     object with a single property 
                                     with string type) :)
    else if ($schema/properties[count(*) eq 1]/*
                    /properties[count(*) eq 1]/*
             /type eq 'string') then 
        let $pname1 := $schema/properties/*/name()
        let $pname2 := $schema/properties/*/properties/*/name()
        let $postfix :=
            if ($pname1 eq 'error' and $pname2 eq 'message') then '#error.message'
            else if ($pname1 eq 'response' and $pname2 eq 'status') then '#response.status'
            else ()
        return
            map{'type': concat('#{', $pname1, '={', $pname2, '=#string}}'),
                'pattern': 'simple-type-property-chain' || $postfix}
             
     (: pattern group: object with a single property :)
     else if ($schema/properties[count(*) eq 1]) then
        let $p := $schema/properties/*[1]
        let $pname := $p/name( )
        let $ptype := $p/type
        return
        
            (: simple-type-single-property :)
            if ($ptype = ('file', 'string', 'boolean', 'integer', 'number')) then
                map{'type': '#' || $ptype || '{' || $pname || '}',
                    'pattern': 'simple-type-single-property'}
            
            (: pattern subgroup: object with a single property 
                                 with array type :)
            else if ($ptype eq 'array') then
                let $itemType := $p/items/type
                return
                
                    (: simple-type-array-single-property :)
                    if ($itemType = ('file', 'string', 'boolean', 'integer', 'number')) then
                        map{'type': '#' || $ptype || '{' || $pname || '*}',
                            'pattern': 'simple-type-array-single-property'}
                        
                    (: local-object-array-single-property :)
                    else if ($itemType = 'object') then
                        map{'type': '#object{' || $pname || '*}',
                            'pattern': 'local-object-array-single-property'}
                        
                    (: $itemType-array-single-property :)
                    else if ($itemType) then
                        map{'type': '#' || $ptype || '{' || $pname || '*}',
                            'pattern': $itemType || '-array-single-property'}
                        
                    (: array-single-property :)
                    else                        
                        map{'type': '#' || $ptype || '{' || $pname || '}',
                            'pattern': 'array-single-property'}
                            
            (: local-object-single-property   (object with a single property
                                               which is an obj:)                
            else if ($ptype eq 'object') then
                map{'type': '#object{' || $pname || '}',
                    'pattern': 'local-object-single-property'}
                    
            (: $propertyType-single-property :)                    
            else
                map{'type': '#' || $ptype || '{' || $pname || '}',
                    'pattern': $ptype || '-single-property'}
                
    (: local-object :)
    else if ($schema/properties) then
        map{'type': '#object(' || count($schema/properties/*) || ' properties)',
            'pattern': 'local-object'}
                
    (: local-object-array :)
    else if ($schema/items/properties) then
        map{'type': '#object(' || count($schema/items/properties/*) || ' properties)*',
            'isArray': 'true',
            'pattern': 'local-object-array'}
                
    (: status-and-message :)
    else if ($schema/properties[count(*) eq 2 and status and message]) then
        map{'type': '#status-and-message',
            'pattern': 'status-and-message'}
                
    (: other type :)
    else
        map{'type': '#other-type',
            'pattern': 'other-type'}
};
