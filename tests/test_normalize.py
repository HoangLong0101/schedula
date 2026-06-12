from booking_cascade.normalize import (
    canonicalize_service_type,
    normalize_date,
    normalize_email,
    normalize_phone,
    normalize_time,
)


class TestNormalizeDate:
    def test_thu_hai_tuan_sau(self, reference_datetime):
        result = normalize_date("thứ hai tuần sau", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-15"

    def test_thu_ba_tuan_sau(self, reference_datetime):
        result = normalize_date("thứ ba tuần sau", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-16"

    def test_ngay_mai(self, reference_datetime):
        result = normalize_date("ngày mai", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-13"

    def test_ngay_mot(self, reference_datetime):
        result = normalize_date("ngày mốt", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-14"

    def test_bare_weekday_resolves_to_upcoming_occurrence(self, reference_datetime):
        # Reference is a Friday, so "thứ sáu" means next Friday, not today.
        result = normalize_date("thứ sáu", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-19"

    def test_numeric_weekday(self, reference_datetime):
        result = normalize_date("thứ 7", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-13"

    def test_chu_nhat(self, reference_datetime):
        result = normalize_date("chủ nhật", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-14"

    def test_dmy_slash_form(self, reference_datetime):
        result = normalize_date("15/6", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-15"

    def test_ngay_thang_form(self, reference_datetime):
        result = normalize_date("ngày 20 tháng 6", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-06-20"

    def test_bare_day_rolls_to_next_month_when_passed(self, reference_datetime):
        result = normalize_date("ngày 5", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-07-05"

    def test_explicit_iso_date(self, reference_datetime):
        result = normalize_date("2026-07-01", reference_datetime)
        assert result.success
        assert result.iso_date == "2026-07-01"

    def test_past_date_is_rejected_with_warning(self, reference_datetime):
        result = normalize_date("hôm qua", reference_datetime)
        assert not result.success
        assert result.iso_date is None
        assert result.warning is not None
        assert "đã qua" in result.warning

    def test_unparseable_date(self, reference_datetime):
        result = normalize_date("blorp99", reference_datetime)
        assert not result.success
        assert result.iso_date is None
        assert result.warning is not None


class TestNormalizeTime:
    def test_3_gio_chieu(self):
        result = normalize_time("3 giờ chiều")
        assert result.success
        assert result.time_24h == "15:00"

    def test_3_ruoi_chieu(self):
        result = normalize_time("3 rưỡi chiều")
        assert result.success
        assert result.time_24h == "15:30"

    def test_24h_passthrough(self):
        result = normalize_time("15:00")
        assert result.success
        assert result.time_24h == "15:00"

    def test_15h30(self):
        result = normalize_time("15h30")
        assert result.success
        assert result.time_24h == "15:30"

    def test_9_gio_sang(self):
        result = normalize_time("9 giờ sáng")
        assert result.success
        assert result.time_24h == "09:00"

    def test_12_gio_trua_is_noon(self):
        result = normalize_time("12 giờ trưa")
        assert result.success
        assert result.time_24h == "12:00"

    def test_7_gio_toi(self):
        result = normalize_time("7 giờ tối")
        assert result.success
        assert result.time_24h == "19:00"

    def test_unambiguous_24h_hour_without_period(self):
        result = normalize_time("14h")
        assert result.success
        assert result.time_24h == "14:00"

    def test_bare_number_is_ambiguous(self):
        result = normalize_time("8")
        assert not result.success
        assert result.time_24h is None
        assert "buổi" in result.warning

    def test_low_hour_without_period_is_ambiguous(self):
        result = normalize_time("8 giờ")
        assert not result.success
        assert result.time_24h is None

    def test_unparseable_time(self):
        result = normalize_time("xế trưa gì đó")
        assert not result.success
        assert result.time_24h is None


class TestNormalizePhone:
    def test_canonical_passthrough(self):
        result = normalize_phone("0901234567")
        assert result.success
        assert result.phone == "0901234567"

    def test_plus_84_with_separators(self):
        result = normalize_phone("+84 90 123 4567")
        assert result.success
        assert result.phone == "0901234567"

    def test_invalid_phone(self):
        result = normalize_phone("12345")
        assert not result.success
        assert result.phone is None
        assert "không hợp lệ" in result.warning


class TestNormalizeEmail:
    def test_lowercased(self):
        result = normalize_email("Ngoc.Tran@Gmail.com")
        assert result.success
        assert result.email == "ngoc.tran@gmail.com"

    def test_invalid_email(self):
        result = normalize_email("not-an-email")
        assert not result.success
        assert result.email is None


class TestCanonicalizeServiceType:
    def test_massage_variants(self):
        assert canonicalize_service_type("mát xa toàn thân") == "massage toàn thân"
        assert canonicalize_service_type("massage body") == "massage toàn thân"
        assert canonicalize_service_type("Massage Toàn Thân") == "massage toàn thân"

    def test_facial_variants(self):
        assert canonicalize_service_type("facial") == "chăm sóc da mặt"
        assert canonicalize_service_type("làm mặt") == "chăm sóc da mặt"

    def test_goi_dau(self):
        assert canonicalize_service_type("gội đầu") == "gội đầu dưỡng sinh"

    def test_nail(self):
        assert canonicalize_service_type("làm nail") == "làm móng"

    def test_unknown_service(self):
        assert canonicalize_service_type("cắt tóc undercut") is None
