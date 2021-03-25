(:
 : -------------------------------------------------------------------------
 :
 : jtree.xqm - functions constructing tree representations of JSON Schema documents
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/jtree";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

import module namespace ref="http://www.oaslab.org/ns/xquery-functions/ref" 
at "ref.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

import module namespace nav="http://www.oaslab.org/ns/xquery-functions/navigation" 
at "navigation.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";
declare namespace oas="http://www.oaslab.org/ns/oas";
declare namespace js="http://www.oaslab.org/ns/json-schema";

(:~
 : Maps a JSON Schema schema to a tree representation.
 :
 : @param schema a schema object
 : @return the tree representation
 :) 
declare function f:jtree($schema as element(),
                         $options as map(*)?)
        as item()* {
    let $flat := $options?flat
    let $bare := $options?bare
    let $tree01 := $schema ! f:jtree01RC(., $flat, 'schema', ())
    let $tree02 := $tree01 ! f:jtree02RC(., $flat, 'schema', ())
    let $tree03 := $tree02 ! f:jtree03RC(., $flat, 'schema', ())
    let $tree04 := $tree03 ! f:jtree04RC(., $flat, 'schema', ())
    let $tree05 := 
        if (not($bare)) then $tree04
        else $tree04 ! f:jtreeBareRC(., $flat, 'schema', ())
    return $tree05
};

(:~
 : Recursive helper function fo `jtree`.
 :
 : Maps JSON objects and arrays to XML structures and expands
 : references (if $flat not true).
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtree01RC($n as node(), 
                           $flat as xs:boolean?,
                           $schemaContext as xs:string?,
                           $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    (: Reference is expanded :)
    case element(_0024ref) return
        let $typeName := $n ! replace(., '^.*/', '')
        return
            if ($flat) then <z:schema ref="{$typeName}"/>
            else
                let $referenced := $n/foxf:resolveJsonRef(., ., 'single')
                let $content := $referenced/node() 
                    ! f:jtree01RC(., $flat, 'named-schema', $newVisited)
                return 
                    <z:schema name="{$typeName}">{
                        util:attsElems($content)}</z:schema>
            
    (: Properties :)
    case element(properties) return
        <js:properties>{
            for $child in $n/* return f:jtree01_copy(
                $child, $flat, 'property-schema', '#local-name', $newVisited)
        }</js:properties>
        
    case element(example) return
        f:jtree01_copy($n, $flat, 'example', '#js-name', $newVisited)
        
    case element(_) return
        let $name :=
            if ($schemaContext eq 'enum') then 'z:enumValue'
            else if ($schemaContext = ('allOf', 'oneOf', 'anyOf')) then 'z:schema'
            else if ($schemaContext = ('required')) then 'z:requiredProperty'
            else $n/local-name(.)
        return
            f:jtree01_copy($n, $flat, 'enum-value', $name, $newVisited)
            
    (: Other element :)
    case element() return
        if ($schemaContext = ('example', 'example-content')) then
            f:jtree01_copy($n, $flat, 'example-content', '#local-name', $newVisited)
        else 
            f:jtree01_copy($n, $flat, $n/local-name(.), '#js-name', $newVisited)
      
    case attribute(type) return ()
    
    default return $n                
};   

(:~
 : Recursive helper function of `jtree`.
 :
 : Applied to tree01. Makes properties more compact, turning divers child elements
 : into attributes: 
 :   type, format, pattern, nullable,
 :   minLength, maxLength, minimum, maximum, minItems, maxItems 
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtree02RC($n as node(), 
                           $flat as xs:boolean?,
                           $schemaContext as xs:string?,
                           $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(js:type) 
         | element(js:format) 
         | element(js:maxLength) 
         | element(js:minLength) 
         | element(js:pattern)
         | element(js:minimum)
         | element(js:maximum)
         | element(js:minItems)
         | element(js:maxItems)
         | element(js:nullable)
         return
        attribute {local-name($n)} {$n}
        
    case element() return
        let $newSchemaContext := 
            if ($n/parent::js:properties) then 'property-schema'
            else local-name($n)
        return
            f:jtree02_copy($n, $flat, $newSchemaContext, (), $newVisited)

    default return $n
};   

(:~
 : Recursive helper function of `jtree`.
 :
 : Applied to tree02. Removes `required` keyword and adds to required properties
 : attribute @required=true.
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtree03RC($n as node(), 
                           $flat as xs:boolean?,
                           $schemaContext as xs:string?,
                           $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(js:properties) return
        let $pnames := $n/*/util:jname(.) return
        
        element {node-name($n)} {
            $n/@* ! f:jtree03RC(., $flat, 'properties', $visited),

            for $child in $n/*
            let $addAttributes := 
                if ($child/util:jname(.) = $n/../js:required/z:requiredProperty) then attribute required {true()}
                else ()
            return
                f:jtree03_copy($child, $flat, 'property-schema', (), $addAttributes, $newVisited),
                
            for $requiredProperty in $n/../js:required/z:requiredProperty[not(. = $pnames)]
            return
                element {$requiredProperty ! convert:encode-key(.)} {
                    attribute required {'true'},
                    attribute added {'because-required'}
                }
        }
        
    case element(js:required) return 
        let $pnames := $n/../js:properties/*/util:jname(.)
        let $requiredAdditionalPnames := $n/z:requiredProperty[not(. = $pnames)]
        return
            (: If required properties, yet no "properties" element, it is created now :)
            if (empty($requiredAdditionalPnames) or $n/../js:properties) then () else
                <js:properties>{
                    $requiredAdditionalPnames !
                    element {. ! convert:encode-key(.)} {
                        attribute required {'true'},
                        attribute added {'because-required'}
                    }
                }</js:properties>
    
    case element() return        
        f:jtree03_copy($n, $flat, $n/local-name(.), (), (), $newVisited)
        
    default return $n        
};   

(:~
 : Recursive helper function of `jtree`.
 :
 : Applied to tree03. Removes unnecessary structure:
 : - a <schema> without attributes and a single <schema> child is removed
 : - an <allOf>, <oneOf>, <anyOf> with a single child is replaced by the child
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtree04RC($n as node(), 
                             $flat as xs:boolean?,
                             $schemaContext as xs:string?,
                             $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(z:schema) return
        let $nextElem :=
            if ($n/(not(@*) and count(*) eq 1 and z:schema)) then $n/z:schema
            else $n
        return $nextElem ! f:jtree04_copy(., $flat, 'schema', (), $newVisited)

    case element(js:allOf) | element(js:oneOf) | element(js:anyOf) return
        (: Single child :)
        if (count($n/*) eq 1) then
            let $nextElem :=
                if ($n/*/(not(@*) and count(*) eq 1 and z:schema)) then $n/*/*
                else $n/*
            return $nextElem ! f:jtree04_copy(., $flat, 'schema', (), $newVisited)
        (: Multiple children :)
        else 
            $n ! f:jtree04_copy(., $flat, $n/local-name(.), (), $newVisited)
        
    case element() return
        $n ! f:jtree04_copy(., $flat, $n/local-name(.), (), $newVisited)    
        
    default return $n        
};   

(:~
 : Recursive helper function of `jtree`.
 :
 : Applied to tree03. Removes unnecessary structure:
 : - a <schema> without attributes and a single <schema> child is removed
 : - an <allOf>, <oneOf>, <anyOf> with a single child is replaced by the child
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtreeBareRC($n as node(), 
                               $flat as xs:boolean?,
                               $schemaContext as xs:string?,
                               $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(js:description) 
         | element(js:example)
         | element(js:title)
         return ()
         
    case element(js:properties) return
        $n/* ! f:jtreeBare_copy(., $flat, 'property-schema', (), $newVisited)
       
    (: The contents of "items" are unwrapped, "items" vanishes:
       items/@type becomes @itemType;
       note that the child elements of "items" and the child
         element of the parent of "items" are merged; it must
         still be clarified if this can cause problems and
         imply a significant loss of information
     :)
    case element(js:items) return (
        $n/@type ! attribute itemType {.},
        $n/(@* except @type) ! f:jtreeBareRC(., $flat, 'item-schema', $newVisited),
        let $nextElems :=
            if ($n/(z:schema and count(*) eq 1)) then $n/z:schema/*
            else $n/*
        return
            $nextElems ! f:jtreeBareRC(., $flat, 'item-schema', $newVisited)
    )
    
    case element(z:schema) return
        if ($n/@name and $schemaContext eq 'property-schema') then (
            $n/@name ! attribute schemaName {.},
            $n/* ! f:jtreeBareRC(., $flat, local-name(.), $newVisited)
        ) else
            $n ! f:jtreeBare_copy(., $flat, $n/local-name(.), (), $newVisited)
        
    case element() return
        $n ! f:jtreeBare_copy(., $flat, $n/local-name(.), (), $newVisited)    
        
    default return $n        
};   

(:~
 : Returns a flattened copy of a group (allOf, oneOf or anyOf) with immediate 
 : descendant groups of the same kind "unwrapped", replaced with its child
 : nodes.
 :
 : Example:
 :
 : js:allOf
 :   js:schema
 :     js:allOf
 :       js:schema
 :         js:properties
 :           foo
 :       js:schema
 :         js:allOf
 :           js:schema
 :             js:items
 :   js:schema
 :     js:properties
 :       bar
 : becomes:
 :
 : js:allOf
 :   js:schema
 :     js:properties
 :       foo
 :   js:schema
 :     js:items
 :   js:schema
 :     js:properties
 :       bar
 :
 : @param group a group node (allOf, oneOf or anyOf)
 : @param options for future use
 : @return a copy of the jtree with occurrences of the root group kind
 :   unwrapped
 :)
declare function f:jtreeFlattenGroup($group as element(),
                                     $options as map(*)?)
        as element() {
    let $groupKind := $group/local-name(.)
    return
        element {node-name($group)} {
            $group/z:schema ! f:jtreeFlattenGroupRC(., $groupKind, $options)
        }
};        

(:~
 : Recursive helper function of `jtreeFlattenGroup`.
 :)
declare function f:jtreeFlattenGroupRC($schema as element(z:schema),
                                       $groupKind as xs:string*,
                                       $options as map(*)?)
        as node()* {
    let $next := $schema/js:*[local-name(.) = $groupKind]/z:schema
    return
        if ($next) then $next ! f:jtreeFlattenGroupRC(., $groupKind, $options)
        else $schema
};        

(:~
 : Helper function of function `jtree01RC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtree01_copy($e as element(), 
                              $flat as xs:boolean?,
                              $schemaContext as xs:string?,
                              $elemName as xs:string?,
                              $visited as node()*)
        as element() {
    let $name := 
        if ($elemName eq '#local-name') then $e/local-name(.)
        else if ($elemName eq '#js-name') then 'js:' || $e/local-name(.)
        else if ($elemName) then $elemName
        else 'js:' || $e/local-name(.)
    return
        element {$name} {
            $e/@* ! f:jtree01RC(., $flat, $schemaContext, $visited),
            $e/node() ! f:jtree01RC(., $flat, $schemaContext, $visited)
        }
};        

(:~
 : Helper function of function `jtree02RC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtree02_copy($e as element(), 
                              $flat as xs:boolean?,
                              $schemaContext as xs:string?,
                              $elemName as xs:string?,
                              $visited as node()*)
        as element() {
    let $name := 
        if ($elemName) then $elemName
        else node-name($e)
    let $content := (
        $e/@* ! f:jtree02RC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtree02RC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtree03RC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtree03_copy($e as element(), 
                              $flat as xs:boolean?,
                              $schemaContext as xs:string?,
                              $elemName as xs:string?,
                              $additionalAttributes as attribute()*,
                              $visited as node()*)
        as element() {
    let $name := 
        if ($elemName) then $elemName
        else node-name($e)
    let $content := (
        $e/@* ! f:jtree03RC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtree03RC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $additionalAttributes,
            $contentAtts,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtree04RC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtree04_copy($e as element(), 
                              $flat as xs:boolean?,
                              $schemaContext as xs:string?,
                              $elemName as xs:string?,
                              $visited as node()*)
        as element() {
    let $name := 
        if ($elemName) then $elemName
        else node-name($e)
    let $content := (
        $e/@* ! f:jtree04RC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtree04RC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtreeBareRC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtreeBare_copy(
                            $e as element(), 
                            $flat as xs:boolean?,
                            $schemaContext as xs:string?,
                            $elemName as xs:string?,
                            $visited as node()*)
        as element() {
    let $name := 
        if ($elemName) then $elemName
        else node-name($e)
    let $content := (
        $e/@* ! f:jtreeBareRC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtreeBareRC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        





