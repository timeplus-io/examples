/* eslint-disable */
/* tslint:disable */
/*
 * ---------------------------------------------------------------
 * ## THIS FILE WAS GENERATED VIA SWAGGER-TYPESCRIPT-API        ##
 * ##                                                           ##
 * ## AUTHOR: acacode                                           ##
 * ## SOURCE: https://github.com/acacode/swagger-typescript-api ##
 * ---------------------------------------------------------------
 */

export interface APIKey {
  /**
   * creation time represented as the number of seconds elapsed since January 1, 1970 UTC
   * @example 1257894000
   */
  created_at?: number;

  /**
   * expiration time represented as the number of seconds elapsed since January 1, 1970 UTC
   * @example 1257894000
   */
  expire_at?: number;

  /** a string that identifies an API key, readonly. */
  id?: string;

  /** the name of the API key */
  name?: string;

  /**
   * list of permissions associated with the API key
   * @example ["read:query","write:query"]
   */
  permissions?: string[];
}

export interface AnalyzeSQLRequest {
  sql?: string;
}

export interface BatchingPolicy {
  /** The max result count per batch */
  count?: number;

  /** The max interval per batch in milliseconds */
  time_ms?: number;
}

export interface Column {
  name?: string;
  type?: string;
}

export interface ColumnDef {
  compression_codec?: string;
  default?: string;
  name: string;
  skipping_index_expression?: string;
  ttl_expression?: string;
  type: string;
}

export interface ColumnsResp {
  default?: string;

  /** @example value */
  name?: string;
  nullable?: boolean;

  /** @example int64 */
  type?: string;
}

export interface Connection {
  config?: ConnectionConfig;
  stat: ConnectionStat;
}

export interface ConnectionConfig {
  auto_create?: boolean;
  stream_definition?: StreamDef;
}

export interface ConnectionStat {
  message: string;
  status: string;
}

export interface CreateAPIKeyRequest {
  /**
   * define the expiration time of the API key by specifying the exact date time,
   * cannot use with expire_in
   * @format RFC3339
   * @example 2022-06-07T12:00:00Z08:00
   */
  expire_at?: string;

  /**
   * define the expiration time of the API key by specifying the amount of time to count from now,
   * cannot use with expire_at
   * @example 24h
   */
  expire_in?: string;

  /** the name of the API key */
  name: string;
}

export interface CreateAPIKeyResponse {
  /**
   * generated API key. API keys are treated as secrets and are not stored in the system.
   * It is the users' responsibility to safely store the API key for future use.
   * @example vthm5o5ENm4TaX5RcixG+DB8q9ALQtrU3VlfQBVFv1lQauWeDXR87MI5kOjXG
   */
  api_key?: string;

  /**
   * creation time represented as the number of seconds elapsed since January 1, 1970 UTC
   * @example 1257894000
   */
  created_at?: number;

  /**
   * expiration time represented as the number of seconds elapsed since January 1, 1970 UTC
   * @example 1257894000
   */
  expire_at?: number;

  /** a string that identifies an API key, readonly. */
  id?: string;

  /** the name of the API key */
  name?: string;

  /**
   * list of permissions associated with the API key
   * @example ["read:query","write:query"]
   */
  permissions?: string[];
}

export interface CreateDashboardRequest {
  description?: string;
  name: string;
  panels?: DashboardPanel[];
}

export interface CreateQueryRequestV1Beta2 {
  /** Controls how often a batch of results will be flushed via SSE channel */
  batching_policy?: BatchingPolicy;
  description?: string;
  name?: string;
  sql: string;
  tags?: string[];
}

export interface CreateQueryResponse {
  analysis: SQLAnalyzeResult;

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description?: string;
  duration: number;
  end_time: number;
  id: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  message: string;
  name?: string;
  response_time: number;
  result: QueryResult;
  sinks: Record<string, SinkStat>;
  sql: string;
  start_time: number;
  status: string;
  tags?: string[];
  timeColumns: TimeColumns;
}

export interface CreateSinkRequest {
  description?: string;
  name: string;
  properties?: Record<string, any>;
  sql: string;
  type: string;
}

export interface CreateSourceRequest {
  connection_config?: ConnectionConfig;
  description?: string;
  name: string;
  properties?: Record<string, any>;
  type: string;
}

export interface CreateViewRequest {
  /** @example the description of my_test_stream */
  description?: string;
  materialized?: boolean;

  /** @example my_test_stream */
  name: string;

  /** @example select * from devops */
  query: string;

  /**
   * This option is applicable only when `materialized` is `true`. Specify this when you want to have multiple
   * materialized views sink to the same target stream.
   */
  target_stream?: string;
}

export interface Edge {
  source?: string;
  target?: string;
}

export interface ErrorResponse {
  code?: number;
  message?: string;
}

export type Event = Record<string, any>;

export interface EventInferRequest {
  event?: Event;
}

export interface EventInferResponse {
  inferred_columns?: ColumnDef[];
  recommeneded_columns?: ColumnDef[];
}

export interface ExternalStreamDef {
  column?: ColumnDef;
  description?: string;
  name?: string;
  settings?: StreamSetting[];
}

export interface FileUploadResponse {
  path?: string;
}

export interface FormatQueryRequest {
  sql?: string;
}

export interface FormatQueryResponse {
  sql?: string;
}

export interface GlobalMetricsResult {
  sink_throughput: number;
  source_throughput: number;
  storage: number;
}

export interface Graph {
  edges?: Edge[];
  nodes?: Node[];
}

export interface IngestData {
  columns?: string[];
  data?: any[][];
}

export interface Node {
  id?: string;
  name?: string;
  ownership?: Owner;
  properties?: Record<string, any>;
  type?: string;
}

export interface Owner {
  /** @example bob-id */
  id: string;

  /** @example Bob */
  name: string;
}

export interface Query {
  analysis: SQLAnalyzeResult;

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description?: string;
  duration: number;
  end_time: number;
  id: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by: Owner;
  message: string;
  name?: string;
  response_time: number;
  result: QueryResult;
  sinks: Record<string, SinkStat>;
  sql: string;
  start_time: number;
  status: string;
  tags?: string[];
  timeColumns: TimeColumns;
}

export interface QueryPipeline {
  edges?: QueryPipelineEdge[];
  nodes?: QueryPipelineNode[];
}

export interface QueryPipelineEdge {
  from?: number;
  to?: number;
}

export interface QueryPipelineNode {
  id?: number;
  metric?: QueryPipelineNodeMetric;
  name?: string;
  status?: string;
}

export interface QueryPipelineNodeMetric {
  processed_bytes?: number;
  processing_time_ns?: number;
}

export interface QueryResult {
  data?: any[][];
  header: Column[];
}

export interface ResourceMetricsRequest {
  metricsNames?: string[];
  metricsTypes?: string[];
  resourceIds?: string[];
  timeRange?: number;
}

export interface ResourceMetricsResult {
  id: string;
  metrics_name: string;
  metrics_type: string;
  time: string;
  value: number;
}

export interface SQLAnalyzeColumn {
  column?: string;
  column_type?: string;
  database?: string;
  is_view?: boolean;
  table?: string;
}

export interface SQLAnalyzeResult {
  group_by_columns?: string[];
  has_aggr?: boolean;
  has_subquery?: boolean;
  has_table_join?: boolean;
  has_union?: boolean;
  is_streaming?: boolean;
  original_query?: string;
  query_type?: string;
  required_columns?: SQLAnalyzeColumn[];
  result_columns?: SQLAnalyzeColumn[];
  rewritten_query?: string;
}

export interface Sink {
  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description: string;
  id: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  name: string;
  properties: Record<string, any>;
  queries: string[];
  query?: Query;
  type: string;
}

export interface SinkStat {
  failure_count?: number;
  success_count?: number;
}

export interface Source {
  connection: Connection;

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description: string;
  id: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  name: string;
  properties: Record<string, any>;
  start_time: number;
  type: string;
}

export interface SourcePreviewRequest {
  properties?: Record<string, any>;
  size?: number;
  type?: string;
}

export interface Stream {
  columns: ColumnsResp[];

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;

  /** @example my test stream */
  description: string;

  /** @example Stream */
  engine: string;

  /** @example false */
  is_external: boolean;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;

  /** @example 1073741824 */
  logstore_retention_bytes: number;

  /** @example 86400000 */
  logstore_retention_ms: number;

  /** @example test_stream */
  name: string;

  /**
   * ORDER_BY     string        `json:"order_by_expression"`
   * PATTITION_BY string        `json:"partition_by_expression"`
   * @example to_datetime(_tp_time) + INTERVAL 7 DAY
   */
  ttl: string;
}

export interface StreamDef {
  columns?: ColumnDef[];
  description?: string;
  event_time_column?: string;
  event_time_timezone?: string;
  logstore_retention_bytes?: number;
  logstore_retention_ms?: number;
  mode?: string;

  /**
   * Stream name should only contain a maximum of 64 letters, numbers, or _, and start with a letter
   * @example test_stream
   */
  name: string;
  order_by_expression?: string;
  order_by_granularity?: string;
  partition_by_granularity?: string;
  primary_key?: string;
  replication_factor?: number;
  shards?: number;
  ttl_expression?: string;
}

export interface StreamMatchRequest {
  events?: Event[];
}

export interface StreamSetting {
  key?: string;
  value?: string;
}

export interface StreamStats {
  /** @example 2023-02-01T01:02:03.456Z */
  earliest_event?: string;

  /** @example 234567 */
  historical_data_bytes?: number;

  /** @example 2023-02-13T07:08:09.012Z */
  latest_event?: string;

  /** @example 20 */
  row_count?: number;

  /** @example 12345 */
  streaming_data_bytes?: number;
}

export interface TimeColumns {
  eventTime: number;
  windowEnd: number;
  windowStart: number;
}

export interface UDF {
  /**
   * The input argument of the UDF
   *   * For UDA: the number and type of arguments should be consistent with the main function of UDA.
   *     the type should be the data types of proton not javascript types. It only supports int8/16/32/64, uint8/16/32/64,
   */
  arguments?: UDFArgument[];
  auth_context?: UDFAuthContext;
  auth_method?: string;

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description?: string;

  /** Whether it is an aggregation function. Only valid when type is 'javascript' */
  is_aggregation?: boolean;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  name?: string;

  /**
   * The erturn type of the UDF
   *   * For UDA: if it returns a single value, the return type is the corresponding data type of Timeplus.
   *     It supports the same types of input arguments, except for datetime, it only supports DateTime64(3).
   */
  return_type?: string;

  /**
   * The source code of the UDA. There are functions to be defined:
   *  * main function: with the same name as UDA. Timeplus calls this function for each input row. The main function can return two types of result: object or simple data type
   *    - If it returns an object, the object is like {“emit”: true, “result”: …}. ‘Emit’ (boolean) property tells Timeplus whether or not the result should emit. ‘result’ is the current aggregate result, if ‘emit’ is false, the result will be ignored by Timeplus. Timeplus will convert the ‘result’ property of v8 to the data types defined when creating UDA.
   *    - If it returns a simple data type, Timeplus considers the return data as the result to be emitted immediately. It converts the return data to the corresponding data type and Timeplus emits the aggregating result.
   *    - Once UDA tells Timeplus to emit the data, UDA takes the full responsibility to clear the internal state, prepare and restart a new aggregating window, et al.
   *  * state function: which returns the serialized state of all internal states of UDA in string. The UDA takes the responsibility therefore Timeplus can choose to persist the internal state of UDA for query recovery.
   *  * init function: the input of this function is the string of serialized state of the internal states UDA. Timeplus calls this function when it wants to recover the aggregation function with the persisted internal state.
   */
  source?: string;

  /** Either `javascript` or `remote` */
  type?: string;
  url?: string;
}

export interface UDFArgument {
  name?: string;
  type?: string;
}

export interface UDFAuthContext {
  key_name?: string;
  key_value?: string;
}

export interface UpdateDashboardRequest {
  description?: string;
  name: string;
  panels?: DashboardPanel[];
}

export interface UpdateSourceRequest {
  connection_config?: ConnectionConfig;
  description?: string;
  name?: string;
  properties?: Record<string, any>;
}

export interface UpdateStreamRequest {
  description?: string;
  logstore_retention_bytes?: number;
  logstore_retention_ms?: number;
  ttl_expression?: string;
}

export interface UpdateViewRequest {
  description?: string;
  logstore_retention_bytes?: number;
  logstore_retention_ms?: number;
  query?: string;
  ttl_expression?: string;
}

export interface View {
  columns: ColumnsResp[];

  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description?: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  logstore_retention_bytes: number;
  logstore_retention_ms: number;
  materialized?: boolean;
  name?: string;
  query?: string;
  target_stream?: string;
  ttl: string;
}

export interface DashboardDashboard {
  /** @example 2023-02-01 23:22:59 */
  created_at?: string;
  created_by?: Owner;
  description: string;
  id: string;

  /** @example 2023-02-05 11:12:13 */
  last_updated_at?: string;
  last_updated_by?: Owner;
  name: string;
  panels: DashboardPanel[];
}

export interface DashboardPanel {
  description?: string;
  id?: string;

  /** e.g. {"x":0,"y":0,"w":6,"h":2,"nextX":6,"nextY":2} */
  position?: Record<string, any>;
  title?: string;

  /**
   * The JSON configuration of the viz
   * For chart, it is `{ "chart_type": "line", ...  }`
   * For markdown, it is `{ "favour": "github", ...  }`
   */
  viz_config?: Record<string, any>;

  /**
   * For chart, the viz_content is the SQL
   * For markdown, the viz_content is the markdown itself
   */
  viz_content?: string;

  /** e.g. `chart`, `markdown` */
  viz_type?: string;
}
