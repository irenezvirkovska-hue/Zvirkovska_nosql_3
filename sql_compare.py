"""Порівняння з реляційною моделлю (частина 6).

Завантажує ті самі CSV у SQLite (у пам'яті) і виконує SQL-версії двох запитів частини 3:
запиту 5 (рекомендації) і запиту 4 (жанри). Запуск:
    python sql_compare.py
"""
import csv
import sqlite3
import time

db = sqlite3.connect(":memory:")
db.executescript("""
CREATE TABLE movies(movie_id INTEGER PRIMARY KEY, title TEXT, year INTEGER);
CREATE TABLE movie_genres(movie_id INTEGER, genre TEXT);
CREATE TABLE ratings(user_id INTEGER, movie_id INTEGER, rating INTEGER, ts INTEGER,
                     PRIMARY KEY (user_id, movie_id));
CREATE INDEX ratings_movie ON ratings(movie_id);
""")

with open("import/movies.csv", encoding="utf-8") as f:
    for m in csv.DictReader(f):
        db.execute("INSERT INTO movies VALUES (?, ?, ?)", (int(m["movieId"]), m["title"], int(m["year"])))
        db.executemany("INSERT INTO movie_genres VALUES (?, ?)",
                       [(int(m["movieId"]), g) for g in m["genres"].split("|")])
with open("import/ratings.csv", encoding="utf-8") as f:
    db.executemany("INSERT INTO ratings VALUES (?, ?, ?, ?)",
                   ((int(r["userId"]), int(r["movieId"]), int(r["rating"]), int(r["timestamp"]))
                    for r in csv.DictReader(f)))

# Запит 5 у SQL: таблиця ratings з'єднується сама з собою кілька разів
Q5 = """
WITH my_liked AS (
    SELECT movie_id FROM ratings WHERE user_id = 1 AND rating >= 4
),
similar AS (
    SELECT r.user_id, COUNT(*) AS common_liked
    FROM ratings r
    JOIN my_liked ml ON ml.movie_id = r.movie_id
    WHERE r.rating >= 4 AND r.user_id <> 1
    GROUP BY r.user_id
    ORDER BY common_liked DESC
    LIMIT 50
)
SELECT m.title, COUNT(*) AS recommended_by, ROUND(AVG(r.rating), 2) AS avg_rating
FROM similar s
JOIN ratings r ON r.user_id = s.user_id AND r.rating >= 4
JOIN movies m  ON m.movie_id = r.movie_id
WHERE NOT EXISTS (SELECT 1 FROM ratings mine
                  WHERE mine.user_id = 1 AND mine.movie_id = r.movie_id)
GROUP BY m.movie_id, m.title
ORDER BY recommended_by DESC, avg_rating DESC
LIMIT 5;
"""

# Запит 4 у SQL: одна агрегація по всіх оцінках
Q4 = """
SELECT g.genre, ROUND(AVG(r.rating), 2) AS avg_rating, COUNT(*) AS ratings
FROM movie_genres g
JOIN ratings r ON r.movie_id = g.movie_id
GROUP BY g.genre
ORDER BY avg_rating DESC
LIMIT 5;
"""

for name, sql in [("Запит 5 (рекомендації для userId 1)", Q5), ("Запит 4 (жанри, усі 1 млн оцінок)", Q4)]:
    start = time.perf_counter()
    rows = db.execute(sql).fetchall()
    ms = (time.perf_counter() - start) * 1000
    print(f"{name}: {ms:,.0f} ms")
    for row in rows:
        print(f"    {row}")
