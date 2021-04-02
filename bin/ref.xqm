(:
 : -------------------------------------------------------------------------
 :
 : jsref.xqm - functions dealing with JSON references
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="jsref" type="item()?" func="jsrefOP">     
         <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
         <param name="odir" type="xs:string?"/>
      </operation>
    </operations>  
:)  
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/ref";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

import module namespace nav="http://www.oaslab.org/ns/xquery-functions/navigation" 
at "navigation.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";

(:~
 : Implements the operation 'jsref. See function `jsrefReport` for details.
 :
 : @param request the operation request with its input parameters
 : @return a report about JSON Schema references used in the input documents
 :) 
declare function f:jsrefOP($request as element())
        as item()? {
    let $oas := tt:getParam($request, 'oas')/*
    let $odir := tt:getParam($request, 'odir')
    let $addSuffix := tt:getParam($request, 'addSuffix')
    let $addPrefix := tt:getParam($request, 'addPrefix')
    let $fnameReplacement := tt:getParam($request, 'fnameReplacement')

    let $options := map:merge((
        $odir ! map:entry('odir', .),
        $addSuffix ! map:entry('addSuffix', .),
        $addPrefix ! map:entry('addPrefix', .),
        $addPrefix ! map:entry('fnameReplacement', .)        
    ))
    return
        f:jsrefReport($oas, $options)
};

(:~
 : Creates a JSON Schema References Report. Details later ...
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @return a JSON Schema References Report
 :) 
declare function f:jsrefReport($oas as element()+,
                               $options as map(xs:string, item()*)?)
        as item()? {
        
    let $docReports :=        
        for $doc in $oas
        let $refSchemas := foxf:oasJschemaKeywords($doc, '$ref', ())/..
        let $refReports :=
            for $refSchema in $refSchemas
            let $jpath := foxf:namePath($refSchema, 'jname', ())
            let $expanded := f:expandRef($refSchema)
            return
                <schema jpath="{$jpath}">{
                    $expanded
                }</schema>
        return
            <doc xml:base="{$doc/base-uri(.)}">{
                $refReports
            }</doc>
    return
        <docs count="{count($docReports)}">{
            $docReports
        }</docs>
};

declare function f:expandRef($object as element())
        as element() {
    f:expandRefRC($object, ())        
};        

declare function f:expandRefRC($object as element(),
                               $visited as element()*)
        as node()* {
    if ($object intersect $visited) then
        attribute RECURSIVE_CYCLE {foxf:namePath($object, 'jname', ())}
    else
    
    element {node-name($object)} {
        $object/@*,
        for $child in $object/*
        return
            typeswitch($child)
            case element(_0024ref) return
                <_0024referenced>{
                   foxf:resolveJsonRef($child, $child, 'single') 
                   ! f:expandRefRC(., ($visited, $object)) 
                }</_0024referenced>
            default return $child                
    }
};        

(:~
 : Extracts from a reference the name of the last step.
 :
 : @param ref a JSON reference
 : @return the name of the last step
 :)
declare function f:refValueName($ref as xs:string)
        as xs:string {
    replace($ref, '.*/', '')            
};        
