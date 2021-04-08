(:
 : oaslab - 
 :
 : @version 2021-04-08T19:54:11.294+02:00 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_docs.xqm",
    "tt/_help.xqm",
    "tt/_pcollection.xqm",
    "tt/_request.xqm";

import module namespace a6="http://www.oaslab.org/ns/xquery-functions" at
    "spec.xqm";

import module namespace a1="http://www.oaslab.org/ns/xquery-functions/allOf" at
    "allOfResolver.xqm";

import module namespace a5="http://www.oaslab.org/ns/xquery-functions/jtree" at
    "schemaGroup.xqm";

import module namespace a2="http://www.oaslab.org/ns/xquery-functions/mtree" at
    "mtree.xqm";

import module namespace a3="http://www.oaslab.org/ns/xquery-functions/prune" at
    "prune.xqm";

import module namespace a4="http://www.oaslab.org/ns/xquery-functions/ref" at
    "ref.xqm";

declare namespace m="http://www.oaslab.org/ns/xquery-functions";
declare namespace z="http://www.oaslab.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $request as xs:string external;

(: tool scheme 
   ===========
:)
declare variable $toolScheme :=
<topicTool name="oaslab">
  <operations>
    <operation name="_dcat" func="getRcat" type="element()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="docs" type="catDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="catFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="_docs" func="getDocs" type="element()+" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
    </operation>
    <operation name="_doctypes" func="getDoctypes" type="node()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
      <param name="attNames" type="xs:boolean" default="false"/>
      <param name="elemNames" type="xs:boolean" default="false"/>
      <param name="sortBy" type="xs:string?" fct_values="name,namespace" default="name"/>
    </operation>
    <operation name="_search" type="node()" func="search" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_searchCount" type="item()" func="searchCount" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_createNcat" type="node()" func="createNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_feedNcat" type="node()" func="feedNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="doc" type="docURI*" sep="WS"/>
      <param name="docs" type="catDFD*" sep="SC"/>
      <param name="dox" type="catFOX*" sep="SC"/>
      <param name="path" type="xs:string?"/>
    </operation>
    <operation name="_copyNcat" type="node()" func="copyNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI?" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
      <param name="toNodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_deleteNcat" type="node()" func="deleteNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_nodlSample" type="node()" func="nodlSample" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="model" type="xs:string?" fct_values="xml, sql, mongo" default="xml"/>
    </operation>
    <operation name="resolveAllOf" type="item()?" func="resolveAllOfOP" mod="allOfResolver.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/allOf">
      <param name="mtree" type="docFOX" fct_minDocCount="1"/>
      <param name="odir" type="xs:string?"/>
      <param name="addSuffix" type="xs:string?"/>
      <param name="addPrefix" type="xs:string?"/>
      <param name="fnameReplacement" type="xs:string?"/>
      <param name="ostage" type="xs:integer?"/>
    </operation>
    <operation name="mtree" type="item()?" func="mtreeOP" mod="mtree.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/mtree">
      <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
      <param name="flat" type="xs:boolean?" default="false"/>
      <param name="bare" type="xs:boolean?"/>
      <param name="lean" type="xs:boolean?"/>
      <param name="pathFilter" type="nameFilter?"/>
      <param name="methodFilter" type="nameFilter?"/>
      <param name="roleFilter" type="nameFilter?"/>
      <param name="schemaKeyStyle" type="xs:string?" fct_values="path, pathname" default="pathname"/>
      <param name="odir" type="xs:string?"/>
      <param name="addSuffix" type="xs:string?"/>
      <param name="addPrefix" type="xs:string?"/>
      <param name="fnameReplacement" type="xs:string?"/>
      <param name="ostage" type="xs:integer?"/>
    </operation>
    <operation name="stree" type="item()?" func="streeOP" mod="mtree.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/mtree">
      <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
      <param name="flat" type="xs:boolean?" default="false"/>
      <param name="bare" type="xs:boolean?"/>
      <param name="lean" type="xs:boolean?"/>
      <param name="nameFilter" type="nameFilter?"/>
      <param name="odir" type="xs:string?"/>
      <param name="addSuffix" type="xs:string?"/>
      <param name="addPrefix" type="xs:string?"/>
      <param name="fnameReplacement" type="xs:string?"/>
      <param name="ostage" type="xs:integer?"/>
    </operation>
    <operation name="prune" type="item()?" func="pruneOP" mod="prune.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/prune">
      <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
      <param name="pathFilter" type="nameFilter?"/>
      <param name="operationFilter" type="nameFilter?"/>
      <param name="statusFilter" type="nameFilter?"/>
      <param name="odir" type="xs:string?"/>
      <param name="addSuffix" type="xs:string?"/>
      <param name="addPrefix" type="xs:string?"/>
      <param name="fnameReplacement" type="xs:string?"/>
    </operation>
    <operation name="jsref" type="item()?" func="jsrefOP" mod="ref.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/ref">
      <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
      <param name="odir" type="xs:string?"/>
    </operation>
    <operation name="group" type="item()?" func="groupOP" mod="schemaGroup.xqm" namespace="http://www.oaslab.org/ns/xquery-functions/jtree">
      <param name="oas" type="jsonFOX" fct_minDocCount="1"/>
      <param name="skipWithSingleChild" type="xs:boolean?" default="false"/>
      <param name="groupKind" type="xs:string*" fct_values="allOf, oneOf, anyOf"/>
      <param name="odir" type="xs:string?"/>
      <param name="addSuffix" type="xs:string?"/>
      <param name="addPrefix" type="xs:string?"/>
      <param name="fnameReplacement" type="xs:string?"/>
    </operation>
    <operation name="spec.keywords" type="node()" func="spec.objectsOP" mod="spec.xqm" namespace="http://www.oaslab.org/ns/xquery-functions">
      <param name="version" type="xs:string?" default="31" fct_values="20, 30, 31" pgroup="input"/>
      <param name="shape" type="xs:string?" default="flat" fct_values="flat, deep"/>
      <param name="objectTypes" type="nameFilter?"/>
      <param name="properties" type="nameFilter?"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="_help" func="_help" mod="tt/_help.xqm">
      <param name="default" type="xs:boolean" default="false"/>
      <param name="type" type="xs:boolean" default="false"/>
      <param name="mode" type="xs:string" default="overview" fct_values="overview, scheme"/>
      <param name="ops" type="nameFilter?"/>
    </operation>
  </operations>
  <types/>
  <facets/>
</topicTool>;

declare variable $req as element() := tt:loadRequest($request, $toolScheme);


(:~
 : Executes pseudo operation '_storeq'. The request is stored in
 : simplified form, in which every parameter is represented by a 
 : parameter element whose name captures the parameter value
 : and whose text content captures the (unitemized) parameter 
 : value.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__storeq($request as element())
        as node() {
    element {node-name($request)} {
        attribute crTime {current-dateTime()},
        
        for $c in $request/* return
        let $value := replace($c/@paramText, '^\s+|\s+$', '', 's')
        return
            element {node-name($c)} {$value}
    }       
};

    
(:~
 : Executes operation '_dcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__dcat($request as element())
        as element() {
    tt:getRcat($request)        
};
     
(:~
 : Executes operation '_docs'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__docs($request as element())
        as element()+ {
    tt:getDocs($request)        
};
     
(:~
 : Executes operation '_doctypes'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__doctypes($request as element())
        as node() {
    tt:getDoctypes($request)        
};
     
(:~
 : Executes operation '_search'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__search($request as element())
        as node() {
    tt:search($request)        
};
     
(:~
 : Executes operation '_searchCount'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__searchCount($request as element())
        as item() {
    tt:searchCount($request)        
};
     
(:~
 : Executes operation '_createNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__createNcat($request as element())
        as node() {
    tt:createNcat($request)        
};
     
(:~
 : Executes operation '_feedNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__feedNcat($request as element())
        as node() {
    tt:feedNcat($request)        
};
     
(:~
 : Executes operation '_copyNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__copyNcat($request as element())
        as node() {
    tt:copyNcat($request)        
};
     
(:~
 : Executes operation '_deleteNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__deleteNcat($request as element())
        as node() {
    tt:deleteNcat($request)        
};
     
(:~
 : Executes operation '_nodlSample'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__nodlSample($request as element())
        as node() {
    tt:nodlSample($request)        
};
     
(:~
 : Executes operation 'resolveAllOf'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_resolveAllOf($request as element())
        as item()? {
    a1:resolveAllOfOP($request)        
};
     
(:~
 : Executes operation 'mtree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_mtree($request as element())
        as item()? {
    a2:mtreeOP($request)        
};
     
(:~
 : Executes operation 'stree'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_stree($request as element())
        as item()? {
    a2:streeOP($request)        
};
     
(:~
 : Executes operation 'prune'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_prune($request as element())
        as item()? {
    a3:pruneOP($request)        
};
     
(:~
 : Executes operation 'jsref'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_jsref($request as element())
        as item()? {
    a4:jsrefOP($request)        
};
     
(:~
 : Executes operation 'group'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_group($request as element())
        as item()? {
    a5:groupOP($request)        
};
     
(:~
 : Executes operation 'spec.keywords'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_spec.keywords($request as element())
        as node() {
    a6:spec.objectsOP($request)        
};
     
(:~
 : Executes operation '_help'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__help($request as element())
        as node() {
    tt:_help($request, $toolScheme)        
};

(:~
 : Executes an operation.
 :
 : @param req the operation request
 : @return the result of the operation
 :)
declare function m:execOperation($req as element())
      as item()* {
    if ($req/self::zz:errors) then tt:_getErrorReport($req, 'Invalid call', 'code', ()) else
    if ($req/@storeq eq 'true') then m:execOperation__storeq($req) else
    
    let $opName := tt:getOperationName($req) 
    let $result :=    
        if ($opName eq '_help') then m:execOperation__help($req)
        else if ($opName eq '_dcat') then m:execOperation__dcat($req)
        else if ($opName eq '_docs') then m:execOperation__docs($req)
        else if ($opName eq '_doctypes') then m:execOperation__doctypes($req)
        else if ($opName eq '_search') then m:execOperation__search($req)
        else if ($opName eq '_searchCount') then m:execOperation__searchCount($req)
        else if ($opName eq '_createNcat') then m:execOperation__createNcat($req)
        else if ($opName eq '_feedNcat') then m:execOperation__feedNcat($req)
        else if ($opName eq '_copyNcat') then m:execOperation__copyNcat($req)
        else if ($opName eq '_deleteNcat') then m:execOperation__deleteNcat($req)
        else if ($opName eq '_nodlSample') then m:execOperation__nodlSample($req)
        else if ($opName eq 'resolveAllOf') then m:execOperation_resolveAllOf($req)
        else if ($opName eq 'mtree') then m:execOperation_mtree($req)
        else if ($opName eq 'stree') then m:execOperation_stree($req)
        else if ($opName eq 'prune') then m:execOperation_prune($req)
        else if ($opName eq 'jsref') then m:execOperation_jsref($req)
        else if ($opName eq 'group') then m:execOperation_group($req)
        else if ($opName eq 'spec.keywords') then m:execOperation_spec.keywords($req)
        else if ($opName eq '_help') then m:execOperation__help($req)
        else
        tt:createError('UNKNOWN_OPERATION', concat('No such operation: ', $opName), 
            <error op='{$opName}'/>)    
     let $errors := if ($result instance of node()+) then tt:extractErrors($result) else ()     
     return
         if ($errors) then tt:_getErrorReport($errors, 'System error', 'code', ())     
         else $result
};

m:execOperation($req)
    