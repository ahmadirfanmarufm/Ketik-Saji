class_name SharedTypes
extends RefCounted
## Shared canonical enums across Ketik Saji controllers and static resources.
##
## Defines code-level state identifiers from docs/ARCHITECTURE.md §2 without
## mutable runtime state or player-facing localization text.

enum Phase {
	PLANNING,
	SERVING,
	CLOSING,
	RESULTS,
	FINISHED,
}

enum OrderKind {
	DINE_IN,
	ONLINE,
}

enum OrderStatus {
	OPEN,
	COMPLETED,
	FAILED,
}

enum CustomerState {
	OUTSIDE_WAITING,
	SEATED_WAITING,
	EATING,
	LEFT,
}

enum TableState {
	CLEAN_VACANT,
	OCCUPIED_WAITING,
	OCCUPIED_EATING,
	DIRTY,
}

enum DriverState {
	AT_PICKUP_SPOT,
	OUTSIDE_DRIVER_QUEUE,
}

enum FixtureKind {
	BOX,
	FRIDGE,
	STOVE,
	WASHER,
	PLATE_RACK,
	RICE_COOKER,
	DINING_TABLE,
}

enum PrepState {
	RAW,
	WASHED,
	COOKED_RICE,
	CHOPPED,
	COOKED,
	CHOPPED_AND_COOKED,
}

enum DayOutcome {
	UNDECIDED,
	WON,
	LOST,
}

enum EmployeeRole {
	COOK,
	CASHIER,
	WAITER,
}

enum EmployeeAnimState {
	IDLE,
	WALK,
	WORK,
	CLEAN,
	SERVE,
}
