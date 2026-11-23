"""Конвертація MovieLens 1M: .dat (роздільник '::', Latin-1) -> .csv (роздільник ',', UTF-8).

Запуск один раз перед завантаженням у Neo4j:
    python3 convert.py

Читає файли з ml-1m/, пише результат у import/ (ця папка підключена в контейнер Neo4j).
"""
import csv
import re

SRC = "ml-1m"
DST = "import"

# Назва завжди закінчується роком у дужках: "Toy Story (1995)".
# Беремо лише останню пару дужок, бо в деяких назвах є ще й альтернативна назва в дужках:
# "Seven (Se7en) (1995)". Пробіл перед роком необов'язковий: в одній назві його немає,
# "Associate, The (L'Associe)(1982)".
TITLE_YEAR = re.compile(r"^(.*?)\s*\((\d{4})\)$")


def convert(name, header, transform):
    """Читає ml-1m/<name>.dat, кожен рядок пропускає через transform і пише import/<name>.csv."""
    rows = []
    with open(f"{SRC}/{name}.dat", encoding="latin-1") as f_in, \
         open(f"{DST}/{name}.csv", "w", newline="", encoding="utf-8") as f_out:
        writer = csv.writer(f_out)
        writer.writerow(header)
        for line in f_in:
            row = transform(line.strip().split("::"))
            writer.writerow(row)
            rows.append(row)
    print(f"{name}.csv: {len(rows):>9,} рядків  {header}")
    for row in rows[:2]:
        print(f"    {row}")
    return rows


def movie(parts):
    # MovieID::Title::Genres -> movieId, title, year, genres
    movie_id, title, genres = parts
    match = TITLE_YEAR.match(title)
    if not match:
        raise ValueError(f"Не знайдено рік у назві: {title!r}")
    return [movie_id, match.group(1), match.group(2), genres]


def user(parts):
    # UserID::Gender::Age::Occupation::Zip -> zip не потрібен
    return parts[:4]


def rating(parts):
    # UserID::MovieID::Rating::Timestamp -> без змін
    return parts


if __name__ == "__main__":
    convert("movies", ["movieId", "title", "year", "genres"], movie)
    convert("users", ["userId", "gender", "age", "occupation"], user)
    convert("ratings", ["userId", "movieId", "rating", "timestamp"], rating)
