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
 : Returns the JSON name of a node.
 :
 : @param node a node
 : @return the original JSON name of the node
 :)
declare function f:jname($node as node())
        as xs:string {
    $node/local-name(.) ! convert:decode-key(.)            
};

(:~
 : Writes a document into a file. The document is not necessarily
 : an XML node tree. 
 :
 : Parameter $fileNameRaw specifies a source file name which is either 
 : retained or edited according to other parameters taken from the 
 : options (addPrefix, addSuffix, fnameReplacement). If the value is 
 : a string, it is treated as a file name or a URI from which the file 
 : name is extracted. If the value is a node, the source file name is 
 : derived from the base URI of the node.
 :
 : When $fileNameRaw is not provided, the document must be an XML node tree 
 : and the raw file name is derived from its base URI. 
 :
 : Options:
 : odir - target folder (mandatory!)
 : addPrefix - a prefix to be added to the source file name
 : addSuffix - a suffix to be inserted before the file name
 :     extension
 : fnameReplacement - describes a string replacement to be
 :     applied to the source file name; syntax: fromSubstring=toSubstring
 :  
 : @param doc the document to be written
 : @param fileNameRaw specifies the file name, optionally to be edited before 
 :   use
 : @param options Options controlling the target file location.
 : @return empty sequence
 :)
declare function f:writeFile($doc as item(),
                             $fileNameRaw as item()?,
                             $options as map(*))
        as empty-sequence() {
    let $odir := $options?odir
    return if (not($odir)) then () else

    let $fileName := 
        if ($fileNameRaw) then
            if ($fileNameRaw instance of node()) then $fileNameRaw/base-uri(.) ! file:name(.)
            else $fileNameRaw ! file:name(.)
        else if ($doc instance of node()) then 
            $doc/base-uri(.) ! file:name(.)
        else 
            error(QName((), 'INVALID_CALL'), "Non-node document requires explicit $sourceFilenName.")
    let $fileNameFinal := 
        f:editFileName($fileName, 
                       $options?addPrefix, $options?addSuffix, $options?fnameReplacement)
    let $filePath := $odir || '/' || $fileNameFinal
    return file:write($filePath, $doc)
};

(:~
 : Edits a file name. Input parameters may specify:
 : - a prefix
 : - a suffix (to be inserted before the file name extension, 
 :    if there is one, and appended to the name, otherwise
 : - a replacement, format "from=to"
 :
 : When editing, replacement is performed before adding
 : prefix and suffix.
 :
 : @param fileName the file name to be edited
 : @param prefix a prefix to be inserted
 : @param suffix a suffix to be inserted (before the file name extension)
 : @param a replacement of a substring by another substring; syntax:
 :    from=to
 : @return the edited file name
 :)
declare function f:editFileName($fileName as xs:string,
                                $addPrefix as xs:string?,
                                $addSuffix as xs:string?,
                                $replacement as xs:string?)
        as xs:string {
    let $fname1 :=      
        if (not($replacement)) then $fileName 
        else
            let $from := replace($replacement, '=.*', '')
            let $to := replace($replacement, '^.*?=', '')
            return trace(replace($fileName, $from, $to, 'i') , '_FNAME: ')
    let $fname2 := $addPrefix || $fname1
    let $fname3 := 
        if (not($addSuffix)) then $fname2
        else
           if (not(contains($fname2, '.'))) then $fname2 || $addSuffix
           else replace($fname2, '\.[^.]*$', $addSuffix || '$0')
    return $fname3
};

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
    (: let $ser := json:serialize($useDoc, map{}) :)
    let $ser := serialize($useDoc, map{'method': 'json', 'use-character-maps': map{'/':'/'}})
    return $ser
};   

(:~
 : Reorders a sequence of nodes so that attributs precede
 : any other nodes.
 :
 : @param nodes nodes to be reordered
 : @return reordered nodes
 :)
declare function f:attsElems($nodes as node()*)
        as node()* {
    let $atts := $nodes[self::attribute()]        
    return ($atts, $nodes except $atts)
};        
        
        