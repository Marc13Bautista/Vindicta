#include "common.hpp"

/*
Class: AI.AICommander
AI class for the commander.

Author: Sparker 12.11.2018
*/

#ifndef RELEASE_BUILD
#define DEBUG_COMMANDER
#endif

#define PLAN_INTERVAL 30
#define pr private

CLASS("AICommander", "AI")

	VARIABLE("side");
	VARIABLE("msgLoop");
	VARIABLE("locationDataWest");
	VARIABLE("locationDataEast");
	VARIABLE("locationDataInd");
	VARIABLE("locationDataThis"); // Points to one of the above arrays depending on its side
	VARIABLE("notificationID");
	VARIABLE("notifications"); // Array with [task name, task creation time]
	VARIABLE("intelDB"); // Intel database

	// Friendly garrisons we can access
	VARIABLE("garrisons");

	VARIABLE("targets"); // Array of targets known by this Commander
	VARIABLE("targetClusters"); // Array with target clusters
	VARIABLE("nextClusterID"); // A unique cluster ID generator

	VARIABLE("lastPlanningTime");
	VARIABLE("cmdrAI");
	VARIABLE("worldModel");

	#ifdef DEBUG_CLUSTERS
	VARIABLE("nextMarkerID");
	VARIABLE("clusterMarkers");
	#endif

	#ifdef DEBUG_COMMANDER
	VARIABLE("state");
	VARIABLE("stateStart");
	#endif

	METHOD("new") {
		params [P_THISOBJECT, ["_agent", "", [""]], ["_side", WEST, [WEST]], ["_msgLoop", "", [""]]];
		
		OOP_INFO_1("Initializing Commander for side %1", str(_side));
		
		ASSERT_OBJECT_CLASS(_msgLoop, "MessageLoop");
		T_SETV("side", _side);
		T_SETV("msgLoop", _msgLoop);
		T_SETV("locationDataWest", []);
		T_SETV("locationDataEast", []);
		T_SETV("locationDataInd", []);
		pr _thisLDArray = switch (_side) do {
			case WEST: {T_GETV("locationDataWest")};
			case EAST: {T_GETV("locationDataEast")};
			case INDEPENDENT: {T_GETV("locationDataInd")};
		};
		T_SETV("locationDataThis", _thisLDArray);
		T_SETV("notificationID", 0);
		T_SETV("notifications", []);
		
		T_SETV("garrisons", []);
		
		T_SETV("targets", []);
		T_SETV("targetClusters", []);
		T_SETV("nextClusterID", 0);

		// Create intel database
		pr _intelDB = NEW("IntelDatabaseServer", [_side]);
		T_SETV("intelDB", _intelDB);

		#ifdef DEBUG_CLUSTERS
		T_SETV("nextMarkerID", 0);
		T_SETV("clusterMarkers", []);
		#endif

		#ifdef DEBUG_COMMANDER
		T_SETV("state", "none");
		T_SETV("stateStart", 0);
		[_thisObject, _side] spawn {
			params ["_thisObject", "_side"];
			private _pos = switch (_side) do {
				case WEST: { [0, -1000, 0 ] };
				case EAST: { [0, -1500, 0 ] };
				case INDEPENDENT: { [0, -500, 0 ] };
			};
			private _mrk = createmarker [_thisObject + "_label", _pos];
			_mrk setMarkerType "mil_objective";
			_mrk setMarkerColor (switch (_side) do {
				case WEST: {"ColorWEST"};
				case EAST: {"ColorEAST"};
				case INDEPENDENT: {"ColorGUER"};
				default {"ColorCIV"};
			});
			_mrk setMarkerAlpha 1;
			while{true} do {
				sleep 5;
				_mrk setMarkerText (format ["Cmdr %1: %2 (%3s)", _thisObject, T_GETV("state"), TIME_NOW - T_GETV("stateStart")]);
			};
		};
		#endif
		
		// Create sensors
		pr _sensorLocation = NEW("SensorCommanderLocation", [_thisObject]);
		CALLM1(_thisObject, "addSensor", _sensorLocation);
		pr _sensorTargets = NEW("SensorCommanderTargets", [_thisObject]);
		CALLM1(_thisObject, "addSensor", _sensorTargets);
		pr _sensorCasualties = NEW("SensorCommanderCasualties", [_thisObject]);
		CALLM(_thisObject, "addSensor", [_sensorCasualties]);
		
		T_SETV("lastPlanningTime", TIME_NOW);
		private _cmdrAI = NEW("CmdrAI", [_side]);
		T_SETV("cmdrAI", _cmdrAI);
		private _worldModel = NEW("WorldModel", []);
		T_SETV("worldModel", _worldModel);

		// // Register locations
		// private _locations = CALLSM("Location", "getAll", []);
		// OOP_INFO_1("Registering %1 locations with Model", count _locations);
		// { 
		// 	T_CALLM()
		// 	NEW("LocationModel", [_worldModel ARG _x]) 
		// } forEach _locations;
	} ENDMETHOD;
	
	METHOD("process") {
		params [P_THISOBJECT];
		
		OOP_INFO_0(" - - - - - P R O C E S S - - - - -");
		
		// U P D A T E   S E N S O R S
		#ifdef DEBUG_COMMANDER
		T_SETV("state", "update sensors");
		T_SETV("stateStart", TIME_NOW);
		#endif

		// Update sensors
		CALLM0(_thisObject, "updateSensors");
		
		// U P D A T E   C L U S T E R S
		#ifdef DEBUG_COMMANDER
		T_SETV("state", "update clusters");
		T_SETV("stateStart", TIME_NOW);
		#endif

		// TODO: we should just respond to new cluster creation explicitly instead?
		// Register for new clusters		
		T_PRVAR(worldModel);
		{
			private _ID = _x select TARGET_CLUSTER_ID_ID;
			private _cluster = [_thisObject ARG _ID];
			if(IS_NULL_OBJECT(CALLM(_worldModel, "findClusterByActual", [_cluster]))) then {
				OOP_INFO_1("Target cluster with ID %1 is new", _ID);
				NEW("ClusterModel", [_worldModel ARG _cluster]);
			};
		} forEach T_GETV("targetClusters");

		// Delete old notifications
		pr _nots = T_GETV("notifications");
		pr _i = 0;
		while {_i < count (_nots)} do {
			(_nots select _i) params ["_task", "_time"];
			// If this notification ahs been here for too long
			if (TIME_NOW - _time > 120) then {
				[_task, T_GETV("side")] call BIS_fnc_deleteTask;
				// Delete this notification from the list				
				_nots deleteAt _i;
			} else {
				_i = _i + 1;
			};
		};

		// C M D R A I   P L A N N I N G
		#ifdef DEBUG_COMMANDER
		T_SETV("state", "model sync");
		T_SETV("stateStart", TIME_NOW);
		#endif

		T_PRVAR(cmdrAI);
		T_PRVAR(worldModel);
		// Sync before update
		CALLM(_worldModel, "sync", []);
		CALLM(_cmdrAI, "update", [_worldModel]);
		
		T_PRVAR(lastPlanningTime);
		if(TIME_NOW - _lastPlanningTime > PLAN_INTERVAL) then {
			#ifdef DEBUG_COMMANDER
			T_SETV("state", "model planning");
			T_SETV("stateStart", TIME_NOW);
			#endif

			// Sync after update
			CALLM(_worldModel, "sync", []);

			CALLM(_worldModel, "updateThreatMaps", []);
			CALLM(_cmdrAI, "plan", [_worldModel]);

			// Make it after planning so we get a gap
			T_SETV("lastPlanningTime", TIME_NOW);
		};

		// C L E A N U P
		#ifdef DEBUG_COMMANDER
		T_SETV("state", "cleanup");
		T_SETV("stateStart", TIME_NOW);
		#endif

		{
			// Unregister from ourselves straight away.
			T_CALLM("_unregisterGarrison", [_x]);
			CALLM2(_x, "postMethodAsync", "destroy", []);
		} forEach (T_GETV("garrisons") select { CALLM(_x, "isEmpty", []) });

		#ifdef DEBUG_COMMANDER
		T_SETV("state", "inactive");
		T_SETV("stateStart", TIME_NOW);
		#endif
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                    G E T   M E S S A G E   L O O P
	// ----------------------------------------------------------------------
	
	METHOD("getMessageLoop") {
		params [P_THISOBJECT];
		
		T_GETV("msgLoop");
	} ENDMETHOD;
	
	/*
	Method: (static)getCommanderAIOfSide
	Returns AICommander object that commands given side
	
	Parameters: _side
	
	_side - side
	
	Returns: <AICommander>
	*/
	STATIC_METHOD("getCommanderAIOfSide") {
		params [P_THISOBJECT, ["_side", WEST, [WEST]]];
		switch (_side) do {
			case WEST: {
				if(isNil "gAICommanderWest") then { NULL_OBJECT } else { gAICommanderWest }
			};
			case EAST: {
				if(isNil "gAICommanderEast") then { NULL_OBJECT } else { gAICommanderEast }
			};
			case INDEPENDENT: {
				if(isNil "gAICommanderInd") then { NULL_OBJECT } else { gAICommanderInd }
			};
			default {
				NULL_OBJECT
			};
		};
	} ENDMETHOD;
	
	// Location data
	// If you pass any side except EAST, WEST, INDEPENDENT, then this AI object will update its own knowledge about provided locations
	METHOD("updateLocationData") {
		params [P_THISOBJECT, ["_loc", "", [""]], ["_updateType", 0, [0]], ["_side", CIVILIAN], ["_showNotification", true]];
		
		OOP_INFO_1("UPDATE LOCATION DATA: %1", _this);

		pr _thisSide = T_GETV("side");
		
		pr _ld = switch (_side) do {
			case WEST: {T_GETV("locationDataWest")};
			case EAST: {T_GETV("locationDataEast")};
			case INDEPENDENT: {T_GETV("locationDataInd")};
			default { _side = _thisSide; T_GETV("locationDataThis")};
		};
				
		// Check if we have intel about such location already
		pr _intelQuery = NEW("IntelLocation", [_side]);
		SETV(_intelQuery, "location", _loc);
		pr _intelDB = T_GETV("intelDB");
		pr _intelResult = CALLM1(_intelDB, "findFirstIntel", _intelQuery);

		OOP_INFO_1("Intel query result: %1;", _intelResult);
		
		if (_intelResult != "") then {
			// There is an intel item with this location

			OOP_INFO_1("Intel was found in existing database: %1", _loc);

			// Create intel item from location, update the old item
			pr _args = [_loc, _updateType];
			pr _intel = CALL_STATIC_METHOD("AICommander", "createIntelFromLocation", _args);

			CALLM2(_intelDB, "updateIntel", _intelResult, _intel);

			// Delete the intel object that we have created temporary
			DELETE(_intel);
		} else {
			// There is no intel item with this location
			
			OOP_INFO_1("Intel was NOT found in existing database: %1", _loc);

			// Create intel from location, add it
			pr _args = [_loc, _updateType];
			pr _intel = CALL_STATIC_METHOD("AICommander", "createIntelFromLocation", _args);
			
			OOP_INFO_1("Created intel item from location: %1", _intel);
			//[_intel] call OOP_dumpAllVariables;

			CALLM1(_intelDB, "addIntel", _intel);
			// Don't delete the intel object now! It's in the database from now.

			// Register with the World Model
			T_PRVAR(worldModel);
			CALLM(_worldModel, "findOrAddLocationByActual", [_loc]);
		};
		
	} ENDMETHOD;
	
	// Creates a LocationData array from Location
	STATIC_METHOD("createIntelFromLocation") {
		params ["_thisClass", ["_loc", "", [""]], ["_updateLevel", 0, [0]]];
		
		ASSERT_OBJECT_CLASS(_loc, "Location");
		
		pr _gar = CALLM0(_loc, "getGarrisons") select 0;
		if (isNil "_gar") then {
			_gar = "";
		};
		
		pr _value = NEW("IntelLocation", []);
		
		// Set position
		pr _locPos = +(CALLM0(_loc, "getPos"));
		_locPos resize 2;
		SETV(_value, "pos", _locPos);
		
		// Set time
		//SETV(_value, "", set [CLD_ID_TIME, TIME_NOW];
		
		// Set type
		if (_updateLevel >= CLD_UPDATE_LEVEL_TYPE) then {
			SETV(_value, "type", CALLM0(_loc, "getType")); // todo add types for locations at some point?
		} else {
			SETV(_value, "type", LOCATION_TYPE_UNKNOWN);
		};
		
		// Set side
		if (_updateLevel >= CLD_UPDATE_LEVEL_SIDE) then {
			if (_gar != "") then {
				SETV(_value, "side", CALLM0(_gar, "getSide"));
			} else {
				SETV(_value, "side", CLD_SIDE_UNKNOWN);
			};
		} else {
			SETV(_value, "side", CLD_SIDE_UNKNOWN);
		};
		
		// Set unit count
		if (_updateLevel >= CLD_UPDATE_LEVEL_UNITS) then {
			pr _CLD_full = CLD_UNIT_AMOUNT_FULL;
			if (_gar != "") then {
				{
					_x params ["_catID", "_catSize"];
					pr _query = [[_catID, 0]];
					for "_subcatID" from 0 to (_catSize - 1) do {
						(_query select 0) set [1, _subcatID];
						pr _amount = CALLM1(_gar, "countUnits", _query);
						(_CLD_full select _catID) set [_subcatID, _amount];
					};
				} forEach [[T_INF, T_INF_SIZE], [T_VEH, T_VEH_SIZE], [T_DRONE, T_DRONE_SIZE]];
			};
			SETV(_value, "unitData", _CLD_full);
		} else {
			SETV(_value, "unitData", CLD_UNIT_AMOUNT_UNKNOWN);
		};
		
		// Set ref to location object
		SETV(_value, "location", _loc);
		
		_value
	} ENDMETHOD;
	
	// Returns known locations which are assumed to be controlled by this AICommander
	METHOD("getFriendlyLocations") {
		params ["_thisObject"];
		
		pr _thisSide = T_GETV("side");
		pr _friendlyLocs = T_GETV("locationDataThis") select {
			_x select CLD_ID_SIDE == _thisSide
		} apply {
			_x select CLD_ID_LOCATION
		};
		
		_friendlyLocs		
	} ENDMETHOD;
	
	// Generates a new target cluster ID
	METHOD("getNewTargetClusterID") {
		params ["_thisObject"];
		pr _nextID = T_GETV("nextClusterID");
		T_SETV("nextClusterID", _nextID + 1);
		_nextID
	} ENDMETHOD;
		
	// // /*
	// // Method: onTargetClusterCreated
	// // Gets called on creation of a totally new target cluster
	
	// // Parameters: _tc
	
	// // _ID - the new target cluster ID (must already exist in the cluster array)
	
	// // Returns: nil
	// // */
	// METHOD("onTargetClusterCreated") {
	// 	params ["_thisObject", "_ID"];
	// 	OOP_INFO_1("TARGET CLUSTER CREATED, ID: %1", _ID);
	// 	T_PRVAR(worldModel);
	// 	NEW("ClusterModel", [_worldModel ARG [_thisObject ARG _ID]]);
	// } ENDMETHOD;

	/*
	Method: onTargetClusterSplitted
	Gets called when an already known cluster gets splitted into multiple new clusters.
	
	Parameters: _tcsNew
	
	_tcsNew - array of [_affinity, _newTargetCluster]
	
	Returns: nil
	*/
	METHOD("onTargetClusterSplitted") {
		params ["_thisObject", "_tcOld", "_tcsNew"];
		
		pr _IDOld = _tcOld select TARGET_CLUSTER_ID_ID;
		pr _a = _tcsNew apply {[_x select 0, _x select 1 select TARGET_CLUSTER_ID_ID]};
		OOP_INFO_2("TARGET CLUSTER SPLITTED, old ID: %1, new affinity and IDs: %2", _IDOld, _a);

		// Sort new clusters by affinity
		_tcsNew sort DESCENDING;

		// Relocate all actions assigned to the old cluster to the new cluster with maximum affinity
		pr _newClusterID = _tcsNew select 0 select 1 select TARGET_CLUSTER_ID_ID;

		T_PRVAR(worldModel);
		// Retarget in the model
		CALLM(_worldModel, "retargetClusterByActual", [[_thisObject ARG _IDOld] ARG [_thisObject ARG _newClusterID]]);
	} ENDMETHOD;	

	/*
	Method: onTargetClusterMerged
	Gets called when old clusters get merged into a new one
	
	Parameters: _tc
	
	_tc - the new target cluster
	
	Returns: nil
	*/
	METHOD("onTargetClustersMerged") {
		params ["_thisObject", "_tcsOld", "_tcNew"];

		pr _IDnew = _tcNew select TARGET_CLUSTER_ID_ID;
		pr _IDsOld = []; { _IDsOld pushBack (_x select TARGET_CLUSTER_ID_ID)} forEach _tcsOld;
		OOP_INFO_2("TARGET CLUSTER MERGED, old IDs: %1, new ID: %2", _IDsOld, _IDnew);

		T_PRVAR(worldModel);

		// Assign all actions from old IDs to new IDs
		{
			pr _IDOld = _x;
			// Retarget in the model
			CALLM(_worldModel, "retargetClusterByActual", [[_thisObject ARG _IDOld] ARG [_thisObject ARG _IDnew]]);
		} forEach _IDsOld;

	} ENDMETHOD;
	
	/*
	Method: onTargetClusterDeleted
	Gets called on deletion of a cluster because these enemies are not spotted any more
	
	Parameters: _tc
	
	_tc - the new target cluster
	
	Returns: nil
	*/
	METHOD("onTargetClusterDeleted") {
		params ["_thisObject", "_tc"];
		
		pr _ID = _tc select TARGET_CLUSTER_ID_ID;
		OOP_INFO_1("TARGET CLUSTER DELETED, ID: %1", _ID);
		
	} ENDMETHOD;
	
	/*
	Method: getTargetCluster
	Returns a target cluster with specified ID
	
	Parameters: _ID
	
	_ID - ID of the target cluster
	
	Returns: target cluster structure or [] if nothing was found
	*/
	METHOD("getTargetCluster") {
		params ["_thisObject", ["_ID", 0, [0]]];
		
		pr _targetClusters = T_GETV("targetClusters");
		pr _ret = [];
		{ // foreach _targetClusters
			if (_x select TARGET_CLUSTER_ID_ID == _ID) exitWith {
				_ret = _x;
			};
		} forEach _targetClusters;
		
		_ret
	} ENDMETHOD;
	
	/*
	Method: getThreat
	Get estimated threat at a particular position
	
	Parameters:
	_pos - <position>
	
	Returns: Array - threat efficiency at _pos
	*/
	METHOD("getThreat") { // thread-safe
		params [P_THISOBJECT, P_ARRAY("_pos")];
		T_PRVAR(worldModel);
		CALLM(_worldModel, "getThreat", [_pos])
	} ENDMETHOD;
	
	/*
	Method: registerGarrison
	Registers a garrison to be processed by this AICommander
	
	Parameters:
	_gar - <Garrison>
	
	Returns: nil
	*/
	STATIC_METHOD("registerGarrison") {
		params [P_THISCLASS, P_OOP_OBJECT("_gar")];
		ASSERT_OBJECT_CLASS(_gar, "Garrison");
		private _side = CALLM(_gar, "getSide", []);
		private _thisObject = CALL_STATIC_METHOD("AICommander", "getCommanderAIOfSide", [_side]);

		private _newModel = NULL_OBJECT;
		if(!IS_NULL_OBJECT(_thisObject)) then {
			ASSERT_THREAD(_thisObject);

			OOP_DEBUG_MSG("Registering garrison %1", [_gar]);
			T_GETV("garrisons") pushBack _gar; // I need you for my army!
			CALLM(_gar, "ref", []);
			T_PRVAR(worldModel);
			_newModel = NEW("GarrisonModel", [_worldModel ARG _gar]);
		};
		_newModel
	} ENDMETHOD;

	/*
	Method: registerLocation
	Registers a location to be known by this AICommander
	
	Parameters:
	_loc - <Location>
	
	Returns: nil
	*/
	METHOD("registerLocation") {
		params [P_THISOBJECT, P_OOP_OBJECT("_loc")];
		ASSERT_OBJECT_CLASS(_loc, "Location");

		private _newModel = NULL_OBJECT;
		OOP_DEBUG_MSG("Registering location %1", [_loc]);
		//T_GETV("locations") pushBack _loc; // I need you for my army!
		// CALLM2(_loc, "postMethodAsync", "ref", []);
		T_PRVAR(worldModel);
		// Just creating the location model is registering it with CmdrAI
		NEW("LocationModel", [_worldModel ARG _loc]);
	} ENDMETHOD;

	/*
	Method: unregisterGarrison
	Unregisters a garrison from this AICommander
	
	Parameters:
	_gar - <Garrison>
	
	Returns: nil
	*/
	STATIC_METHOD("unregisterGarrison") {
		params [P_THISCLASS, P_OOP_OBJECT("_gar")];
		ASSERT_OBJECT_CLASS(_gar, "Garrison");
		private _side = CALLM(_gar, "getSide", []);
		private _thisObject = CALL_STATIC_METHOD("AICommander", "getCommanderAIOfSide", [_side]);
		if(!IS_NULL_OBJECT(_thisObject)) then {
			T_CALLM2("postMethodAsync", "_unregisterGarrison", [_gar]);
		} else {
			OOP_WARNING_MSG("Can't unregisterGarrison %1, no AICommander found for side %2", [_gar ARG _side]);
		};
	} ENDMETHOD;

	METHOD("_unregisterGarrison") {
		params [P_THISOBJECT, P_STRING("_gar")];
		ASSERT_THREAD(_thisObject);

		T_PRVAR(garrisons);
		// Check the garrison is registered
		private _idx = _garrisons find _gar;
		if(_idx != NOT_FOUND) then {
			OOP_DEBUG_MSG("Unregistering garrison %1", [_gar]);
			// Remove from model first
			T_PRVAR(worldModel);
			private _garrisonModel = CALLM(_worldModel, "findGarrisonByActual", [_gar]);
			CALLM(_worldModel, "removeGarrison", [_garrisonModel]);
			_garrisons deleteAt _idx; // Get out of my sight you useless garrison!
			CALLM(_gar, "unref", []);
		} else {
			OOP_WARNING_MSG("Garrison %1 not registered so can't _unregisterGarrison", [_gar]);
		};
	} ENDMETHOD;
		
	/*
	Method: registerIntelCommanderAction
	Registers a piece of intel on an action that this Commander owns.
	Parameters:
	_intel - <IntelCommanderAction>
	
	Returns: nil
	*/
	STATIC_METHOD("registerIntelCommanderAction") {
		params [P_THISCLASS, P_OOP_OBJECT("_intel")];
		ASSERT_OBJECT_CLASS(_intel, "IntelCommanderAction");
		private _side = GETV(_intel, "side");
		private _thisObject = CALL_STATIC_METHOD("AICommander", "getCommanderAIOfSide", [_side]);

		T_PRVAR(intelDB);
		CALLM(_intelDB, "addIntelClone", [_intel])
	} ENDMETHOD;
ENDCLASS;
