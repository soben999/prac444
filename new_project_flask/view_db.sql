-- =============================================
-- ПРОСТЫЕ ЗАПРОСЫ ДЛЯ ПРОСМОТРА ДАННЫХ
-- =============================================

-- 1. Все пользователи
SELECT * FROM users;

-- 2. Все номера
SELECT * FROM rooms;

-- 3. Все удобства
SELECT * FROM room_features;

-- 4. Все бронирования с информацией о номерах
SELECT 
    b.id,
    b.guest_last_name || ' ' || b.guest_name as full_name,
    r.category as room,
    b.check_in_date,
    b.check_out_date,
    b.total_price,
    b.status
FROM bookings b
JOIN rooms r ON b.room_id = r.id
ORDER BY b.created_at DESC;

-- 5. Отзывы с рейтингом
SELECT 
    u.username,
    r.category,
    rv.rating,
    rv.comment,
    rv.created_at
FROM reviews rv
LEFT JOIN users u ON rv.user_id = u.id
LEFT JOIN rooms r ON rv.room_id = r.id
ORDER BY rv.created_at DESC;

-- 6. Номера с полным списком удобств
SELECT 
    r.category,
    GROUP_CONCAT(rf.name, ', ') as amenities
FROM rooms r
LEFT JOIN room_feature_association rfa ON r.id = rfa.room_id
LEFT JOIN room_features rf ON rfa.feature_id = rf.id
GROUP BY r.id;