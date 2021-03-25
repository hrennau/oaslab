(:
 : -------------------------------------------------------------------------
 :
 : navigation.xqm - functions for navigation OpenAPI documents
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/navigation";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";


declare function f:oasMsgObjects($oasElem as element())
        as element()* {
    let $opElems := f:oasOperationObjects($oasElem)        
    let $msgObjects := (
        $opElems/parameters/_/foxf:jsonEffectiveValue(.)[in eq 'body'],
        $opElems/requestBody/foxf:jsonEffectiveValue(.)
            /content/f:selectMediaTypeObject(., 'json'),
        $opElems/responses/*/foxf:jsonEffectiveValue(.)
            /(.[schema], content/f:selectMediaTypeObject(., 'json'))
        )
    return $msgObjects            
};

(:~
 : Returns the Operation Objects contained by an OpenAPI document.
 : The document is identified by an element from its content.
 :
 : @param oasElem an element from the OpenAPI document in question
 :)
declare function f:oasOperationObjects($oasElem as element())
        as element()* {
    let $oas := $oasElem/ancestor-or-self::*[last()]
    return
        $oas/paths/*/foxf:jsonEffectiveValue(.)/
            (get, post, put, delete, head, options, patch, trace)
};     

(:~
 : Maps a Schema Object to the set of all Schema Objects
 : required to process the Schema Object, including the
 : original Schema Object.
 :
 : @param schema a Schema Object
 : @return the input object and all Schema Objects required
 :   to process it
 :)
declare function f:requiredSchemas($schemas as element()*)
        as element()* {
    f:requiredSchemasRC($schemas, ())        
};

(:
declare function f:requiredSchemasRC($schemas as element()*,
                                     $visited as element()*)
        as element()* {
    if (empty($schemas)) then () else
    
    let $head := head($schemas)
    let $tail := tail($schemas)
    return
        if ($head intersect $visited) then
            if ($tail) then f:requiredSchemasRC($tail, $visited)
            else $visited
        else
            let $refs := trace($head//_0024ref/string() , '_ALL_REFS: ')
            let $referenced := $refs ! foxf:resolveJsonRef(trace(., '_RESOLVE: '), $head, 'single')
            let $_DEBUG := trace(count($referenced), '#REFERENCED: ')
            let $newTargets := $referenced except $visited
            let $_DEBUG := trace($newTargets/generate-id(), '_NEW_TARGET_IDS: ')
            let $newVisited := $visited
            let $newTargetsRecursive := (
                $newTargets,
                f:requiredSchemasRC($newTargets, $newVisited))
            let $newVisited := $newVisited | $newTargetsRecursive
            return
                if ($tail) then f:requiredSchemasRC($tail, $newVisited)
                else $newVisited
};
:)

declare function f:requiredSchemasRC($schemas as element()*,
                                     $visited as element()*)
        as element()* {
    if (empty($schemas)) then () else
    
    let $head := head($schemas)
    let $tail := tail($schemas)
    return
        let $refs := $head//_0024ref/string()
        let $referenced := $refs ! foxf:resolveJsonRef(., $head, 'single')
        let $newTargets := $referenced except $visited
        let $newVisited := ($visited, $newTargets)
        let $newTargetsRecursive := (
            $newTargets, f:requiredSchemasRC($newTargets, $newVisited))
        let $newVisited := $newVisited | $newTargetsRecursive
        return
            if ($tail) then f:requiredSchemasRC($tail, $newVisited)
            else $newVisited
};

(:~
 : Selects from a Content Object a particular MediaType object.
 :
 : The selection is defined by parameter $filter. Currently, only
 : the value 'json' is supported. The selection thus specified 
 : returns, in this order:
 : - the MediaType object for media type 'application/json'
 : - the MediaType object for media type 'application/scim+json'
 : - the Mediatype objects for any other mediatype matching the
 :     pattern 'application/*json'.
 :
 : @param content a content object
 : @param filter defines the selection
 : @return the selected MediaType Objects
 :)
declare function f:selectMediaTypeObject($content as element(content),
                                         $filter as xs:string)
        as element()* {
    if ($filter eq 'json') then
        let $set1 := (
            $content/*[convert:decode-key(name(.)) eq 'application/json'],
            $content/*[convert:decode-key(name(.)) eq 'application/scim+json']
        )
        let $set2 := $content/(* except $set1)
            [convert:decode-key(name(.)) ! matches(., '^application/.*json.*')]
        return ($set1, $set2)
    else
        error(QName((), 'NOT_YET_IMPLEMENTED'), 'The filter must be: "json"')
};

