CREATE OR REPLACE FUNCTION python_version(s string) RETURNS string LANGUAGE PYTHON AS $$
import sys
import ssl
def python_version(arg):
    result = []
    for i in arg:
        result.append(sys.version + ":" + ssl.OPENSSL_VERSION)
 
    return result
$$;