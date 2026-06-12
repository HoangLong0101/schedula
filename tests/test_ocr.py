from booking_cascade.ocr import OCRConfig, is_booking_line, read_image
from tests._helpers import FakeOCRReader, make_ocr_line


def test_read_image_filters_low_confidence_lines():
    reader = FakeOCRReader(
        [
            make_ocr_line("Đặt lịch massage thứ ba tuần sau", 0.95),
            make_ocr_line("nhiễu mờ", 0.1),  # below min_confidence
        ]
    )

    result = read_image(b"fake-image", OCRConfig(), reader=reader)

    assert [line.text for line in result.lines] == ["Đặt lịch massage thứ ba tuần sau"]
    assert reader.calls == [b"fake-image"]


def test_booking_lines_are_isolated_from_screenshot_noise():
    reader = FakeOCRReader(
        [
            make_ocr_line("Tin nhắn", 0.9),
            make_ocr_line("Đang hoạt động", 0.9),
            make_ocr_line("Đặt lịch massage toàn thân thứ ba tuần sau", 0.95),
            make_ocr_line("lúc 3 giờ chiều, tên em là Ngọc", 0.9),
            make_ocr_line("sđt 0901234567", 0.9),
            make_ocr_line("Thích · Trả lời", 0.9),
        ]
    )

    result = read_image(b"img", OCRConfig(), reader=reader)

    assert result.booking_lines == [
        "Đặt lịch massage toàn thân thứ ba tuần sau",
        "lúc 3 giờ chiều, tên em là Ngọc",
        "sđt 0901234567",
    ]
    assert result.booking_text == (
        "Đặt lịch massage toàn thân thứ ba tuần sau "
        "lúc 3 giờ chiều, tên em là Ngọc "
        "sđt 0901234567"
    )
    assert "Đang hoạt động" in result.full_text  # full text keeps everything


def test_falls_back_to_all_text_when_nothing_looks_booking_related():
    reader = FakeOCRReader(
        [make_ocr_line("xin chào", 0.9), make_ocr_line("cảm ơn nha", 0.9)]
    )

    result = read_image(b"img", OCRConfig(), reader=reader)

    assert result.booking_lines == []
    assert result.booking_text == "xin chào cảm ơn nha"


def test_is_booking_line_examples():
    assert is_booking_line("Đặt lịch gội đầu giúp mình")
    assert is_booking_line("15h30 nhé")
    assert is_booking_line("thứ 7 này")
    assert is_booking_line("0901234567")
    assert is_booking_line("ngoc.tran@gmail.com")
    assert not is_booking_line("Đang hoạt động")
    assert not is_booking_line("Thích · Trả lời")
