include "alldifferent.mzn";
include "cumulative.mzn";


%%% Model Parameters and Decision Variables %%%

int: noc = 3;
int: process_time = 1;
int: consume_time = 0; % assume no delay between consuming and producing tokens
int: max_time = 10;
var 1..max_time: makespan;
enum actors = {a1, a2, a3}; % use dzn file
enum messages = {m1, m2, m3,m4,m5}; % dzn - symbolic execution wp for sdf
enum messages_with_null = C(messages) ++ {Null};
array[messages] of int: dependencies = [0,1,2,3,4]; % dzn
array[messages] of int: src = [1,2,3,3,3]; % dzn
array[messages] of int: dst = [2,3,1,1,1]; % dzn
int: tdma_max = 2; % dzn
array[1..9, 1..9] of int: tdma_table = array2d(1..9, 1..9, 
      [1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,1]
); % dzn
array[messages, 1..max_time] of var 0..1: route_n;
array[messages, 1..max_time] of var 0..1: route_s;
array[messages, 1..max_time] of var 0..1: route_e;
array[messages, 1..max_time] of var 0..1: route_w;
array[messages] of var 1..max_time: starts;
array[messages] of var 1..max_time: ends;
array[actors] of var 1..noc: mapx;
array[actors] of var 1..noc: mapy;
function var int: mapping(var int: x, var int: y) = (y-1)*noc + x;
function actors: source(messages: m) = actors[src[m]];
function actors: dest(messages: m) = actors[dst[m]];

%%% Defining relationships using constraints %%%

% Firing Time
constraint forall (m in messages)(
  starts[m] = min(t in 1..max_time where route_n[m,t]+route_s[m,t]+route_e[m,t]+route_w[m,t] > 0)(t)
);

% Ending Time
constraint forall (m in messages)(
  ends[m] = max(t in 1..max_time where route_n[m,t]+route_s[m,t]+route_e[m,t]+route_w[m,t] > 0)(t)
);


%%% Model Constraints %%%

% 1. Each actor a unique mapping
constraint alldifferent([mapping(mapx[a],mapy[a]) | a in actors]);

% 2. Messages must reach destination
constraint forall(m in messages)(
  sum([route_s[m,t] - route_n[m,t] | t in 1..max_time]) = mapy[dest(m)] - mapy[source(m)]
);
constraint forall(m in messages)(
  sum([route_e[m,t] - route_w[m,t] | t in 1..max_time]) = mapx[dest(m)] - mapx[source(m)]
);

% 3. Messages stay in range of NoC
constraint forall(m in messages)(
  forall(curr_t in 1..max_time)(
    sum([route_s[m,t] - route_n[m,t] | t in 1..curr_t]) + mapy[source(m)] > 0 /\ sum([route_s[m,t] - route_n[m,t] | t in 1..curr_t]) + mapy[source(m)] <= noc
  )
);
constraint forall(m in messages)(
  forall(curr_t in 1..max_time)(
    sum([route_e[m,t] - route_w[m,t] | t in 1..curr_t]) + mapx[source(m)] > 0 /\ sum([route_e[m,t] - route_w[m,t] | t in 1..curr_t]) + mapx[source(m)] <= noc 
  )
);

% 4. Schedule makespan is the largest end 
constraint forall (m in messages)(
  makespan >= ends[m]
);

% 5. Messages only move in one direction
constraint forall (m in messages)(
  forall (t in 1..max_time)(
    route_n[m,t]+route_s[m,t]+route_e[m,t]+route_w[m,t] <= 1
  )
);

% 6. Bufferless NoC
constraint forall (m in messages)(
  forall (t in 1..max_time)(
    forall(t1 in 1..max_time where t1 > t)(
      forall(t2 in 1..max_time where t2 > t1)(
        route_n[m,t]+route_s[m,t]+route_e[m,t]+route_w[m,t] - route_n[m,t1]+route_s[m,t1]+route_e[m,t1]+route_w[m,t1] + route_n[m,t2]+route_s[m,t2]+route_e[m,t2]+route_w[m,t2] <= 1
      )
    )
  )
);

% 7. Each actor may send at most one message for each time
constraint forall (a in actors)(
  alldifferent([starts[m] | m in messages where source(m) = a])
);

% 8. Messages are sent either after the end of previous messages using the same actor or after the start of non-related actors
constraint forall (m in messages)(
  starts[m] > if dependencies[m] > 0 then ends[messages[dependencies[m]]]+consume_time else 1 endif % >1 to account for pe->router time, > end+delay to account for router->pe time
);

% 9. Firing time follows TDMA
constraint forall (m in messages)(
  (starts[m]-1) mod tdma_max = tdma_table[mapping(mapx[source(m)],mapy[source(m)]), mapping(mapx[dest(m)],mapy[dest(m)])]
);


% 10. No Collision on NoC structure
constraint forall (t in 1..max_time-1)(
  forall (m_prev in messages)(
    forall (m_next in messages where m_next > m_prev)(
      route_n[m_prev, t+1]+route_n[m_next, t+1] < if
      mapping(mapx[source(m_prev)] + route_e[m_prev,t] - route_w[m_prev,t], mapy[source(m_prev)] + route_s[m_prev,t] - route_n[m_prev,t]) = mapping(mapx[source(m_next)] + route_e[m_next,t] - route_w[m_next,t], mapy[source(m_next)] + route_s[m_next,t] - route_n[m_next,t])
      then 2
      else 3
      endif
    )
  )
);
constraint forall (t in 1..max_time-1)(
  forall (m_prev in messages)(
    forall (m_next in messages where m_next > m_prev)(
      route_s[m_prev, t+1]+route_s[m_next, t+1] < if
      mapping(mapx[source(m_prev)] + route_e[m_prev,t] - route_w[m_prev,t], mapy[source(m_prev)] + route_s[m_prev,t] - route_n[m_prev,t]) = mapping(mapx[source(m_next)] + route_e[m_next,t] - route_w[m_next,t], mapy[source(m_next)] + route_s[m_next,t] - route_n[m_next,t])
      then 2
      else 3
      endif
    )
  )
);
constraint forall (t in 1..max_time-1)(
  forall (m_prev in messages)(
    forall (m_next in messages where m_next > m_prev)(
      route_e[m_prev, t+1]+route_e[m_next, t+1] < if
      mapping(mapx[source(m_prev)] + route_e[m_prev,t] - route_w[m_prev,t], mapy[source(m_prev)] + route_s[m_prev,t] - route_n[m_prev,t]) = mapping(mapx[source(m_next)] + route_e[m_next,t] - route_w[m_next,t], mapy[source(m_next)] + route_s[m_next,t] - route_n[m_next,t])
      then 2
      else 3
      endif
    )
  )
);
constraint forall (t in 1..max_time-1)(
  forall (m_prev in messages)(
    forall (m_next in messages where m_next > m_prev)(
      route_w[m_prev, t+1]+route_w[m_next, t+1] < if
      mapping(mapx[source(m_prev)] + route_e[m_prev,t] - route_w[m_prev,t], mapy[source(m_prev)] + route_s[m_prev,t] - route_n[m_prev,t]) = mapping(mapx[source(m_next)] + route_e[m_next,t] - route_w[m_next,t], mapy[source(m_next)] + route_s[m_next,t] - route_n[m_next,t])
      then 2
      else 3
      endif
    )
  )
);

%%% Objective %%%
solve minimize makespan;