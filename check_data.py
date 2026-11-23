"""Перевірки даних MovieLens 1M, на які я посилаюсь у README.

Запуск після convert.py:
    python check_data.py
"""
import csv
from collections import Counter

with open("import/movies.csv", encoding="utf-8") as f:
    movies = list(csv.DictReader(f))
with open("import/ratings.csv", encoding="utf-8") as f:
    ratings = list(csv.DictReader(f))

# 1. Чи є повторні оцінки: той самий користувач оцінив той самий фільм більше одного разу
pairs = Counter((r["userId"], r["movieId"]) for r in ratings)
repeated = sum(1 for n in pairs.values() if n > 1)
print("1. Повторні оцінки")
print(f"   оцінок усього:                  {len(ratings):,}")
print(f"   унікальних пар користувач-фільм: {len(pairs):,}")
print(f"   пар з кількома оцінками:         {repeated}")

# 2. Чи в усіх фільмів знайшовся рік
no_year = [m for m in movies if not m["year"]]
print("2. Рік у фільмах")
print(f"   фільмів: {len(movies):,}, без року: {len(no_year)}, "
      f"роки від {min(m['year'] for m in movies)} до {max(m['year'] for m in movies)}")

# 3. Чи є символи поза ASCII (é, ñ тощо) у назвах
non_ascii = [m["title"] for m in movies if not m["title"].isascii()]
print("3. Символи поза ASCII у назвах")
print(f"   назв зі спецсимволами: {len(non_ascii)}")

# 4. Які значення оцінок трапляються і скільки оцінок має кожен користувач
values = Counter(r["rating"] for r in ratings)
per_user = Counter(r["userId"] for r in ratings)
print("4. Оцінки")
print(f"   значення: {dict(sorted(values.items()))}")
print(f"   оцінок на користувача: мінімум {min(per_user.values())}, максимум {max(per_user.values())}")

# 5. Жанри: скільки різних назв, скільки жанрів у фільму, скільки фільмів у кожному жанрі
movie_genres = [m["genres"].split("|") for m in movies]
per_genre = Counter(g for gs in movie_genres for g in gs)
per_movie = Counter(len(gs) for gs in movie_genres)
print("5. Жанри")
print(f"   різних назв жанрів: {len(per_genre)}")
print(f"   жанрів у фільму: {dict(sorted(per_movie.items()))}  (кількість жанрів: кількість фільмів)")
print(f"   зв'язків фільм-жанр: {sum(per_genre.values()):,}")
print("   фільмів у жанрі:")
for genre, n in per_genre.most_common():
    print(f"      {genre:<12} {n:>5}")

# 6. Скільки пар користувачів не мають жодного спільного оціненого фільму
# (для них найкоротший шлях у графі довший за 2). Перебір усіх 18 млн пар займає ~10 секунд.
user_movies = {}
for r in ratings:
    user_movies.setdefault(r["userId"], set()).add(r["movieId"])
users = list(user_movies)
no_common = 0
for i, a in enumerate(users):
    movies_a = user_movies[a]
    for b in users[i + 1:]:
        if movies_a.isdisjoint(user_movies[b]):
            no_common += 1
pairs_total = len(users) * (len(users) - 1) // 2
print("6. Пари користувачів без спільних фільмів")
print(f"   пар усього: {pairs_total:,}, без жодного спільного фільму: {no_common:,} "
      f"({100 * no_common / pairs_total:.1f}%)")
