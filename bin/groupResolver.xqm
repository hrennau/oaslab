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
    let $_DEBUG := trace($options, '_OPTIONS: ')
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
        if ($odir) then $docs ! util:writeFile(., (), $options)
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
    
    let $normalized := f:normalizeAllOf($schema, $options) 
    let $subschemasMerged := f:mergeAllOfSubschemas($normalized, $options)
    let $constraintsMerged := f:mergeAllOfConstraints($subschemasMerged, $options)
    return 
        if ($ostage eq 1) then $normalized
        else if ($ostage eq 2) then $subschemasMerged
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
 : Every schema containing an "allOf" keyword is normalized to contain a single 
 : "allOf" and nothing else. Rules:
 :
 : (1) If the schema contains no other keywords than "allOf", it is not 
 :     changed. 
 : (2)  Otherwise, the keywords are replaced with a single new "allOf" 
 : keyword containing the following subschemas:
 : - one subschema containing the adjacent keywords of the original "allOf"
 : - all subschemas of the original "allOf"
 :
 : @param mtree a JSON Schema raw tree
 : @param options options (for future use)
 : @return the normalized schema
 :)
declare function f:normalizeAllOf(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOfRC1($mtree, $options)        
    !
    f:normalizeAllOfRC2(., $options)
    
};        

declare function f:normalizeAllOfRC1($n as node(),
                                   $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOfRC1(., $options)}
    case element() return
        if (not($n/js:allOf/(preceding-sibling::*, following-sibling::*))) then
            element {node-name($n)} {
                $n/@* !  f:normalizeAllOfRC1(., $options),
                $n/node() ! f:normalizeAllOfRC1(., $options)        
            }
        else
            let $adjacentKeywords := $n/(* except js:allOf)
            return
                <js:allOf>{
                    <z:schema source="created-during-normalization">{
                              $adjacentKeywords ! f:normalizeAllOfRC1(., $options)
                    }</z:schema>,
                    $n/js:allOf/node() ! f:normalizeAllOfRC1(., $options)
                }</js:allOf>
                
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    default return $n        
};        

declare function f:normalizeAllOfRC2($n as node(),
                                   $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOfRC2(., $options)}
    case element(js:allOf) return
        let $children := $n/node() ! f:normalizeAllOfRC2(., $options)
        let $subschemasRaw :=
            for $child in $children 
            let $allOfSubschemas := (
                $child/self::js:allOf/node(),
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
                $n/@* !  f:normalizeAllOfRC2(., $options),
                $subschemas
            }
    case element() return
        element {node-name($n)} {
            $n/@* !  f:normalizeAllOfRC2(., $options),
            $n/node() ! f:normalizeAllOfRC2(., $options)        
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
                let $schema1 :=            
                    if ($property1/js:allOf) then $property1/js:allOf/*
                    else
                        <z:schema>{
                            $property1/* ! f:mergeAllOfConstraintsRC(., ()) 
                        }</z:schema>
                let $schema2 := $property2/*
                return
                    element {node-name($property1)} {
                        <js:allOf>{$schema1, $schema2}</js:allOf>                    
                    }
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
