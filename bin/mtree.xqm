(:
 : -------------------------------------------------------------------------
 :
 : msgtree.xqm - functions constructing tree representations of OAS messages
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="mtree" type="item()?" func="mtreeOP">     
         <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
         <param name="flat" type="xs:boolean?" default="false"/>
         <param name="bare" type="xs:boolean?"/>         
         <param name="pathFilter" type="nameFilter?"/>
         <param name="methodFilter" type="nameFilter?"/>
         <param name="roleFilter" type="nameFilter?"/>
         <param name="schemaKeyStyle" type="xs:string?" fct_values="path, pathname" default="pathname"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>
      </operation>
      <operation name="stree" type="item()?" func="streeOP">     
         <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
         <param name="flat" type="xs:boolean?" default="false"/>
         <param name="bare" type="xs:boolean?"/>         
         <param name="nameFilter" type="nameFilter?"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>
      </operation>
      
    </operations>  
:)  
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/mtree";

import module namespace jt="http://www.oaslab.org/ns/xquery-functions/jtree" 
at "jtree.xqm";    

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

import module namespace name="http://www.oaslab.org/ns/xquery-functions/name-util" 
at "nameUtil.xqm";    

import module namespace shut="http://www.oaslab.org/ns/xquery-functions/schema-util" 
at "schemaUtil.xqm";    

import module namespace spat="http://www.oaslab.org/ns/xquery-functions/schema-pattern" 
at "schemaPattern.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

import module namespace nav="http://www.oaslab.org/ns/xquery-functions/navigation" 
at "navigation.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";
declare namespace oas="http://www.oaslab.org/ns/oas";

(:~
 : Implements the operation 'mtree'. See function `mtree` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:mtreeOP($request as element())
        as item()? {
    let $oas := tt:getParam($request, 'oas')/*
    let $flat := tt:getParam($request, 'flat')
    let $schemaKeyStyle := tt:getParam($request, 'schemaKeyStyle')    
    let $bare := tt:getParam($request, 'bare')
    let $odir := tt:getParam($request, 'odir')
    let $addSuffix := tt:getParam($request, 'addSuffix')
    let $addPrefix := tt:getParam($request, 'addPrefix')
    let $fnameReplacement := tt:getParam($request, 'fnameReplacement')
    
    let $pathFilter := tt:getParam($request, 'pathFilter')
    let $methodFilter := tt:getParam($request, 'methodFilter')
    let $roleFilter := tt:getParam($request, 'roleFilter')
    
    let $options := map:merge((
        $flat ! map:entry('flat', .),
        $schemaKeyStyle ! map:entry('schemaKeyStyle', .),        
        $bare ! map:entry('bare', .), 
        $odir ! map:entry('odir', .),
        $addSuffix ! map:entry('addSuffix', .),
        $addPrefix ! map:entry('addPrefix', .),
        $fnameReplacement ! map:entry('fnameReplacement', .),
        $pathFilter ! map:entry('pathFilter', .),
        $methodFilter ! map:entry('methodFilter', .),      
        $roleFilter ! map:entry('roleFilter', .)
    ))
    return
        f:mtree($oas, $options)
};

(:~
 : Implements the operation 'mtree'. See function `mtree` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:streeOP($request as element())
        as item()? {
    let $oas := tt:getParam($request, 'oas')/*
    let $flat := tt:getParam($request, 'flat')
    let $bare := tt:getParam($request, 'bare')    
    let $odir := tt:getParam($request, 'odir')
    let $addSuffix := tt:getParam($request, 'addSuffix')
    let $addPrefix := tt:getParam($request, 'addPrefix')
    let $fnameReplacement := tt:getParam($request, 'fnameReplacement')
    
    let $nameFilter := tt:getParam($request, 'nameFilter')
    
    let $options := map:merge((
        $flat ! map:entry('flat', .),
        $bare ! map:entry('bare', .),        
        $odir ! map:entry('odir', .),
        $addSuffix ! map:entry('addSuffix', .),
        $addPrefix ! map:entry('addPrefix', .),
        $addPrefix ! map:entry('fnameReplacement', .),
        $nameFilter ! map:entry('nameFilter', .)
    ))
    return
        f:stree($oas, $options)
};

(:~
 : Creates a message tree report. Details later ...
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return a JSON Schema References Report
 :) 
declare function f:mtree($oas as element()+,
                         $options as map(xs:string, item()*)?)
        as item()? {
        
    let $odir := $options?odir        
    let $pathFilter := $options?pathFilter
    let $methodFilter := $options?methodFilter
    let $roleFilter := $options?roleFilter
    let $optionsSchemaKey := map{'retainAnno': false(), 'retainExample': false()}
    
    let $docReports :=        
        for $doc in $oas 
        return
            f:oasMsgTrees($doc, $options)
    return 
        if ($odir) then
            $docReports ! util:writeFile(., @sourceOAS ! file:name(.) ! replace(., '\.json$', '.xml'), $options)
        else
            <z:docs count="{count($docReports)}" 
                    xmlns:oas="http://www.oaslab.org/ns/oas"
                    xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $docReports
            }</z:docs>
};

(:~
 : Creates a message tree report. Details later ...
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return a JSON Schema References Report
 :) 
declare function f:oasMsgTrees($oas as element(),
                               $options as map(xs:string, item()*)?)
        as element() {
    let $bare := $options?bare
    let $optionsOasMsgObjectTree := map:put($options, 'withSchemaDict', not($bare))    
    let $treeAndSchemaDict := f:oasMsgObjectTree($oas, $optionsOasMsgObjectTree)        
    let $tree := 
        <z:msgObjectTree>{
            $treeAndSchemaDict[. instance of node()]/(@*, *)
        }</z:msgObjectTree>
    let $schemaDict := $treeAndSchemaDict[. instance of map(*)]
    let $schemaTrees := if ($bare) then () else
        for $key in map:keys($schemaDict)
        let $tree := jt:jtree($schemaDict($key), $options)
        let $schemaName := $key[not(starts-with(., '<'))]
        let $schemaKey := $key[starts-with(., '<')]
        order by lower-case($key)
        return
            <z:msg>{
                $schemaName ! attribute schemaName {.},
                $schemaKey ! attribute schemaKey {.},
                $tree
            }</z:msg> 
    let $schemaTreeDict := if ($bare) then () else
        <z:msgs count="{count($schemaTrees)}"
                xmlns:js="http://www.oaslab.org/ns/json-schema">{
            $schemaTrees
        }</z:msgs>   
    let $report :=
        <z:oas>{
            $tree/@*,
            $schemaTreeDict,
            $tree
        }</z:oas>
    return $report
};

(:~
 : Creates a message object tree and (optionally) a schema dictionary.
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return message objects trees and an optional message dictionary
 :) 
declare function f:oasMsgObjectTree(
                         $oas as element(),
                         $options as map(xs:string, item()*)?)
        as item()+ {
    let $withSchemaDict := $options?withSchemaDict
    let $schemaKeyStyle := $options?schemaKeyStyle
    
    let $fn_msgElem := 
        function($role, $mediatype, $schemaKey) {
            element z:msg {
                attribute role {$role}, 
                $mediatype ! attribute mediaType {$mediatype}, 
                attribute schemaKey {$schemaKey}
            }        
        }
        
    let $pathFilter := $options?pathFilter
    let $methodFilter := $options?methodFilter
    let $roleFilter := $options?roleFilter
    let $optionsSchemaKey := map{'retainAnno': false(), 'retainExample': false()}
    let $oasTreeContentEtc := 
        let $pathElemsEtc :=        
            for $pathItem in $oas/paths/*
            let $path := $pathItem/util:jname(.)
            let $effectivePathItem := $pathItem/foxf:jsonEffectiveValue(.)            
            let $opElemsEtc := 
                for $op in $effectivePathItem/
                    (get, post, put, delte, head, options, patch, trace)
                let $httpMethod := $op/local-name(.)
                let $msgElemsEtc := (
                    let $msgo := nav:operationInputMsg($op, 'json')[1] 
                    let $mediatype := $msgo[parent::content]/util:jname(.)
                    let $schemaElem := $msgo/schema
                    let $schemaKey := $schemaElem ! shut:schemaKey(., ())
                    where $schemaKey and (empty($roleFilter) or 
                            tt:matchesNameFilter('input', $roleFilter))
                    return (
                        map:entry($schemaKey, $schemaElem),
                        $fn_msgElem('input', $mediatype, $schemaKey))
                    ,
                    for $rs in $op/responses/*
                    let $msgRole := $rs/shut:msgRole(.)
                    let $msgo := $rs/foxf:jsonEffectiveValue(.)
                        /nav:msgObjectFromLogicalMsgObject(., 'json')[1]
                    let $mediatype := $msgo[parent::content]/util:jname(.)           
                    let $schemaElem := $msgo/schema
                    let $schemaKey := $schemaElem ! shut:schemaKey(., ())
                    where $schemaKey and (empty($roleFilter) or 
                        tt:matchesNameFilter($msgRole, $roleFilter))
                    order by 
                        if (starts-with($msgRole, 'input')) then 1 
                        else if (starts-with($msgRole, 'output')) then 2
                        else 3,
                        $msgRole
                    return (
                        map:entry($schemaKey, $schemaElem),
                        $fn_msgElem($msgRole, $mediatype, $schemaKey))
                )
                let $msgElems := $msgElemsEtc[. instance of node()]
                let $schemaDictEntries := $msgElemsEtc[not(. instance of node())][$withSchemaDict]
                where exists($msgElems) and (empty($methodFilter) or 
                    tt:matchesNameFilter($httpMethod, $methodFilter))                
                return (
                    $schemaDictEntries,
                    <z:operation method="{$httpMethod}">{
                        $op/operationId ! attribute operationId {.},
                        $msgElems
                    }</z:operation>)
            let $opElems := $opElemsEtc[. instance of node()]        
            let $schemaDictEntries := $opElemsEtc[not(. instance of node())]

            where empty($pathFilter) or tt:matchesNameFilter($path, $pathFilter)                    
            order by lower-case($path)
            return (
                $schemaDictEntries,
                <z:endpoint path="{$path}">{$opElems}</z:endpoint>)
        let $pathElems := $pathElemsEtc[. instance of node()] 
        let $schemaDictEntries := $pathElemsEtc[. instance of map(*)][$withSchemaDict]
        return (
            $schemaDictEntries,
            $pathElems
        )
        
    let $oasTreeContent := $oasTreeContentEtc[. instance of node()]
    let $schemaDictEntries := $oasTreeContentEtc[not(. instance of node())]
      
    let $schemaKeys := $oasTreeContent//@schemaKey
    let $countMsgUses := count($schemaKeys)    
    let $countMsgs := count($schemaKeys => distinct-values())
    let $oasTree := <z:oas sourceOAS="{$oas/base-uri(.)}"
                           countMsgs="{$countMsgs}"
                           countMsgUses="{$countMsgUses}" 
    >{$oasTreeContent}</z:oas>
    let $schemaDict := map:merge($schemaDictEntries)[$withSchemaDict]
    
    let $schemaKeyMappings := f:getSchemaKeyMappings($oasTree, $schemaDict, $schemaKeyStyle)    
    let $oasTreeEdited :=
        if (empty($schemaKeyMappings)) then $oasTree else
            copy $oasTree_copy := $oasTree
            modify 
                for $key in map:keys($schemaKeyMappings) return
                    for $schemaKey in $oasTree_copy//@schemaKey[. eq $key]
                    return replace value of node $schemaKey with $schemaKeyMappings($key)
            return $oasTree_copy  
    let $schemaDictEdited :=
        if (not($withSchemaDict)) then ()
        else if (empty($schemaKeyMappings)) then $schemaDict else
            let $keysToBeReplaced := map:keys($schemaKeyMappings)
            let $keysDict := $schemaDict ! map:keys($schemaDict)
            return map:merge((
                $keysDict[not(. = $keysToBeReplaced)] ! map:entry(., $schemaDict(.)),
                for $key in $keysToBeReplaced return
                    $schemaKeyMappings($key) ! map:entry(., $schemaDict($key))
            ))
    return (
        $schemaDictEdited,
        $oasTreeEdited
    )
};

declare function f:getSchemaKeyMappings($oasTree as element(), 
                                        $schemaDict as map(*),
                                        $schemaKeyStyle as xs:string)
        as map(*)? {
    let $schemaKeys := $oasTree//@schemaKey[starts-with(., '<')]
    return
        if (empty($schemaKeys)) then () else
            map:merge((
                for $schemaKey in $schemaKeys
                group by $keyValue := string($schemaKey)
                return 
                    switch($schemaKeyStyle)
                    
                    (: Style 'pathname' - use a mapping of URI path/method/msgRole to an XML name :)
                    case 'pathname' return
                        let $schemaKey1 := $schemaKey[1]
                        let $schema := $schemaDict($schemaKey1)                        
                        let $operationId := $schemaKey1/ancestor::z:operation/@operationId                 
                        let $uriPath := $schemaKey1/ancestor::z:endpoint/@path
                        let $httpMethod := $schemaKey1/ancestor::z:operation/@method
                        let $msgRole := $schemaKey1/ancestor::z:msg/@role
                        let $name := $schema/spat:msgNodeName(., $operationId, $uriPath, $httpMethod, $msgRole, true())
                                     ?msgNodeName
                        let $_DEBUG := trace($name, '_SCHEMA__NAME: ')
                        return map:entry($schemaKey1, $name)


                    default return
                        $schemaKey[1]/map:entry(., string-join((
                            ancestor::z:endpoint[1]/@path,
                            ancestor::z:operation[1]//@method,
                            ancestor::z:msg[1]/@role), '###'))
                    ))                    
};

(:~
 : Creates a message tree report. Details later ...
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return a JSON Schema References Report
 :) 
declare function f:mtreeOld($oas as element()+,
                            $options as map(xs:string, item()*)?)
        as item()? {
        
    let $odir := $options?odir        
    let $pathFilter := $options?pathFilter
    let $methodFilter := $options?methodFilter
    let $roleFilter := $options?roleFilter
    let $optionsSchemaKey := map{'retainAnno': false(), 'retainExample': false()}
    
    let $docReports :=        
        for $doc in $oas
        let $endpointReports :=            
            let $pathItems := $doc/paths/*
            for $pathItem in $pathItems
            let $path := $pathItem/util:jname(.)
            let $effectivePathItem := $pathItem/foxf:jsonEffectiveValue(.)
            
            let $operationReports :=
                for $op in $effectivePathItem/(get, post, put, delte, head, options, patch, trace)
                let $httpMethod := $op/local-name(.)
                let $operationId := $op/operationId
                
                let $msgReports :=
                    let $rq := 
                        let $msgo := $op/(
                            parameters/_/foxf:jsonEffectiveValue(.)[in eq 'body'],
                            requestBody/foxf:jsonEffectiveValue(.)/content/nav:selectMediaTypeObject(., 'json')                        
                        )
                        let $schemaKey := $msgo/schema ! shut:schemaKey(., ())
                        let $msgoTree := $msgo ! f:msgObjectTree(., $options)
                        where $msgoTree and (empty($roleFilter) or tt:matchesNameFilter('input', $roleFilter))
                        return <z:msg role="input" schemaKey="{$schemaKey}">{$msgoTree}</z:msg>
                    let $rs := 
                        for $rs in $op/responses/*
                        let $jname := $rs/local-name(.) ! convert:decode-key(.)
                        let $role := 
                            if ($jname eq 'default') then 'fault'
                            else
                                let $d1 := $jname ! substring(., 1, 1) ! xs:integer(.)
                                return
                                    if ($d1 lt 4) then
                                        if ($jname eq '200') then 'output'
                                        else 'output-' || $jname
                                    else 'fault-' || $jname
                        let $rse := $rs/foxf:jsonEffectiveValue(.)
                        let $msgo :=
                            if ($rse[schema]) then $rse
                            else $rse/content/nav:selectMediaTypeObject(., 'json')
                        let $schemaKey := $msgo/schema ! shut:schemaKey(., ())                            
                        let $msgoTree := $msgo ! f:msgObjectTree(., $options)
                        where empty($roleFilter) or tt:matchesNameFilter($role, $roleFilter)                        
                        return $msgo ! <z:msg role="{$role}" schemaKey="{$schemaKey}">{$msgoTree}</z:msg>
                    return ($rq, $rs)
                where empty($methodFilter) or tt:matchesNameFilter($httpMethod, $methodFilter)                    
                return
                    <z:op httpMethod="{$httpMethod}">{
                        $operationId ! attribute operationId {.},
                        $msgReports
                    }</z:op>
            where empty($pathFilter) or tt:matchesNameFilter($path, $pathFilter)                    
            order by lower-case($path)
            return
                <z:endpoint path="{$path}">{
                    $operationReports
                }</z:endpoint>
        let $msgUses := $endpointReports//z:msg
        let $countMsgUses := count($msgUses)
        let $countMsgs := count($msgUses/@schemaKey => distinct-values())
        return
            <z:doc sourceOAS="{$doc/base-uri(.)}" 
                   countMsgs="{$countMsgs}" 
                   countMsgUses="{$countMsgUses}"
                   xmlns:oas="http://www.oaslab.org/ns/oas"
                   xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $endpointReports
            }</z:doc>
    return 
        if ($odir) then
            $docReports ! util:writeFile(., @sourceOAS ! file:name(.) ! replace(., '\.json$', '.xml'), $options)
        else
            <z:docs count="{count($docReports)}" 
                    xmlns:oas="http://www.oaslab.org/ns/oas"
                    xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $docReports
            }</z:docs>
};

(:~
 : Creates a schema tree report. Details later ...
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return a JSON Schema References Report
 :) 
declare function f:stree($oas as element()+,
                         $options as map(xs:string, item()*)?)
        as item()? {
        
    let $nameFilter := $options?nameFilter    
    
    let $docReports :=        
        for $doc in $oas
        let $schemaReports :=
            for $schema in $doc/(definitions, components/schemas)/*
            let $sname := $schema ! local-name(.) ! convert:decode-key(.)
            let $tree := jt:jtree($schema, $options)
            where empty($nameFilter) or tt:matchesNameFilter(local-name(.) ! convert:decode-key(.), $nameFilter)
            order by $sname
            return
                <z:schema name="{$sname}">{
                    $tree
                }</z:schema>
        return
            <z:doc sourceOAS="{$doc/base-uri(.)}"
                   xmlns:oas="http://www.oaslab.org/ns/oas"
                   xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $schemaReports
            }</z:doc>
            
    return
        <z:docs count="{count($docReports)}" 
                xmlns:oas="http://www.oaslab.org/ns/oas"
                xmlns:js="http://www.oaslab.org/ns/json-schema">{
            $docReports
        }</z:docs>
};

(:~
 : Returns a tree representation of a message.
 :
 : @param msgObject a Message Object
 : @param options options controling the tree construction
 : @return a tree representation
 :)
declare function f:msgObjectTree($msgObject as element(),
                                 $options as map(*)?)
        as node()* {
    f:msgObjectTreeRC($msgObject, $options)        
};        

(:~
 : Recursive helper function of `msgObjectTree`.
 :)
declare function f:msgObjectTreeRC($n as node(),
                                   $options as map(*)?)
        as node()* {
    typeswitch($n)
    case element(schema) return
        let $content := $n/node() ! jt:jtree(., $options)
        let $contentAtts := $content[self::attribute()]
        let $contentElems := $content except $contentAtts
        return
            <oas:schema>{
                $contentAtts, $contentElems
            }</oas:schema>
    case element() return
        if ($n/../schema) then () else
        
        element {'oas:' || local-name($n)} {
            $n/@* ! f:msgObjectTreeRC(., $options),
            $n/node() ! f:msgObjectTreeRC(., $options)
        }        
    default return $n        
};        
