CREATE EXTERNAL STREAM input(raw string)
SETTINGS type='kafka', brokers='kafka:19092',topic='input-topic';

CREATE EXTERNAL STREAM primes(raw string,_tp_message_key string default raw)
SETTINGS type='kafka', brokers='kafka:19092',topic='primes';

CREATE EXTERNAL STREAM composites(raw string,_tp_message_key string default raw)
SETTINGS type='kafka', brokers='kafka:19092',topic='composites';

CREATE EXTERNAL STREAM dlq(raw string)
SETTINGS type='kafka', brokers='kafka:19092',topic='dlq';

CREATE FUNCTION is_prime(values int8)
RETURNS bool
LANGUAGE JAVASCRIPT AS $$
    function _check_prime(num, limit){
        for (let start = 3; start <= limit; start += 2) {
            if (0 === num % start) {
                return false;
            }
        }
        return num > 1;
    };
    function is_prime(values) {
        var bools=[]
        for(let i=0;i<values.length;i++) {
            var number=values[i];
            bools.push(number === 2 || number % 2 !== 0 && _check_prime(number, Math.sqrt(number)));
        }
        return bools;
    }
$$;

CREATE MATERIALIZED VIEW mv_dlq INTO dlq AS
SELECT raw FROM input WHERE _tp_time>earliest_ts() AND to_int8_or_zero(raw)=0;

CREATE MATERIALIZED VIEW mv_prime INTO primes AS
SELECT raw FROM input WHERE _tp_time>earliest_ts() AND to_int8_or_zero(raw)>0 AND is_prime(to_int8_or_zero(raw));

CREATE MATERIALIZED VIEW mv_not_prime INTO composites AS
SELECT raw FROM input WHERE _tp_time>earliest_ts() AND to_int8_or_zero(raw)>0 AND NOT is_prime(to_int8_or_zero(raw));
