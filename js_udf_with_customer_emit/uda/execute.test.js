const uda = require('./execute');

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
    { BuyId: 'o1', SellId: 'o2', Symbol: 'A', Price: 1, Qty: 100 },
    { BuyId: 'o1', SellId: 'o4', Symbol: 'A', Price: 1, Qty: 100 },
    { BuyId: 'o3', SellId: 'o4', Symbol: 'A', Price: 1, Qty: 100 }
  ],
  [
    { BuyId: 'o3', SellId: 'o6', Symbol: 'A', Price: 1, Qty: 100 },
    { BuyId: 'o5', SellId: 'o8', Symbol: 'A', Price: 1, Qty: 200 }
  ]
]

function transposeArray(matrix) {
  return matrix[0].map((col, i) => matrix.map((row) => row[i]));
}

uda.initialize();

test('all execution should match', () => {
  batches.forEach((data, index) => {
    const emit_target = targets[index];
    const rows = transposeArray(data);
    if (uda.process(...rows) > 0) {
      const emit = uda.finalize();
      const emit_no_time = emit.map( row => {
        let ret = {...row};
        delete ret.Time;
        return ret
      });
      expect(emit_no_time).toStrictEqual(emit_target);
    }
  });
});

