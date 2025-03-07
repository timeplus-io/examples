DROP STREAM IF EXISTS iris;

CREATE STREAM IF NOT EXISTS iris
(
  `sepal.length` float64,
  `sepal.width` float64,
  `petal.length` float64,
  `petal.width` float64,
  `variety` string
);

insert into iris (
  `sepal.length`,
  `sepal.width`,
  `petal.length`,
  `petal.width`,
  `variety`
)
SELECT * 
FROM url('https://tp-solutions.s3.us-west-2.amazonaws.com/iris.csv', 'CSVWithNames');
