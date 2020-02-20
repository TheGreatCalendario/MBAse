xquery version "3.0";

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

 : @author Michael Weichselbaumer
 :)

module namespace scc = "http://www.w3.org/2005/07/scxml/consistency/";

import module namespace functx = 'http://www.functx.com' at 'C:/Git/master/MBAse/modules/functx.xqm';

import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Git/master/MBAse/modules/scxml.xqm';


declare function scc:getAllStates($scxml) as element()* {
    $scxml/(sc:state | sc:parallel | sc:final)
};

declare function scc:getAllStatesAndSubstates($scxml) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)
};

declare function scc:getStateAndSubstates($scxml as element(), $state as xs:string) as xs:string* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]/(descendant-or-self::sc:state | descendant-or-self::sc:parallel | descendant-or-self::sc:final)/fn:string(@id)
};

(: this function returns all states (including their substates) of an original model from its' refined model :)
declare function scc:getAllOriginalStatesFromRefined($originalScxml as element(), $refinedScxml as element()) as element()* {
    let $statesOriginal := scc:getAllStates($originalScxml)
    let $statesRefined := scc:getAllStatesAndSubstates($refinedScxml)

    let $refinedStatesFromOriginal :=
        for $refinedState in $statesRefined
        where functx:is-value-in-sequence($refinedState/@id, $statesOriginal/@id)
        return $refinedState

    return $refinedStatesFromOriginal
};

declare function scc:getAllRelevantStateIdsRelevantToOriginalFromRefined($originalStates as element()*) {
    for $state in $originalStates
        return ($state/@id/data(), sc:getChildStates($state)/@id/data())
};

declare function scc:getAllRefinedTransitionsWithRelevantTargetState($originalScxml as element(), $refinedScxml as element()) as element()* {
    let $refinedStatesFromOriginal := scc:getAllOriginalStatesFromRefined($originalScxml, $refinedScxml)
    (: return all transitions with relevant or no target state :)
    let $allStateIdsRelevantToOriginalModel := scc:getAllRelevantStateIdsRelevantToOriginalFromRefined($refinedStatesFromOriginal)
    let $refinedTransitionsWithRelevantTargetState :=
        for $transition in scc:getAllStates($refinedScxml)//sc:transition
        where functx:is-value-in-sequence($transition/@target/data(), $allStateIdsRelevantToOriginalModel) or not($transition/@target)
        return $transition

    return $refinedTransitionsWithRelevantTargetState
};

declare function scc:getAllRefinedTransitionsWithRelevantSourceAndTargetState($originalScxml as element(), $refinedScxml as element()) as element()* {
    (: get rid of transitions that have source AND target state (or no target state) that is not available in original model  :)
    let $refinedTransitionsWithRelevantSourceAndTargetState :=
        for $transition in scc:getAllRefinedTransitionsWithRelevantTargetState($originalScxml, $refinedScxml)
        return if ((not(functx:is-value-in-sequence($transition/../@id/data(), scc:getAllStates($originalScxml)/@id/data())) and
                not(functx:is-value-in-sequence($transition/@target/data(), functx:value-except(scc:getAllStates($originalScxml)/@id/data(), $transition/ancestor::sc:state/descendant-or-self::sc:state/@id/data())))  and
                not(fn:empty($transition/@target)))
        ) then (
                ()
            ) else (
                $transition
            )
    return $refinedTransitionsWithRelevantSourceAndTargetState
};

(: this functions check if all transitions from U are available in U' and no new transitions between states in U are added in U' :)
declare function scc:isEveryOriginalTransitionInRefined($originalScxml as element(), $refinedScxml as element()) as xs:boolean {
    let $statesOriginal := scc:getAllStates($originalScxml)
    let $originalTransitions := $statesOriginal//sc:transition
    let $originalTransitionsWithTarget := $statesOriginal//sc:transition[@target!=../@id/data()]
    let $refinedTransitionsToCheck := scc:getAllRefinedTransitionsWithRelevantSourceAndTargetState($originalScxml, $refinedScxml)
    let $filteredTransition :=  $refinedTransitionsToCheck[@target != ../@id/data()]
    let $refinedTransitionsWithTargetToCheck := for $filterTransition in $filteredTransition where $filterTransition/@target/data() != scc:getAllStatesAndSubstates($filteredTransition/..)/@id/data() return $filterTransition

    (: if number of refinedTransitionsToCheck is smaller a transition has been removed. if the number is greater than number of originalTransitions, a new transition with no target state has been
       introduced which is ok. :)
    return if ((fn:count($refinedTransitionsToCheck) >= fn:count($originalTransitions) and fn:count($refinedTransitionsWithTargetToCheck) = fn:count($originalTransitionsWithTarget))
            or ((fn:count($refinedTransitionsToCheck) = fn:count($originalTransitions)))) then (
        let $noOfMatchingTransitionsList :=
            for $orginalTransition in $originalTransitions
            let $matchingTransitions :=
                for $refinedTransition in $refinedTransitionsToCheck
                return if (scc:areTransitionsConsistent($orginalTransition, $refinedTransition)) then (
                    true()
                ) else ()
            return fn:count($matchingTransitions)

        return every $noOfMatchingTransitions in $noOfMatchingTransitionsList satisfies ($noOfMatchingTransitions = 1)
    ) else (
        if (fn:count($refinedTransitionsToCheck) > fn:count($originalTransitions)) then (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'BehaviorConsistencyTransitionCheck'),
                    'Illegal transition between states of original model introduced in refined model')
        ) else (
            error(QName('http://www.dke.jku.at/MBA/err',
                    'BehaviorConsistencyTransitionCheck'),
                    'Required transition of original model removed in refined model')
            )
    )
};

(: this function checks if a scxml-state is equal to another scxml-state from a refined scxml-model :)
declare function scc:isOriginalStateEqualToStateFromRefined($originalState as element(), $refinedState as element()) as xs:boolean {
    let $idOfStateOriginal := $originalState/@id
    let $idOfStateRefined := $refinedState/@id

    let $parentNodeOriginal := $originalState/..
    let $parentNodeRefined := $refinedState/..

    let $idOfParentNodeOriginal :=  $parentNodeOriginal/(@name | @id)
    let $idOfParentNodeRefined := $parentNodeRefined/(@name | @id)

    (: use local-name instead of name to circumvent problems with prefix names :)
    return $idOfStateOriginal = $idOfStateRefined and ($idOfParentNodeOriginal = $idOfParentNodeRefined or $parentNodeRefined/local-name() = 'parallel')
};

(: checks if all states in U are available in U' and if they have the same ancestor (substates!) :)
declare function scc:isEveryOriginalStateInRefined($originalStates as element()*, $refinedStates as element()*) as xs:boolean {
    let $allStatesFromOriginalAreOk :=
        every $originalState in $originalStates satisfies
        for $refinedState in $refinedStates
        return if (scc:isOriginalStateEqualToStateFromRefined($originalState, $refinedState)) then (
            true()
        ) else ()

    return  $allStatesFromOriginalAreOk
};

(: checks if no duplicate state ids have been introduced in set of refinedStates :)
declare function scc:isNoDuplicateStateIntroducedInRefined($refinedStates as element()*) as xs:boolean {
   let $noDupliceStateIds :=  every $refinedState in $refinedStates satisfies (fn:count($refinedStates[@id=$refinedState/@id]) = 1)
   return if ($noDupliceStateIds) then (
    true()
   ) else (
       error(QName('http://www.dke.jku.at/MBA/err',
               'UniqueIDConstraint'),
               'State id must be unique')
   )
};



declare function scc:areTransitionsConsistent($originalTransition as element(), $refinedTransition as element()) as xs:boolean {
(:
    check if $originalTransition is the 'same' as $refinedTransition
    rules:
        1. $refinedTransition may have a more specialized source state.
        2. $refinedTransition may have a more specialized target state.
            - If both have no target, then target check is ok
            - if source has no target, refinedTransition may have a target which is stateOrSubstate of source
        3. condition may be added to $refinedTransition (if $originalTransition had no cond). If no condition, every cond can be introduced
        4. conditions in $refinedTransition may be specialized, by adding terms with 'AND'
        5. dot notation of events. If no event, every event can be introduced
:)

    let $origSource := fn:string(sc:getSourceState($originalTransition)/@id)
    let $origTarget := fn:string($originalTransition/@target)
    let $origEvent := fn:string($originalTransition/@event)

    let $scxml := $refinedTransition/ancestor::sc:scxml[1]
    let $origSourceAndSubstates := scc:getStateAndSubstates($scxml, $origSource)
    let $origTargetAndSubstates := scc:getStateAndSubstates($scxml, $origTarget)

    return
        if (
        (: 1. :)(not(sc:getSourceState($originalTransition)/@id or sc:getSourceState($refinedTransition)/@id) or functx:is-value-in-sequence(fn:string(sc:getSourceState($refinedTransition)/@id), $origSourceAndSubstates)) and
                (: 2. :)(not($originalTransition/@target or $refinedTransition/@target)
                or functx:is-value-in-sequence(fn:string($refinedTransition/@target), $origTargetAndSubstates)
                or (not($originalTransition/@target) and functx:is-value-in-sequence($refinedTransition/@target, $origSourceAndSubstates))) and
                (: 3&4:)(not($originalTransition/@cond) or (($refinedTransition/@cond) and scc:areConditionsConsistent($originalTransition/@cond, $refinedTransition/@cond))) and
                (: 5. :)(not($origEvent) or scc:isRefinedEvent($origEvent, fn:string($refinedTransition/@event)))
        ) then
            true()
        else
            false()
};

declare function scc:areConditionsConsistent($originalCondition as xs:string, $refinedCondition as xs:string) as xs:boolean {
    (: original clause is not modified :)
    (fn:compare($originalCondition, $refinedCondition) = 0) or
            (: 'and' is added after original clause:)
            ((fn:compare($originalCondition, fn:substring($refinedCondition, 1, fn:string-length($originalCondition))) = 0) and
                    (fn:compare(' and ', fn:substring($refinedCondition, fn:string-length($originalCondition) + 1, 5)) = 0)) or
            (: 'and' is added before original clause :)
            ((fn:compare($originalCondition, fn:substring($refinedCondition, fn:string-length($refinedCondition) - fn:string-length($originalCondition) + 1, fn:string-length($refinedCondition))) = 0)) and
                    (fn:compare(' and', fn:substring($refinedCondition, fn:string-length($refinedCondition) - fn:string-length($originalCondition) - 4, 4)) = 0)

};

declare function scc:isRefinedEvent($originalEvent as xs:string, $refinedEvent as xs:string) as xs:boolean {
    (fn:compare($originalEvent, $refinedEvent) = 0) or
            ((fn:compare($originalEvent, fn:substring($refinedEvent, 1, fn:string-length($originalEvent))) = 0) and
                    (fn:compare('.', fn:substring($refinedEvent, fn:string-length($originalEvent) + 1, 1)) = 0))
};


declare function scc:isBehaviorConsistentSpecialization($originalScxml as element(), $refinedScxml as element()) as xs:boolean {
    let $scxmlOriginalStates := scc:getAllStatesAndSubstates($originalScxml)
    let $scxmlRefinedStates := scc:getAllStatesAndSubstates($refinedScxml)

    return (scc:isEveryOriginalStateInRefined($scxmlOriginalStates, $scxmlRefinedStates) and scc:isNoDuplicateStateIntroducedInRefined($scxmlRefinedStates)
            and scc:isEveryOriginalTransitionInRefined($originalScxml, $refinedScxml))
};