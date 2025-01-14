const uda = require('./update');

// data -> Time, OrderId, Symbol, Side, OrderQty, OrderType, Price
const batches = [
  [
    [new Date().getTime(), "o1", "A", "buy", 200, "LIMIT", 1.0],
    [new Date().getTime(), "o2", "A", "sell", 100, "LIMIT", 1.0],
    [new Date().getTime(), "o3", "A", "buy", 200, "LIMIT", 1.0],
    [new Date().getTime(), "o4", "A", "sell", 200, "LIMIT", 1.0],
  ],
  [
    [new Date().getTime(), "o5", "A", "buy", 200, "LIMIT", 1.0],
    [new Date().getTime(), "o6", "A", "sell", 100, "LIMIT", 1.0],
    [new Date().getTime(), "o7", "A", "buy", 200, "LIMIT", 1.0],
    [new Date().getTime(), "o8", "A", "sell", 200, "LIMIT", 1.0],
  ],
];

const targets = [
  [
    { "OrderId": "o1", "Symbol": "A", "Side": "buy", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Pending", "FilledQty": 0, "AvailableQty": 200 },
    { "OrderId": "o2", "Symbol": "A", "Side": "sell", "OrderQty": 100, "OrderType": "LIMIT", "Price": 1, "Status": "Pending", "FilledQty": 0, "AvailableQty": 100 },
    { "OrderId": "o1", "Symbol": "A", "Side": "buy", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Partially Filled", "FilledQty": 100, "AvailableQty": 100 },
    { "OrderId": "o2", "Symbol": "A", "Side": "sell", "OrderQty": 100, "OrderType": "LIMIT", "Price": 1, "Status": "Filled", "FilledQty": 100, "AvailableQty": 0 },
    { "OrderId": "o3", "Symbol": "A", "Side": "buy", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Pending", "FilledQty": 0, "AvailableQty": 200 },
    { "OrderId": "o4", "Symbol": "A", "Side": "sell", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Pending", "FilledQty": 0, "AvailableQty": 200 },
    { "OrderId": "o1", "Symbol": "A", "Side": "buy", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Filled", "FilledQty": 200, "AvailableQty": 0 },
    { "OrderId": "o4", "Symbol": "A", "Side": "sell", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Partially Filled", "FilledQty": 100, "AvailableQty": 100 },
    { "OrderId": "o3", "Symbol": "A", "Side": "buy", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Partially Filled", "FilledQty": 100, "AvailableQty": 100 },
    { "OrderId": "o4", "Symbol": "A", "Side": "sell", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Status": "Filled", "FilledQty": 200, "AvailableQty": 0 },

  ],
  [
    { "AvailableQty": 200, "FilledQty": 0, "OrderId": "o5", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "buy", "Status": "Pending", "Symbol": "A" },
    { "AvailableQty": 100, "FilledQty": 0, "OrderId": "o6", "OrderQty": 100, "OrderType": "LIMIT", "Price": 1, "Side": "sell", "Status": "Pending", "Symbol": "A" },
    { "AvailableQty": 0, "FilledQty": 200, "OrderId": "o3", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "buy", "Status": "Filled", "Symbol": "A" },
    { "AvailableQty": 0, "FilledQty": 100, "OrderId": "o6", "OrderQty": 100, "OrderType": "LIMIT", "Price": 1, "Side": "sell", "Status": "Filled", "Symbol": "A" },
    { "AvailableQty": 200, "FilledQty": 0, "OrderId": "o7", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "buy", "Status": "Pending", "Symbol": "A" },
    { "AvailableQty": 200, "FilledQty": 0, "OrderId": "o8", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "sell", "Status": "Pending", "Symbol": "A" },
    { "AvailableQty": 0, "FilledQty": 200, "OrderId": "o5", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "buy", "Status": "Filled", "Symbol": "A" },
    { "AvailableQty": 0, "FilledQty": 200, "OrderId": "o8", "OrderQty": 200, "OrderType": "LIMIT", "Price": 1, "Side": "sell", "Status": "Filled", "Symbol": "A" }
  ]
];

function transposeArray(matrix) {
  return matrix[0].map((col, i) => matrix.map((row) => row[i]));
};

uda.initialize();

test('all execution should match', () => {
  batches.forEach((data, index) => {
    const emit_target = targets[index];
    const rows = transposeArray(data);
    if (uda.process(...rows) > 0) {
      const emit = uda.finalize();
      const emit_no_time = emit.map(row => {
        let ret = { ...row };
        delete ret.Time;
        return ret
      });
      expect(emit_no_time).toStrictEqual(emit_target);
    }
  });
});

