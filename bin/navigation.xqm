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
 : Returns true if a given element is an OAS schema library
 : element.
 :)
declare function f:oasSchemaLibrary($oasElem as element())
        as xs:boolean {
    exists(        
        $oasElem/(        
            self::definitions,
            self::schemas/parent::components)
        /parent::json[not(parent::*)])
              
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

(:~
 : Recursive helper function of `requiredSchemas`.
 :
 : @param schemas the schemas to be analyzed
 : @param found the schemas already found
 :)
declare function f:requiredSchemasRC($schemas as element()*,
                                     $found as element()*)
        as element()* {
    if (empty($schemas)) then $found else
    
    let $head := head($schemas)
    let $tail := tail($schemas)
    return
        let $refs := $head//_0024ref/string()
        let $referenced := $refs ! foxf:resolveJsonRef(., $head, 'single')
                                 ! f:containingNamedSchema(.)
        let $newTargets := $referenced except $found
        let $newFoundHere := ($found, $newTargets)
        let $newFound := f:requiredSchemasRC($newTargets, $newFoundHere)
        return
            if ($tail) then f:requiredSchemasRC($tail, $newFound)
            else $newFound
};

(:~
 : Returns for a given JSON Schema element the named schema containing it.
 :
 : @param jsElem a JSON Schema element
 : @return the containing named schema
 :)
declare function f:containingNamedSchema($jsElem as element())
        as element()? {
    $jsElem/ancestor-or-self::*
    [parent::definitions/parent::json[not(parent::*)],
     parent::schemas/parent::components/parent::json[not(parent::*)]]
    [1]
};

(:~
 : Returns the message elements representing the message objects of an operation. 
 :
 : @param op an Operation Object
 : @param filter an optional filter for media type objects
 : @return the input messages
 :)
declare function f:operationInputMsg($op as element(), $filter as xs:string?)
        as element()* {
    $op/(
        parameters/_/foxf:jsonEffectiveValue(.)[in eq 'body'],
        requestBody/foxf:jsonEffectiveValue(.)/f:msgObjectFromLogicalMsgObject(., $filter)                        
    )        
};

(:~
 : Returns the message objects used by a given logical message object. A
 : logical message object is an object representing a message used in a
 : particular role (e.g. request or response in case of a particular HTTP
 : status code), yet independently of the media type.
 :
 : In OAS version 2, the message object is equal to the logical message object. 
 : In OAS version 3, the logical message object is a Content Object containing 
 : Media Type Objects, which may the message objects.
 :
 : Parameter $filter is an optional filter controlling the selection of Media 
 : Type Objects; default value is 'json'. See function 'selectMediaTypeObject'
 : for details about the selection.
 :
 : Note that this function may return several message objects.
 :
 : @param msgObject a message object
 : @param filter an optional filter controlling the selection of Media Type Objects;
 :   by default, the Media Type Object of application/json is selected, if existent,
 :   or an arbitrarily selected Media Type Object with a *json* mediatype, if
 :   existent, otherwise an arbitrarily selected Media Type Object is returned
 : @return zero or more Schema Objects
 :)
declare function f:msgObjectFromLogicalMsgObject($lmsgObject as element(), 
                                                 $filter as xs:string)
        as element()* {
    $lmsgObject/(
        .[schema],
        content/f:selectMediaTypeObject(., $filter)
    )
};        

(:~
 : Returns the schema objects used by a given logical message object. A
 : logical message object is an object representing a message used in a
 : particular role (e.g. request or response in case of a particular HTTP
 : status code), yet independently of the media type.
 :
 : In OAS version 2, the schema is the value of the "schema" keyword. 
 : In OAS version 3, the logical message object is a Content Object containing 
 : Media Type Objects, which may contain a "schema" keyword containing the 
 : message schema.
 :
 : Parameter $filter is an optional filter controlling the selection of Media 
 : Type Objects; default value is 'json'. See function 'selectMediaTypeObject'
 : for details about the selection.
 :
 : Note that this function may return several schema objects.
 :
 : Note that a top-level JSON Schema $ref is not resolved.
 :
 : @param msgObject a message object
 : @param filter an optional filter controlling the selection of Media Type Objects;
 :   by default, the Media Type Object of application/json is selected, if existent,
 :   or an arbitrarily selected Media Type Object with a *json* mediatype, if
 :   existent, otherwise an arbitrarily selected Media Type Object is returned
 : @return zero or more Schema Objects
 :)
declare function f:schemaFromLogicalMsgObject($lmsgObject as element(), 
                                              $filter as xs:string)
        as element()* {
    $lmsgObject/(
        schema,
        f:selectMediaTypeObject(., $filter)/schema
    )
};        

(:~
 : Selects from a logical message object a particular MediaType object.
 :
 : If the logical message object is not a Content Object, the
 : input object is returned. (Version 2 - logical message object
 : = mediatype message object.) 
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
declare function f:selectMediaTypeObject($content as element(),
                                         $filter as xs:string)
        as element()* {
    if (not($content/self::content)) then $content else
    
    if ($filter eq 'json') then
        let $set1 := (
            $content/*[convert:decode-key(name(.)) eq 'application/json'],
            $content/*[convert:decode-key(name(.)) eq 'application/scim+json'],
            $content/*[convert:decode-key(name(.)) eq '*/*']
        )
        let $set2 := $content/(* except $set1)
            [convert:decode-key(name(.)) ! matches(., '^application/.*json.*')]
        return ($set1, $set2)
    else
        error(QName((), 'NOT_YET_IMPLEMENTED'), 'The filter must be: "json"')
};

(:~
 : Returns the innermost schema without siblings. Details:
 : - If the input schema has no child schema without siblings, it is returned
 : - Otherwise, the function is called recursively with the child schema.
 :)
declare function f:innermostSiblingLessSchema($schema as element(z:schema))
        as element(z:schema) {
    let $childSchema :=
        $schema
        /z:schema[empty((preceding-sibling::*, following-sibling::*))]
    return
        if ($childSchema) then f:innermostSiblingLessSchema($childSchema)
        else $schema
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
