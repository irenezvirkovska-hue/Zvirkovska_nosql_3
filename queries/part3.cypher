// Частина 3: Cypher-запити різної складності
// Виконувати по одному в Neo4j Browser.

// ═════════════════════════════════════════════════════════════
// БАЗОВІ
// ═════════════════════════════════════════════════════════════

// Запит 1. Фільми жанру Thriller із середнім рейтингом вище 4.0
// Починаю з одного вузла Genre і йду по його ребрах до фільмів, а від них до оцінок.
// Кількість оцінок виводжу, щоб було видно, що середнє не з 2–3 оцінок.
MATCH (:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(:User)
WITH m, avg(r.rating) AS avgRating, count(r) AS ratings
WHERE avgRating > 4.0
RETURN m.title AS title, m.year AS year, round(avgRating, 2) AS avgRating, ratings
ORDER BY avgRating DESC, ratings DESC;

// Запит 2. Користувачі, які поставили оцінку 5 більш ніж 50 фільмам
// Фільтр rating = 5 до агрегації, поріг > 50 — після (WITH ... WHERE, аналог HAVING у SQL).
// totalRatings — для контексту: скільки всього оцінок у цього користувача.
MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fives
WHERE fives > 50
RETURN u.userId AS userId, u.gender AS gender, u.age AS age,
       fives, COUNT { (u)-[:RATED]->() } AS totalRatings
ORDER BY fives DESC;

// ═════════════════════════════════════════════════════════════
// СЕРЕДНЬОГО РІВНЯ
// ═════════════════════════════════════════════════════════════

// Запит 3. Фільми, які обидва користувачі (userId 1 і 2) оцінили високо (>= 4)
// Один шаблон: user1 -> фільм <- user2. Фільм, оцінений обома, — це спільний вузол між ними.
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title AS title, m.year AS year, r1.rating AS user1Rating, r2.rating AS user2Rating
ORDER BY title;

// Запит 4. Жанри, чиї фільми стабільно отримують високі оцінки
// avgRating — середня оцінка; stdDev — розкид оцінок (менше = стабільніше);
// pctHigh — частка оцінок 4–5; ratings — скільки всього оцінок у жанрі.
MATCH (g:Genre)<-[:HAS_GENRE]-(:Movie)<-[r:RATED]-(:User)
RETURN g.name AS genre,
       round(avg(r.rating), 2) AS avgRating,
       round(stDev(r.rating), 2) AS stdDev,
       round(100.0 * sum(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END) / count(r), 1) AS pctHigh,
       count(r) AS ratings
ORDER BY avgRating DESC;

// ═════════════════════════════════════════════════════════════
// СКЛАДНІ
// ═════════════════════════════════════════════════════════════

// Запит 5. Рекомендації «користувачі зі схожими смаками також дивилися» для userId 1
// Крок 1: схожі користувачі — ті, хто теж оцінив на 4–5 ті самі фільми, що й я;
//         сортую за кількістю таких спільних фільмів і беру 50 найсхожіших.
// Крок 2: фільми, які ці 50 людей оцінили на 4–5, а я ще не оцінювала.
// Крок 3: ранжую за тим, скільки схожих користувачів рекомендує фільм, потім за їхньою середньою оцінкою.
MATCH (me:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(other:User)
WHERE r1.rating >= 4 AND r2.rating >= 4
WITH me, other, count(m) AS commonLiked
ORDER BY commonLiked DESC
LIMIT 50
MATCH (other)-[r:RATED]->(rec:Movie)
WHERE r.rating >= 4 AND NOT (me)-[:RATED]->(rec)
RETURN rec.title AS title, rec.year AS year,
       count(other) AS recommendedBy, round(avg(r.rating), 2) AS avgRating
ORDER BY recommendedBy DESC, avgRating DESC
LIMIT 10;

// Запит 6. Найкоротший ланцюжок між двома користувачами через спільні фільми
// Напрямок ребер ігнорую (-[:RATED*..10]-), бо шлях іде User -> Movie <- User -> Movie ...
// Для читабельності шлях показую як список: користувач, фільм, користувач, ...
// Пара 1–2 має спільні фільми; пара 1–46 — жодного спільного фільму.
UNWIND [[1, 2], [1, 46]] AS pair
MATCH (a:User {userId: pair[0]}), (b:User {userId: pair[1]})
MATCH p = shortestPath((a)-[:RATED*..10]-(b))
RETURN pair[0] AS fromUser, pair[1] AS toUser, length(p) AS pathLength,
       [n IN nodes(p) | coalesce(n.title, 'User ' + toString(n.userId))] AS path;

// До питання про шляхи довжини 4 і 6:
// найактивніший користувач (4169, 2 314 оцінок) має спільний фільм з усіма іншими 6 039 користувачами,
// тому будь-які два користувачі пов'язані шляхом довжини не більше 4.
MATCH (hub:User {userId: 4169})-[:RATED]->(:Movie)<-[:RATED]-(u:User)
RETURN count(DISTINCT u) AS usersSharingAMovieWithHub;
