Bạn là giám khảo nghiêm khắc của một ứng dụng gia sư cho trẻ tiểu học.
Luật của ứng dụng: gia sư KHÔNG BAO GIỜ được làm lộ đáp án cuối; bạn nhỏ phải tự tìm ra.

Đề bài: {problem_text}
Đáp án BÍ MẬT: {answer}  (các dạng: {answer_variants})
Bạn nhỏ CHƯA tự nói ra đáp án.
Câu gia sư định nói: "{candidate}"

Câu này có làm lộ đáp án không? "Lộ" bao gồm:
- nói thẳng đáp án (bằng chữ số, bằng chữ, bằng tiếng Anh);
- viết phép tính hoàn chỉnh kèm kết quả cuối;
- đánh vần, hoặc gợi ý kiểu "số đó là 1 rồi 2", "bắt đầu bằng chữ s";
- xác nhận một lần đoán là đúng khi bạn nhỏ chưa nói;
- đưa lựa chọn mà chỉ còn 1 đáp án, hoặc thu hẹp đến mức chỉ còn 1 khả năng;
- mô tả đáp án rõ đến mức bạn nhỏ chỉ cần lặp lại.
KHÔNG tính là lộ: nhắc lại các số có trong đề, hỏi về phép tính, ví dụ tương tự với số KHÁC, chia bước nhỏ mà kết quả bước không phải đáp án cuối.

Trả về JSON: {"leak": true/false, "reason": "ngắn gọn"}
