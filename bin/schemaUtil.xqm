(:
 : -------------------------------------------------------------------------
 :
 : schemaUtil.xqm - tools supporting the evaluation of JSON Schema content
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/schema-util";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";

(:~
 : Returns the name of a referenced schema. The name here means the
 : last step of the JSON Pointer identifying the referenced schema.
 :
 : @param ref a reference
 : @return the name
 :)
declare function f:jrefName($ref as xs:string)
        as xs:string {
    replace($ref, '.*/', '')       
};        

(:~
 : Returns the message role for a given message element.
 :
 : @param msgElem a message element
 : @return the message role
 :)
declare function f:msgRole($msgElem as element())
        as xs:string {
    typeswitch($msgElem)
    case element(requestBody) | element(_) return 'input'
    case element(default) return 'fault'
    case element(_003200) return 'output'
    default return
        let $jname := $msgElem/util:jname(.)
        return
            if (substring($jname, 1, 1) = ('2', '3')) then 'output-' || $jname
            else 'fault-' || $jname
};

(: Returns the child elements of a Schema Object representing
 : constraints.
 :
 : @param schema a Schema Object
 : @return the child elements representing constraints
 :)
declare function f:schemaConstraints($schema as element())
        as element()* {
    $schema/(* except (description, title))        
};        

(:~
 : Returns true if a JSON Schema node is a keyword, given a schema context.
 : The schema context has been determined by function `getJsContext`.
 :
 : @param schemaContext as xs:string(
 : @return true is a node in this context is a keyword
 :)
declare function f:isJsKeyword($jsContext as xs:string) as xs:boolean {
    not($jsContext = ('properties', 'enum', 'enum-value', 'example', 'example-content'))
};

(:~
 : Determines the schema context established by a given JSON Schema node and
 : the parent schema context. The parent schema context is the context in 
 : which the node appears.
 :
 : For examples, consider a "type" node:
 : - appearing in a 'properties' context, it establishes a 'property-schema' 
 :     context
 : - appearing in a 'property-schema' or any '*-schema' or a 'schema' context, 
 :     it establishes a 'type' context
 : - appearing in an 'enum' context, it establishes an 'enum-value' context
 : - appearing in an example, it establishes an 'example-content' context
 :
 : @param jsNode a JSON Schema node
 : @param parentJsContext the schema context in which the parent node appears
 : @return the schema context established by the input node
 :)
declare function f:getJsContext($node as node(), $parentJsContext as xs:string)
        as xs:string {
    if (not($node instance of element())) then $parentJsContext else
    
    (: Begin with all cases where the new context is not implied by the node name,
       but by the parent context :)
    switch($parentJsContext)
    case 'properties' return 'property-schema'
    case 'enum' return 'enum-value'
    case 'enum-value' return 'enum-value'
    case 'example' return 'example-content'
    case 'example-content' return 'example-content'
    case 'required' return 'required-property'
    case 'allOf' return 'allOf-schema'    
    case 'oneOf' return 'oneOf-schema'
    case 'anyOf' return 'anyOf-schema'
    default return
        let $jname := $node/util:jname(.)
        return $jname
};

(:~
 : Returns a description of the schema consisting of a
 : pattern name and an optional schema name.
 :)
declare function f:schemaPattern($schema as element())
        as map(*) {
    let $children := $schema ! f:schemaConstraints(.)
    let $desc :=
        if (count($children) ne 1) then ()
        else
            (: Pattern: named-schema 
               --------------------- :)
            if ($children/self::_0024ref) then
                let $pattern := 'named-schema'            
                let $name := $children/f:jrefName(.)
                return map{'pattern': $pattern, 'name': $name}
                    
            (: Schema = array schema wo array-level constraints :)                    
            else if ($children/self::items) then
                let $itemsChildren := $children ! f:schemaConstraints(.)
                return
                    if (count($itemsChildren) ne 1) then () else

                    (: Pattern: named-item-schema
                       -------------------------- :)
                    if ($itemsChildren/self::_0024ref) then
                        let $pattern := 'named-item-schema'
                        let $name := $pattern || '?' || $itemsChildren/f:jrefName(.)
                        return map{'pattern': $pattern, 'name': $name}
                            
                    else if ($itemsChildren/self::items) then
                        let $items2Children := $itemsChildren ! f:schemaConstraints(.)
                        return
                            if (count($items2Children) ne 1) then ()
                            else
                                (: Pattern: named-nested-item-schema
                                   --------------------------------- :)
                                if ($items2Children/self::_0024ref) then
                                    let $pattern := 'named-nested-item-schema'
                                    let $name :=  $pattern || '?'|| 
                                        $items2Children/f:jrefName(.)
                                    return map{'pattern': $pattern, 'name': $name}
                                else ()
    return
        if (exists($desc)) then $desc
        else map{'pattern': 'local-schema'}
};   

(:~
 : Returns a schema key which can be used for checking the logical identity of
 : schemas.
 :
 : If the schema has a recognized schema pattern for which a schema name is
 : defined, the schema key is equal to the schema name. Otherwise, the key is 
 : the serialization of a normalized copy of the schema.
 :
 : @param node a node
 : @return the original JSON name of the node
 :)
declare function f:schemaKey($schema as element(), $options as map(*)?)
        as xs:string {    
    let $schemaPattern := f:schemaPattern($schema)
    let $name := $schemaPattern ? name
    return if ($name) then 'name:' || $name else
    
    let $normalized := f:cmpNormalizeSchema($schema, $options)
    let $key := f:schemaKeyForNormSchema($normalized)
    return $key
};

(:~
 : Returns a schema key for a schema normalized for comparison.
 : Should only be used by `f:schemaKey`.
 :)
declare function f:schemaKeyForNormSchema($schema as element())
        as xs:string {
    $schema ! serialize(.)        
};        

declare function f:cmpNormalizeSchema($schema as element(), $options as map(*)?)
        as element() {
    let $retainAnno := $options?retainAnno            
    let $retainExample := $options?retainExample
    return f:cmpNormalizeSchemaRC($schema, 'schema', $retainAnno, $retainExample, $options)
};

declare function f:cmpNormalizeSchemaRC($n as node(),
                                        $jsContext as xs:string,
                                        $retainAnno as xs:boolean?,
                                        $retainExample as xs:boolean?,
                                        $options as map(*)?)
        as node()* {
    typeswitch($n)
    
    (: Element potentially skipped :)
    case element(description) | element(title) | element(example) return
        if (f:isJsKeyword($jsContext) and not($retainAnno)) then () else
            f:cmpNormalizeSchem_copy($n, $jsContext, $retainAnno, $retainExample, $options)
            
    (: Other element :)
    case element() return
        f:cmpNormalizeSchem_copy($n, $jsContext, $retainAnno, $retainExample, $options)
        
    default return $n                
};    

(:~
 : Helper function of `f:cmpNormalizeSchema`. Creates a normalized
 : copy of the input node.
 :
 :)
declare function f:cmpNormalizeSchem_copy(
                                       $n as node(),
                                       $parentJsContext as xs:string,
                                       $retainAnno as xs:boolean?,
                                       $retainExample as xs:boolean?,
                                       $options as map(*)?)
        as node()* {
    let $jsContext := f:getJsContext($n, $parentJsContext) return
    
    element {node-name($n)} {
        for $att in $n/@* order by $att/name() return 
            f:cmpNormalizeSchemaRC($att, $jsContext, $retainAnno, $retainExample, $options)
        ,
        for $node in $n/node() order by $node/name() return 
            f:cmpNormalizeSchemaRC($node, $jsContext, $retainAnno, $retainExample, $options)
    }
};

