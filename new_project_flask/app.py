from datetime import date, datetime
from functools import wraps

from flask import (
    Flask, request, render_template, redirect, url_for, session, flash
)

import db

app = Flask(__name__)
app.secret_key = 'hotel-svetlye-sny-secret-key'  # нужен для сессий и flash-сообщений

ADMIN_LOGIN = 'hotel123'
ADMIN_PASSWORD = 'adminHotel'

db.init_db()


def login_required(view):
    """Доступ к панели управления только после входа администратора."""
    @wraps(view)
    def wrapped(*args, **kwargs):
        if not session.get('is_admin'):
            flash('Пожалуйста, войдите в панель управления.', 'warning')
            return redirect(url_for('login', next=request.path))
        return view(*args, **kwargs)
    return wrapped


def parse_date(value):
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except (TypeError, ValueError):
        return None


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')

        if username == ADMIN_LOGIN and password == ADMIN_PASSWORD:
            session['is_admin'] = True
            flash('Успешный вход!', 'success')
            next_url = request.args.get('next') or url_for('admin')
            return redirect(next_url)

        flash('Неверный логин или пароль.', 'danger')
        return render_template('login.html'), 401

    return render_template('login.html')


@app.route('/logout')
def logout():
    session.pop('is_admin', None)
    flash('Вы вышли из панели управления.', 'success')
    return redirect(url_for('index'))


@app.route('/', methods=['GET'])
def index():
    category = request.args.get('category') or None
    rooms = db.get_rooms(category=category)
    categories = db.get_categories()
    return render_template(
        'index.html', rooms=rooms, categories=categories, active_category=category
    )


@app.route('/admin')
@login_required
def admin():
    bookings = db.get_all_bookings()
    return render_template('admin.html', bookings=bookings)


@app.route('/admin/booking/<int:booking_id>/approve', methods=['POST'])
@login_required
def admin_approve_booking(booking_id):
    db.approve_booking(booking_id)
    flash('Заявка одобрена.', 'success')
    return redirect(url_for('admin'))


@app.route('/admin/booking/<int:booking_id>/delete', methods=['POST'])
@login_required
def admin_delete_booking(booking_id):
    db.delete_booking(booking_id)
    flash('Заявка удалена.', 'success')
    return redirect(url_for('admin'))


@app.route('/order', methods=['GET', 'POST'])
def order():
    rooms = db.get_rooms()
    bookings_by_room = db.get_approved_bookings_by_room()
    today = date.today().isoformat()

    if request.method == 'POST':
        form = request.form
        errors = []

        name = (form.get('name') or '').strip()
        last_name = (form.get('last_name') or '').strip()
        phone = (form.get('phone') or '').strip()
        email = (form.get('email') or '').strip()
        room_id_raw = form.get('room_id')
        guests_raw = form.get('guests_count')
        check_in_raw = form.get('check_in')
        check_out_raw = form.get('check_out')

        if not name:
            errors.append('Укажите имя.')
        if not last_name:
            errors.append('Укажите фамилию.')
        if not phone:
            errors.append('Укажите телефон.')
        if not email:
            errors.append('Укажите почту.')

        room = None
        try:
            room_id = int(room_id_raw)
            room = db.get_room(room_id)
        except (TypeError, ValueError):
            room_id = None
        if not room:
            errors.append('Выберите номер для бронирования.')

        try:
            guests_count = int(guests_raw)
        except (TypeError, ValueError):
            guests_count = None
        if not guests_count or guests_count < 1:
            errors.append('Укажите количество гостей.')
        elif room and guests_count > room['max_guests']:
            errors.append(
                f'Для номера "{room["category"]}" максимум {room["max_guests"]} гостей.'
            )

        check_in = parse_date(check_in_raw)
        check_out = parse_date(check_out_raw)

        if not check_in:
            errors.append('Укажите корректную дату заезда.')
        elif check_in < date.today():
            errors.append('Дата заезда не может быть раньше сегодняшнего дня.')

        if not check_out:
            errors.append('Укажите корректную дату выезда.')
        elif check_in and check_out <= check_in:
            errors.append('Дата выезда должна быть позже даты заезда.')

        if room and check_in and check_out and check_in >= date.today() and check_out > check_in:
            if db.room_has_approved_overlap(room['id'], check_in.isoformat(), check_out.isoformat()):
                errors.append(
                    'На выбранные даты номер уже забронирован (заявка одобрена). '
                    'Пожалуйста, выберите другой период — занятые даты отмечены в календаре.'
                )

        if errors:
            for e in errors:
                flash(e, 'danger')
            selected_room_id = room['id'] if room else (int(room_id_raw) if room_id_raw and room_id_raw.isdigit() else None)
            return render_template(
                'order.html', rooms=rooms, bookings_by_room=bookings_by_room,
                today=today, form_data=form, selected_room_id=selected_room_id,
            ), 400

        nights = (check_out - check_in).days
        total_price = float(room['price_per_person']) * guests_count * nights

        db.create_booking({
            'room_id': room['id'],
            'guest_name': name,
            'guest_last_name': last_name,
            'phone': phone,
            'email': email,
            'check_in_date': check_in.isoformat(),
            'check_out_date': check_out.isoformat(),
            'guests_count': guests_count,
            'total_price': total_price,
        })

        flash('Заявка успешно отправлена! Мы свяжемся с вами после подтверждения.', 'success')
        return redirect(url_for('order'))

    room_id_param = request.args.get('room_id', type=int)
    return render_template(
        'order.html', rooms=rooms, bookings_by_room=bookings_by_room,
        today=today, form_data={}, selected_room_id=room_id_param,
    )


if __name__ == '__main__':
    app.run(debug=True)
