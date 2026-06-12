from booking_cascade.intent import detect_intent


def test_dat_lich_is_book():
    result = detect_intent("Mình muốn đặt lịch massage cho tuần sau")
    assert result.intent == "book"
    assert "đặt lịch" in result.matched_phrase


def test_no_explicit_marker_defaults_to_book():
    result = detect_intent("Cho mình làm chăm sóc da mặt ngày mai nhé")
    assert result.intent == "book"
    assert result.matched_phrase is None


def test_huy_is_cancel():
    result = detect_intent("Mình muốn hủy lịch hẹn ngày mai")
    assert result.intent == "cancel"
    assert "hủy" in result.matched_phrase


def test_huy_alternate_unicode_spelling_is_cancel():
    # "huỷ" (ỷ) vs "hủy" (ủ): both common spellings must be recognized.
    result = detect_intent("Cho em huỷ buổi hẹn chiều nay với")
    assert result.intent == "cancel"


def test_doi_lich_is_reschedule():
    result = detect_intent("Mình muốn đổi lịch hẹn sang ngày khác")
    assert result.intent == "reschedule"


def test_doi_keyword_is_reschedule():
    result = detect_intent("Dời lịch hẹn thứ năm của mình sang thứ sáu")
    assert result.intent == "reschedule"


def test_query_may_gio():
    result = detect_intent("Lịch hẹn của tôi lúc mấy giờ vậy?")
    assert result.intent == "query"


def test_cancel_takes_priority_over_reschedule_phrasing():
    # "thật ra"-type correction words alone shouldn't flip this to
    # reschedule -- explicit cancel wins.
    result = detect_intent("Thật ra mình muốn hủy lịch luôn, khỏi dời nữa")
    assert result.intent == "cancel"


def test_correction_message_defaults_to_book_when_no_keyword():
    result = detect_intent("à không, đổi lại 4 giờ chiều")
    assert result.intent == "book"
