import "./styles.css";
import "bootstrap/dist/css/bootstrap.min.css";

import { useState } from "react";
import { Query, QueryBuilder, SetEnv } from "./api";
import { Stack, Button, Form, InputGroup } from "react-bootstrap";

export default function App() {
  const [env, setEnv] = useState({
    host: "http://localhost:8000",
    tenant: "local",
    username: "gang",
    password: "qwerty",
    target: "onprem",
  });

  const [querySQL, setQuerySQL] = useState(
    "SELECT * FROM mv_coinbase_tickers_extracted"
  );

  const [currentQuery, setCurrentQuery] = useState<Query>(null);
  const [queryResult, setQueryResult] = useState([]);

  const tableLimit = 10;
  const runQuery = async function () {
    if (currentQuery) {
      currentQuery.close();
    }

    SetEnv(env);
    let queryResultAll = [];
    const builder = new QueryBuilder();
    builder.withSQL(querySQL).withOnRows((rows) => {
      // handle real-time query result
      // keep all query resuslt history in a local variable
      queryResultAll = [...queryResultAll, ...rows];
      // set the display result to the latest 10 records
      // reverse the list to show latest result on top of table
      setQueryResult(queryResultAll.slice(-tableLimit).reverse());
    });

    const query = await builder.start();
    if (!(query instanceof Query)) {
      console.error("oops", query);
      return;
    }
    setCurrentQuery(query);
  };

  const cancelQuery = function () {
    if (currentQuery) {
      currentQuery.close();
    }
  };

  return (
    <div
      style={{ width: "100vh", margin: "auto", marginTop: 20, marginLeft: 20 }}
    >
      <h1>Timeplus Query API</h1>
      <Stack gap={1}>
        <InputGroup size="sm" className="mb-3">
          <InputGroup.Text id="inputGroup-address">Address</InputGroup.Text>
          <Form.Control
            aria-label="Small"
            aria-describedby="inputGroup-sizing-sm"
            defaultValue={env.host}
            onChange={(e) => setEnv({ ...env, host: e.target.value })}
          />
        </InputGroup>
        <InputGroup size="sm" className="mb-3">
          <InputGroup.Text id="inputGroup-tenant">Tenant</InputGroup.Text>
          <Form.Control
            aria-label="Small"
            aria-describedby="inputGroup-sizing-sm"
            defaultValue={env.tenant}
            onChange={(e) => setEnv({ ...env, tenant: e.target.value })}
          />
        </InputGroup>
        <InputGroup size="sm" className="mb-3">
          <InputGroup.Text id="inputGroup-apikey">API Key</InputGroup.Text>
          <Form.Control
            aria-label="Small"
            aria-describedby="inputGroup-sizing-sm"
            type="password"
            defaultValue={env.apiKey}
            onChange={(e) => setEnv({ ...env, apiKey: e.target.value })}
          />
        </InputGroup>
        <InputGroup size="sm" className="mb-3">
          <InputGroup.Text id="inputGroup-query">Query SQL</InputGroup.Text>
          <Form.Control
            aria-label="Small"
            aria-describedby="inputGroup-sizing-sm"
            defaultValue={querySQL}
            onChange={(e) => setQuerySQL(e.target.value)}
          />
        </InputGroup>
        <Stack direction="horizontal" gap={3}>
          <Button variant="primary" size="sm" onClick={(e) => runQuery()}>
            Run
          </Button>
          <Button variant="primary" size="sm" onClick={(e) => cancelQuery()}>
            Cancel
          </Button>
        </Stack>
        {/* render a live table here */}
        <table id="customers">
          {/* render table header using query.header */}
          <thead>
            <tr>
              {currentQuery &&
                currentQuery.header.map((e) => {
                  return <th>{e.name.toString()}</th>;
                })}
            </tr>
          </thead>
          {/* render live table content using state queryResult */}
          {queryResult.map((row) => {
            return (
              <tr>
                {row.map((cell) => {
                  return <td>{cell}</td>;
                })}
              </tr>
            );
          })}
        </table>
      </Stack>
    </div>
  );
}
