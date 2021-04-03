(:
 : -------------------------------------------------------------------------
 :
 : groupResolver.xqm - functions resolving JSON Schema groups (allOf, oneOf, anyOf)
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="resolveGroups" type="item()?" func="resolveGroupsOP">     
         <param name="mtree" type="docFOX" fct_minDocCount="1"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>
         <param name="ostage" type="xs:integer?"/>
      </operation>      
    </operations>  
:)  
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/group";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm",
   "tt/_request.xqm";    

import module namespace jt="http://www.oaslab.org/ns/xquery-functions/jtree" 
at "jtree.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";
declare namespace oas="http://www.oaslab.org/ns/oas";
declare namespace js="http://www.oaslab.org/ns/json-schema";

(:~
 : Implements the operation 'mtree'. See function `mtree` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:resolveGroupsOP($request as element())
        as item()? {
    let $mtree := tt:getParam($request, 'mtree')/*
    let $odir := tt:getParam($request, 'odir')
    let $addSuffix := tt:getParam($request, 'addSuffix')
    let $addPrefix := tt:getParam($request, 'addPrefix')
    let $fnameReplacement := tt:getParam($request, 'fnameReplacement')
    let $ostage := tt:getParam($request, 'ostage')

    let $options := map:merge((
        $odir ! map:entry('odir', .),
        $addSuffix ! map:entry('addSuffix', .),
        $addPrefix ! map:entry('addPrefix', .),
        $fnameReplacement ! map:entry('fnameReplacement', .),
        $ostage ! map:entry('ostage', .)        
    ))
    return
        f:groupResolver($mtree, $options)
};

(:~
 : Implements the operation 'mtree'. See function `mtree` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:groupResolver($mtrees as element()+,
                                 $options as map(*)?)
        as item()? {
    let $odir := $options?odir        
    let $docs :=
        for $doc in $mtrees
        return f:resolveAllOf($doc, $options)
    return
        if ($odir) then $docs ! util:writeFile(., base-uri(.), $options)
        else $docs
};

(:~
 : Transforms a JSON Schema schema or an OAS node containing
 : JSON Schemas so that all allOf groups are resolved to their
 : merged contents. The result does not contain any allOf groups.
 :)
declare function f:resolveAllOf($schema as element(),
                                 $options as map(*)?)
        as element() {
    let $ostage := $options?ostage
    
    let $normalized1 := f:normalizeAllOf1($schema, $options) 
    let $normalized2 := f:normalizeAllOf2($normalized1, $options)
    let $subschemasMerged := f:mergeAllOfSubschemas($normalized2, $options)
    let $constraintsMerged := f:mergeAllOfConstraints($subschemasMerged, $options)
    return 
        if ($ostage eq 1) then $normalized1
        else if ($ostage eq 2) then $normalized2
        else if ($ostage eq 3) then $subschemasMerged
        else $constraintsMerged
};

(: 
 : ===================================================================================
 :
 :     N o r m a l i z e    a l l O f    g r o u p s
 :
 : =================================================================================== 
 :)

(:~
 : Any siblings of `allOf` are wrapped in a subschema inserted
 : into the `allOf`. As a result, any schema containing `allOf`
 : contains the `allOf` keyword and nothing else.
 :
 : @param mtree a JSON Schema raw tree
 : @param options options (for future use)
 : @return the normalized schema
 :) 
declare function f:normalizeAllOf1(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOf1RC($mtree, $options)        
};        

(:~
 : Flattens `allOf´ trees, recursively replacing `allOf` subschemas of an 
 : `allOf` keyword with its subschemas.
 :)
declare function f:normalizeAllOf2(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOf2RC($mtree, $options)
};        

(:~
 : Recursive helper function of `f:normalizeAllOf1`.
 :) 
declare function f:normalizeAllOf1RC($n as node(),
                                     $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOf1RC(., $options)}
        
    case element() return
        if (not($n/js:allOf/(preceding-sibling::*, following-sibling::*))) then
            element {node-name($n)} {
                attribute xml:base {$n/base-uri(.)}[not($n/parent::*)],
                $n/@* !  f:normalizeAllOf1RC(., $options),
                $n/node() ! f:normalizeAllOf1RC(., $options)        
            }
        else
        (:
            let $_DEBUG1 := $n/js:allOf/(preceding-sibling::*, following-sibling::*)
            let $_DEBUG2 := $_DEBUG1 ! f:normalizeAllOf1RC(., $options)
            let $_DEBUG1a := trace($_DEBUG1/local-name(.) => string-join(', '), '_SIBLING_NAMES1: ') 
            let $_DEBUG1b := trace($_DEBUG2/local-name(.) => string-join(', '), '_SIBLING_NAMES2: ')
         :)
            let $additionalSchema :=
                <z:schema source="created-during-normalization">{
                    $n/js:allOf/(preceding-sibling::*, following-sibling::*) 
                    ! f:normalizeAllOf1RC(., $options)
                }</z:schema>
            let $allOfSubschemas :=
                $n/js:allOf/* ! f:normalizeAllOf1RC(., $options)
            return
                element {node-name($n)} {
                    $n/@* ! f:normalizeAllOf1RC(., $options),
                    <js:allOf>{
                        $additionalSchema,
                        $allOfSubschemas
                    }</js:allOf>
                }
                
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    case attribute(xml:base) return ()        
    default return $n        
};        

(:~
 : Recursive helper function of `f:normalizeAllOf2`.
 :)
declare function f:normalizeAllOf2RC($n as node(),
                                     $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOf2RC(., $options)}
    case element(js:allOf) return
        let $children := $n/node() ! f:normalizeAllOf2RC(., $options)
        let $subschemasRaw :=
            for $child in $children 
            let $allOfSubschemas := (
            (:    $child/self::js:allOf/node(), :)
                $child/self::z:schema/js:allOf/node())
            return
                if ($allOfSubschemas) then $allOfSubschemas
                else $child
        (: Remove duplicate schemas :)
        let $subschemas :=
            for $subschema at $pos in $subschemasRaw
            group by $subschemaName := ($subschema/@name, $pos)[1]
            return $subschema[1]
        return
            element {node-name($n)} {
                $n/@* !  f:normalizeAllOf2RC(., $options),
                $subschemas
            }
    case element() return
        element {node-name($n)} {
            $n/@* !  f:normalizeAllOf2RC(., $options),
            $n/node() ! f:normalizeAllOf2RC(., $options)        
        }
      
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    default return $n        
};        

(: 
 : ===================================================================================
 :
 :     M e r g e    a l l O f    s u b s c h e m a s
 :
 : =================================================================================== 
 :)

(:~
 : Replaces `allOf` keywords with merged subschemas, raw
 : format. The keywords of the merged subschemas may contain
 : <z:all> elements with <z:constraint> children, representing
 : the constraints contributed by individual subschemas. The
 : resolving of sets of constraints is performed by
 : `mergeAllOfConstraints`.
 :
 : @param schema a JSON Schema schema, or OpenAPI node containing schemas
 : @param options options, for future use
 :)
declare function f:mergeAllOfSubschemas(
                              $schema as element(),
                              $options as map(*)?)
        as element() {
    f:mergeAllOfSubschemasRC($schema, $options)        
};        

(:~
 : Recursive helper function of `mergeAllOfSubschemas`.
 :)
declare function f:mergeAllOfSubschemasRC(
                              $n as node(),
                              $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:mergeAllOfSubschemasRC(., $options)}
    case element(js:allOf) return
        let $content := fold-left($n/*, (), f:mergeSubschemaPairAllOf#2)
        return $content
    case element() return
        element {node-name($n)} {
            $n/@* !  f:mergeAllOfSubschemasRC(., $options),
            $n/node() ! f:mergeAllOfSubschemasRC(., $options)
        }
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
    default return $n        
};        

(:~
 : Helper function of `mergeAllOfSubschemas`. The function is passed to
 : fn:fold-left, merging the contents of two subschemas.
 : 
 :)
declare function f:mergeSubschemaPairAllOf(
                              $schema1Content as element()*,
                              $schema2 as element())
        as element()* {

    if (not($schema1Content)) then $schema2/* ! f:mergeAllOfSubschemasRC(., ())
    else
    
    let $schema2Content := $schema2/* ! f:mergeAllOfSubschemasRC(., ())
    let $keywordNames1 := $schema1Content/local-name(.)        
    let $keywordNames2 := $schema2Content/local-name(.)
    
    let $notCommonKeywords := (
        $schema1Content[not(local-name(.) = $keywordNames2)],
        $schema2Content[not(local-name(.) = $keywordNames1)]        
    )
    let $commonKeywords :=
        for $keyword1 in $schema1Content[local-name(.) = $keywordNames2]
        let $keyword2 := $schema2Content[local-name(.) eq $keyword1/local-name(.)]
        
        let $constraint1 :=
            if ($keyword1/z:all) then $keyword1/z:all/*
            else
                <z:constraint>{
                    $keyword1/text() ! <z:value>{.}</z:value>,
                    $keyword1/* ! f:mergeAllOfSubschemasRC(., ()) 
                }</z:constraint>
        let $constraint2 := 
            <z:constraint>{
                $keyword2/(
                    text() ! <z:value>{.}</z:value>,
                    * ! f:mergeAllOfSubschemasRC(., ()))
            }</z:constraint>
        return
            element {node-name($keyword1)} {
                <z:all>{
                    $constraint1, $constraint2
                }</z:all>
            }
    return (
        $notCommonKeywords,
        $commonKeywords
    )
};       

(: 
 : ===================================================================================
 :
 :     R e s o l v e    < z : a l l >    c o n s t r a i n t s
 :
 : =================================================================================== 
 :)

(:~
 : Replaces <z:all> elements - contained by a keyword element and containing 
 : <z:constraint> elements - with a merged representation of the constraints. 
 : The constraints have been constructed when merging subschemas: when a set 
 : of subschemas contains two or more subschemas containing the same keyword, 
 : the merged schema contains the keyword with an <z:all> child element 
 : wrapping <z:constraint> child elements representing the keyword content of 
 : one of the subschemas.
 :
 : @param schema a JSON Schema schema, or OpenAPI node containing schemas
 : @param options options, for future use
 :)
declare function f:mergeAllOfConstraints($schema as element(),
                                         $options as map(*)?)
        as node()* {
    f:mergeAllOfConstraintsRC($schema, $options)        
};

declare function f:mergeAllOfConstraintsRC($n as node(),
                                           $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:mergeAllOfConstraintsRC(., $options)}
    case element(js:type) return
        if (not($n/z:all)) then
            element {node-name($n)} {
                $n/@* ! f:mergeAllOfConstraintsRC(., $options),
                $n/node() ! f:mergeAllOfConstraintsRC(., $options)
            }
        else f:mergeAllOfConstraints_type($n)
                        
    case element(z:required) return
        if (not($n/z:all)) then
            element {node-name($n)} {
                $n/@* ! f:mergeAllOfConstraintsRC(., $options),
                $n/node() ! f:mergeAllOfConstraintsRC(., $options)
            }
        else f:mergeAllOfConstraints_required($n)
    case element(js:properties) return
        if (not($n/z:all)) then
            element {node-name($n)} {
                $n/@* ! f:mergeAllOfConstraintsRC(., $options),
                $n/node() ! f:mergeAllOfConstraintsRC(., $options)
            }
        else
            let $mergedProperties := fold-left($n/z:all/*, (), f:mergeAllOfConstraintPair_properties#2)
            (: Merged properties may contain an allOf keyword :) 
            let $mergedResolved :=
                for $property in $mergedProperties
                return
                    if (not($property/z:allOf)) then $property
                    else $property/z:allOf/f:resolveAllOf(., $options)
            return
                element {node-name($n)} {
                    $mergedResolved
                }

    case element() return
        element {node-name($n)} {
            $n/@* ! f:mergeAllOfConstraintsRC(., $options),
            $n/node() ! f:mergeAllOfConstraintsRC(., $options)
        }
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
    default return $n            
};        

declare function f:mergeAllOfConstraints_type($type as element(js:type))
        as element()? {
            (: ___TO_DO___ Not yet considered: possibility to have type arrays to be ANDed :)
    let $types1 := $type/z:all/z:constraint/z:value => distinct-values()
    let $types2 := $type/z:all/z:constraint/_ => sort() => string-join('|')
    return
        if ($types1) then <type>{$types1[1]}</type>
        else if ($types2) then 
            <type type="array">{
                ($types2/tokenize(., '\|') => distinct-values() => sort())
                ! <_>.</_>}</type>
        else ()                
};

declare function f:mergeAllOfConstraints_required($type as element(z:required))
        as element()? {
            (: ___TO_DO___ Not yet considered: possibility to have type arrays to be ANDed :)
    if ($type/z:all/z:constraint/z:value = 'true') then 
        <z:required>true</z:required>
    else
        <z:required>false</z:required>
};

declare function f:mergeAllOfConstraintPair_properties(
                                           $constraint1Content as element()*,
                                           $constraint2 as element(z:constraint))
        as element()* {
    if (empty($constraint1Content)) then $constraint2/* ! f:mergeAllOfConstraints(., ()) 
    else    
    
    let $constraint2Content := $constraint2/* ! f:mergeAllOfConstraintsRC(., ())
    let $propertyNames1 := $constraint1Content/local-name(.)        
    let $propertyNames2 := $constraint2Content/local-name(.)
    
    let $allPropertyNames := ($propertyNames1, $propertyNames2) => distinct-values()
    
    let $properties := (
        for $property1 in $constraint1Content
        let $property2 := $constraint2Content[local-name(.) eq $property1/local-name(.)]
        return
            if (not($property2)) then $property1
            else
                let $allOf :=
                    let $schema1 :=            
                        if ($property1/js:allOf) then $property1/js:allOf/*
                        else
                            <z:schema>{
                                $property1/* ! f:mergeAllOfConstraintsRC(., ()) 
                            }</z:schema>
                    let $schema2 := 
                        <z:schema>{
                            $property2/*
                        }</z:schema>
                    return
                        element {node-name($property1)} {
                            <js:allOf>{$schema1, $schema2}</js:allOf>                    
                        }
                let $allOfResolved := $allOf ! f:resolveAllOf($allOf, ())
                return $allOfResolved
            ,
            $constraint2Content[not(local-name(.) = $propertyNames1)]
        )

(:
    let $notCommonProperties := (
        $constraint1Content[not(local-name(.) = $propertyNames2)],
        $constraint2Content[not(local-name(.) = $propertyNames1)]        
    )
    let $commonProperties :=
        for $property1 in $constraint1Content[local-name(.) = $propertyNames2]
        let $property2 := $constraint2Content[local-name(.) eq $property1/local-name(.)]
        
        let $schema1 :=
            if ($property1/js:allOf) then $property1/js:allOf/*
            else
                <z:schema>{
                    $property1/* ! f:mergeAllOfConstraintsRC(., ()) 
                }</z:schema>
        let $schema2 := 
            <z:schema>{
                $property2/* ! f:mergeAllOfConstraintsRC(., ())
            }</z:schema>
        return
            element {node-name($property1)} {
                <js:allOf>{
                    $schema1, $schema2
                }</js:allOf>
            }
    return (
        $notCommonProperties,
        $commonProperties
    )
:)
    return (
        $properties
    )

};        
