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

import module namespace all="http://www.oaslab.org/ns/xquery-functions/allOf" 
at "allOfResolver.xqm";    

import module namespace ref="http://www.oaslab.org/ns/xquery-functions/ref" 
at "ref.xqm";    

import module namespace shut="http://www.oaslab.org/ns/xquery-functions/schema-util" 
at "schemaUtil.xqm";    

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
    let $ostage := $options?ostage
    let $allOf := $options?allOf    
    let $flat := $options?flat
    let $lean := $options?lean
    
    let $tree01 := $schema ! f:jtree01RC(., $flat, 'schema', ())
    let $tree02 := $tree01 (: Switch off the shifting of property details into details :)
    let $tree03 := $tree02 ! f:jtreeRequiredRC(., $flat, 'schema', ())
    let $tree04 := $tree03 ! f:jtreePruneRC(., $flat, 'schema', ())
    
    (: If option 'allOf', allOf groups are *not* resolved :)
    let $tree05 := 
        if ($allOf) then $tree04 
        else $tree04 ! all:resolveAllOf(., $options)
    
    (: ostage values between 100 and 199 mean that some stage of the
       resolving of allOf groups is requested :)
    return if ($ostage ge 100 and $ostage lt 200) then $tree05 else
    
    let $tree06 := $tree05 ! f:jtreePropertyAttsRC(., $flat, 'schema', ())
    
    (: If option 'lean', the model is made compact, e.g. unwrapping 
           `properties` and `schema` keywords :)
    let $tree07 := 
        if (not($lean)) then $tree06
        else $tree06 ! f:jtreeLeanRC(., $flat, 'schema', ())
        
    return 
        if (empty($ostage)) then $tree07
        else
            switch($ostage)
            case 1 return $tree01
            case 2 return $tree02
            case 3 return $tree03
            case 4 return $tree04
            case 5 return $tree05
            case 6 return $tree06
            default return $tree07
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
    
    let $newVisited := ($visited, $n)    
    let $nextSchemaContext := shut:getJsContext($n, $schemaContext)
    return
    
    typeswitch($n)
    
    (: Reference is expanded :)
    case element(_0024ref) return
        let $mode := 'new'    
        let $typeName := $n ! ref:refValueKey(.) 
        return
            if ($flat) then <z:schema ref="{$typeName}"/>
            else
                let $referenced := $n/foxf:resolveJsonRef(., ., 'single')            
                let $content :=
                
                (: mode = new :)
                if ($mode eq 'new') then                
                    if ($referenced = $newVisited) then attribute recursiveContent {'yes'} 
                    else
                        let $rawContent := $referenced/node() 
                            ! f:jtree01RC(., $flat, 'named-schema', $newVisited)
                        let $recursiveContent := $rawContent/self::attribute(recursiveContent)
                        return
                            if ($recursiveContent) then $recursiveContent
                            else util:attsElems($rawContent)
            
                (: mode = old :)            
                else 
                    ($referenced/node() 
                    ! f:jtree01RC(., $flat, 'named-schema', $newVisited)
                    ) => util:attsElems()
                return
                    <z:schema name="{$typeName}">{$content}</z:schema>
                
    (: Properties :)
    case element(properties) return
        <js:properties>{
            for $p in $n/*
            let $pSchemaContext := $p ! shut:getJsContext(., $nextSchemaContext)
            return f:jtree01_copy(
                $p, $flat, $pSchemaContext, '#local-name', $newVisited)
        }</js:properties>
        
    case element(_) return
        let $_DEBUG := if (not($n/parent::xxx)) then () else trace(
            $schemaContext, '___XXX_ITEM_SCHEMA_CONTEXT: ') return
        
        let $name :=
            switch($schemaContext)
            case 'enum' return 'z:enumValue'
            case 'required' return 'z:requiredProperty'            
            case 'allOf' return 'z:schema'
            case 'oneOf' return 'z:schema'
            case 'anyOf' return 'z:schema'            
            default return $n/local-name(.)
        return
            f:jtree01_copy($n, $flat, $nextSchemaContext, $name, $newVisited)
            
    (: Other element :)
    case element() return
        let $_DEBUG := if (not($n/self::xxx)) then () else trace(
            $nextSchemaContext, '___XXX_NEXT_SCHEMA_CONTEXT: ') return
        
        let $elemName :=
            switch($schemaContext)
            case 'example' return '#local-name'
            case 'example-content' return '#local-name'
            default return '#js-name'
        return f:jtree01_copy($n, $flat, $nextSchemaContext, $elemName, $newVisited)
      
    case attribute(type) return ()
    
    default return $n                
};   

declare function f:jtree01RC_old($n as node(), 
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
 : Applied to a JSON Schema model tree. Makes properties more compact, 
 : turning divers child elements into attributes: 
 :   type, format, pattern, nullable,
 :   minLength, maxLength, minimum, maximum, minItems, maxItems 
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtreePropertyAttsRC(
                           $n as node(), 
                           $flat as xs:boolean?,
                           $schemaContext as xs:string?,
                           $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(js:format) 
         | element(js:maxLength) 
         | element(js:minLength) 
         | element(js:pattern)
         | element(js:minimum)
         | element(js:maximum)
         | element(js:minItems)
         | element(js:maxItems)
         | element(js:nullable)
         | element(z:propertyAdded)
         | element(js:readOnly)
         | element(z:recursiveContent)         
         | element(z:required)
         | element(z:schemaName)
         return
        attribute {local-name($n)} {$n}
        
    case element(js:xml) return
        for $child in $n/*
        let $attName := 'xml.' || $child/local-name(.)
        return attribute {$attName} {$n}
        
    case element(js:default) return
        if ($n/*) then 
            let $newSchemaContext := shut:getJsContext($n, $schemaContext)
            return f:jtreePropertyAtts_copy($n, $flat, $newSchemaContext, (), $newVisited)
        else $n/attribute {local-name(.)} {.}
    
    case element(js:type) return
        let $types := $n/(text(), _) => distinct-values() => sort() => string-join(', ')
        return
            attribute type {$types}
    case element() return
        let $newSchemaContext := shut:getJsContext($n, $schemaContext)
        return
            f:jtreePropertyAtts_copy($n, $flat, $newSchemaContext, (), $newVisited)

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
declare function f:jtreeRequiredRC(
                           $n as node(), 
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
            $n/@* ! f:jtreeRequiredRC(., $flat, 'properties', $visited),

            for $child in $n/*
            let $addElems := 
                if ($child/util:jname(.) = $n/../js:required/z:requiredProperty) then 
                    <z:required>true</z:required>
                else ()
            return
                f:jtreeRequired_copy($child, $flat, 'property-schema', (), $addElems, $newVisited),
                
            for $requiredProperty in $n/../js:required/z:requiredProperty[not(. = $pnames)]
            return
                element {$requiredProperty ! convert:encode-key(.)} {
                    <z:required>true</z:required>,
                    <z:propertyAdded>because-required</z:propertyAdded>
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
                        <z:required>true</z:required>,
                        <z:propertyAdded>because-required</z:propertyAdded>
                    }
                }</js:properties>
    
    case element() return        
        f:jtreeRequired_copy($n, $flat, $n/local-name(.), (), (), $newVisited)
        
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
declare function f:jtreePruneRC(
                        $n as node(), 
                        $flat as xs:boolean?,
                        $schemaContext as xs:string?,
                        $visited as node()*)
        as node()* {
    if ($n intersect $visited) then attribute recursiveContent {'yes'} else    
    let $newVisited := ($visited, $n) return
    
    typeswitch($n)
    
    case element(z:schema) return
        let $nextElem := 
            if ($n/@*) then $n
            else if ($n[count(*) eq 1]/z:schema) then $n/z:schema 
            else $n
        return $nextElem ! f:jtreePrune_copy(., $flat, (), (), $newVisited)

    case element(js:allOf) | element(js:oneOf) | element(js:anyOf) return
        (: Single child :)
        if (count($n/*) eq 1) then
            let $nextElem :=
                if ($n/z:schema[not(@*)]) then $n/z:schema/*
                else $n/*
            return
                $nextElem ! f:jtreePrune_copy(., $flat, 'schema', (), $newVisited)
        (: Multiple children :)
        else 
            $n ! f:jtreePrune_copy(., $flat, (), (), $newVisited)
        
    case element() return
        $n ! f:jtreePrune_copy(., $flat, $n/local-name(.), (), $newVisited)    
        
    default return $n        
};   

(:~
 : Recursive helper function of `jtree`.
 :
 : Edits a JSON Schema model. Removes unnecessary structure:
 : - removes `description`, `example`, `title`
 : - unwraps the contents of `properties` keywords
 : - unwraps the contents of `schema` elements
 :
 : @param n the node to be preocessed
 : @param flat if true, references are not expanded
 : @param schemaContext the kind of object containing the current node, e.g. "schema" or "allOf"
 : @param visited nodes already visited
 : @return the processed input node
 :)
declare function f:jtreeLeanRC($n as node(), 
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
         
    case element(z:schemaInfo-source) return ()         
         
    case element(js:enum) return
        attribute {local-name($n)} {$n/* => string-join(', ')}
      
    case element(js:items) return
        (: Nested array ! :)
        if ($n/js:items or $n/z:schema/js:items) then
            let $childResults := $n/(js:items, z:schema/js:items) ! f:jtreeLeanRC(., $flat, 'item-schema', $newVisited)            
            let $childResultsAtts := $childResults[self::attribute()] 
            let $childResultsChildren := $childResults except $childResultsAtts
            let $childResultsAttsEdited :=
                for $att in $childResultsAtts
                let $name := concat('items.', $att/local-name(.))
                return attribute {$name} {$att}
            let $itemsSchemaNameAtt := $n/z:schema[js:items]/@name ! attribute itemsSchema.name {.}         
            let $_DEBUG := trace($childResultsAttsEdited, '_CHILD_RESLTS_ATTS_EDITED: ')
            return ( 
                $itemsSchemaNameAtt,
                $childResultsAttsEdited, 
                $childResultsChildren
            )
            
        (: Not nested array :)
        else
        
        let $singleSchemaChild := $n/*:schema[empty((preceding-sibling::*, following-sibling::*))]        
        let $continueWithChildrenOf := ($singleSchemaChild, $n)[1]

        let $content := 
            $continueWithChildrenOf/node() ! f:jtreeLeanRC(., $flat, 'item-schema', $newVisited)
        let $contentAtts := $content/self::attribute()
        let $contentChildren := $content except $contentAtts
    
        let $itemsAtts := (
            for $att in $n/@*
            let $attName := 'items.' || local-name($att)
            return attribute {$attName} {$att},

            for $att in $contentAtts
            let $attName := 'items.' || local-name($att)
            return attribute {$attName} {$att},
            
            for $att in $singleSchemaChild/@*
            let $attName := 'itemsSchema.' || local-name($att)
            return attribute {$attName} {$att}
        )   
        return (
            $itemsAtts,
            $contentChildren
        )
        
    case element(js:properties) return
        $n/* ! f:jtreeLean_copy(., $flat, 'property-schema', (), $newVisited)
       
    (: The contents of "items" are unwrapped, "items" vanishes:
       items/@type becomes @itemType;
       note that the child elements of "items" and the child
         element of the parent of "items" are merged; it must
         still be clarified if this can cause problems and
         imply a significant loss of information
     :)
    case element(js:itemsXXX) return (
        $n/@type ! attribute itemType {.},
        $n/(@* except @type) ! f:jtreeLeanRC(., $flat, 'item-schema', $newVisited),
        let $nextElems :=
            if ($n/(z:schema and count(*) eq 1)) then $n/z:schema/*
            else $n/*
        return
            $nextElems ! f:jtreeLeanRC(., $flat, 'item-schema', $newVisited)
    )
    
    case element(z:schema) return
        if ($n/@name and $schemaContext = ('property-schema', 'items')) then
        
        let $schemaAtts :=
            for $att in $n/@*
            let $attName := 'schema.' || $att/local-name(.)
            return attribute {$attName} {$att}
        let $content :=
            $n/ node() ! f:jtreeLeanRC(., $flat, local-name(.), $newVisited)
        let $contentAtts := $content[self::attribute()]            
        let $contentChildren := $content except $contentAtts
        return (
            $contentAtts, 
            $schemaAtts,
            $contentChildren
        )
        
        else
            $n ! f:jtreeLean_copy(., $flat, $n/local-name(.), (), $newVisited)
    
(:    
    case element(z:schema) return
        if ($n/@name and $schemaContext = ('property-schema', 'items')) then (
            $n/@name ! attribute schemaName {.},
            $n/* ! f:jtreeLeanRC(., $flat, local-name(.), $newVisited)
        ) else
            $n ! f:jtreeLean_copy(., $flat, $n/local-name(.), (), $newVisited)
:)        
    case element() return
        if (starts-with($n/local-name(.), 'x-')) then () else
            $n ! f:jtreeLean_copy(., $flat, $n/local-name(.), (), $newVisited)    
        
    case attribute(propertyAdded) return ()
    
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
            util:attsElems((
                $e/@* ! f:jtree01RC(., $flat, $schemaContext, $visited),
                $e/node() ! f:jtree01RC(., $flat, $schemaContext, $visited)))                
        }
};        

(:~
 : Helper function of function `jtreePropertyAttsRC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtreePropertyAtts_copy(
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
        $e/@* ! f:jtreePropertyAttsRC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtreePropertyAttsRC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
        
    (: Temporary workaround :)
    let $contentAtts :=
        for $att in $contentAtts
        group by $attName := $att/name()
        return
            attribute {$attName} {$att}
       
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtreeRequiredRC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtreeRequired_copy(
                              $e as element(), 
                              $flat as xs:boolean?,
                              $schemaContext as xs:string?,
                              $elemName as xs:string?,
                              $additionalElems as element()*,
                              $visited as node()*)
        as element() {
    let $name := 
        if ($elemName) then $elemName
        else node-name($e)
    let $content := (
        $e/@* ! f:jtreeRequiredRC(., $flat, $schemaContext, $visited),
        $e/(node() except js:required) ! f:jtreeRequiredRC(., $flat, $schemaContext, $visited),
        $e/js:required ! f:jtreeRequiredRC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $additionalElems,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtreePruneRC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtreePrune_copy(
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
        $e/@* ! f:jtreePruneRC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtreePruneRC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        

(:~
 : Helper function of function `jtreeLeanRC`. Returns a processed
 : copy of the input element.
 
 : @param e an element to be preocessed
 : @param isMapField if true, the node is a map key, not a JSON Schema keyword
 : @param visited nodes already visited
 : @return a processed copy of the input element
 
 :)
declare function f:jtreeLean_copy(
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
        $e/@* ! f:jtreeLeanRC(., $flat, $schemaContext, $visited),
        $e/node() ! f:jtreeLeanRC(., $flat, $schemaContext, $visited))
    let $contentAtts := $content[self::attribute()]
    let $contentElems := $content except $contentAtts
    return
        element {$name} {
            $contentAtts,
            $contentElems
        }
};        






