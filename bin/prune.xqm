(:
 : -------------------------------------------------------------------------
 :
 : prune.xqm - functions writing pruned copies of OpenAPI documents
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="prune" type="item()?" func="pruneOP">     
         <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
         <param name="pathFilter" type="nameFilter?"/>
         <param name="methodFilter" type="nameFilter?"/>
         <param name="operationIdFilter" type="nameFilter?"/>
         <param name="statusFilter" type="nameFilter?"/>
         <param name="odir" type="xs:string?"/>
         <param name="addSuffix" type="xs:string?"/>
         <param name="addPrefix" type="xs:string?"/>
         <param name="fnameReplacement" type="xs:string?"/>
      </operation>
    </operations>  
:)  
 
module namespace f="http://www.oaslab.org/ns/xquery-functions/prune";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_nameFilter.xqm";    

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util" 
at "oaslabUtil.xqm";    

import module namespace nav="http://www.oaslab.org/ns/xquery-functions/navigation" 
at "navigation.xqm";    

declare namespace z="http://www.oaslab.org/ns/structure";

(:~
 : Implements the operation 'prune'. See function `pruneOAS` for details.
 :
 : @param request the operation request with its input parameters
 : @return pruned copies, either returned as strings, or written
 :   into files
 :) 
declare function f:pruneOP($request as element())
        as item()? {
    let $oas := tt:getParam($request, 'oas')/*
    let $pathFilter := tt:getParam($request, 'pathFilter')
    let $methodFilter := tt:getParam($request, 'methodFilter')
    let $opidFilter := tt:getParam($request, 'operationIdFilter')
    let $statusFilter := tt:getParam($request, 'statusFilter')
    let $filters :=
        map:merge((
            $pathFilter ! map:entry('pathFilter', .),
            $methodFilter ! map:entry('methodFilter', .),
            $opidFilter ! map:entry('opidFilter', .),
            $statusFilter ! map:entry('statusFilter', .)
        ))
    
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
        f:pruneOAS($oas, $filters, $options)
};

(:~
 : Creates pruned copies of the input OpenAPI documents. Pruning 
 : is by filtering Path Item Objects and/or Operation Objects, 
 : and removing any named schemas not referenced in the pruned document.
 :
 : If $odir is specified, the pruned copies are written into files 
 : in that folder, retaining their file name. Otherwise, they are 
 : returned as strings.
 :
 : @param oas one or several OpenAPI documents, as XML node trees
 : @param filters filters defining the pruning (pathFilter, methodFilter,
 :   operationIdFilter, statusFilter)
 : @return pruned copies, either returned as strings, or written
 :   into files
 :) 
declare function f:pruneOAS($oas as element()+,
                            $filters as map(*),
                            $options as map(xs:string, item()*)?)
        as item()? {
      
    let $odir := $options?odir
    for $doc in $oas
    let $docEdited := f:pruneDocOAS($doc, $filters)
    let $jdoc := $docEdited ! util:jsonSerialize(.)
    return
        if ($odir) then $jdoc ! util:writeFile(., $doc, $options)
        else $jdoc
};

(:~
 : Creates a pruned copy of an OpenAPI document. If $filters?pathFilter 
 : is not empty, any Path Item Objects with a non-matching path are removed. 
 : If $filters?methodFilter is not empty, any Operation Objects with a 
 : non-matching name are removed. If $filters?opidFilter is not empty,
 : any operation which does not have a matching operation Id is removed.
 : If $filters?statusFilter, any message not assigned to a matching HTTP
 : status code is removed.
 : 
 : @param oas an OpenAPI document
 : @param pathFilter a filter for Path Item Objects
 : @param methodFilter a filter for Operation Objects, filtering by element name
 : @param opidFilter a filter for Operation Objects, filtering by operation Id 
 : @return a pruned copy of the input document.
 :)
declare function f:pruneDocOAS($oas as element(),
                               $filters as map(*))
        as node()? {
    let $methodFilter := $filters?methodFilter
    let $opidFilter := $filters?opidFilter
    
    let $opElems :=
        if (empty(($methodFilter, $opidFilter))) then () else nav:oasOperationObjects($oas)
    let $prune1 := f:prunePathsAndOperationsRC($oas, $filters, $opElems)
    let $msgObjects := nav:oasMsgObjects($prune1)
    let $_DEBUG := trace('PRUNE1 done') 
    let $requiredMsgObjects := 
        let $req := trace($msgObjects/nav:requiredSchemas(.)/. , '_REQUIRED_MSG_OBJECTS: ')
        return if ($req) then $req else <DUMMY/> (: in order to avoid an empty value :)
    let $_DEBUG := trace(count($requiredMsgObjects), '#REQ_MSG_OBJECTS: ')        
    let $_WRITE := file:write('DEBUG_schemas', <result>{$msgObjects}</result>)
    let $_WRITE := file:write('DEBUG_schemas2', <result>{$msgObjects, $requiredMsgObjects}</result>)
    let $prune2 := f:removeNamedSchemas($prune1, $requiredMsgObjects, ())
    return $prune2
};   

(:~
 : Recursive helper function of `f:pruneDocOAS`.
 :)
declare function f:prunePathsAndOperationsRC(
                                $n as node(),
                                $filters as map(*),
                                $opElems as element()*)
        as node()? {
    let $pathFilter := $filters?pathFilter
    let $methodFilter := $filters?methodFilter
    let $opidFilter := $filters?opidFilter
    let $statusFilter := $filters?statusFilter
    return
    
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! 
            f:prunePathsAndOperationsRC(., $filters, $opElems)}
    case element(paths) return
        if ($n/parent::json and not($n/../parent::*)) then
            $n/element {node-name(.)} {
                @*,
                for $path in *
                let $jname := trace( $path/local-name(.) ! convert:decode-key(.) , '___JNAME: ')
                where empty($pathFilter) or tt:matchesNameFilter($jname, $pathFilter)
                let $_DEBUG := trace($path/name(), '_PATH_ACCEPTED: ')
                return 
                    f:prunePathsAndOperations_copy($path, $filters, $opElems)[*]
            }        
        else f:prunePathsAndOperations_copy($n, $filters, $opElems)
    case element(get) | element(post) | element(put) | element(delete) |
         element(head) | element(options) | element(patch) | element(trace)
         return
            if ($n intersect $opElems and not(tt:matchesNameFilter($n/local-name(.), $methodFilter))) then ()
            else if ($n intersect $opElems and not(tt:matchesNameFilter($n/operationId, $opidFilter))) then ()
            else f:prunePathsAndOperations_copy($n, $filters, $opElems)
         
    case element() return
        let $suppress := 
            $n/parent::responses/parent::*/parent::*/parent::paths/parent::json
            and $statusFilter
            and not($n/util:jname(.) ! tt:matchesNameFilter(., $statusFilter))
        return 
            if ($suppress) then trace((), concat('_SUPPRESS_', $n/util:jname(.), ': ')) else 
                f:prunePathsAndOperations_copy($n, $filters, $opElems)
    default return $n    
};        

(:~
 : Helper function of `f:prunePathsAndOperations`: maps an input element to
 : a recursively processed copy.
 :)
declare function f:prunePathsAndOperations_copy(
                                 $e as element(),
                                 $filters as map(*),
                                 $opElems as element()*)
        as element() {
    $e/element {node-name(.)} {
        @* ! f:prunePathsAndOperationsRC(., $filters, $opElems),
        node() ! f:prunePathsAndOperationsRC(., $filters, $opElems)
    }
};

(:~
 : Remove named schemas. More precisely, only those named schemas re
 : retained which are directly or indirectly referenced by the message 
 : schemas retained after pruning.
 :)
declare function f:removeNamedSchemas($oas as element(),
                                      $keepSchemas as element()*,
                                      $dropSchemas as element()*)
        as node()? {
    f:removeNamedSchemasRC($oas, $keepSchemas, $dropSchemas)
};

(:~
 : Recursive helper function of `f:removeNamedSchemas`.
 :)
declare function f:removeNamedSchemasRC($n as node(),
                                        $keepSchemas as element()*,
                                        $dropSchemas as element()*)
        as node()? {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:removeNamedSchemasRC(., $keepSchemas, $dropSchemas)}
    case element(definitions) | element(schemas) return
        if (not($n/self::definitions/parent::json[not(parent::*)]) and
            not($n/self::schemas/parent::components/parent::json[not(parent::*)])) then 
            f:removeNamedSchemas_copy($n, $keepSchemas, $dropSchemas)
        else      
            let $_DEBUG := trace('GOING TO PRUNE DEFINITIONS ...')
            let $_DEBUG := trace(count($keepSchemas), '___#KEEP_SCHEMA: ')
            let $children := $n/*
            let $retain := $children
                [not(. intersect $dropSchemas)]
                [empty($keepSchemas) or . intersect $keepSchemas]
            return
                element {node-name($n)} {
                    $n/@* ! f:removeNamedSchemasRC(., $keepSchemas, $dropSchemas),
                    $retain ! f:removeNamedSchemasRC(., $keepSchemas, $dropSchemas)
                }
    case element() return f:removeNamedSchemas_copy($n, $keepSchemas, $dropSchemas)
    default return $n
};        

(:~
 : Helper function of `f:removeNamedSchemas`: maps an input element to
 : a recursively processed copy.
 :)
declare function f:removeNamedSchemas_copy(
                                 $e as element(),
                                 $keepSchemas as element()*,
                                 $dropSchemas as element()*)
        as element() {
    $e/element {node-name(.)} {
        @* ! f:removeNamedSchemasRC(., $keepSchemas, $dropSchemas),
        node() ! f:removeNamedSchemasRC(., $keepSchemas, $dropSchemas)
    }
};

