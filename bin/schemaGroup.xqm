(:
 : -------------------------------------------------------------------------
 :
 : schemaGroup.xqm - functions processing and reporting allOf, oneOf, anyOf groups
 :
 : -------------------------------------------------------------------------
 :)

(:~@operations
   <operations>
      <operation name="group" type="item()?" func="groupOP">     
         <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
         <param name="skipWithSingleChild" type="xs:boolean?" default="false"/>
         <param name="groupKind" type="xs:string*" fct_values="allOf, oneOf, anyOf"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>         
      </operation>
   </operations>      
:)

module namespace f="http://www.oaslab.org/ns/xquery-functions/jtree";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

import module namespace jt="http://www.oaslab.org/ns/xquery-functions/jtree" 
at "jtree.xqm";    

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
 : Implements the operation 'group'. See function `groupReport` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about the schema groups occurring in the input documents
 :) 
declare function f:groupOP($request as element())
        as item()? {
    let $oas := tt:getParam($request, 'oas')/*
    let $skipWithSingleChild := tt:getParam($request, 'skipWithSingleChild')   
    let $groupKind := tt:getParam($request, 'groupKind')
    
    let $odir := tt:getParam($request, 'odir')
    let $addSuffix := tt:getParam($request, 'addSuffix')
    let $addPrefix := tt:getParam($request, 'addPrefix')
    let $fnameReplacement := tt:getParam($request, 'fnameReplacement')
    
    let $options := map:merge((
        $skipWithSingleChild ! map:entry('skipWithSingleChild', .),
        $groupKind ! map:entry('groupKind', .),
        $odir ! map:entry('odir', .),
        $addSuffix ! map:entry('addSuffix', .),
        $addPrefix ! map:entry('addPrefix', .),
        $fnameReplacement ! map:entry('fnameReplacement', .)
    ))
    return
        f:groupReport($oas, $options)
};

(:~
 : Maps a JSON Schema schema to a tree representation.
 :
 : @param schema a schema object
 : @return the tree representation
 :) 
declare function f:groupReport($oas as element()+,
                               $options as map(*)?)
        as item()* {
        
    let $odir := $options?odir        
    let $skipWithSingleChild := $options?skipWithSingleChild
    let $groupKind := $options?groupKind
    
    let $docReports :=        
        for $doc in $oas
        let $groups := $doc//(allOf, oneOf, anyOf)[empty($groupKind) or local-name(.) = $groupKind]
        
        let $groupReports :=
            for $group in $groups[not($skipWithSingleChild) or count(*) gt 1]
            let $location := foxf:namePath($group, 'jname', ())
            let $groupTree := jt:jtree($group, $options)
            let $groupTreeFlattened := jt:jtreeFlattenGroup($groupTree, $options)
            let $groupSummary := f:groupSummary($groupTree, $groupTreeFlattened, $group)
            return
                element {'z:' || local-name($group)} {
                    attribute jpath {$location},
                    $groupSummary,
                    <z:details>{
                        <z:origTree>{$groupTree}</z:origTree>,
                        <z:groupExpandedTree>{$groupTreeFlattened}</z:groupExpandedTree>
                           [not(deep-equal($groupTree, $groupTreeFlattened))]
                    }</z:details>
                }
        let $groupReportsCollected :=
            for $groupReport in $groupReports
            group by $kind := $groupReport/local-name(.) ! replace(., '.+:', '')
            return
                element {'z:' || $kind || 's'} {
                    for $gr in $groupReport order by $gr/@jpath return $gr
                }
        return
            <z:doc xml:base="{$doc/base-uri(.)}">{
                $groupReportsCollected
            }</z:doc>
    return 
        if ($odir) then
            $docReports ! util:writeFile(., base-uri(.) ! file:name(.) ! replace(., '\.json$', '.xml'), $options)
        else
            <z:docs count="{count($docReports)}" 
                    xmlns:oas="http://www.oaslab.org/ns/oas"
                    xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $docReports
            }</z:docs>
};

declare function f:groupSummary($groupTree as element(*), 
                                $groupTreeFlattened as element(*),
                                $group as element())
        as element(z:groupSummary) {
    let $types := 
        for $child in $groupTreeFlattened/*
        return
            if ($child/@type) then $child/@type
            else if ($child/(js:properties, js:additionalProperties)) then 'object'
            else if ($child/(js:items, js:additionalItems)) then 'array'
            else '?'
    let $typesDV := distinct-values($types) => sort()
    let $typesRequired := $typesDV[matches(., '[^?]$')]
    let $schemasNoType := $types[. eq '?']    
    let $typesHetero := count($typesRequired) gt 1
    return
        <z:groupSummary countSubschemas="{count($groupTreeFlattened/*)}"
                        typesHetero="{$typesHetero}"
                        types="{$typesDV}">{
            if (empty($schemasNoType)) then () else
                attribute WARN_count_schemas_without_type {count($schemasNoType)}
        }</z:groupSummary>
};        
