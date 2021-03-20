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
         <param name="operationFilter" type="nameFilter?"/>
         <param name="odir" type="xs:string?"/>
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
 : Returns the path of the 'resources' folder.
 :
 : @return an absolute path
 :) 
declare function f:pruneOP($request as element())
        as item() {
    let $oas := tt:getParam($request, 'oas')/*
    let $pathFilter := tt:getParam($request, 'pathFilter')
    let $opFilter := tt:getParam($request, 'operationFilter')
    let $odir := tt:getParam($request, 'odir')

    let $options := map{}
    return
        f:pruneOAS($oas, $pathFilter, $opFilter, $odir)
};

declare function f:pruneOAS($oas as element()+,
                            $pathFilter as element(nameFilter)?,
                            $opFilter as element(nameFilter)?,
                            $options as map(xs:string, item()*)?)
        as item()? {
        
    for $doc in $oas
    let $docEdited := f:pruneDocOAS($oas, $pathFilter, $opFilter)
    return
        $docEdited ! util:jsonSerialize(.)
};

(:~
 : Creates a pruned copy of an OpenAPI document. If $pathFilter is not empty,
 : any Path Item Objects with a non-matching path are removed. If $opFilter is
 : not empty, any Operation Objects with a non-matching name are removed.
 :
 : @param oas an OpenAPI document
 : @param pathFilter a filter for Path Item Objects
 : @param opFilter a filter for operation Objects
 : @return a pruned copy of the input document.
 :)
declare function f:pruneDocOAS($oas as element(),
                               $pathFilter as element(nameFilter)?,
                               $opFilter as element(nameFilter)?)
        as node()? {
    let $opElems :=
        if (empty($opFilter)) then () else nav:oasOperationObjects($oas)
    let $prune1 := f:pruneDocOASRC($oas, $pathFilter, $opFilter, $opElems)
    let $msgObjects := nav:oasMsgObjects($prune1)
    let $requiredMsgObjects := $msgObjects/nav:requiredSchemas(.)/.
    let $_WRITE := file:write('DEBUG_schemas', <result>{$msgObjects}</result>)
    let $_WRITE := file:write('DEBUG_schemas2', <result>{$msgObjects, $requiredMsgObjects}</result>)
    let $prune2 := f:removeNamedSchemas($prune1, $requiredMsgObjects, ())
    return $prune2
};   

(:~
 : Recursive helper function of `f:pruneDocOAS`.
 :)
declare function f:pruneDocOASRC($n as node(),
                                 $pathFilter as element(nameFilter)?,
                                 $opFilter as element(nameFilter)?,
                                 $opElems as element()*)
        as node()? {
    typeswitch($n)
    case document-node() return 
        document {$n/node() ! f:pruneDocOASRC(., $pathFilter, $opFilter, $opElems)}
    case element(paths) return
        if ($n/parent::json and not($n/../parent::*)) then
            $n/element {node-name(.)} {
                @*,
                for $path in *
                let $jname := $path/local-name(.) ! convert:decode-key(.)
                where empty($pathFilter) or tt:matchesNameFilter($jname, $pathFilter)
                return f:pruneDocOAS_copy($path, $pathFilter, $opFilter, $opElems)
            }        
        else f:pruneDocOAS_copy($n, $pathFilter, $opFilter, $opElems)
    case element(get) | element(post) | element(put) | element(delete) |
         element(head) | element(options) | element(patch) | element(trace)
         return
            if ($n intersect $opElems and not(tt:matchesNameFilter($n/local-name(.), $opFilter))) then ()
            else f:pruneDocOAS_copy($n, $pathFilter, $opFilter, $opElems)
         
    case element() return
        f:pruneDocOAS_copy($n, $pathFilter, $opFilter, $opElems)
    default return $n    
};        

(:~
 : Helper function of `f:pruneDocOAS`: maps an input element to
 : a recursively processed copy.
 :)
declare function f:pruneDocOAS_copy(
                                 $e as element(),
                                 $pathFilter as element(nameFilter)?,
                                 $opFilter as element(nameFilter)?,
                                 $opElems as element()*)
        as element() {
    $e/element {node-name(.)} {
        @* ! f:pruneDocOASRC(., $pathFilter, $opFilter, $opElems),
        node() ! f:pruneDocOASRC(., $pathFilter, $opFilter, $opElems)
    }
};

(:~
 : Remove named schemas.
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

