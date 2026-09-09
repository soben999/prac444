(function () {
    'use strict';

    var roomSelect = document.getElementById('room_id');
    var checkInInput = document.getElementById('check_in');
    var checkOutInput = document.getElementById('check_out');
    var guestsInput = document.getElementById('guests_count');
    var calendarEl = document.getElementById('booking-calendar');
    var errorEl = document.getElementById('js-date-error');
    var priceEl = document.getElementById('price-summary');

    if (!roomSelect || !calendarEl) {
        return;
    }

    function toISODate(d) {
        var y = d.getFullYear();
        var m = String(d.getMonth() + 1).padStart(2, '0');
        var day = String(d.getDate()).padStart(2, '0');
        return y + '-' + m + '-' + day;
    }

    function parseISODate(s) {
        var parts = s.split('-').map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2]);
    }

    function isSameDay(a, b) {
        return a && b && a.getFullYear() === b.getFullYear() &&
            a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function isBefore(a, b) { return a.getTime() < b.getTime(); }
    function isBeforeOrSame(a, b) { return a.getTime() <= b.getTime(); }

    var todayStr = checkInInput.min || toISODate(new Date());
    var today = parseISODate(todayStr);

    var state = {
        bookings: [],
        maxGuests: null,
        price: 0,
        checkIn: checkInInput.value ? parseISODate(checkInInput.value) : null,
        checkOut: checkOutInput.value ? parseISODate(checkOutInput.value) : null,
        viewYear: today.getFullYear(),
        viewMonth: today.getMonth()
    };

    // Занят ли день d в брони [check_in, check_out) выбранного номера
    function isBusy(d) {
        for (var i = 0; i < state.bookings.length; i++) {
            var ci = parseISODate(state.bookings[i].check_in);
            var co = parseISODate(state.bookings[i].check_out);
            if (!isBefore(d, ci) && isBefore(d, co)) {
                return true;
            }
        }
        return false;
    }

    function isPast(d) {
        return isBefore(d, today);
    }

    // Есть ли занятый день внутри полуоткрытого диапазона [start, end)
    function rangeHasBusy(start, end) {
        var cur = new Date(start);
        while (isBefore(cur, end)) {
            if (isBusy(cur)) return true;
            cur.setDate(cur.getDate() + 1);
        }
        return false;
    }

    function showError(msg) {
        errorEl.textContent = msg;
        errorEl.classList.remove('d-none');
    }

    function clearError() {
        errorEl.textContent = '';
        errorEl.classList.add('d-none');
    }

    function updatePriceSummary() {
        if (!state.checkIn || !state.checkOut || !state.price) {
            priceEl.textContent = '';
            return;
        }
        var nights = Math.round((state.checkOut - state.checkIn) / 86400000);
        var guests = parseInt(guestsInput.value, 10) || 1;
        var total = nights * guests * state.price;
        priceEl.textContent = 'Ночей: ' + nights + ' × Гостей: ' + guests +
            ' × ' + state.price + ' ₽ = Итого: ' + total.toLocaleString('ru-RU') + ' ₽';
    }

    function loadRoomData() {
        var opt = roomSelect.options[roomSelect.selectedIndex];
        if (!opt || !opt.value) {
            state.bookings = [];
            state.maxGuests = null;
            state.price = 0;
            renderCalendar();
            updatePriceSummary();
            return;
        }
        try {
            state.bookings = JSON.parse(opt.getAttribute('data-bookings') || '[]');
        } catch (e) {
            state.bookings = [];
        }
        state.maxGuests = parseInt(opt.getAttribute('data-max-guests'), 10) || null;
        state.price = parseFloat(opt.getAttribute('data-price')) || 0;

        if (state.maxGuests) {
            guestsInput.max = state.maxGuests;
            if (guestsInput.value && parseInt(guestsInput.value, 10) > state.maxGuests) {
                guestsInput.value = state.maxGuests;
            }
        }

        if (state.checkIn && state.checkOut && rangeHasBusy(state.checkIn, state.checkOut)) {
            showError('Для выбранного номера этот период уже занят. Пожалуйста, выберите другие даты.');
            state.checkIn = null;
            state.checkOut = null;
            checkInInput.value = '';
            checkOutInput.value = '';
        }

        renderCalendar();
        updatePriceSummary();
    }

    function onDayClick(d) {
        clearError();
        if (!state.checkIn || (state.checkIn && state.checkOut)) {
            state.checkIn = d;
            state.checkOut = null;
        } else if (isBeforeOrSame(d, state.checkIn)) {
            state.checkIn = d;
            state.checkOut = null;
        } else if (rangeHasBusy(state.checkIn, d)) {
            showError('В выбранный период попадает уже занятая дата. Выберите другой диапазон.');
            state.checkIn = d;
            state.checkOut = null;
        } else {
            state.checkOut = d;
        }

        checkInInput.value = state.checkIn ? toISODate(state.checkIn) : '';
        checkOutInput.value = state.checkOut ? toISODate(state.checkOut) : '';

        renderCalendar();
        updatePriceSummary();
    }

    function renderCalendar() {
        calendarEl.innerHTML = '';
        var wrapper = document.createElement('div');
        wrapper.className = 'booking-calendar';

        var header = document.createElement('div');
        header.className = 'cal-header';

        var prevBtn = document.createElement('button');
        prevBtn.type = 'button';
        prevBtn.className = 'cal-nav-btn';
        prevBtn.textContent = '‹';
        prevBtn.setAttribute('aria-label', 'Предыдущий месяц');
        prevBtn.addEventListener('click', function () {
            state.viewMonth--;
            if (state.viewMonth < 0) { state.viewMonth = 11; state.viewYear--; }
            renderCalendar();
        });

        var nextBtn = document.createElement('button');
        nextBtn.type = 'button';
        nextBtn.className = 'cal-nav-btn';
        nextBtn.textContent = '›';
        nextBtn.setAttribute('aria-label', 'Следующий месяц');
        nextBtn.addEventListener('click', function () {
            state.viewMonth++;
            if (state.viewMonth > 11) { state.viewMonth = 0; state.viewYear++; }
            renderCalendar();
        });

        var monthNames = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
        var title = document.createElement('span');
        title.textContent = monthNames[state.viewMonth] + ' ' + state.viewYear;

        header.appendChild(prevBtn);
        header.appendChild(title);
        header.appendChild(nextBtn);
        wrapper.appendChild(header);

        var grid = document.createElement('div');
        grid.className = 'cal-grid';

        ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].forEach(function (wd) {
            var el = document.createElement('div');
            el.className = 'cal-weekday';
            el.textContent = wd;
            grid.appendChild(el);
        });

        var firstOfMonth = new Date(state.viewYear, state.viewMonth, 1);
        var startOffset = (firstOfMonth.getDay() + 6) % 7;
        var daysInMonth = new Date(state.viewYear, state.viewMonth + 1, 0).getDate();

        for (var i = 0; i < startOffset; i++) {
            var empty = document.createElement('div');
            empty.className = 'cal-day cal-empty';
            grid.appendChild(empty);
        }

        var roomChosen = !!roomSelect.value;

        for (var day = 1; day <= daysInMonth; day++) {
            var d = new Date(state.viewYear, state.viewMonth, day);
            var cell = document.createElement('div');
            cell.className = 'cal-day';
            cell.textContent = String(day);

            var past = isPast(d);
            var busy = roomChosen && isBusy(d);

            if (past) cell.classList.add('cal-past');
            if (busy) cell.classList.add('cal-busy');
            if (isSameDay(d, today)) cell.classList.add('cal-today');
            if (state.checkIn && isSameDay(d, state.checkIn)) cell.classList.add('cal-selected');
            if (state.checkOut && isSameDay(d, state.checkOut)) cell.classList.add('cal-selected');
            if (state.checkIn && state.checkOut && isBefore(state.checkIn, d) && isBefore(d, state.checkOut)) {
                cell.classList.add('cal-in-range');
            }

            if (!past && !busy && roomChosen) {
                cell.addEventListener('click', (function (clickedDate) {
                    return function () { onDayClick(clickedDate); };
                })(d));
            } else if (!roomChosen && !past) {
                cell.classList.add('cal-past');
            }

            grid.appendChild(cell);
        }

        wrapper.appendChild(grid);
        calendarEl.appendChild(wrapper);
    }

    function syncFromNativeInputs() {
        clearError();
        var ci = checkInInput.value ? parseISODate(checkInInput.value) : null;
        var co = checkOutInput.value ? parseISODate(checkOutInput.value) : null;

        if (ci && isPast(ci)) {
            showError('Дата заезда не может быть раньше сегодняшнего дня.');
        } else if (ci && co && !isBefore(ci, co)) {
            showError('Дата выезда должна быть позже даты заезда.');
            co = null;
            checkOutInput.value = '';
        } else if (ci && co && rangeHasBusy(ci, co)) {
            showError('На выбранный период номер уже забронирован. Пожалуйста, выберите другие даты.');
        }

        state.checkIn = ci;
        state.checkOut = co;
        if (ci) { state.viewYear = ci.getFullYear(); state.viewMonth = ci.getMonth(); }
        renderCalendar();
        updatePriceSummary();
    }

    roomSelect.addEventListener('change', loadRoomData);
    guestsInput.addEventListener('input', updatePriceSummary);
    checkInInput.addEventListener('change', syncFromNativeInputs);
    checkOutInput.addEventListener('change', syncFromNativeInputs);

    var form = document.getElementById('order-form');
    if (form) {
        form.addEventListener('submit', function (e) {
            clearError();
            var ci = checkInInput.value ? parseISODate(checkInInput.value) : null;
            var co = checkOutInput.value ? parseISODate(checkOutInput.value) : null;

            if (!roomSelect.value) {
                e.preventDefault();
                showError('Выберите номер.');
                return;
            }
            if (!ci || isPast(ci)) {
                e.preventDefault();
                showError('Дата заезда не может быть раньше сегодняшнего дня.');
                return;
            }
            if (!co || !isBefore(ci, co)) {
                e.preventDefault();
                showError('Дата выезда должна быть позже даты заезда.');
                return;
            }
            if (rangeHasBusy(ci, co)) {
                e.preventDefault();
                showError('На выбранный период номер уже забронирован (заявка одобрена). Выберите другой период.');
            }
        });
    }

    if (state.checkIn) {
        state.viewYear = state.checkIn.getFullYear();
        state.viewMonth = state.checkIn.getMonth();
    }
    loadRoomData();
})();
