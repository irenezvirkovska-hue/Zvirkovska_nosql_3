// Частина 2: індекси та завантаження даних MovieLens 1M
// Виконувати блоки по черзі в Neo4j Browser (http://localhost:7474).
// CSV лежать у ./import, який підключений у контейнер, тому шлях — file:///<назва>.csv
// Усі числа в CSV — це рядки, тому перетворюю їх через toInteger().

// ─────────────────────────────────────────────────────────────
// Крок 1. Обмеження унікальності (вони ж індекси)
// Створюю ДО завантаження вузлів: MERGE шукає вузол перед створенням,
// і без індексу кожен пошук — це перебір усіх вузлів цього лейблу.
// Обмеження також гарантує, що дубль вузла з тим самим ID неможливий.
// ─────────────────────────────────────────────────────────────
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id IF NOT EXISTS
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;

// ─────────────────────────────────────────────────────────────
// Крок 2. Вузли User (6 040)
// MERGE по ключу userId, решту властивостей — через SET,
// щоб повторний запуск оновлював вузол, а не створював дубль.
// ─────────────────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender     = row.gender,
    u.age        = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// ─────────────────────────────────────────────────────────────
// Крок 3. Вузли Movie (3 883), вузли Genre (18) і ребра HAS_GENRE (6 408)
// Жанри в CSV — рядок "Animation|Children's|Comedy":
// split() робить з нього список, UNWIND — по рядку на кожен жанр.
// ─────────────────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year  = toInteger(row.year)
WITH m, row
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);

// ─────────────────────────────────────────────────────────────
// Крок 4. Ребра RATED (1 000 209) батчами через APOC
// Перший запит лише читає рядки CSV, другий виконується для кожного рядка,
// а APOC комітить кожні 10 000 рядків окремою транзакцією.
// Вузли вже існують, тому шукаю їх через MATCH (за індексом), а не MERGE.
// parallel: false — потоки не конкурують за блокування тих самих вузлів
// (у популярних фільмів тисячі оцінок у різних батчах).
// ─────────────────────────────────────────────────────────────
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User  {userId:  toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating    = toInteger(row.rating),
       r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, parallel: false}
)
YIELD batches, total, timeTaken, committedOperations, failedOperations, errorMessages
RETURN batches, total, timeTaken, committedOperations, failedOperations, errorMessages;

// ─────────────────────────────────────────────────────────────
// Крок 5. Перевірка результату
// Очікую: 6 040 / 3 883 / 18 / 1 000 209 / 6 408 (як у check_data.py)
// ─────────────────────────────────────────────────────────────
MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;

// Усе одним запитом — для скріншоту
CALL { MATCH (u:User)  RETURN count(u) AS users }
CALL { MATCH (m:Movie) RETURN count(m) AS movies }
CALL { MATCH (g:Genre) RETURN count(g) AS genres }
CALL { MATCH ()-[r:RATED]->()     RETURN count(r) AS ratings }
CALL { MATCH ()-[h:HAS_GENRE]->() RETURN count(h) AS hasGenre }
RETURN users, movies, genres, ratings, hasGenre;

// Немає дублів ребер: пари користувач–фільм з більш ніж одним RATED (очікую 0)
MATCH (u:User)-[r:RATED]->(m:Movie)
WITH u, m, count(r) AS n
WHERE n > 1
RETURN count(*) AS duplicatePairs;

// Створені обмеження та індекси
SHOW CONSTRAINTS YIELD name, labelsOrTypes, properties, type;
