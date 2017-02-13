-module(test_message_ordering).

-export([
	test_best_case/2,
	test_worst_case/2
]).

-record(task, {
	id,
	latency = 0,
	elapsed_time = 0,
	finished = false :: boolean()
}).

-define(WORKER_CAPABILITY, 10).

generate_best_case(N, K) ->	
	lists:flatmap(fun(I) -> generate_best_case_messages(I, K) end, lists:seq(1, N)).	

generate_best_case_messages(N, K) ->
	SessionName = "session" ++ integer_to_list(N),
	InitialMsg = {SessionName, initial},
        OtherMessages = [{SessionName, X} || X <- lists:seq(1, K)],
	[InitialMsg | OtherMessages].	

generate_worst_case(N, K) ->
	generate_worst_case_initial_messages(N) ++
		generate_worst_case_reply_messages(N, K).

generate_worst_case_initial_messages(N) ->
	[{"session" ++ integer_to_list(X), initial} || X <- lists:seq(1, N)].

generate_worst_case_reply_messages(N, K) ->
	GenerateFun = fun (X) ->
		SessionName = "session" ++ integer_to_list(X),
		[{SessionName, Y} || Y <- lists:seq(1, K)]
	end,
	lists:flatmap(GenerateFun, lists:seq(1, N)).

test_best_case(N, K) ->
	Messages = generate_best_case(N, K),
	process(Messages, K).

test_worst_case(N, K) ->
	Messages = generate_worst_case(N, K),
	process(Messages, K).

process(Messages, K) ->
	process(Messages, K, maps:new()).

%% Инициирующее сообщение
process([], _K, Tasks) ->
	ResultList = maps:to_list(Tasks),
	ElapsedTimeList = [E || {_, #task{elapsed_time = E}} <- ResultList],
	LatencyList = [L || {_, #task{latency = L}} <- ResultList],
	[{min_elapsed, lists:min(ElapsedTimeList)}, {max_elapsed, lists:max(ElapsedTimeList)}, {min_latency, lists:min(LatencyList)}, {max_latency, lists:max(LatencyList)}, {result, ResultList}];
process([{SessionId, initial} | Tail], K, Tasks) ->
	ElapcedTime = ?WORKER_CAPABILITY,
       	Task = #task{id = SessionId, elapsed_time = ElapcedTime},
	Tasks2 = maps:put(SessionId, Task, Tasks),
        Tasks3 = waste_time(ElapcedTime, Tasks2),
	process(Tail, K, Tasks3);
process([{SessionId, I} | Tail], K, Tasks) ->
	ElapsedTimeToAdd = ?WORKER_CAPABILITY,
	Finished = I == K,
	Task = #task{elapsed_time = ElapsedTime} = maps:get(SessionId, Tasks),
	Tasks2 = maps:put(SessionId, Task#task{elapsed_time = ElapsedTime + ElapsedTimeToAdd, finished = Finished}, Tasks),
	Tasks3 = waste_time(ElapsedTimeToAdd, Tasks2),
	process(Tail, K, Tasks3).

waste_time(TimeToWaste, Tasks) ->
	WasteFun = fun 
			(_, T = #task{latency = X, finished = false}) -> 
				T#task{latency = X + TimeToWaste};
			(_, T) ->
				T
	           end,
	maps:map(WasteFun, Tasks).
