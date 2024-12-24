
use testdb

db.testcollection.drop();

db.createCollection("testcollection", {
  changeStreamPreAndPostImages: { enabled: true }
});


db.testcollection.insert({"_id": 1, name: "Alice", age: 30})

db.testcollection.updateOne(
    { "_id": 1 },  // Filter
    { $set: { "age": 32 } }  // Update
)

db.testcollection.deleteOne({ "_id": 1 });