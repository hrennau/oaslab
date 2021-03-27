(:
 : -------------------------------------------------------------------------
 :
 : schemaUtil.xqm - some general tools supporting the evaluation of JSON Schema content
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
 : Determins the schema context established by a given JSON Schema node and
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
declare function f:getJsContext($jsNode as element(), $parentJsContext as xs:string)
        as xs:string {
    switch($parentJsContext)
    case 'properties' return 'property-schema'
    case 'property-schema' return $jsNode/local-name(.)
    case 'enum' return 'enum-value'
    case 'enum-value' return 'enum-value'
    case 'example' return 'example-content'
    case 'example-content' return 'example-content'
    default return $jsNode/util:jname(.)
};

(:~
 : Returns a schema key which can be used for checking the logical identity of
 : schemas.
 :
 : @param node a node
 : @return the original JSON name of the node
 :)
declare function f:schemaKey($schema as element(), $options as map(*)?)
        as xs:string {
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

