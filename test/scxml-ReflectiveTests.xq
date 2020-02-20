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

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Git/master/MBAse/modules/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Git/master/MBAse/modules/functx.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Git/master/MBAse/modules/scxml.xqm';
import module namespace scx='http://www.w3.org/2005/07/scxml/extension/' at 'C:/Git/master/MBAse/modules/scxml_extension.xqm';
import module namespace scc='http://www.w3.org/2005/07/scxml/consistency/' at 'C:/Git/master/MBAse/modules/scxml_consistency.xqm';
import module namespace reflection='http://www.dke.jku.at/MBA/Reflection' at 'C:/Git/master/MBAse/modules/reflection.xqm';

declare variable $db := 'myMBAse';
declare variable $collectionName := 'parallelHomogenous';

declare variable $mbaHoltonFromDB := mba:getMBA($db, $collectionName, "HoltonHotelChain");
declare variable $mbaAustriaFromDB := mba:getMBA($db, $collectionName, "Austria");

declare variable $mbaDocument := fn:doc('C:/Git/master/MBAse/example/heteroHomogeneous/HoltonHotelChain-MBA-NoBoilerPlateElements.xml');
declare variable $mbaHolton := $mbaDocument/mba:mba;

declare variable $originalState :=  $mbaHolton//sc:state[@id='Running'];


(: Check if refined model is behavior consistent to original model. expected result: true)
   This test is here because it is a precondition for the following tests regarding reflective functions 
   sccIsBehaviorConsistentSpecialization is used as the default behavior function - see API description
return scc:isBehaviorConsistentSpecialization($scxmlRentalOriginal, $scxmlRentalRefined)  

declare variable $subState := 
  <sc:state id="RunningGood">   
  </sc:state>;

return $mbaHolton;  :)

(: Check if non-updating version of refine state function works.  
Using an MBA that is loaded from file system isntead of repository makes it easier to be sure it has no descendants. expected result: refined state node  
let $subState := 
  <sc:state id="RunningGood"/>   


let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2  
return reflection:getRefinedState($originalState, $subState, $defaultBehavior)  :)

(: Check if introducing a duplicate state id in refinement is detected..  expected result: error
let $subState := 
  <sc:state id="RunningGood">
    <sc:state id="Restructuring"/>
  </sc:state>   


let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2  
return reflection:getRefinedState($originalState, $subState, $defaultBehavior)   :)

(: Check if a final node can also be inserted using the refine state function. expected result: refined state node  
let $finalState :=
  <sc:final id="TheEnd">   
  </sc:final>

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2  
return reflection:getRefinedState($originalState, $finalState, $defaultBehavior) :)


(: Check if updating version of refine state function works. Backup is necessary before executing this test.    
declare variable $originalStateAustriaFromDB := $mbaAustriaFromDB//sc:state[@id='OffSeason'];
declare variable $subStateAustriaFromDB := 
  <sc:state id="StaffHome">
  </sc:state>; :)
  

(: Step 1: execute updating function
   Step 2: return variable :)  
(:reflection:refineStateDefaultBehavior($originalStateAustriaFromDB, $subStateAustriaFromDB) :)
(: $mbaAustriaFromDB :)

  
(: Check if refineState fails if an MBA has already descendants: expected: error
For this purpose MBA is loaded from database  
declare variable $originalStateFromDB :=  $mbaHoltonFromDB//sc:state[@id='Running'];

reflection:refineStateDefaultBehavior($originalStateFromDB, $subState)  :)


(: Check if extending with parallel region works. expected: parallel node
let $originalState :=  $mbaHolton//sc:state[@id='Restructuring']
let $parallelState := <sc:state id="Renovating"></sc:state>


let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
 return reflection:getParallelRegionExtension($originalState, $parallelState, $defaultBehavior, ())  :)


(: Check if extending with parallel region fails because MBA has descendants. expected: error  
let $originalState := $mbaHoltonFromDB//sc:state[@id='Restructuring']
let $parallelState :=  <sc:state id="Renovating"></sc:state>

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getParallelRegionExtension($originalState, $parallelState, $defaultBehavior, ()) :)

(: Check if extending with parallel region works if an optionalNode is specified: expected: parallel node 
let $originalState :=  $mbaHolton//sc:state[@id='Restructuring']
let $parallelState := <sc:state id="Renovating"></sc:state>
let $optionalState := <onentry><assign location="description" expr="Sorry we are currently closed"/></onentry>

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getParallelRegionExtension($originalState, $parallelState, $defaultBehavior, $optionalState) :)

(: Check if extending with parallel region that has multiple nodes in parameter parallelState works. expected parallel node 
let $originalState :=  $mbaHolton//sc:state[@id='Restructuring']
let $parallelState := <sc:state id="Renovating"></sc:state> 
let $parallelState2 := <sc:state id="RecalculatePrices"/>
let $parallelStates := ($parallelState, $parallelState2)

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getParallelRegionExtension($originalState, $parallelStates, $defaultBehavior, ()) :)


(: Check if refining condition of transition with no current condition works. expected: refined transition 
let $originalState :=  $mbaHolton//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $condition := "New Condition"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinedPreCondition($transition, $condition, $defaultBehavior)   :)


(: Check if refining condition of transition with already existing condition works. expected: refined transition 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="reopen" cond="existingCondition" target="Running"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $condition := "New Condition"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinedPreCondition($transition, $condition, $defaultBehavior) :)

(: Check if refining event of transition with no current event works. expected: refined transition  
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition cond="existingCondition" target="Running"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']

let $transition := $originalState//sc:transition[2]
let $event := "NewEvent"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinendEvents($transition, $event, $defaultBehavior) :)

(: Check if refining event of transition with already existing event works. expected: refined transition 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']

let $transition := $originalState//sc:transition[2]
let $event := "subEvent"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinendEvents($transition, $event, $defaultBehavior) :)


(: Check if refining target of transition that is a valid substate of existing target. expected: refined transition 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
              <sc:state id="RefinedRunning"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $newTarget := "RefinedRunning"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinedTarget($transition, $newTarget, $defaultBehavior) :)



(: Check if refining target of transition that is not a valid substate of existing target. expected: error 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
              <sc:state id="RefinedRunning"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $newTarget := "SomeOtherState"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinedTarget($transition, $newTarget, $defaultBehavior) :)

(: Check if refining target of transition that has no target works. expected: refined transition 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Restructuring"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $newTarget := "RefinedRestructuring"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2 
let $result := reflection:getTransitionWithRefinedTarget($transition, $newTarget, $defaultBehavior) 
return $result :)


(: Check if refining source of transition works. expected: refined transition 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[1]
let $source := "RefinedRestructuring"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2
return reflection:getTransitionWithRefinedSource($transition, $source, $defaultBehavior) :)
(: return reflection:refineSourceCustomBehavior($transition, $source, $defaultBehavior) :)


(: Check if refining source of transition by moving it to a different state as in the original model works. expected: error 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>

let $originalState :=  $inlineMBA//sc:state[@id='Restructuring']
let $transition := $originalState//sc:transition[2]
let $source := "Running"

let $defaultBehavior := scc:isBehaviorConsistentSpecialization#2 

return reflection:getTransitionWithRefinedSource($transition, $source, $defaultBehavior) :)
(: return reflection:refineSourceCustomBehavior($transition, $source, $defaultBehavior)   :)



(: Check if adding an additional setter transitions works for consistency check. expected: positive result for check 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>
    
let $inlineMBARefined := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
               <!--  additional setter transitions with no target or state/substate that refers to source-->
              <sc:transition event="setterEvent1"/>  
              <sc:transition event="setterEvent2" target="Restructuring"/>  
              <sc:transition event="setterEvent3" target="RefinedRestructuring"/> 
              <sc:transition event="event1.refined" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring">
                 <!--  additional transition that has state/substate as target and should work --> 
               <sc:transition event="setterEvent4" target="RefinedRestructuring"/> 
              </sc:state>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
           
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>
    
    
let $originalScxml := $inlineMBA//sc:scxml
let $refinedScxml := $inlineMBARefined//sc:scxml

let $result := scc:isBehaviorConsistentSpecialization($originalScxml, $refinedScxml)  
return $result :)

(: Check if adding a new transition between existing states in the original model works. expected: error 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>
    
let $inlineMBARefined := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
               <!--  additional transition that breaks consistency when added    --> 
              <sc:transition event="breakingEvent" target="Running"/>
              <sc:transition event="event1.refined" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring" />
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>
    
    
let $originalScxml := $inlineMBA//sc:scxml
let $refinedScxml := $inlineMBARefined//sc:scxml


let $result := scc:isBehaviorConsistentSpecialization($originalScxml, $refinedScxml) 
return $result  :)

(: Check if creating a substate with duplicate id will create an error 
let $inlineMBA := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
              <sc:transition event="event1" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring"/>
            </sc:state>
            <sc:state id="Running">
             <!--  <sc:transition event="restructure" target="Restructuring"/> -->
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba>
    
let $inlineMBARefined := <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="HoltonHotelChain" hierarchy="parallel" topLevel="business" isDefault="true">
    <levels>
      <level name="business"> 
        <elements>
          <sc:scxml name="Business">
            <sc:datamodel>
              <sc:data id="description">Worldwide hotel chain</sc:data>
            </sc:datamodel>
            <sc:initial>
              <sc:transition target="Restructuring"/>
            </sc:initial>
            <sc:state id="Restructuring">
              <sc:transition event="createAccomodationType">
                <sync:newDescendant name="$_event/data/name" level="accomodationType"/>
              </sc:transition>
               <!--  additional setter transitions with no target or state/substate that refers to source-->
              <sc:transition event="setterEvent1"/>  
              <sc:transition event="setterEvent2" target="Restructuring"/>  
              <sc:transition event="setterEvent3" target="RefinedRestructuring"/> 
              <sc:transition event="event1.refined" cond="existingCondition" target="Running"/>
              <sc:state id="RefinedRestructuring">
                 <!--  additional transition that has state/substate as target and should work --> 
               <sc:transition event="setterEvent4" target="RefinedRestructuring"/> 
              </sc:state>
            </sc:state>
            <sc:state id="Running">
              <sc:transition event="restructure" target="Restructuring"/>
              <sc:state id="Restructuring"/>
            </sc:state>
          </sc:scxml>
        </elements>
      </level>
     </levels>
    </mba> 
    

    
    
let $originalScxml := $inlineMBA//sc:scxml
let $refinedScxml := $inlineMBARefined//sc:scxml

let $result := scc:isBehaviorConsistentSpecialization($originalScxml, $refinedScxml)  
return $result :)