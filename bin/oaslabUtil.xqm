(:
 : -------------------------------------------------------------------------
 :
 : oaslabUtil.xqm - utility functions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/util";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace foxf="http://www.foxpath.org/ns/fox-functions" 
at "tt/_foxpath-fox-functions.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";

(:~
 : Returns the path of the 'resources' folder.
 :
 : @return an absolute path
 :) 
declare function f:resourcesPath()
        as xs:string {
    static-base-uri() ! resolve-uri('../resources', .)
};

(:~
 : Creates a copy with all whitespace text nodes serving indentation
 : removed.
 :
 : @param doc the document to be processed
 : @param options for future use
 : @return an edited copy of the input document
 :)
declare function f:prettyPrint($doc as node(), 
                               $options as map(xs:string, item()*)?)
        as node()? {
    f:prettyPrintRC($doc, $options)        
};        

(:~
 : Recursive helper function of `prettyPrint`.
 :)
declare function f:prettyPrintRC($n as node(),
                                 $options as map(xs:string, item()*)?)
        as node()? {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:prettyPrintRC(., $options)}
    case element() return
        $n/element {node-name(.)} {
            @* ! f:prettyPrint(., $options),
            node() ! f:prettyPrint(., $options)
        }
    case text() return
        if ($n/not(matches(., '\S')) and $n/../*) then () else $n
    default return $n        
};   

declare function f:jsonSerialize($doc as element())
        as xs:string {
    let $useDoc :=
        if ($doc/@xml:*) then
            $doc/element {node-name($doc)} {@* except @xml:*, node()}
        else $doc
    let $ser := json:serialize($useDoc, map{})
    return $ser
};   
        