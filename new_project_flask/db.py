"""
Работа с базой данных SQLite для сервиса бронирования номеров.

При первом запуске приложения база данных создаётся из файла db.sql
(схема + демонстрационные данные). При последующих запусках существующая
база не перезаписывается, чтобы не потерять реальные заявки на бронь.
"""
import os
import sqlite3
from datetime import date

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, 'hotel.db')
SCHEMA_PATH = os.path.join(BASE_DIR, 'db.sql')


def get_db():
    """Открыть новое соединение с базой данных."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON')
    return conn


def init_db(force=False):
    """Создать базу данных из db.sql, если она ещё не существует."""
    if force and os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    if os.path.exists(DB_PATH):
        return

    conn = sqlite3.connect(DB_PATH)
    try:
        with open(SCHEMA_PATH, 'r', encoding='utf-8') as f:
            conn.executescript(f.read())
        conn.commit()
    finally:
        conn.close()


def get_rooms(category=None):
    """Список номеров (категорий) с удобствами. Можно отфильтровать по категории."""
    conn = get_db()
    try:
        query = """
            SELECT
                r.id, r.category, r.price_per_person, r.max_guests,
                r.description, r.image_url, r.is_available,
                GROUP_CONCAT(rf.name, ', ') AS features
            FROM rooms r
            LEFT JOIN room_feature_association rfa ON r.id = rfa.room_id
            LEFT JOIN room_features rf ON rfa.feature_id = rf.id
        """
        params = ()
        if category:
            query += " WHERE r.category = ? "
            params = (category,)
        query += " GROUP BY r.id ORDER BY r.id"
        rows = conn.execute(query, params).fetchall()
        return rows
    finally:
        conn.close()


def get_room(room_id):
    conn = get_db()
    try:
        return conn.execute('SELECT * FROM rooms WHERE id = ?', (room_id,)).fetchone()
    finally:
        conn.close()


def get_categories():
    conn = get_db()
    try:
        rows = conn.execute('SELECT DISTINCT category FROM rooms ORDER BY category').fetchall()
        return [r['category'] for r in rows]
    finally:
        conn.close()


def get_approved_bookings_by_room():
    """
    Словарь {room_id: [{'check_in': 'YYYY-MM-DD', 'check_out': 'YYYY-MM-DD'}, ...]}
    только для заявок, одобренных администратором (status = 'approved').
    Эти периоды считаются занятыми и должны быть неактивны в календаре.
    """
    conn = get_db()
    try:
        rows = conn.execute("""
            SELECT room_id, check_in_date, check_out_date
            FROM bookings
            WHERE status = 'approved' AND check_out_date >= ?
            ORDER BY check_in_date
        """, (date.today().isoformat(),)).fetchall()
    finally:
        conn.close()

    result = {}
    for row in rows:
        result.setdefault(row['room_id'], []).append({
            'check_in': row['check_in_date'],
            'check_out': row['check_out_date'],
        })
    return result


def room_has_approved_overlap(room_id, check_in, check_out):
    """
    True, если для номера room_id уже есть ОДОБРЕННАЯ бронь, период которой
    пересекается с [check_in, check_out). День выезда считается свободным
    (гость уже покинул номер), поэтому используется полуоткрытый интервал.
    """
    conn = get_db()
    try:
        row = conn.execute("""
            SELECT COUNT(*) AS cnt
            FROM bookings
            WHERE room_id = ?
              AND status = 'approved'
              AND check_in_date < ?
              AND check_out_date > ?
        """, (room_id, check_out, check_in)).fetchone()
        return row['cnt'] > 0
    finally:
        conn.close()


def create_booking(data):
    conn = get_db()
    try:
        cur = conn.execute("""
            INSERT INTO bookings (
                room_id, guest_name, guest_last_name, phone, email,
                check_in_date, check_out_date, guests_count, total_price, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
        """, (
            data['room_id'], data['guest_name'], data['guest_last_name'],
            data['phone'], data['email'], data['check_in_date'],
            data['check_out_date'], data['guests_count'], data['total_price'],
        ))
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


def get_all_bookings():
    conn = get_db()
    try:
        rows = conn.execute("""
            SELECT
                b.id, b.guest_name, b.guest_last_name, b.phone, b.email,
                b.check_in_date, b.check_out_date, b.guests_count,
                b.total_price, b.status, b.created_at,
                r.category AS room_category
            FROM bookings b
            JOIN rooms r ON b.room_id = r.id
            ORDER BY
                CASE b.status WHEN 'pending' THEN 0 ELSE 1 END,
                b.check_in_date
        """).fetchall()
        return rows
    finally:
        conn.close()


def approve_booking(booking_id):
    conn = get_db()
    try:
        conn.execute("UPDATE bookings SET status = 'approved' WHERE id = ?", (booking_id,))
        conn.commit()
    finally:
        conn.close()


def delete_booking(booking_id):
    conn = get_db()
    try:
        conn.execute("DELETE FROM bookings WHERE id = ?", (booking_id,))
        conn.commit()
    finally:
        conn.close()
