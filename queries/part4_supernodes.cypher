// Частина 4: виявлення супервузлів
// Виконувати по одному в Neo4j Browser.

// ─────────────────────────────────────────────────────────────
// Крок 1. Розподіл ступенів (кількості ребер) за типом вузла
// Ступінь вузла — кількість його ребер у будь-якому напрямку: COUNT { (n)--() }.
// Порівнюю медіану, 99-й перцентиль і максимум: «аномально великий» = далеко від медіани.
// ─────────────────────────────────────────────────────────────
MATCH (n)
WITH labels(n)[0] AS label, COUNT { (n)--() } AS degree
RETURN label,
       count(*) AS nodes,
       round(avg(degree), 1) AS avgDegree,
       percentileDisc(degree, 0.5) AS median,
       percentileDisc(degree, 0.99) AS p99,
       max(degree) AS maxDegree
ORDER BY maxDegree DESC;

// ─────────────────────────────────────────────────────────────
// Крок 2. Вузли з найбільшою кількістю ребер (топ-15)
// coalesce показує назву фільму, назву жанру або ID користувача — залежно від типу вузла.
// ─────────────────────────────────────────────────────────────
MATCH (n)
WITH n, COUNT { (n)--() } AS degree
ORDER BY degree DESC
LIMIT 15
RETURN labels(n)[0] AS label,
       coalesce(n.title, n.name, 'User ' + toString(n.userId)) AS node,
       degree;

// ─────────────────────────────────────────────────────────────
// Крок 3. Жанрові вузли: власні ребра і скільки оцінок «за» ними
// Власних ребер у жанру небагато (до 1 603), але запит «через жанр» до оцінок
// проходить на крок далі і зачіпає сотні тисяч ребер RATED.
// ─────────────────────────────────────────────────────────────
MATCH (g:Genre)
CALL {
  WITH g
  MATCH (g)<-[:HAS_GENRE]-(m:Movie)
  RETURN count(m) AS movies, sum(COUNT { (m)<-[:RATED]-() }) AS ratingsBehind
}
RETURN g.name AS genre, movies, ratingsBehind
ORDER BY movies DESC;

// ─────────────────────────────────────────────────────────────
// Крок 4. Той самий запит через супервузол і через звичайний вузол
// «Які фільми оцінювали ті, хто оцінив цей фільм» (2 кроки від фільму).
// American Beauty (movieId 2858): 3 428 оцінок — найбільший вузол графа.
// Nights of Cabiria (movieId 2351): 111 оцінок — рівно медіана для фільмів.
// PROFILE показує план виконання і кількість звернень до бази (db hits).
// ─────────────────────────────────────────────────────────────
PROFILE
MATCH (:Movie {movieId: 2858})<-[:RATED]-(:User)-[:RATED]->(other:Movie)
RETURN count(DISTINCT other) AS reachableMovies, count(*) AS pathsVisited;

PROFILE
MATCH (:Movie {movieId: 2351})<-[:RATED]-(:User)-[:RATED]->(other:Movie)
RETURN count(DISTINCT other) AS reachableMovies, count(*) AS pathsVisited;

// ─────────────────────────────────────────────────────────────
// Крок 5. Те саме для жанрів: середній рейтинг через Drama і через Film-Noir
// ─────────────────────────────────────────────────────────────
PROFILE
MATCH (:Genre {name: 'Drama'})<-[:HAS_GENRE]-(:Movie)<-[r:RATED]-(:User)
RETURN round(avg(r.rating), 2) AS avgRating, count(r) AS ratings;

PROFILE
MATCH (:Genre {name: 'Film-Noir'})<-[:HAS_GENRE]-(:Movie)<-[r:RATED]-(:User)
RETURN round(avg(r.rating), 2) AS avgRating, count(r) AS ratings;

// ─────────────────────────────────────────────────────────────
// Крок 6. Стратегія: попередньо пораховані агрегати на вузлі Movie
// Один раз рахую для кожного фільму кількість і середнє його оцінок і зберігаю як властивості.
// Тоді запит по жанру проходить лише по ребрах HAS_GENRE (до 1 603), а не по 354 тис. RATED.
// Ці властивості треба оновлювати при нових оцінках — це ціна прискорення.
// ─────────────────────────────────────────────────────────────
MATCH (m:Movie)
CALL {
  WITH m
  MATCH (m)<-[r:RATED]-()
  RETURN count(r) AS n, avg(r.rating) AS a
}
SET m.ratingCount = n, m.avgRating = a;

// Той самий середній рейтинг Drama, але з агрегатів: зважене середнє по фільмах
PROFILE
MATCH (:Genre {name: 'Drama'})<-[:HAS_GENRE]-(m:Movie)
WHERE m.ratingCount > 0
RETURN round(sum(m.avgRating * m.ratingCount) / sum(m.ratingCount), 2) AS avgRating,
       sum(m.ratingCount) AS ratings;
