-- =============================================
-- База данных гостиницы "Светлые Сны"
-- =============================================

-- Удаляем старые таблицы, если есть
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS room_feature_association;
DROP TABLE IF EXISTS room_features;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS users;

-- =============================================
-- 1. Таблица пользователей
-- =============================================
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(200) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. Таблица номеров
-- =============================================
CREATE TABLE rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category VARCHAR(50) NOT NULL,
    price_per_person DECIMAL(10,2) NOT NULL,
    max_guests INTEGER DEFAULT 2,
    description TEXT,
    image_url VARCHAR(200),
    is_available BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 3. Таблица удобств номеров
-- =============================================
CREATE TABLE room_features (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- =============================================
-- 4. Связь номеров с удобствами (многие ко многим)
-- =============================================
CREATE TABLE room_feature_association (
    room_id INTEGER,
    feature_id INTEGER,
    PRIMARY KEY (room_id, feature_id),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (feature_id) REFERENCES room_features(id) ON DELETE CASCADE
);

-- =============================================
-- 5. Таблица бронирований
-- =============================================
CREATE TABLE bookings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL,
    room_id INTEGER NOT NULL,
    guest_name VARCHAR(50) NOT NULL,
    guest_last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(120) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guests_count INTEGER DEFAULT 1,
    total_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, cancelled
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

-- =============================================
-- 6. Таблица отзывов
-- =============================================
CREATE TABLE reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL,
    room_id INTEGER NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
);

-- =============================================
-- 7. Триггер для автоматического обновления updated_at
-- =============================================
CREATE TRIGGER update_bookings_updated_at 
AFTER UPDATE ON bookings
BEGIN
    UPDATE bookings SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_reviews_updated_at 
AFTER UPDATE ON reviews
BEGIN
    UPDATE reviews SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =============================================
-- 8. ВСТАВКА ДАННЫХ
-- =============================================

-- 8.1 Добавляем пользователей
INSERT INTO users (username, email, password_hash, role) VALUES
('admin', 'admin@hotel.ru', 'admin_hash', 'admin'),
('ivanov', 'ivanov@mail.ru', 'user_hash_123', 'user'),
('petrov', 'petrov@mail.ru', 'user_hash_456', 'user'),
('sidorov', 'sidorov@mail.ru', 'user_hash_789', 'user');

-- 8.2 Добавляем удобства
INSERT INTO room_features (name) VALUES
('Завтрак'),
('Обед'),
('Ужин'),
('Душ'),
('Ванна'),
('Кондиционер'),
('Телевизор'),
('Мини-бар'),
('Вид на город'),
('Бесплатный Wi-Fi'),
('Парковка'),
('Фен');

-- 8.3 Добавляем номера
INSERT INTO rooms (category, price_per_person, max_guests, description, image_url) VALUES
('Стандарт', 10000, 2, 'Уютный стандартный номер со всеми удобствами. Идеальный вариант для деловых поездок.', 'standart.png'),
('Студия', 8000, 2, 'Просторная студия с современным дизайном. Отлично подходит для длительного проживания.', 'studio.jpg'),
('Люкс', 19000, 4, 'Роскошный люкс с панорамным видом на город. Включает все возможные удобства.', 'lux.png'),
('Стандарт Плюс', 12000, 3, 'Улучшенный стандарт с дополнительным пространством и большим окном.', 'standart_plus.jpg'),
('Семейный', 15000, 5, 'Большой номер для семейного отдыха. Две комнаты и дополнительная кровать.', 'family.jpg');

-- 8.4 Связываем номера с удобствами
-- Стандарт (id=1): Завтрак, Душ, Ванна, Телевизор
INSERT INTO room_feature_association (room_id, feature_id) VALUES
(1, 1), (1, 4), (1, 5), (1, 7);

-- Студия (id=2): Завтрак, Обед, Душ, Ванна, Кондиционер, Телевизор, Бесплатный Wi-Fi
INSERT INTO room_feature_association (room_id, feature_id) VALUES
(2, 1), (2, 2), (2, 4), (2, 5), (2, 6), (2, 7), (2, 10);

-- Люкс (id=3): Все удобства
INSERT INTO room_feature_association (room_id, feature_id) VALUES
(3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 6), (3, 7), (3, 8), (3, 9), (3, 10), (3, 11), (3, 12);

-- Стандарт Плюс (id=4): Завтрак, Обед, Душ, Ванна, Кондиционер, Бесплатный Wi-Fi
INSERT INTO room_feature_association (room_id, feature_id) VALUES
(4, 1), (4, 2), (4, 4), (4, 5), (4, 6), (4, 10);

-- Семейный (id=5): Завтрак, Обед, Ужин, Душ, Ванна, Кондиционер, Телевизор, Бесплатный Wi-Fi, Парковка
INSERT INTO room_feature_association (room_id, feature_id) VALUES
(5, 1), (5, 2), (5, 3), (5, 4), (5, 5), (5, 6), (5, 7), (5, 10), (5, 11);

-- 8.5 Добавляем бронирования
INSERT INTO bookings (user_id, room_id, guest_name, guest_last_name, phone, email, 
                      check_in_date, check_out_date, guests_count, total_price, status) VALUES
(1, 1, 'Иван', 'Петров', '+7(800)555-35-35', 'petrov@mail.ru', 
 '2026-09-10', '2026-09-12', 2, 20000, 'approved'),

(1, 2, 'Иван', 'Петров', '+7(800)555-35-35', 'petrov@mail.ru', 
 '2026-09-15', '2026-09-18', 2, 24000, 'pending'),

(2, 3, 'Сергей', 'Иванов', '+7(800)555-35-35', 'ivanov@mail.ru', 
 '2026-09-20', '2026-09-25', 2, 95000, 'pending'),

(NULL, 1, 'Алексей', 'Сидоров', '+7(800)555-35-35', 'sidorov@mail.ru', 
 '2026-10-01', '2026-10-03', 1, 20000, 'approved'),

(3, 4, 'Анна', 'Козлова', '+7(800)555-35-35', 'kozlova@mail.ru', 
 '2026-10-05', '2026-10-10', 3, 60000, 'pending'),

(3, 5, 'Анна', 'Козлова', '+7(800)555-35-35', 'kozlova@mail.ru', 
 '2026-11-01', '2026-11-05', 4, 60000, 'rejected'),

(4, 2, 'Дмитрий', 'Смирнов', '+7(800)555-35-35', 'smirnov@mail.ru', 
 '2026-12-01', '2026-12-03', 1, 16000, 'approved');

-- 8.6 Добавляем отзывы
INSERT INTO reviews (user_id, room_id, rating, comment) VALUES
(1, 1, 5, 'Отличный отель! Чисто, уютно, персонал вежливый. Обязательно вернусь!'),
(2, 3, 4, 'Люкс просто шикарный! Вид на город завораживает. Единственный минус - дорогой мини-бар.'),
(3, 2, 5, 'Студия отличная! Всё продумано до мелочей. Очень понравился дизайн.'),
(4, 1, 3, 'Неплохо, но для стандарта цена завышена. Ванная комната маленькая.'),
(1, 5, 5, 'Семейный номер - спасение для большой семьи! Дети в восторге!');

-- =============================================
-- 9. ПОЛЕЗНЫЕ ЗАПРОСЫ ДЛЯ ПРОВЕРКИ
-- =============================================

-- 9.1 Все номера с их удобствами
SELECT 
    r.id,
    r.category,
    r.price_per_person,
    r.max_guests,
    r.description,
    GROUP_CONCAT(rf.name, ', ') as features
FROM rooms r
LEFT JOIN room_feature_association rfa ON r.id = rfa.room_id
LEFT JOIN room_features rf ON rfa.feature_id = rf.id
GROUP BY r.id;

-- 9.2 Активные бронирования
SELECT 
    b.id,
    b.guest_name,
    b.guest_last_name,
    r.category as room_category,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    b.status
FROM bookings b
JOIN rooms r ON b.room_id = r.id
WHERE b.status IN ('pending', 'approved')
ORDER BY b.check_in_date;

-- 9.3 Статистика бронирований по статусам
SELECT 
    status,
    COUNT(*) as count,
    SUM(total_price) as total_revenue
FROM bookings
GROUP BY status;

-- 9.4 Самые популярные номера
SELECT 
    r.category,
    COUNT(b.id) as bookings_count,
    AVG(rv.rating) as avg_rating
FROM rooms r
LEFT JOIN bookings b ON r.id = b.room_id AND b.status = 'approved'
LEFT JOIN reviews rv ON r.id = rv.room_id
GROUP BY r.id
ORDER BY bookings_count DESC;

-- 9.5 Загрузка номеров по месяцам
SELECT 
    strftime('%Y-%m', check_in_date) as month,
    COUNT(*) as bookings_total,
    SUM(total_price) as revenue
FROM bookings
WHERE status = 'approved'
GROUP BY month
ORDER BY month DESC;

-- 9.6 Средний чек по категориям номеров
SELECT 
    r.category,
    AVG(b.total_price) as avg_booking_price,
    AVG(b.total_price / b.guests_count) as avg_price_per_guest
FROM bookings b
JOIN rooms r ON b.room_id = r.id
WHERE b.status = 'approved'
GROUP BY r.category;