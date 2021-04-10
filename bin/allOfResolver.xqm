(:
 : -------------------------------------------------------------------------
 :
 : allOfResolver.xqm - functions resolving JSON Schema groups, kind 'allOf'
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="resolveAllOf" type="item()?" func="resolveAllOfOP">     
         <param name="mtree" type="docFOX" fct_minDocCount="1"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>
         <param name="ostage" type="xs:integer?"/>
      </operation>      
    </operations>  
:)  
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/allOf";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm",
   "tt/_request.xqm";    

import module namespace jt="http://www.oaslab.org/ns/xquery-functions/jtree" 
at "jtree.xqm";    

import module namespace nav="http://www.oaslab.org/ns/xquery-functions/navigation" 
at "navigation.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";
declare namespace oas="http://www.oaslab.org/ns/oas";
declare namespace js="http://www.oaslab.org/ns/json-schema";

(:~
 : Implements the operation 'resolveAllOf'. See function `allOfResolver` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:resolveAllOfOP($request as element())
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
        f:jtreeAllOf($mtree, $options)
};

(:~
 : Transforms JSON Schema model trees by resolving all allOf groups.
 :
 : @param mtrees JSON Schema model trees
 : @param options options controlling function execution
 : @return the transformed model trees
 :) 
declare function f:jtreeAllOf($mtrees as element()+,
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
    let $normalized3 := f:normalizeAllOf3($normalized2, $options)
    let $normalized4 := f:normalizeAllOf4($normalized3, $options)
    let $subschemasMerged := f:mergeAllOfSubschemas($normalized4, $options)
    let $constraintsMerged := f:mergeAllOfConstraints($subschemasMerged, $options)
    return 
        if ($ostage eq 0) then $schema
        else if ($ostage eq 1) then $normalized1    
        else if ($ostage eq 2) then $normalized2
        else if ($ostage eq 3) then $normalized3
        else if ($ostage eq 4) then $normalized4
        else if ($ostage eq 5) then $subschemasMerged
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
 : Edits any element (except allOf, oneOf, anyOf) containing a z:schema element 
 : with siblings. The element content is replaced with an 'allOf' keyword containing 
 : the following subschemas:
 : - any z:schema element among the child elements
 : - any sequence of non-schema elements wrapped in a z:schema element
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
 : Any siblings of `allOf` are wrapped in a subschema inserted
 : into the `allOf`. As a result, any schema containing `allOf`
 : contains the `allOf` keyword and nothing else.
 :
 : @param mtree a JSON Schema raw tree
 : @param options options (for future use)
 : @return the normalized schema
 :) 
declare function f:normalizeAllOf2(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOf2RC($mtree, $options)        
};        

(:~
 : Flattens `allOf´ trees, recursively replacing `allOf` subschemas of an 
 : `allOf` keyword with its subschemas.
 :)
declare function f:normalizeAllOf3(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOf3RC($mtree, $options)
};        

(:~
 : Replaces nested z:schema elements with innermost element.
 :)
declare function f:normalizeAllOf4(
                   $mtree as element(),
                   $options as map(*)?)
        as element() {
    f:normalizeAllOf4RC($mtree, $options)
};        

(:~
 : Recursive helper function of `f:normalizeAllOf1`.
 :) 
declare function f:normalizeAllOf1RC($n as node(),
                                     $options as map(*)?)
        as node()* {
    (: Set the base attribute in the root element :)        
    let $baseAtt := 
        $n[empty(parent::*/name(.))][not(@xml:base)]
        /attribute xml:base {base-uri(.)}
    let $baseAtt := ()   (: BaseX bug? never found a parent, always wrote att :)        
    return
    
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOf1RC(., $options)}
        
    case element(z:oas) return 
        element {node-name($n)} {
            $baseAtt,
            $n/@* !  f:normalizeAllOf1RC(., $options),
            $n/node() ! f:normalizeAllOf1RC(., $options)        
        }
    
    case element(js:allOf) | element(js:oneOf) | element(js:anyOf) return
        $n/element {node-name()} {
            @* !  f:normalizeAllOf1RC(., $options),
            node() ! f:normalizeAllOf1RC(., $options)        
        }
    
    case element() return
        (: Schema with siblings is wrapped in `allOf` :)
        if ($n/z:schema[preceding-sibling::*, following-sibling::*])
        then
            let $subschemas := f:schemasAndKeywordsToSchemas($n/*)
            return
                element {node-name($n)} {
                    $baseAtt,
                    <js:allOf>{$subschemas}</js:allOf>}
        else
            element {node-name($n)} {
                $baseAtt,
                $n/@* !  f:normalizeAllOf1RC(., $options),
                $n/node() ! f:normalizeAllOf1RC(., $options)        
            }
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    default return $n        
};        

(:~
 : Maps a sequence of sibling elements to a sequence of <z:schema> elements:
 : - any <z:schema> element item is returned as is
 : - any sequence of elements which are not <z:schema> is returned wrapped in a new <z:schema>
 :) 
declare function f:schemasAndKeywordsToSchemas($fields as element()*)
        as element(z:schema)* {
    let $head := head($fields)
    return
        if ($head/self::z:schema) then (
            $head,
            tail($fields) => f:schemasAndKeywordsToSchemas()
        ) else
            let $tail := tail($fields)
            let $nextSchema := $head/following-sibling::z:schema[1]
            return
                if (empty($nextSchema)) then <z:schema>{$fields}</z:schema>
                else (
                    <z:schema>{$fields[. << $nextSchema]}</z:schema>,
                    $nextSchema,
                    $nextSchema/following-sibling::* => f:schemasAndKeywordsToSchemas()
                )
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
        
    case element(z:oas) return 
        element {node-name($n)} {
            $n/@* !  f:normalizeAllOf2RC(., $options),
            $n/node() ! f:normalizeAllOf2RC(., $options)        
        }
    
    case element() return
        if (not($n/js:allOf/(preceding-sibling::*, following-sibling::*))) then
            element {node-name($n)} {
                $n/@* !  f:normalizeAllOf2RC(., $options),
                $n/node() ! f:normalizeAllOf2RC(., $options)        
            }
        else
            let $additionalSchema :=
                <z:schema source="created-during-normalization">{
                    $n/js:allOf/(preceding-sibling::*, following-sibling::*) 
                    ! f:normalizeAllOf2RC(., $options)
                }</z:schema>
            let $allOfSubschemas :=
                $n/js:allOf/* ! f:normalizeAllOf2RC(., $options)
            return
                element {node-name($n)} {
                    $n/@* ! f:normalizeAllOf2RC(., $options),
                    <js:allOf>{
                        $additionalSchema,
                        $allOfSubschemas
                    }</js:allOf>
                }
                
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    default return $n        
};        

(:~
 : Recursive helper function of `f:normalizeAllOf3`.
 :)
declare function f:normalizeAllOf3RC($n as node(),
                                     $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOf3RC(., $options)}
        
    (: Replace nested schemas with innermost schema :)
    (:
    case element(z:schemaXXX) return
        let $next := nav:innermostSiblingLessSchema($n)
        return
            $next/element {node-name(.)} {
                @* !  f:normalizeAllOf3RC(., $options),
                node() ! f:normalizeAllOf3RC(., $options)        
        }
    :)  
    case element(js:allOf) return
        let $children := $n/node() ! f:normalizeAllOf3RC(., $options)
        let $subschemasRaw :=
            for $child in $children 
            let $allOfSubschemas := (
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
                $n/@* !  f:normalizeAllOf3RC(., $options),
                $subschemas
            }
    case element() return
        element {node-name($n)} {
            $n/@* !  f:normalizeAllOf3RC(., $options),
            $n/node() ! f:normalizeAllOf3RC(., $options)        
        }
      
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
        
    default return $n        
};        

(:~
 : Recursive helper function of `f:normalizeAllOf4`.
 :)
declare function f:normalizeAllOf4RC($n as node(),
                                     $options as map(*)?)
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n/node() ! f:normalizeAllOf4RC(., $options)}
        
    (: Replace nested schemas with innermost schema :)
    case element() return
        let $next := 
            if (not($n/self::z:schema)) then $n
            else nav:innermostSiblingLessSchema($n)    
        return
            $next/element {node-name(.)} {
                @* !  f:normalizeAllOf4RC(., $options),
                node() ! f:normalizeAllOf4RC(., $options)        
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
    let $schemaAttNameMapping :=
        map{'name': 'z:schemaName', 'recursiveContent': 'z:recursiveContent'}
        
    (: A function turning schema attributes in pseudo-keywords :)
    let $fn_processSchemaAtts := function($schema) {
        for $att in $schema/@*
        let $elemName := $att/name() ! ($schemaAttNameMapping(.), 'z:schemaInfo-' || .)[1]
        return element {$elemName} {string($att)}
    }

    return
    
    if (not($schema1Content)) then (
        $schema2/* ! f:mergeAllOfSubschemasRC(., ()),
        $schema2 ! $fn_processSchemaAtts(.))            
    else
    
    let $schema2Content := (
        $schema2/* ! f:mergeAllOfSubschemasRC(., ()),
        $schema2 ! $fn_processSchemaAtts(.))
        
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
    case element() return
        if (not($n/z:all)) then f:mergeAllOfConstraints_copy($n, $options)
        else
            typeswitch($n)
            case element(js:description) return f:mergeAllOfConstraints_description($n)            
            case element(js:enum) return f:mergeAllOfConstraints_enum($n)            
            case element(js:format) return f:mergeAllOfConstraints_format($n)
            case element(js:items) return f:mergeAllOfConstraints_items($n)            
            case element(js:minItems) return f:mergeAllOfConstraints_minItems($n)            
            case element(js:minProperties) return f:mergeAllOfConstraints_minProperties($n)
            case element(js:maxItems) return f:mergeAllOfConstraints_maxItems($n)            
            case element(js:maxProperties) return f:mergeAllOfConstraints_maxProperties($n)
            case element(js:nullable) return f:mergeAllOfConstraints_nullable($n)
            case element(js:properties) return f:mergeAllOfConstraints_properties($n)
            case element(z:required) return f:mergeAllOfConstraints_required($n)            
            case element(z:schema) return f:mergeAllOfConstraints_schema($n)            
            case element(z:schemaName) return f:mergeAllOfConstraints_schemaInfoName($n)
            case element(z:recursiveContent) return f:mergeAllOfConstraints_schemaInfoRecursiveContent($n)
            case element(js:type) return f:mergeAllOfConstraints_type($n)            
            default return f:mergeAllOfConstraints_other($n, $options)
    case text() return
        if ($n/../* and $n/not(matches(., '\S'))) then () else $n
    default return $n            
};        

(:~
 : Helper function of `mergeAllOfConstraintsRC`.
 :)
declare function f:mergeAllOfConstraints_copy(
                             $n as node(),
                             $options as map(*)?)
        as node()* {
    element {node-name($n)} {
        $n/@* ! f:mergeAllOfConstraintsRC(., $options),
        $n/node() ! f:mergeAllOfConstraintsRC(., $options)
    }
};        

(: 
 : ===================================================================================
 :
 :     C o m b i n e    k e y w o r d    c o n t e n t s
 :
 : =================================================================================== 
 :)

declare function f:mergeAllOfConstraints_description($description as element(js:description))
        as element()? {
    let $descriptions := $description/z:all/z:constraint/z:value[string()] => distinct-values()       
    return
    
    element {node-name($description)} {
        if (count($descriptions) eq 1) then $descriptions else
        (
        for $item at $pos in $descriptions
        return '(' || $pos || ') ' || $item
        )
        => string-join('&#xA;')
    }        
};

declare function f:mergeAllOfConstraints_format($format as element(js:format))
        as element()? {
    element {node-name($format)} {        
        let $formats := $format/z:all/z:constraint/z:value => distinct-values()
        return
            if (count($formats) eq 1) then text {$formats}
            else
                <z:all>{
                    for $format in $formats
                    return <z:constraint><z:value>{$format}</z:value></z:constraint>
                }</z:all>
    }
};

declare function f:mergeAllOfConstraints_enum($enum as element(js:enum))
        as element()? {
    element {node-name($enum)} {        
        (
        $enum/z:all/z:constraint/z:enumValue => distinct-values() 
        )
        ! <z:enumValue>.</z:enumValue>
    }        
};

declare function f:mergeAllOfConstraints_items($items as element(js:items))
        as element()? {
    let $subschemas := $items/z:all/z:constraint/<z:schema>{node()}</z:schema>        
    let $allOfSchema := element {node-name($items)} {<js:allOf>{$subschemas}</js:allOf>}
    return
        f:resolveAllOf($allOfSchema, ())
};

declare function f:mergeAllOfConstraints_minItems($minItems as element(js:minItems))
        as element()? {
    ($minItems/z:all/z:constraint/z:value/xs:integer(.) => max())
    ! <js:minItems>{.}</js:minItems>
};

declare function f:mergeAllOfConstraints_minProperties($minProperties as element(js:minProperties))
        as element()? {
    ($minProperties/z:all/z:constraint/z:value/xs:integer(.) => max())
    ! <js:minProperties>{.}</js:minProperties>
};

declare function f:mergeAllOfConstraints_maxItems($maxItems as element(js:maxItems))
        as element()? {
    ($maxItems/z:all/z:constraint/z:value/xs:integer(.) => min()) 
    ! <js:maxItems>{.}</js:maxItems>
};

declare function f:mergeAllOfConstraints_maxProperties($maxProperties as element(js:maxProperties))
        as element()? {
    ($maxProperties/z:all/z:constraint/z:value/xs:integer(.) => min()) 
    ! <js:maxProperties>{.}</js:maxProperties>
};

declare function f:mergeAllOfConstraints_nullable($nullable as element(js:nullable))
        as element()? {
    let $values := $nullable/z:all/z:constraint/z:value => distinct-values()
    let $value := 
        if (count($values) eq 1) then $values
        else if ($values = 'false') then 'false'
        else 'true'
    return
        <js:nullable>{$value}</js:nullable>
};

declare function f:mergeAllOfConstraints_properties($properties as element(js:properties))
        as element(js:properties) {
    let $mergedProperties := 
        fold-left($properties/z:all/*, (), f:mergeAllOfConstraintPair_properties#2)
    (: Merged properties may contain an allOf keyword :) 
    let $mergedResolved :=
        for $property in $mergedProperties
        return
            if (not($property/z:allOf)) then $property
            else $property/z:allOf/f:resolveAllOf(., ())
    return
        element {node-name($properties)} {
            $mergedResolved
        }
};

declare function f:mergeAllOfConstraints_required($type as element(z:required))
        as element()? {
    if ($type/z:all/z:constraint/z:value = 'true') then 
        <z:required>true</z:required>
    else
        <z:required>false</z:required>
};

declare function f:mergeAllOfConstraints_schema($schema as element())
        as element()* {
    let $subschemasRaw := $schema/z:all/z:constraint/<z:schema>{@*, node()}</z:schema>
    (: Remove duplicate schemas :)
    let $subschemas :=
        for $subschema at $pos in $subschemasRaw
        group by $subschemaName := ($subschema/@name, $pos)[1]
        return $subschema[1]
    let $allOfSchema :=
        <z:schema><js:allOf>{$subschemas}</js:allOf></z:schema>
    (: let $_DEBUG := file:write('DEBUG_ALL_OF_SCHEMA.xml', $allOfSchema) :)
    let $resolved := f:resolveAllOf($allOfSchema, ())        
    return $resolved/*
        (: <z:schema>{$resolved}</z:schema> , '___SCHEMA: ') :)
};

declare function f:mergeAllOfConstraints_schemaInfoName($name as element(z:schemaName))
        as element()? {
    let $names := $name/z:all/z:constraint/z:value => distinct-values() => sort() => string-join(', ')
    return
        <z:schemaName>{$names}</z:schemaName>
};

declare function f:mergeAllOfConstraints_schemaInfoRecursiveContent($recursiveContent as element(z:recursiveContent))
        as element()? {
    let $values := $recursiveContent/z:all/z:constraint/z:value => distinct-values()
    return
        if ($values = 'yes') then <z:recursiveContent>yes</z:recursiveContent>
};

declare function f:mergeAllOfConstraints_type($type as element(js:type))
        as element()? {
            (: ___TO_DO___ Not yet considered: possibility to have type arrays to be ANDed :)
    let $types1 := $type/z:all/z:constraint/z:value => distinct-values()
    let $types2 := $type/z:all/z:constraint/_ => sort() => string-join('|')
    return
        if (exists($types1)) then <js:type>{$types1[1]}</js:type>
        else if (exists($types2)) then 
            <js:type type="array">{
                ($types2/tokenize(., '\|') => distinct-values() => sort())
                ! <_>.</_>}</js:type>
        else ()                
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
        let $_DEBUG := $property1[name() eq 'valuesXXX'] ! trace(., 'PROPERTY1: ')
        let $_DEBUG := $property2[name() eq 'valuesXXX'] ! trace(., 'PROPERTY2: ')
        return
            if (not($property2)) then $property1
            else
                let $_DEBUG := $property1/name()[.  eq 'valuesXXX'] ! trace(., '_SHARED_PROP: ')            
                let $allOf :=
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
                            <js:allOf>{$schema1, $schema2}</js:allOf>                    
                        }
                let $allOfResolved := $allOf ! f:resolveAllOf($allOf, ())
                let $_DEBUG := if (not($property1/local-name(.) eq 'valuesXXX')) then () else trace($allOf,         '___ALLOF:    ')
                let $_DEBUG := if (not($property1/local-name(.) eq 'valuesXXX')) then () else trace($allOfResolved, '___RESOLVED: ')
                
                let $_DEBUG := if (not($property1/local-name(.) eq 'valuesXXX')) then () else file:write('DEBUG_ALL_OF_VALUES_ELEM1.xml', $allOf)
                let $_DEBUG := if (not($property1/local-name(.) eq 'valuesXXX')) then () else file:write('DEBUG_ALL_OF_VALUES_ELEM2.xml', $allOfResolved)
                
                return $allOfResolved
            ,
            $constraint2Content[not(local-name(.) = $propertyNames1)]
        )
    return (
        $properties
    )
};        

(:~
 : Attempts to merge the constraints of a `z:all` set of constraints.
 : Strategy: if all constraints are deep-equal, the `z:all` set is 
 : replaced with the content of the first constraint. Otherwise,
 : the `z:all` set is retained.
 : 
 : @param other a keyword containing a `z:all` set of constraints
 : @return the result of merging the constraints, or a copy of them
 :)
declare function f:mergeAllOfConstraints_other($other as element(), $options as map(*)?)
        as element()? {
(: Earlier version:

    let $values := $other/z:all/z:constraint/z:value => distinct-values()
    return
        if (count($values) eq 1) then element {node-name($other)} {$values}
        else f:mergeAllOfConstraints_copy($other, $options)
:)
    let $constraints := $other/z:all/z:constraint
    let $uniform :=
        every $index in 2 to count($constraints) satisfies
            deep-equal($constraints[$index - 1], $constraints[$index])
    return
        if ($uniform) then element {node-name($other)} {$other/z:all/z:constraint[1]/node()}
        else f:mergeAllOfConstraints_copy($other, $options)
};            