//const uda = require('./execute_v1');
const uda = require('./update');
const MarketSimulator = require('./market_simulator');

function transposeArray(matrix) {
  return matrix[0].map((col, i) => matrix.map((row) => row[i]));
}

uda.initialize();

const marketSimulator = new MarketSimulator('AAPL');
const test_data = marketSimulator.simulateMarket(500, 10000); 

start = new Date().getTime();
count = 0;
test_data.forEach((data) => {
  const rows = transposeArray(data);
  const process_start_time = new Date().getTime()
  if (uda.process(...rows) > 0) {
    const process_end_time = new Date().getTime()
    const emit = uda.finalize();
    console.log('emit ' + emit.length);
    const emit_throughput = (emit.length / (process_end_time - process_start_time)) * 1000;
    console.log('emit throughput ' + emit_throughput);

    count += emit.length
  }
});

end = new Date().getTime();
elapsed = end - start

console.log('emit count ' + count);
console.log('time spend ' + elapsed);
console.log('e2e eps ' + count / (elapsed / 1000) );
