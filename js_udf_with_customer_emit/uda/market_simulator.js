const { v4: uuidv4 } = require("uuid");

class MarketSimulator {
  constructor(symbol, initial_price = 100.0, interval = 0.1) {
    this.symbol = symbol;
    this.price = initial_price;
    this.orders = [];
    this.batches = [];
  }

  generateLimitOrder(side, quantity, price) {
    const order = [new Date().getTime(), uuidv4(), this.symbol, side, quantity, 'LIMIT', price];
    return order;
  }

  placeBuyOrder(quantity, price) {
    const buyOrder = this.generateLimitOrder('buy', quantity, price);
    this.orders.push(buyOrder);
    //console.log(`Buy Order placed: ${JSON.stringify(buyOrder)}`);
  }

  placeSellOrder(quantity, price) {
    const sellOrder = this.generateLimitOrder('sell', quantity, price);
    this.orders.push(sellOrder);
    //console.log(`Sell Order placed: ${JSON.stringify(sellOrder)}`);
  }

  simulateMarket(numIterations, batchNumber) {
    for (let i = 0; i < numIterations; i++) {
      for (let j = 0; j < batchNumber; j++) {
        if (Math.random() < 0.5) {
          const quantity = Math.floor(Math.random() * 1000) + 1;
          const price = +(this.price * (Math.random() * (1.01 - 0.99) + 0.99)).toFixed(2);
          this.placeBuyOrder(quantity, price);
        } else {
          const quantity = Math.floor(Math.random() * 1000) + 1;
          const price = +(this.price * (Math.random() * (1.01 - 0.99) + 0.99)).toFixed(2);
          this.placeSellOrder(quantity, price);
        }
      }
      this.price = +(this.price * (Math.random() * (1.01 - 0.99) + 0.99)).toFixed(2);
      this.batches.push(this.orders);
      this.orders = [];
    }
    return this.batches;
  }
}

module.exports = MarketSimulator;
