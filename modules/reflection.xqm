(:~

 : --------------------------------
 : MBAse: An MBA database in XQuery
 : --------------------------------
  
 : Copyright (C) 2014, 2015 Christoph Schütz
   
 : This program is free software; you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
 : the Free Software Foundation; either version 2 of the License, or
 : (at your option) any later version.
 
 : This program is distributed in the hope that it will be useful,
 : but WITHOUT ANY WARRANTY; without even the implied warranty of
 : MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 : GNU General Public License for more details.
 
 : You should have received a copy of the GNU General Public License along
 : with this program; if not, write to the Free Software Foundation, Inc.,
 : 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 :
 : @author Michael Weichselbaumer
 :)
module namespace reflection='http://www.dke.jku.at/MBA/Reflection';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'mba.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'scxml.xqm';
import module namespace functx = 'http://www.functx.com' at 'functx.xqm';
import module namespace scc = "http://www.w3.org/2005/07/scxml/consistency/" at 'scxml_consistency.xqm';

declare updating function reflection:setActive($mba  as element(),
                                               $name as xs:string) {
  ()
};


declare function reflection:getRefinedState($state as element(), $subState as element(), $evalFunction as item()) as element()* {
  let $mba := $state/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
      let $originalScxml := $state/ancestor::sc:scxml

      let $refinedScxml := copy $c := $originalScxml modify (
        let $stateCopy := $c//sc:state[@id=$state/@id/data()]
        return insert node $subState into $stateCopy
      ) return $c

      return if ($evalFunction($originalScxml, $refinedScxml)) then (
          $refinedScxml//sc:state[@id=$state/@id/data()]
      ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                        'RefineStateConsistencyCheck'),
                        'State cannot be refined because this would result in behavior consistency violation')
      )
    ) else (
      error(QName('http://www.dke.jku.at/MBA/err',
              'RefineStateDescendantCheck'),
              concat('State cannot be refined because MBA ', $mba/@name/data(), ' has already descendants'))
    )
};

declare function reflection:refineStateDefaultBehavior($state as element(), $subState as element()) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getRefinedState($state, $subState, $defaultBehaviorFunction)
};

declare function reflection:refineStateCustomBehavior($state as element(), $subState as element(), $evalFunction as item()) {
     reflection:getRefinedState($state, $subState, $evalFunction)
};


declare function reflection:getParallelRegionExtension($state as element(), $parallelState as element()+, $evalFunction as item(), $optionalNodes as element()?) as element()* {
    let $mba := $state/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
        let $originalScxml := $state/ancestor::sc:scxml

        let $refinedScxml := copy $c := $originalScxml modify (
            let $stateCopy := $c//sc:state[@id=$state/@id/data()]
            let $newParallelNode := <sc:parallel>
                {$optionalNodes}
                {$stateCopy}
                {$parallelState}
            </sc:parallel>
            return replace node $stateCopy with $newParallelNode

        ) return $c

        return if ($evalFunction($originalScxml, $refinedScxml)) then (
            $refinedScxml//sc:state[@id=$state/@id/data()]/..
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'ExtendWithParallelRegionConsistencyCheck'),
                    'Parallel region cannot be introduced because this would result in behavior consistency violation')
        )
    ) else (
        error(QName('http://www.dke.jku.at/MBA/err',
                'ExtendWithParallelRegionDescendantCheck'),
                concat('Parallel region cannot be introduced because MBA ', $mba/@name/data(), ' has already descendants'))
    )
};

declare function reflection:addParallelStateDefaultBehavior($state as element(), $parallelState as element(), $optionalNodes as element()?) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getParallelRegionExtension($state, $parallelState, $defaultBehaviorFunction, $optionalNodes)
};

declare function reflection:addParallelStateCustomBehavior($state as element(), $parallelState as element(), $evalFunction as item(), $optionalNodes as element()?) {
   reflection:getParallelRegionExtension($state, $parallelState, $evalFunction, $optionalNodes)
};

declare function reflection:getTransitionWithRefinedPreCondition($transition as element(), $condition as xs:string, $evalFunction as item()) as element()* {
    let $mba := $transition/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
        let $originalScxml := $transition/ancestor::sc:scxml

        let $transitionSourceState := sc:getSourceState($transition)
        let $indexOfTransition := functx:index-of-node($transitionSourceState//sc:transition, $transition)

        let $refinedScxml := copy $c := $originalScxml modify (
            let $stateCopy := $c//sc:state[@id = $transitionSourceState/@id/data()]
            let $transitionCopy := $stateCopy//sc:transition[$indexOfTransition]
            let $conditionCopy := $transitionCopy/@cond

            return if (fn:empty($conditionCopy)) then (
                replace node $transitionCopy with functx:add-attributes($transitionCopy, fn:QName('', 'cond'), $condition)
            ) else (
                replace node $transitionCopy with functx:add-or-update-attributes($transitionCopy, fn:QName('', 'cond'), ($conditionCopy || " and " || $condition))
            )
        ) return $c

        return if ($evalFunction($originalScxml, $refinedScxml)) then (
            $refinedScxml//sc:state[@id = $transitionSourceState/@id]//sc:transition[$indexOfTransition]
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'RefineTransitionWithPreConditionConsistencyCheck'),
                    concat('Transition cannot be refined with precondition ', $condition, ' because this would result in behavior consistency violation'))
        )
    ) else (
        error(QName('http://www.dke.jku.at/MBA/err',
                'RefineTransitionPreConditionCheck'),
                concat('Transition cannot be refined with condition ', $condition, ' because MBA ', $mba/@name/data(), ' has already descendants'))
    )
};

declare function reflection:refinePreConditionDefaultBehavior($transition as element(), $condition as xs:string) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getTransitionWithRefinedPreCondition($transition, $condition, $defaultBehaviorFunction)
};

declare function reflection:refinePreConditionCustomBehavior($transition as element(), $condition as xs:string, $evalFunction as item()) {
    reflection:getTransitionWithRefinedPreCondition($transition, $condition, $evalFunction)
};

declare function reflection:getTransitionWithRefinendEvents($transition as element(), $event as xs:string, $evalFunction as item()) as element()* {
    let $mba := $transition/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
        let $originalScxml := $transition/ancestor::sc:scxml
        let $transitionSourceState := sc:getSourceState($transition)
        let $indexOfTransition := functx:index-of-node($transitionSourceState//sc:transition, $transition)

        let $refinedScxml := copy $c := $originalScxml modify (
            let $stateCopy := $c//sc:state[@id = $transitionSourceState/@id/data()]
            let $transitionCopy := $stateCopy//sc:transition[$indexOfTransition]
            let $eventCopy := $transitionCopy/@event

            return if (fn:empty($eventCopy)) then (
                replace node $transitionCopy with functx:add-attributes($transitionCopy, fn:QName('', 'event'), $event)
            ) else (
                replace node $transitionCopy with functx:add-or-update-attributes($transitionCopy, fn:QName('', 'event'), ($eventCopy || "." || $event))
            )
        ) return $c

        return if ($evalFunction($originalScxml, $refinedScxml)) then (
            $refinedScxml//sc:state[@id = $transitionSourceState/@id]//sc:transition[$indexOfTransition]
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'RefineTransitionWithEventConsistencyCheck'),
                    concat('Transition cannot be refined with event ', $event, ' because this would result in behavior consistency violation'))
        )
    ) else (
        error(QName('http://www.dke.jku.at/MBA/err',
                'RefineTransitionEventCheck'),
                concat('Transition cannot be refined with event ', $event, ' because MBA ', $mba/@name/data(), ' has already descendants'))
    )
};

declare function reflection:refineEventDefaultBehavior($transition as element(), $event as xs:string) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getTransitionWithRefinendEvents($transition, $event, $defaultBehaviorFunction)
};

declare  function reflection:refineEventCustomBehavior($transition as element(), $event as xs:string, $evalFunction as item()) {
    reflection:getTransitionWithRefinendEvents($transition, $event, $evalFunction)
};

declare function reflection:getTransitionWithRefinedTarget($transition as element(), $target as xs:string, $evalFunction as item()) as element()* {
    let $mba := $transition/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
        let $originalScxml := $transition/ancestor::sc:scxml
        let $transitionSourceState := sc:getSourceState($transition)
        let $indexOfTransition := functx:index-of-node($transitionSourceState//sc:transition, $transition)

        let $refinedScxml := copy $c := $originalScxml modify (
            let $stateCopy := $c//sc:state[@id = $transitionSourceState/@id/data()]
            let $transitionCopy := $stateCopy//sc:transition[$indexOfTransition]

            return replace node $transitionCopy with functx:add-or-update-attributes($transitionCopy, fn:QName('', 'target'), ($target))
        ) return $c

        return if ($evalFunction($originalScxml, $refinedScxml)) then (
            $refinedScxml//sc:state[@id = $transitionSourceState/@id]//sc:transition[$indexOfTransition]
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'RefineTransitionWithTargetConsistencyCheck'),
                    concat('Transition cannot be refined with new target ', $target, ' because this would result in behavior consistency violation'))
        )
    ) else (
        error(QName('http://www.dke.jku.at/MBA/err',
                'RefineTransitionTargetCheck'),
                concat('Transition cannot be refined with new target ', $target, ' because MBA ', $mba/@name/data(), ' has already descendants'))
    )

};

declare function reflection:refineTargetDefaultBehavior($transition as element(), $target as xs:string) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getTransitionWithRefinedTarget($transition, $target, $defaultBehaviorFunction)
};


declare function reflection:refineTargetCustomBehavior($transition as element(), $target as xs:string, $evalFunction as item()) {
    reflection:getTransitionWithRefinedTarget($transition, $target, $evalFunction)
};

declare function reflection:getTransitionWithRefinedSource($transition as element(), $source as xs:string, $evalFunction as item()) as element()* {
    let $mba := $transition/ancestor::mba:mba

    return if (not(mba:getDescendants($mba))) then (
        let $originalScxml := $transition/ancestor::sc:scxml
        let $transitionSourceState := sc:getSourceState($transition)
        let $indexOfTransition := functx:index-of-node($transitionSourceState//sc:transition, $transition)

        let $refinedScxml := copy $c := $originalScxml modify (
            let $stateCopy := $c//sc:state[@id = $transitionSourceState/@id/data()]
            let $newSourceState := $c//sc:state[@id = $source]
            let $transitionCopy := $stateCopy//sc:transition[$indexOfTransition]

            return (insert node $transitionCopy into $newSourceState,
            delete node $transitionCopy)
        ) return $c

        return if ($evalFunction($originalScxml, $refinedScxml)) then (
            $refinedScxml//sc:state[@id = $transitionSourceState/@id]
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'RefineTransitionWithSourceConsistencyCheck'),
                    concat('Transition cannot be refined with new source ', $source, ' because this would result in behavior consistency violation'))
        )
    ) else (
        error(QName('http://www.dke.jku.at/MBA/err',
                'RefineTransitionSourceCheck'),
                concat('Transition cannot be refined with new source ', $source, ' because MBA ', $mba/@name/data(), ' has already descendants'))
    )
};

declare function reflection:refineSourceDefaultBehavior($transition as element(), $source as xs:string) {
    let $defaultBehaviorFunction := scc:isBehaviorConsistentSpecialization#2
    return reflection:getTransitionWithRefinedSource($transition, $source, $defaultBehaviorFunction)
};


declare function reflection:refineSourceCustomBehavior($transition as element(), $target as xs:string,  $evalFunction as item()) {
    reflection:getTransitionWithRefinedSource($transition, $target, $evalFunction)
};
