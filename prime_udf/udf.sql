CREATE FUNCTION is_prime_sql AS (n) ->
    n > 1 AND NOT array_exists(x -> n % x = 0, range(2, to_uint16(sqrt(n)) + 1));

CREATE OR REPLACE FUNCTION is_prime_js(n int)
RETURNS bool
LANGUAGE JAVASCRIPT AS $$
function is_prime_js(values) {
  return values.map(n => {
    if (n <= 1) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (i = 3; i <= Math.sqrt(n); i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  });
}
$$;

CREATE OR REPLACE FUNCTION is_prime_py(n int)
RETURNS bool
LANGUAGE PYTHON AS $$
def is_prime_py(col1):
  result = []
  for n in col1:
    if n <= 1:
      result.append(False)
    elif n == 2:
      result.append(True)
    elif n % 2 == 0:
      result.append(False)
    else:
      is_prime = True
      for i in range(3, int(n ** 0.5) + 1, 2):
        if n % i == 0:
          is_prime = False
          break
      result.append(is_prime)
  return result
$$;

SELECT is_prime_sql(7);
SELECT COUNT() FROM numbers(1,1000000) WHERE is_prime_sql(number);
SELECT COUNT() FROM numbers(1,1000000) WHERE is_prime_js(number);
SELECT COUNT() FROM numbers(1,1000000) WHERE is_prime_py(number);
