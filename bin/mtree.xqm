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

import module namespace shut="http://www.oaslab.org/ns/xquery-functions/schema-util" 
at "schemaUtil.xqm";    

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
        let $endpointReports :=            
            let $pathItems := $doc/paths/*
            for $pathItem in $pathItems
            let $path := $pathItem/local-name(.) ! convert:decode-key(.)
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
            <z:doc xml:base="{$doc/base-uri(.)}" 
                   countMsgs="{$countMsgs}" 
                   countMsgUses="{$countMsgUses}"
                   xmlns:oas="http://www.oaslab.org/ns/oas"
                   xmlns:js="http://www.oaslab.org/ns/json-schema">{
                $endpointReports
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
            <z:doc xml:base="{$doc/base-uri(.)}"
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
