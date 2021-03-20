(:
 : -------------------------------------------------------------------------
 :
 : spec.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="spec.keywords" type="node()" func="spec.objectsOP">     
         <param name="version" type="xs:string?" default="31" fct_values="20, 30, 31" pgroup="input"/>
         <param name="shape" type="xs:string?" default="flat" fct_values="flat, deep"/>
         <param name="objectTypes" type="nameFilter?"/>
         <param name="properties" type="nameFilter?"/>
         <pgroup name="input" minOccurs="1"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.oaslab.org/ns/xquery-functions";

import module namespace util="http://www.oaslab.org/ns/xquery-functions/util"
at "oaslabUtil.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";    
    
declare namespace z="http://www.oaslab.org/ns/structure";

(:~
 : Implements operation 'spec.objects'. The operation returns
 : a representation of the objects defined by the OpenAPI
 : specification.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:spec.objectsOP($request as element())
        as element() {
    let $version := tt:getParam($request, 'version')
    let $shape := tt:getParam($request, 'shape')
    let $objectTypes := tt:getParam($request, 'objectTypes')
    let $properties := tt:getParam($request, 'properties')
    let $options := map{'objectTypes': $objectTypes,
                        'properties': $properties}
    return
        f:spec.objects($version, $shape, $options)
};

(:~
 : Returns a representation of the objects of the OpenAPI defined
 : by the OpenAPI model.
 :
 : @param version OAS specification version
 : @return a representation of the objects
 :) 
declare function f:spec.objects($version as xs:string,
                                $shape as xs:string,
                                $options as map(xs:string, item()*)?)
        as item() {
    let $pathResources := util:resourcesPath()
    let $fileName := 'oas-model.v' || $version || '.xml'    
    let $pathDoc := $pathResources || '/' || $fileName
    let $doc := doc($pathDoc)/*
    return
        if ($shape eq 'flat') then f:spec.objectsFlat($doc, $options)
        else f:spec.objectsDeep($doc, $options)
};        

(:~
 : Returns a flat representation of the OAS object model.
 :)
declare function f:spec.objectsFlat($doc as element(), 
                                    $options as map(xs:string, item()*)?)
        as element() {
    let $objectTypes := $options?objectTypes        
    let $properties := $options?properties
    let $model :=
        $doc/element {node-name(.)} {
            @*,
            *[not($objectTypes) or tt:matchesNameFilter(local-name(.), $objectTypes)]
             [not($properties) or *[tt:matchesNameFilter(local-name(.), $properties)]]
        }
    return $model/util:prettyPrint(., $options)       
};

(:~
 : Returns a deep representation of the OAS object model.
 :)
declare function f:spec.objectsDeep($doc as element(), 
                                    $options as map(xs:string, item()*)?)
        as element() {
    let $objectNames := $doc/*/name()
    return
        f:spec.objectsDeepRC($doc/OpenAPIObject, $objectNames, (), $options)
};

(:~
 : Recursive helper function of `spec.objectsDeep`.
 :)
declare function f:spec.objectsDeepRC($n as node(),
                                      $objectNames as xs:string+,
                                      $visited as element()*,
                                      $options as map(xs:string, item()*)?)
        as element()* {
    let $content :=    
        for $child in $n/*
        let $childName := $child/local-name(.)
        let $isMapType := starts-with($child/@type, 'map-')
        let $mapKeyName := $child/@keyName/concat('_', .)
        let $typeName := $child/@type/replace(., '^map-', '')   
        let $typeDisplayName := (
            if ($child/@array eq 'yes') then '['||$typeName||']' 
            else if ($isMapType) then '{'||$typeName||'}'
            else $typeName
            ) ! concat(., '!'[$child/@required eq 'yes'])
        let $typeDef :=
            let $typeDefName := $objectNames[. eq $typeName]
            return $n/ancestor-or-self::*[last()]/*[local-name(.) eq $typeDefName]
        let $childContent := (
            attribute type {$typeDisplayName},
            $child/@enum,
                
            (: Not a model-defined type :)
            if (not($typeDef)) then 
                (: not a map :)
                if (not($isMapType)) then ()
                (: a map :)
                else element {$mapKeyName} {attribute type {$typeName}, $child/@mapValue}
                    
            (: Recursive type definition - stop here :)
            else if ($typeDef intersect $visited) then attribute recursiveType {$typeDef/name()}
                
            (: A model-defined type :)
            else                     
                let $typeContent := $typeDef/f:spec.objectsDeepRC(., $objectNames, ($visited, $n), $options)/*
                return
                    if ($isMapType) then element {$mapKeyName} {$typeContent}
                    else $typeContent
        )
        return
            if (starts-with($childName, '_') and $isMapType) then ($childContent)
            else element {$childName} {$childContent}

    let $contentAtts := $content/self::attribute()
    let $contentElems := $content except $contentAtts
    return
        $n/element {node-name(.)} {$contentAtts, $contentElems}    
};        
