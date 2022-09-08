-module(test_port).

-export([run/0]).

run() ->
    % Port = erlang:open_port({spawn, "sh -s rabbit_disk_monitor 2>&1"}, [stream]),
    Args = ["-s", "rabbit_disk_monitor"],
    Port = erlang:open_port({spawn_executable, "/bin/sh"}, [stderr_to_stdout, stream, {args, Args}]),
    Df = find_cmd("df", "/bin"),
    F = fun(I) ->
                Result = my_cmd(Df ++ " -lk -x squashfs", Port),
                io:format("@@@@@@@@ RESULT ~w~n~n~p~n~n~n", [I, Result]),
                timer:sleep(1000)
        end,
    lists:foreach(F, lists:seq(0, 9)),
    erlang:port_close(Port).

my_cmd(Cmd0, Port) ->
    %% Insert a new line after the command, in case the command
    %% contains a comment character
    Cmd = io_lib:format("(~s\n) </dev/null; echo  \"\^M\"\n", [Cmd0]),
    Port ! {self(), {command, [Cmd, 10]}},
    get_reply(Port, []).

get_reply(Port, O) ->
    receive 
        {Port, {data, N}} -> 
            case newline(N, O) of
                {ok, Str} -> Str;
                {more, Acc} -> get_reply(Port, Acc)
            end;
        {'EXIT', Port, Reason} ->
            exit({port_died, Reason})
    end.

newline([13|_], B) ->
    {ok, lists:reverse(B)};
newline([H|T], B) ->
    newline(T, [H|B]);
newline([], B) ->
    {more, B}.

%%-- Looking for Cmd location ------------------------------------------
find_cmd(Cmd) ->
    os:find_executable(Cmd).

find_cmd(Cmd, Path) ->
    %% try to find it at the specific location
    case os:find_executable(Cmd, Path) of
        false ->
            find_cmd(Cmd);
        Found ->
            Found
    end.
