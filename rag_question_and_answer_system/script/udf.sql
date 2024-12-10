CREATE REMOTE FUNCTION embedding(input string) RETURNS string 
URL 'http://embedding:5001/embedding'
EXECUTION_TIMEOUT 60000;