-- extracted messages
SELECT
  _tp_time as time, 
  _value:message_type as message_type, 
  _value:message_id as message_id, 
  _value:sender as sender, 
  _value:message_payload as message_payload, 
  _value:recipient as recipient
FROM
  autogen_runtime_500f7519_7afb_4db5_b09f_97d344974f56 -- replace with actual communication channel created every time
WHERE
  _tp_time > earliest_ts();

-- get all move actions
WITH messages AS
  (
    SELECT
      _tp_time AS time, _value:message_type AS message_type, _value:message_id AS message_id, _value:sender AS sender, _value:message_payload AS message_payload, _value:recipient AS recipient
    FROM
      autogen_runtime_500f7519_7afb_4db5_b09f_97d344974f56
    WHERE
      _tp_time > earliest_ts()
  )
SELECT
  sender, message_payload:_data:arguments:thinking as thinking, message_payload:_data:arguments:move as move
FROM
  messages
WHERE
  (message_type = 'send') AND message_payload:_class = 'FunctionCall' and message_payload:_data:name = 'make_move'

-- Hullucination detection - move twice for the same player
WITH messages AS
  (
    SELECT
      _tp_time AS time, _value:message_type AS message_type, _value:message_id AS message_id, _value:sender AS sender, _value:message_payload AS message_payload, _value:recipient AS recipient
    FROM
      autogen_runtime_500f7519_7afb_4db5_b09f_97d344974f56
    WHERE
      _tp_time > earliest_ts()
  ), moves AS
  (
    SELECT
      sender, json_value(json_value(json_value(message_payload, '$.`_data`'), '$.`arguments`'), '$.`thinking`') AS thinking, json_value(json_value(json_value(message_payload, '$.`_data`'), '$.`arguments`'), '$.`move`') AS move
    FROM
      messages
    WHERE
      (message_type = 'send') AND (json_value(message_payload, '$.`_class`') = 'FunctionCall') AND (json_value(json_value(message_payload, '$.`_data`'), '$.`name`') = 'make_move')
  )
SELECT
  sender as current_player, lag(sender) as previous_player
FROM
  moves
where current_player == previous_player

-- Hullucination detection - try to move twice for the same player
WITH messages AS
  (
    SELECT
      _tp_time AS time, _value:message_type AS message_type, _value:message_id AS message_id, _value:sender AS sender, _value:message_payload AS message_payload, _value:recipient AS recipient
    FROM
      autogen_runtime_500f7519_7afb_4db5_b09f_97d344974f56
    WHERE
      _tp_time > earliest_ts()
  ), try_moves AS
  (
    SELECT
      time, sender
    FROM
      messages
    WHERE
      (message_type = 'send') AND (json_value(message_payload, '$.`_class`') = 'FunctionCall') AND (json_value(json_value(message_payload, '$.`_data`'), '$.`name`') = 'get_legal_moves')
  )
SELECT
  time, sender as player, lag(sender) as previous_player
FROM
  try_moves
where player = previous_player

-- Hullucination detection - try invalid move

WITH messages AS
  (
    SELECT
      _tp_time AS time, _value:message_type AS message_type, _value:message_id AS message_id, _value:sender AS sender, _value:message_payload AS message_payload, _value:recipient AS recipient
    FROM
      autogen_runtime_500f7519_7afb_4db5_b09f_97d344974f56
    WHERE
      _tp_time > earliest_ts()
  ), function_calls AS
  (
    SELECT
      time, sender, message_payload, message_type
    FROM
      messages
    WHERE
      message_type in ('send', 'response') 
  ), consecutive_calls AS
  (
    SELECT
      time, sender, lag(sender) as previous_sender, message_payload, lag(message_payload) AS previous_payload, message_type
    FROM
      function_calls
  )
SELECT
  time, sender, previous_sender, message_payload:_data:arguments:move as move, previous_payload:_data:content as legal_moves, position(legal_moves, move) > 0 as legal
FROM
  consecutive_calls
WHERE
  json_value(json_value(message_payload, '$.`_data`'), '$.`name`') = 'make_move' and message_type = 'send' and previous_payload:_data:name = 'get_legal_moves' and not legal

