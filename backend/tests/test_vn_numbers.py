import pytest

from app.pipeline import vn_numbers as vn


@pytest.mark.parametrize("text,expected", [
    ("mười hai", "12"),
    ("Lan có mười hai cái kẹo", "lan có 12 cái kẹo"),
    ("hai mươi lăm", "25"),
    ("hai lăm", "25"),
    ("hai mươi mốt", "21"),
    ("năm mươi tư", "54"),
    ("mười lăm", "15"),
    ("một trăm linh năm", "105"),
    ("một trăm không năm", "105"),
    ("ba nghìn hai trăm", "3200"),
    ("hai chục", "20"),
    ("một hai ba", "1 2 3"),
    ("bạn có biết không", "bạn có biết không"),  # "không" đứng một mình không phải số
    ("thứ tư", "thứ tư"),
])
def test_words_to_digits(text, expected):
    assert vn.words_to_digits(text) == expected


@pytest.mark.parametrize("text,expected", [
    ("12 cái kẹo", ["12"]),
    ("2,5 kg và 1.000 đồng", ["2.5", "1000"]),
    ("3/4 cái bánh", ["3/4"]),
    ("mười hai cái", ["12"]),
    ("7 + 5 = ?", ["7", "5"]),
])
def test_extract_numbers(text, expected):
    assert vn.extract_numbers(text) == expected


def test_numeric_value_and_same_number():
    assert vn.numeric_value("12 cái kẹo") == "12"
    assert vn.numeric_value("sách") is None
    assert vn.same_number("0.5", "1/2")
    assert vn.same_number("2.50", "2.5")
    assert not vn.same_number("12", "21")
