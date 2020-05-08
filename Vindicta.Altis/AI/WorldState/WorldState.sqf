#include "..\AI\AI.hpp"
#include "WorldStateProperty.hpp"
#include "..\..\common.h"

#define pr private
#define WS_ID_WSP	0
#define WS_ID_WSPT	1
#define WS_ID_ORIGIN 2

/*
Class: WorldState
WorldState is an array with WorldStateProperties
World State is a representation of the world relative to the agent

Author: Sparker 07.11.2018
*/


/*
Method: ws_new
Returns a new WorldState object

Parameters: _size

_size - amount of world state properties
_b - 
_c -

Returns: new WorldState object
*/



ws_new = {
	params [P_NUMBER("_size"), ["_origin", ORIGIN_GOAL_WS, [0]]];

	// Array with WorldStateProperties
	pr _array_WSP = [];
	_array_WSP resize _size;
	_array_WSP = _array_WSP apply {0};
	
	// Array with flags indicating if specified WSP exists or not
	pr _array_propTypes = []; // Array of WorldPropertyExists flags
	_array_propTypes resize _size;
	_array_propTypes = _array_propTypes apply {WSP_TYPE_DOES_NOT_EXIST};


	// Array with origin of each WSP
	pr _array_origin = [];
	_array_origin resize _size;
	_array_origin = _array_origin apply {_origin};
	
	// Return
	[_array_WSP, _array_propTypes, _array_origin]
};


/*
Method: ws_getSize
Returns size of this world state

Parameters: _ws

_ws - world state

Returns: Number
*/
ws_getSize = {
	params [P_ARRAY("_WS")];
	count (_WS select 0)
};

/*
Method: ws_getPropertyValue
Returns size of this world state

Parameters: _ws, _key

_ws - world state
_key - Number, ID of world state property

Returns: Number
*/
ws_getPropertyValue = {
	params [P_ARRAY("_WS"), P_NUMBER("_key")];
	_WS select WS_ID_WSP select _key
};

/*
Method: ws_getPropertyOrigin
Returns origin of this WSP
*/
ws_getPropertyOrigin = {
	params [P_ARRAY("_WS"), P_NUMBER("_key")];
	_WS select WS_ID_ORIGIN select _key;
};

/*
Method: ws_propertyExistsAndEquals
Returns true if the property exists and is equal to supplied value

Parameters: _ws, _key, _value

_ws - world state
_key - Number, ID of world state property
_value - value

Returns: Bool
*/
ws_propertyExistsAndEquals = {
	params [P_ARRAY("_WS"), P_NUMBER("_key"), ["_value", 0, WSP_TYPES]];
	pr _prop = _WS select WS_ID_WSP select _key;
	pr _propTypes = _WS select WS_ID_WSPT; // property exists
	// Check both property existance and value
	if (((_propTypes select _key) != WSP_TYPE_DOES_NOT_EXIST) && (_prop isEqualTo _value)) then {
		true
	} else {
		false
	};
};


/*
Method: ws_setPropertyValue
Sets value of property with given key

Parameters: _ws, _key, _value

_ws - world state
_key - Number, ID of world state property
_value - value

Returns: nil
*/
ws_setPropertyValue = {
	params [P_ARRAY("_WS"), P_NUMBER("_key"), ["_value", 0, WSP_TYPES]];
	pr _properties = _WS select WS_ID_WSP;
	_properties set [_key, _value];
	
	pr _propTypes = _WS select WS_ID_WSPT;
	pr _type = WSP_TYPE_DOES_NOT_EXIST;
	call {
		if (_value isEqualType 0) exitWith {_type = WSP_TYPE_NUMBER; };
		if (_value isEqualType "") exitWith {_type = WSP_TYPE_STRING; };
		if (_value isEqualType objNull) exitWith {_type = WSP_TYPE_OBJECT_HANDLE; };
		if (_value isEqualType false) exitWith {_type = WSP_TYPE_BOOL; };
		if (_value isEqualType []) exitWith {_type = WSP_TYPE_ARRAY; };
	};
	_propTypes set [_key, _type];
};

/*
Method: ws_setPropertyOrigin
Sets property origin.
*/

ws_setPropertyOrigin = {
	params [P_ARRAY("_WS"), P_NUMBER("_key"), ["_value", 0, [0]]];
	pr _origins = _WS select WS_ID_ORIGIN;
	_origins set [_key, _value];
};

// Must be used for actions to specify that the property of world state depends on input parameter with _id
ws_setPropertyActionParameterTag = {
	params [P_ARRAY("_WS"), P_NUMBER("_key"), ["_tag", "ERROR_NO_TAG"]];
	pr _properties = _WS select WS_ID_WSP;
	_properties set [_key, _tag];
	
	pr _propTypes = _WS select WS_ID_WSPT;
	_propTypes set [_key, WSP_TYPE_ACTION_PARAMETER];
};

// Must be used for goals to specify that the property of world state depends on input parameter with _id
ws_setPropertyGoalParameterTag = {
	params [P_ARRAY("_WS"), P_NUMBER("_key"), ["_tag", "ERROR_NO_TAG"]];
	pr _properties = _WS select WS_ID_WSP;
	_properties set [_key, _tag];
	
	pr _propTypes = _WS select WS_ID_WSPT;
	_propTypes set [_key, WSP_TYPE_GOAL_PARAMETER];

	// Mark that this property also originates from goal
	pr _origins = _WS select WS_ID_ORIGIN;
	_origins set [_key, ORIGIN_GOAL_PARAMETER];
};

/*
Method: ws_clearProperty
Clears property with given key

Parameters: _ws, _key

_ws - world state
_key - Number, ID of world state property

Returns: nil
*/
ws_clearProperty = {
	params [P_ARRAY("_WS"), P_NUMBER("_key")];
	pr _propTypes = _WS select WS_ID_WSPT;
	pr _props = _WS select WS_ID_WSP;
	_props set [_key, 0];
	_propTypes set [_key, WSP_TYPE_DOES_NOT_EXIST]; // Property doesn't exist any more
};

/*
Method: ws_toString
Converts world state to a string, which can be useful for debug purposes

Parameters: _ws

_ws - world state

Returns: String
*/
// Returns a string in human readable form for debug purposes
ws_toString = {
	params [P_ARRAY("_WS")];
	pr _properties = _WS select WS_ID_WSP;
	pr _propTypes = _WS select WS_ID_WSPT;
	pr _origins = _WS select WS_ID_ORIGIN;
	pr _strOut = "[";
	for "_i" from 0 to ((count _properties) - 1) do {
		if ((_propTypes select _i) != WSP_TYPE_DOES_NOT_EXIST) then { // If this property exists, add it to the string array
			if ((_propTypes select _i) == WSP_TYPE_ACTION_PARAMETER)  then { // If it's a parameter
				_strOut = _strOut + format ["%1(%2):<AP %3>  ", _i, _origins#_i, _properties#_i]; // Key, tag
			} else {
				if ((_propTypes select _i) == WSP_TYPE_GOAL_PARAMETER)  then {
					_strOut = _strOut + format ["%1(%2):<GP %3>  ", _i, _origins#_i, _properties#_i]; // Key, tag
				} else {
					_strOut = _strOut + format ["%1(%2):%3  ", _i, _origins#_i, _properties#_i]; // Key, Value
				};
			};
		};
	};
	_strOut = _strOut + "]";
	
	// Return
	_strOut
	//str _WS
};

/*
Method: ws_isActionSuitable
Checks if an action with given effects and preconditions can be used to satisfy some goal.

An action can be applied if any properties in effects are equal to properties in goal,
or if a property in effects is a parameter which affects an existing property in goal.

BUT preconditions of an action must not be in conflict with the goal.

Return value: [_connected, _parameterID, _parameterValue]
_connected - bool
*/
ws_isActionSuitable = {
	params [P_ARRAY("_preconditions"), P_ARRAY("_effects"), P_ARRAY("_wsGoal") ];

	// Unpack the arrays
	pr _effectsProps = _effects select WS_ID_WSP;
	pr _effectsPropTypes = _effects select WS_ID_WSPT;
	pr _goalProps = _wsGoal select WS_ID_WSP;
	pr _goalPropTypes = _wsGoal select WS_ID_WSPT;
	pr _preProps = _preconditions select WS_ID_WSP;
	pr _prePropTypes = _preconditions select WS_ID_WSPT;

	pr _len = count _effectsProps;

	pr _connected = false;
	pr _conflicting = false;

	pr _i = 0;
	while {!_conflicting && _i < _len} do {
		// If property exists in goal and effects
		if (_goalPropTypes#_i != WSP_TYPE_DOES_NOT_EXIST) then {
			if(_effectsPropTypes#_i != WSP_TYPE_DOES_NOT_EXIST) then {
				// If property in A is a parameter which can affect a property in B
				// OR If both properties are equal
				if (_effectsPropTypes#_i == WSP_TYPE_ACTION_PARAMETER || {_goalProps#_i isEqualTo _effectsProps#_i}) then {
					_connected = true;
				} else {
					if(!(_goalProps#_i isEqualTo _effectsProps#_i)) then {
						_conflicting = true;
					};
				};
			} else {
				// Only consider the pre-conditions if the property doesn't exist in the effects (effects cancel preconditions)
				if(_prePropTypes#_i != WSP_TYPE_DOES_NOT_EXIST && !(_goalProps#_i isEqualTo _preProps#_i)) then {
					_conflicting = true;
				};
			};
		};
		_i = _i + 1;
	};
	_connected && !_conflicting
};

/*
Method: ws_getNumUnsatisfiedProps
Returns number of unsatisfied properties between world state A and B
*/

ws_getNumUnsatisfiedProps = {
	params [P_ARRAY("_wsA"), P_ARRAY("_wsB") ];
	
	pr _num = 0;
	
	// Unpack the arrays
	pr _AProps = _wsA select WS_ID_WSP;
	pr _APropTypes = _wsA select WS_ID_WSPT;
	pr _BProps = _wsB select WS_ID_WSP;
	pr _BPropTypes = _wsB select WS_ID_WSPT;
	
	pr _len = count _AProps;
	
	for "_i" from 0 to (_len-1) do {
		if ((_APropTypes select _i) != WSP_TYPE_DOES_NOT_EXIST) then { // If this property exists in A
		
			// If this property doesn't exist in B
			if ((_BPropTypes select _i) == WSP_TYPE_DOES_NOT_EXIST) then {
				_num = _num + 1;
			} else {
				// If property values are different
				if ( ! ((_BProps select _i) isEqualTo (_AProps select _i)) ) then {
				 	_num = _num + 1;
				};
			};
		};
	};
	
	// Return
	_num
};

/*
Method: ws_substract
 Erases properties in _wsA which are affected by properties in _wsB world state
Modifies the original _wsA array, returns nothing
*/
ws_substract = {
	params [P_ARRAY("_wsA"), P_ARRAY("_wsB") ];
	
	// Unpack the arrays
	pr _AProps = _wsA select WS_ID_WSP;
	pr _APropTypes = _wsA select WS_ID_WSPT;
	pr _BPropTypes = _wsB select WS_ID_WSPT;
	
	pr _len = count _AProps;
	
	for "_i" from 0 to (_len - 1) do {
		if ((_BPropTypes select _i) != WSP_TYPE_DOES_NOT_EXIST) then { // If property exists in B
			// Erase the corresponding property in A
			_AProps set [_i, 0];
			_APropTypes set [_i, WSP_TYPE_DOES_NOT_EXIST];
		};
	};
};


/*
Method: ws_add
Adds _wsB to _wsA, modifying _wsA
By adding B to A, we override properties in A which exist in B by values from B.
*/
ws_add = {
	params [P_ARRAY("_wsA"), P_ARRAY("_wsB") ];
	
	// Unpack the arrays
	pr _AProps = _wsA select WS_ID_WSP;
	pr _APropTypes = _wsA select WS_ID_WSPT;
	pr _APropOrigins = _wsA select WS_ID_ORIGIN;
	pr _BProps = _wsB select WS_ID_WSP;
	pr _BPropTypes = _wsB select WS_ID_WSPT;
	pr _BPropOrigins = _wsB select WS_ID_ORIGIN;
	
	pr _len = count _AProps;
	
	for "_i" from 0 to (_len - 1) do {
		if ((_BPropTypes select _i) != WSP_TYPE_DOES_NOT_EXIST) then {
			// Copy values and types
			_AProps set [_i, _BProps select _i];
			_APropTypes set [_i, _BPropTypes select _i];
			_APropOrigins set [_i, _BPropOrigins select _i];
		};
	};
};

/*
Method: ws_applyParametersToGoalEffects
Applies goal parameters to the world state
*/
ws_applyParametersToGoalEffects = {
	params [P_ARRAY("_effects"), P_ARRAY("_parameters")];
	
	if ((count _parameters) == 0) exitWith { false };
	
	pr _effectsProps = _effects select WS_ID_WSP;
	pr _effectsPropTypes = _effects select WS_ID_WSPT;
	
	pr _len = count _effectsProps;
	pr _parameterApplied = true;
	
	for "_i" from 0 to (_len - 1) do {
		if ((_effectsPropTypes select _i) == WSP_TYPE_GOAL_PARAMETER) then { // If this world state must be retrieved from a goal parameter
			pr _tag = _effectsProps select _i;
			
			// Search for a parameter with given tag
			pr _pid = _parameters findif {(_x select 0) == _tag};
			if (_pid == -1) then {
				diag_log format ["[WS:applyParametersToGoalEffects] Error: could not find tag %1 in parameters %2 for goal effects %3",
					_tag, _parameters, [_effects] call ws_toString];
				_parameterApplied = false;
			} else {
				// Put reference of where to take the value from
				[_effects, _i, _tag] call ws_setPropertyValue;
				// Specify that it originates from goal parameter
				[_effects, _i, ORIGIN_GOAL_PARAMETER] call ws_setPropertyOrigin;
			};
		};
	};
	
	_parameterApplied
};

/*
Method:
ws_applyEffectsToParameters
Effects of actions can depend on parameters
This function fills parameters of action from effects
Returns true if parameters were successfully applied
*/
ws_applyEffectsToParameters = {
	params [P_ARRAY("_effects"), P_ARRAY("_actionParameters"), P_ARRAY("_desiredWS")];
	
	// Unpack the arrays
	pr _effectsProps = _effects select WS_ID_WSP;
	pr _effectsPropTypes = _effects select WS_ID_WSPT;
	pr _dwsProps = _desiredWS select WS_ID_WSP;
	pr _dwsPropTypes = _desiredWS select WS_ID_WSPT;
	pr _dwsOrigins = _desiredWS select WS_ID_ORIGIN;
	
	pr _len = count _effectsProps;
	pr _success = true;
	
	for "_i" from 0 to (_len - 1) do {
	
		// If it's a parameter and it affects something which exists in desired world state
		if ( ((_effectsPropTypes select _i) == WSP_TYPE_ACTION_PARAMETER) &&
			((_dwsPropTypes select _i) != WSP_TYPE_DOES_NOT_EXIST)) then {
			
			// Find parameters with given tag
			pr _parameterTag = _effectsProps select _i;
			pr _paramsWithTagID = _actionParameters findIf {(_x select 0) == _parameterTag};
			
			// If no parameters with this tag have been found, add it
			if (_paramsWithTagID == -1) then {
				switch (_dwsOrigins select _i) do {
					case ORIGIN_GOAL_WS: {
						_actionParameters pushBack [_parameterTag, _i, ORIGIN_GOAL_WS];
					};
					case ORIGIN_GOAL_PARAMETER: {
						_actionParameters pushBack [_parameterTag, _dwsProps select _i, ORIGIN_GOAL_PARAMETER];
					};
					case ORIGIN_STATIC_VALUE: {
						_actionParameters pushBack [_parameterTag, _dwsProps select _i, ORIGIN_STATIC_VALUE];
					};
					default {
						diag_log format ["ws_applyEffectsToParameters: Error: unknown world state origin: %1", _dwsOrigins select _i];
					};
				};
			/*
			// This is actually not an error because some actions can propagate a parameter from multiple effect properties to a single parameter
			} else {
				// A value must be passed from an effect to an action parameter
				// But the action already has this value from the goal parameters
				// So what the fuck is going on here???
				
				diag_log format ["[WS:applyParametersToPreconditions] Error: parameter already exists. Effects: %1,  actionParameters: %2",
					_effects, _actionParameters];
				_success = false;
			*/
			};
		};
	};
	
	_success
};

// Calculates planner cache key
ws_getPlannerCacheKey = {
	params ["_wsCurrent", "_wsGoal"];
	_wsGoal params ["_goalProps", "_goalTypes"];
	_goalProps = +_goalProps;
	_wsCurrent params ["_currentProps", "_currentTypes"];
	_currentProps = +_currentProps;
	
	// todo: use toString instead of str, it's much much faster
	{
		if (! (_x isEqualType false)) then {
			_currentProps set [_forEachIndex, true]; // Bools are much faster to stringify
			_goalProps set [_forEachIndex, _x isEqualTo (_goalProps#_forEachIndex)];
		};
	} forEach _currentProps;

	(str _goalProps) + (str _goalTypes) + (str _currentProps) + (str _currentTypes);
};