CREATE REMOTE FUNCTION chat(input string, temperature float64) RETURNS string 
URL 'http://chat:5001/chat'
EXECUTION_TIMEOUT 60000;