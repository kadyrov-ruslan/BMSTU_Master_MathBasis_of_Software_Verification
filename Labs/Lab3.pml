/***************************************/
/* */
/* PROMELA Model of the */
/* DEEP-SPACE 1 Remote Agent Executive */
/* */
/* Klaus Havelund */
/* Mike Lowry */
/* John Penix */
/* */
/* NASA Ames Research Center */
/* */
/* August 5, 1997 */
/* */
/***************************************/
/*********************/
/* System Parameters */
/*********************/
#define NO_PROPS 2
#define NO_TASKS 3
#define NO_EVENTS 3
/*********************/
/* Boolean Constants */
/*********************/
#define false 0
#define true 1
/*********************/
/* EventId Constants */
/*********************/
#define MEMORY_EVENT 0
#define SNARF_EVENT 1

/*******************/
/* State Constants */
/*******************/
#define SUSPENDED 0 
#define RUNNING 1		
#define ABORTED 2		
#define TERMINATED 3	
/**************************/
/* Memory_Value Constants */
/**************************/
#define undef_value 0 
/**********************/
/* Type Abbreviations */
/**********************/
#define TaskId byte  
#define EventId byte  
#define State byte  
#define Memory_Property byte  
#define Memory_Value byte  
#define list chan 

#define task1_property_broken					\
	(property_locks[0].memory_value == 1 &	\
	property_locks[0].achieved &	\
	db[0] == 0)	\
	
#define task1_terminated						\
	(active_tasks[1].state == TERMINATED ||	\
	active_tasks[1].state == ABORTED)	\
	
#define success \
	(task1_property_broken -> <>task1_terminated) \

//ltl { []!success }

/********************/
/* Type Definitions */
/********************/
typedef Property{
	Memory_Property memory_property;
	Memory_Value memory_value};

typedef Lock{
	Memory_Value memory_value;
	list subscribers = [NO_TASKS] of {TaskId};
	bool achieved};

typedef Event{
	byte count;
	list pending_tasks = [NO_TASKS] of {TaskId}};

typedef Task{
	State state;
	list waiting_for = [NO_EVENTS] of {EventId};
	Property event_arg_test};

/********************************/
/* Global Variable Declarations */
/********************************/
Memory_Value db[NO_PROPS];
Lock property_locks[NO_PROPS];
Event Ev[NO_EVENTS];
Task active_tasks[NO_TASKS];
bool daemon_ready;

/*********************/
/* Lists as channels */
/*********************/

/* append(byte e; wr list[byte] x) */
#define append(e,x) x!e \
/* copy(list[byte] x; wr list[byte] y) */
#define copy(x,y)										\
	byte count;				\
	byte ce;				\
	count = len(x);				\
	do				\
	:: (count > 0) ->				\
		x?ce;				\
		x!ce;				\
		y!ce;				\
		count = count - 1				\
	:: (count == 0) -> break				\
	od				\

/* remove(byte e; wr list[byte] x) */
#define remove(e,x)								\
	assert(e <= 4);		\
	if		\
	:: e == 0 & x??[0] -> x??0		\
	:: e == 1 & x??[1] -> x??1		\
	:: e == 2 & x??[2] -> x??2		\
	:: e == 3 & x??[3] -> x??3		\
	:: e == 4 & x??[4] -> x??4		\
	:: else		\
	fi		\

/* next(list[byte] x; wr byte e) */
#define next(x,e) x?e

/* end lists as channels */

/*******************************************/
/* "Maintain_Properties_Daemon" Procedures */
/*******************************************/

/* wait_for_events(TaskId this; EventId a,b) */
#define wait_for_events(this,a,b)								\	
	atomic {	\
		append(this,Ev[a].pending_tasks);	\
		append(this,Ev[b].pending_tasks);	\
		append(a,active_tasks[this].waiting_for);	\
		append(b,active_tasks[this].waiting_for);	\
		active_tasks[this].state = SUSPENDED;	\
		daemon_ready = 1;	\
		active_tasks[this].state == RUNNING	\
}	\
/* wait_for_event_until(TaskId this; EventId a; Property p) */
#define wait_for_event_until(this,a,p)																				\							
	atomic {	\
		append(this,Ev[a].pending_tasks);	\
		append(a,active_tasks[this].waiting_for);	\
		active_tasks[this].event_arg_test.memory_property = p.memory_property;	\
		active_tasks[this].event_arg_test.memory_value = p.memory_value;	\
		active_tasks[this].state = SUSPENDED;	\
		active_tasks[this].state == RUNNING	\
	}	\

/* signal_event(EventId a) */
#define signal_event(a)																									\
	TaskId t;	\
	EventId e;	\
	list pending = [NO_EVENTS] of {EventId};	\
	Ev[a].count = Ev[a].count + 1;	\
	copy(Ev[a].pending_tasks,pending);	\
	do	\
	:: next(pending,t) ->	\
		if	\
		:: (active_tasks[t].event_arg_test.memory_value == undef_value ||	\
			db_query(active_tasks[t].event_arg_test) ) ->	\
			do	\
			:: next(active_tasks[t].waiting_for,e) ->	\
				remove(t,Ev[e].pending_tasks)	\
			:: empty(active_tasks[t].waiting_for) -> break	\
			od;	\
			active_tasks[t].state = RUNNING	\
		:: else	\
		fi	\
	:: empty(pending) -> break	\
	od	\

/* interrupt_task(TaskId t) */
#define interrupt_task(t)					\	
	active_tasks[t].state = ABORTED	\

/* lock_property_violated(Memory_Property mp; result bool lock_violation) */
#define lock_property_violated(mp,lock_violation)					\
	atomic{	\
		lock_violation =	\
			(property_locks[mp].memory_value != undef_value &	\
				property_locks[mp].achieved &	\
				db[mp] != property_locks[mp].memory_value)	\
	}	\

/* check_locks(result bool lock_violation) */
#define check_locks(lock_violation)													\
	Memory_Property mp;	\
	list sub = [NO_TASKS] of {TaskId};	\
	TaskId t;	\
	mp = 0;	\
	do	\
	:: mp < NO_PROPS ->	\
			lock_property_violated(mp,lock_violation);	\
			if	\
			:: lock_violation ->	\
				atomic{copy(property_locks[mp].subscribers,sub)};	\
				do	\
				:: next(sub,t) -> interrupt_task(t);	\
				:: empty(sub) -> break	\
				od	\
			:: else	\
			fi;	\
			mp++	\
	:: else -> break	\
	od;	\
	mp = 0;	\
	do	\
	:: mp < NO_PROPS ->	\
			lock_property_violated(mp,lock_violation);	\
			if	\
			:: lock_violation -> break	\
			:: else	\
			fi;	\
			mp++	\
	:: else -> break	\
	od	\

/* do_automatic_recovery() */
#define do_automatic_recovery																							\
	bool locks_consistent;	\
	byte lock_counter;	\
	do	\
	:: lock_counter = 0;	\
		locks_consistent = true;	\
		do	\
		:: lock_counter < NO_PROPS ->	\
		if	\
				:: property_locks[lock_counter].achieved ->	\
				locks_consistent =	\
				locks_consistent &&	\
				(property_locks[lock_counter].memory_value == db[lock_counter])	\
			:: else	\
		fi;	\
		lock_counter++	\
		:: else -> break	\
		od;	\
		if	\
			:: locks_consistent -> break	\
			:: else ->	\
			if	\
				:: property_locks[0].achieved &&	\
				!(property_locks[0].memory_value == db[0]) ->	\
				db[0] = property_locks[0].memory_value;	\
				:: property_locks[1].achieved &&	\
				!(property_locks[1].memory_value == db[1]) ->	\
				db[1] = property_locks[1].memory_value;	\
			fi	\
		fi	\
	od	\


/*******************************************/
/* "with_maintained_properties" Procedures */
/*******************************************/

/* db_query(Property p) */
#define db_query(p)													\
	db[p.memory_property] == p.memory_value		\

/* fail_if_incompatible_property(Property p; result bool err) */
#define fail_if_incompatible_property(p,err)															\
	if	\
		:: (property_locks[p.memory_property].memory_value != undef_value &	\
		property_locks[p.memory_property].memory_value != p.memory_value) ->	\
		err = 1	\
		:: else	\
	fi	\

/* snarf_property_lock(TaskId this; Property p; result bool err) */
#define snarf_property_lock(this,p,err)																		\
	atomic{	\
	fail_if_incompatible_property(p,err);	\
	append(this,property_locks[p.memory_property].subscribers);	\
	if	\
		:: property_locks[p.memory_property].memory_value == undef_value ->	\
		property_locks[p.memory_property].memory_value = p.memory_value;	\
		property_locks[p.memory_property].achieved = db_query(p)	\
		:: else	\
	fi;	\
	signal_event(SNARF_EVENT)	\
}	\


/* achieve(Property p; result bool err) */
#define achieve(p,err)														\
	if	\
		:: db_query(p)	\
		:: else ->	\
		if	\
			:: db[p.memory_property] = p.memory_value	\
			:: err = 1	\
		fi	\
	fi	\

/* find_owner(Property p; result TaskId owner) */
#define find_owner(p,owner)																			\
	if	\
		:: property_locks[p.memory_property].subscribers?[1] ->	\
		owner = 1	\
		:: property_locks[p.memory_property].subscribers?[2] ->	\
		owner = 2	\
		:: property_locks[p.memory_property].subscribers?[3] ->	\
		owner = 3	\
		:: property_locks[p.memory_property].subscribers?[4] ->	\
		owner = 4	\
	fi	\

/* achieve_lock_property(TaskId this; Property p; result bool err) */
#define achieve_lock_property(this,p,err)									\
	TaskId owner;	\
	find_owner(p,owner);	\
	if	\
	:: owner == this ->	\
			achieve(p,err);	\
			property_locks[p.memory_property].achieved = true	\
	:: else ->	\
			wait_for_event_until(this,MEMORY_EVENT,p);	\
	fi	\

/* release_lock(TaskId this; Property p) */
#define release_lock(this,p)																					\
	atomic{	\
		remove(this,property_locks[p.memory_property].subscribers);	\
		if	\
		:: empty(property_locks[p.memory_property].subscribers) ->	\
			property_locks[p.memory_property].memory_value = undef_value	\
		:: nempty(property_locks[p.memory_property].subscribers)	\
		fi	\
}	\

#define hang 0

/* closure() */
#define closure if :: true -> skip :: true -> hang fi

/* funcall_with_maintained_property(TaskId this; Property p; Closure c) */
#define funcall_with_maintained_property(this,p,c)		\
	bool err = 0;		\
	{		\
		snarf_property_lock(this,p,err);		\
		achieve_lock_property(this,p,err);		\
		c		\
	}		\
		\
		unless		\
	{err || active_tasks[this].state == ABORTED};		\
	active_tasks[this].state = TERMINATED;		\
	{release_lock(this,p)}		\
		unless		\
	{active_tasks[this].state == ABORTED}		\

/*****************/
/* Task Spawning */
/*****************/

/* spawn(Process(TaskId) task; TaskId t) */
#define spawn(task,t)										\
	atomic{	\
		active_tasks[t].state = RUNNING;	\
		run task(t)	\
	}	\

/*************/
/* Processes */
/*************/

proctype Environment()
{ atomic{
		db[0] = 0;
		signal_event(MEMORY_EVENT)
	}
};

proctype Maintain_Properties_Daemon(TaskId this){
	bit lock_violation;
	byte event_count = 0;
	bit first_time = true;
	do
	:: check_locks(lock_violation);
		if
		:: lock_violation ->
			do_automatic_recovery
		:: else
		fi;
		if
		:: (!first_time &&
			Ev[MEMORY_EVENT].count + Ev[SNARF_EVENT].count != event_count ) ->
			event_count = Ev[MEMORY_EVENT].count + Ev[SNARF_EVENT].count
		:: else ->
			first_time = false;
			wait_for_events(this,MEMORY_EVENT,SNARF_EVENT)
		fi
	od
};

proctype Achieving_Task(TaskId this)
{ Property p;
	p.memory_property = 0;
	if
	:: this == 1 -> p.memory_value = 1;
	:: this == 2 -> p.memory_value = 2
	fi;
	funcall_with_maintained_property(this,p,closure);
};


/******************/
/* Initialization */
/******************/
init
{
	spawn(Maintain_Properties_Daemon,0);
	daemon_ready == true;
	spawn(Achieving_Task,1);
	spawn(Achieving_Task,2);
	run Environment()
}