import type { Column as IColumn, Query as IQuery, TimeColumns as ITimeColumns, SQLAnalyzeResult } from './swagger';

import { createQueryV1beta2 as _createQuery } from './api';

export interface QueryMetrics {
  count: number;
  eps: number;
  processing_time: number;
  last_event_time: number;
  response_time: number;
  scanned_rows?: number;
  scanned_bytes?: number;
}

export interface LastModified {
  by: string;
  at: number;
}

export interface QueryOptions {
  tags?: string[];
}

export interface Message {
  data: string;
  event?: 'query' | 'metrics'
}

type Row = Array<any>;
type onRows = (rows: Array<Row>, header: Array<IColumn>, analysis: SQLAnalyzeResult) => void;
type onClose = (query: Query) => void;
type onError = (err: any) => void;
type onMetrics = (metrics: QueryMetrics) => void;

export type QueryStatus = 'running' | 'failed' | 'finished' | 'canceled';

/**
 * @example
 *
 * const builder = new QueryBuilder();
 * builder
 *   .withSQL('select * from wrongtable')
 *   .withOnRows((rows, header) => {
 *     console.log('received rows', rows, header);
 *   })
 *   .withOnError((err) => {
 *      console.log('error', err);
 *    })
 *    .withOnClose((query) => {
 *      console.log('closed', query);
 *    })
 *    .withOnMetrics((metrics) => {
 *      console.log('received metrics', metrics);
 *    });
 *
 *    // query status becomes `running` once the return value of `builder.start` is `Query` type
 *    const query = await builder.start();
 *
 *    if (query instanceof NeutronError) {
 *      console.log(query);
 *    } else {
 *      console.log('query start', query);
 *      setTimeout(() => {
 *        query.close();
 *      }, 25000);
 *    }
 */
export class QueryBuilder {
  #sql: string;
  #options: QueryOptions;
  #onError: onError;
  #onRows: onRows;
  #onMetrics: onMetrics;
  #onClose: onClose;

  constructor() {
    this.#sql = '';
    this.#options = {};
    this.#onRows = () => { };
    this.#onMetrics = () => { };
    this.#onClose = () => { };
    this.#onError = () => { };
  }

  /**
   * Make sure you've specified sql by calling `withSQL` before calling this function. Otherwise an exception will be thrown.
   * If a `Query` object is returned, its status becomes `running` until `onClose` callback is triggered.
   *
   * @returns the promise of query
   */
  start() {
    if (this.#sql === '') {
      throw 'Please specifing SQL before calling start';
    }

    return createQuery(this.#sql, this.#options, this.#onRows, this.#onClose, this.#onMetrics, this.#onError);
  }

  retry() {
    return createQuery(this.#sql, this.#options, this.#onRows, this.#onClose, this.#onMetrics, this.#onError);
  }

  /**
   * Make sure you call this function before calling `QueryBuilder.start`.
   *
   * @param sql the sql of the query
   */
  withSQL(sql: string) {
    this.#sql = sql;
    return this;
  }

  /**
   * Extra query options
   *
   * @param options the extra options to start the query
   */
  withOptions(options: QueryOptions) {
    this.#options = options;
    return this;
  }

  /**
   * @param onRows a callback function that will be triggered when new rows are received
   */
  withOnRows(onRows: onRows) {
    this.#onRows = onRows;
    return this;
  }

  /**
   * This callback will be fired only whenever the connection is terminated. There are multiple possibilities:
   * 1. The query is a table query and the server finishes sending all the data. The query `status` will be set to `finished`.
   * 2. The client calls `Query.close` to explictly close the connection. The query `status` will be set to `canceled`. Notice that the due to the limitation, only status of the query will be updated (e.g. endTime and any other field won't be updated).
   * 3. The query failes during runtime. The query `status` will be set to `failed` and the `message` will be set.
   *
   * @param onClose a callback function that will be triggered when the query connection is closed
   */
  withOnClose(onClose: onClose) {
    this.#onClose = onClose;
    return this;
  }

  /**
   * The error here is the runtime error. That means the query will still remain in running status and sending data back.
   *
   *  * For errors that will completely fail the query (e.g. Proton failure), the `onClose` callback will be fired instead of this.
   *    The only exception here is the TypeError: network error. It is technically should not cause a query to fail. But in current Neutron impl. it will.
   *  * For errors that preventing the query from running (e.g. table doesn't exist), the `QueryBuilder.start` will return them directly.
   *
   * @param onError a callback function that will be triggered when errors are received
   */
  withOnError(onError: onError) {
    this.#onError = onError;
    return this;
  }

  /**
   * The server will send the latest metrics every few seconds as long as the query is still running.
   *
   * @param onMetrics a callback function that will be triggered when metrics are received
   */
  withOnMetrics(onMetrics: onMetrics) {
    this.#onMetrics = onMetrics;
    return this;
  }
}

/**
 * Please be aware that the Query object IS mutable.
 */
export class Query {
  #raw: IQuery;
  #metrics: QueryMetrics | null;
  #ctrl: AbortController | null;

  constructor(payload: IQuery, ctrl: AbortController | null) {
    this.#raw = payload;
    this.#metrics = null;
    this.#ctrl = ctrl;
  }

  get id(): string {
    return this.#raw.id;
  }

  get startTime(): number {
    return this.#raw.start_time;
  }

  get endTime(): number {
    return this.#raw.end_time;
  }

  get header(): Array<IColumn> {
    return this.#raw.result.header;
  }
  get analysis(): SQLAnalyzeResult {
    return this.#raw.analysis;
  }

  get sql(): string {
    return this.#raw.sql;
  }

  get tags(): string[] {
    if (!this.#raw.tags) {
      return [];
    }

    return this.#raw.tags;
  }

  get timeColumns(): ITimeColumns {
    return this.#raw.timeColumns;
  }

  get status(): QueryStatus {
    return this.#raw.status as QueryStatus;
  }

  set status(s: QueryStatus) {
    this.#raw.status = s;
  }

  get error(): string {
    return this.#raw.message;
  }

  get metrics(): QueryMetrics | null {
    return this.#metrics;
  }

  get lastModified(): LastModified {
    let at = 0;
    if (this.#raw.last_updated_at) {
      at = new Date(this.#raw.last_updated_at + 'Z').getTime();
    }

    return {
      by: this.#raw.last_updated_by.name,
      at: at,
    };
  }

  update(payload: IQuery) {
    this.#raw = payload;
  }

  updateMetrics(payload: QueryMetrics) {
    this.#metrics = payload;
  }

  close() {
    if (!this.#ctrl || this.#ctrl.signal.aborted) {
      return;
    }

    this.#ctrl.abort();
  }
}

/**
 * Not exposing this since the client should use `QueryBuilder` instead.
 */
const createQuery = async (
  sql: string,
  options: QueryOptions,
  onRows: onRows,
  onClose: onClose,
  onMetrics: onMetrics,
  onError: onError
): Promise<Query> => {
  const result = new Promise<Query | any>((resolve) => {
    const ctrl = new AbortController();

    let query: Query | null = null;

    const onmessage = (msg: Message) => {
      let payload = null;
      try {
        payload = JSON.parse(msg.data);
      } catch (err: any) {
        return onError(err);
      }

      if (msg.event === 'query') {
        // init
        if (!query) {
          query = new Query(payload, ctrl);
          resolve(query);
        } else {
          // This is supposed to be the latest event inside SSE channel.
          // `onclose` will be triggered after this.
          query.update(payload);
        }

        return;
      }

      // Shall never happen
      if (!query) {
        console.error('received other events before query');
        return;
      }

      if (msg.event === 'metrics') {
        query.updateMetrics(payload);

        onMetrics(payload);
        return;
      }

      onRows(payload, query.header, query.analysis);
    };

    const onerror = (err: any) => {
      if (!query) {
        resolve(err);
        return;
      }

      return onError(err);
    };

    const onclose = () => {
      // Is it possible?
      if (!query) {
        return;
      }

      onClose(query);
    };

    ctrl.signal.addEventListener('abort', () => {
      if (!query) {
        return;
      }

      // TODO: Fetch latest status from get endpoint. The current issue here is that when getting the query, the backend may not finish persisting the status yet,
      // in that case, the query will still be in `running` status. We will have to keep polling the query until
      // the status is updated to `canceled`

      // TODO: Update to use query v2 get

      // const { body } = await getQuery(query.id);
      // query.update(body);

      query.status = 'canceled';
      onClose(query);
    });

    _createQuery(
      {
        sql,
        ...options,
      },
      {
        onmessage,
        onclose,
        onerror,
        signal: ctrl.signal,
      }
    ).catch((error) => {
      onError(error);
    });
  });

  return result;
};
