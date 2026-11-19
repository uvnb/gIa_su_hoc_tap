/// 🇻🇳 "Việt Nam quê em" – Lịch sử, Địa lý, Văn hóa cho học sinh tiểu học.
/// Mỗi thẻ: chuyện ngắn Cú kể (3–4 câu, từ ngữ đơn giản) + một câu đố 3 lựa chọn.
/// Chỉ dùng sự kiện, số liệu phổ biến trong sách giáo khoa; truyền thuyết ghi rõ là truyền thuyết.
library;

class VnCard {
  final String id;
  final String emoji;
  final String title;
  final String story;
  final String question;
  final String answer;
  final List<String> wrong;
  final String fact; // câu "Bạn có biết?" ngắn cho màn chính
  const VnCard(this.id, this.emoji, this.title, this.story, this.question, this.answer, this.wrong, this.fact);

  List<String> get options => [answer, ...wrong];
}

class VnTopic {
  final String id, emoji, title, subtitle;
  final List<VnCard> cards;
  const VnTopic(this.id, this.emoji, this.title, this.subtitle, this.cards);
}

const vnTopics = <VnTopic>[
  VnTopic('history', '📜', 'Lịch sử', 'Chuyện ông cha ta', [
    VnCard(
        'hung_vuong',
        '👑',
        'Các Vua Hùng dựng nước',
        'Theo truyền thuyết, các Vua Hùng đã dựng nên nước Văn Lang – nhà nước đầu tiên của người Việt. '
            'Đền thờ các Vua Hùng ở Phú Thọ. Hằng năm, ngày 10 tháng 3 âm lịch là ngày Giỗ Tổ Hùng Vương '
            'để con cháu nhớ ơn tổ tiên.',
        'Ngày Giỗ Tổ Hùng Vương là ngày nào?',
        'Ngày 10 tháng 3 âm lịch',
        ['Ngày 1 tháng 1 âm lịch', 'Ngày 15 tháng 8 âm lịch'],
        'Ngày 10 tháng 3 âm lịch là ngày Giỗ Tổ Hùng Vương.'),
    VnCard(
        'thanh_giong',
        '🐎',
        'Thánh Gióng',
        'Truyền thuyết kể rằng cậu bé làng Gióng lên ba tuổi vẫn chưa biết nói. Khi giặc Ân đến, cậu bỗng '
            'vươn vai thành tráng sĩ, cưỡi ngựa sắt đánh giặc. Roi sắt gãy, Gióng nhổ những bụi tre bên đường '
            'quật vào giặc, rồi bay về trời.',
        'Khi roi sắt gãy, Thánh Gióng lấy gì để đánh giặc?',
        'Những bụi tre',
        ['Cây chuối', 'Cây cau'],
        'Truyền thuyết Thánh Gióng kể về cậu bé vươn vai thành tráng sĩ đánh giặc Ân.'),
    VnCard(
        'hai_ba_trung',
        '⚔️',
        'Hai Bà Trưng',
        'Năm 40, hai chị em Trưng Trắc và Trưng Nhị phất cờ khởi nghĩa, đánh đuổi quân xâm lược nhà Hán. '
            'Hai Bà là những nữ anh hùng đầu tiên trong lịch sử nước ta.',
        'Hai Bà Trưng là hai chị em tên gì?',
        'Trưng Trắc và Trưng Nhị',
        ['Trưng Mai và Trưng Lan', 'Trưng Hoa và Trưng Nguyệt'],
        'Hai Bà Trưng khởi nghĩa năm 40 – những nữ anh hùng đầu tiên của nước ta.'),
    VnCard(
        'ngo_quyen',
        '🌊',
        'Ngô Quyền và sông Bạch Đằng',
        'Năm 938, Ngô Quyền cho cắm thật nhiều cọc gỗ đầu nhọn bịt sắt dưới lòng sông Bạch Đằng. Khi nước '
            'triều rút, thuyền giặc Nam Hán mắc cọc, vỡ tan. Chiến thắng này mở ra thời kì độc lập lâu dài.',
        'Ngô Quyền cắm gì dưới lòng sông Bạch Đằng?',
        'Cọc gỗ đầu nhọn',
        ['Lưới đánh cá', 'Những chiếc thuyền'],
        'Năm 938, Ngô Quyền đánh tan quân Nam Hán trên sông Bạch Đằng.'),
    VnCard(
        'ly_thai_to',
        '🐉',
        'Lý Thái Tổ dời đô',
        'Năm 1010, vua Lý Thái Tổ dời đô từ Hoa Lư về thành Đại La và đặt tên mới là Thăng Long, nghĩa là '
            '"rồng bay lên". Thăng Long chính là Hà Nội ngày nay.',
        'Thăng Long có nghĩa là gì?',
        'Rồng bay lên',
        ['Rồng nằm ngủ', 'Chim bay về'],
        'Năm 1010, vua Lý Thái Tổ dời đô về Thăng Long – Hà Nội ngày nay.'),
    VnCard(
        'tran_hung_dao',
        '🛡️',
        'Trần Hưng Đạo',
        'Thời nhà Trần, quân dân Đại Việt ba lần đánh thắng quân Mông – Nguyên rất hùng mạnh. Hưng Đạo Đại '
            'Vương Trần Quốc Tuấn là vị tướng tài giỏi, năm 1288 lại đánh tan giặc trên sông Bạch Đằng.',
        'Thời nhà Trần, quân dân ta ba lần đánh thắng quân nào?',
        'Quân Mông – Nguyên',
        ['Quân Nam Hán', 'Quân Thanh'],
        'Thời nhà Trần, quân dân ta ba lần đánh thắng quân Mông – Nguyên.'),
    VnCard(
        'le_loi',
        '🐢',
        'Lê Lợi và Hồ Gươm',
        'Lê Lợi lãnh đạo khởi nghĩa Lam Sơn suốt 10 năm, đánh đuổi quân Minh. Truyền thuyết kể rằng sau chiến '
            'thắng, nhà vua dạo thuyền trên hồ thì Rùa Vàng nổi lên xin lại thanh gươm thần. Từ đó hồ có tên '
            'Hồ Hoàn Kiếm, hay Hồ Gươm.',
        'Hồ Hoàn Kiếm còn được gọi là gì?',
        'Hồ Gươm',
        ['Hồ Tây', 'Hồ Ba Bể'],
        'Hồ Hoàn Kiếm gắn với truyền thuyết vua Lê Lợi trả gươm cho Rùa Vàng.'),
    VnCard(
        'quang_trung',
        '🏇',
        'Vua Quang Trung',
        'Mùa xuân năm Kỷ Dậu 1789, vua Quang Trung – Nguyễn Huệ cho quân hành quân thần tốc ra Bắc, đánh tan '
            '29 vạn quân Thanh ngay dịp Tết, giải phóng Thăng Long.',
        'Vua Quang Trung đánh tan quân Thanh vào dịp nào?',
        'Tết Kỷ Dậu 1789',
        ['Tết Trung thu', 'Mùa hè năm 1010'],
        'Tết Kỷ Dậu 1789, vua Quang Trung đại phá quân Thanh.'),
    VnCard(
        'quoc_khanh',
        '🇻🇳',
        'Ngày Quốc khánh 2/9',
        'Ngày 2 tháng 9 năm 1945, tại Quảng trường Ba Đình, Hà Nội, Chủ tịch Hồ Chí Minh đọc bản Tuyên ngôn '
            'Độc lập, khai sinh nước Việt Nam Dân chủ Cộng hòa. Từ đó, ngày 2/9 là ngày Quốc khánh.',
        'Ngày Quốc khánh nước ta là ngày nào?',
        'Ngày 2 tháng 9',
        ['Ngày 1 tháng 6', 'Ngày 20 tháng 11'],
        'Ngày 2/9/1945, Bác Hồ đọc Tuyên ngôn Độc lập tại Quảng trường Ba Đình.'),
    VnCard(
        'thong_nhat',
        '🕊️',
        'Ngày thống nhất 30/4',
        'Ngày 30 tháng 4 năm 1975, miền Nam được hoàn toàn giải phóng, đất nước ta thống nhất, Bắc – Nam '
            'sum họp một nhà. Hằng năm cả nước kỉ niệm ngày này.',
        'Ngày 30 tháng 4 năm 1975 là ngày gì?',
        'Ngày thống nhất đất nước',
        ['Ngày Tết Trung thu', 'Ngày khai giảng năm học'],
        'Ngày 30/4/1975 là ngày đất nước ta thống nhất.'),
  ]),
  VnTopic('geography', '🗺️', 'Địa lý', 'Đất nước hình chữ S', [
    VnCard(
        'chu_s',
        '🇻🇳',
        'Đất nước hình chữ S',
        'Việt Nam nằm ở Đông Nam Á, có hình dáng cong cong giống chữ S. Phía đông là biển Đông với bờ biển '
            'dài hơn 3.000 ki-lô-mét, có rất nhiều bãi biển đẹp.',
        'Đất nước Việt Nam có hình giống chữ cái nào?',
        'Chữ S',
        ['Chữ O', 'Chữ L'],
        'Việt Nam có hình chữ S, bờ biển dài hơn 3.000 km.'),
    VnCard(
        'ha_noi',
        '🏛️',
        'Thủ đô Hà Nội',
        'Hà Nội là thủ đô của nước ta, trái tim của cả nước. Ở Hà Nội có Hồ Gươm, Văn Miếu – Quốc Tử Giám, '
            'Lăng Chủ tịch Hồ Chí Minh và nhiều phố cổ.',
        'Thủ đô của Việt Nam là thành phố nào?',
        'Hà Nội',
        ['Thành phố Hồ Chí Minh', 'Đà Nẵng'],
        'Hà Nội là thủ đô của Việt Nam.'),
    VnCard(
        'fansipan',
        '🏔️',
        'Đỉnh Fansipan',
        'Fansipan là đỉnh núi cao nhất Việt Nam, cao hơn 3.100 mét, nằm trên dãy Hoàng Liên Sơn ở miền Bắc. '
            'Người ta gọi Fansipan là "nóc nhà Đông Dương".',
        'Đỉnh núi cao nhất Việt Nam là đỉnh nào?',
        'Fansipan',
        ['Núi Bà Đen', 'Núi Ba Vì'],
        'Fansipan là đỉnh núi cao nhất Việt Nam – "nóc nhà Đông Dương".'),
    VnCard(
        'song_hong',
        '🏞️',
        'Sông Hồng và sông Cửu Long',
        'Sông Hồng ở miền Bắc có nước màu đỏ nâu vì chở nhiều phù sa. Ở miền Nam, sông Mê Kông chảy qua sáu '
            'nước rồi đổ ra biển bằng nhiều cửa, nên phần ở nước ta gọi là sông Cửu Long.',
        'Vì sao sông Hồng có tên như vậy?',
        'Vì nước sông có màu đỏ phù sa',
        ['Vì có nhiều hoa hồng hai bên bờ', 'Vì sông chảy qua núi Hồng'],
        'Sông Hồng có màu đỏ nâu vì chở nhiều phù sa.'),
    VnCard(
        'ha_long',
        '⛰️',
        'Vịnh Hạ Long',
        'Vịnh Hạ Long ở tỉnh Quảng Ninh có hàng nghìn hòn đảo đá vôi lớn nhỏ nhô lên giữa biển xanh. '
            'Vịnh Hạ Long là Di sản thiên nhiên thế giới.',
        'Vịnh Hạ Long ở tỉnh nào?',
        'Quảng Ninh',
        ['Khánh Hòa', 'Kiên Giang'],
        'Vịnh Hạ Long ở Quảng Ninh có hàng nghìn đảo đá vôi.'),
    VnCard(
        'ba_mien',
        '🌦️',
        'Ba miền Bắc – Trung – Nam',
        'Nước ta có ba miền Bắc, Trung, Nam. Miền Bắc có bốn mùa xuân, hạ, thu, đông. Miền Nam ấm áp quanh năm '
            'và chỉ có hai mùa: mùa mưa và mùa khô.',
        'Miền Nam nước ta có mấy mùa?',
        'Hai mùa: mưa và khô',
        ['Bốn mùa', 'Một mùa'],
        'Miền Bắc có bốn mùa, miền Nam chỉ có mùa mưa và mùa khô.'),
    VnCard(
        'bien_dao',
        '🏝️',
        'Biển đảo quê hương',
        'Biển Đông của nước ta có rất nhiều đảo và quần đảo. Hai quần đảo xa bờ là Hoàng Sa và Trường Sa, '
            'nơi các chú bộ đội hải quân ngày đêm canh giữ biển trời Tổ quốc.',
        'Hai quần đảo xa bờ của Việt Nam tên là gì?',
        'Hoàng Sa và Trường Sa',
        ['Phú Quốc và Côn Đảo', 'Cát Bà và Lý Sơn'],
        'Hoàng Sa và Trường Sa là hai quần đảo của Việt Nam.'),
    VnCard(
        'son_doong',
        '🕳️',
        'Hang Sơn Đoòng',
        'Ở miền Trung có hang Sơn Đoòng – hang động tự nhiên lớn nhất thế giới. Trong hang có cả rừng cây, '
            'sông suối và mây riêng! Hang nằm trong vùng Phong Nha – Kẻ Bàng.',
        'Hang Sơn Đoòng nổi tiếng vì điều gì?',
        'Là hang động lớn nhất thế giới',
        ['Là hang có nhiều dơi nhất', 'Là hang ở trên đỉnh núi cao nhất'],
        'Hang Sơn Đoòng là hang động lớn nhất thế giới.'),
    VnCard(
        'cho_noi',
        '🛶',
        'Chợ nổi miền Tây',
        'Ở đồng bằng sông Cửu Long – vựa lúa lớn nhất nước ta – có những chợ nổi họp ngay trên sông. '
            'Người ta mua bán trái cây, rau củ trên thuyền và treo hàng lên cây "bẹo" để khách nhìn thấy.',
        'Chợ nổi miền Tây họp ở đâu?',
        'Trên sông',
        ['Trên núi', 'Trong hang'],
        'Ở miền Tây có chợ nổi – mua bán ngay trên thuyền.'),
    VnCard(
        'dan_toc',
        '🤝',
        '54 dân tộc anh em',
        'Việt Nam có 54 dân tộc anh em cùng chung sống: dân tộc Kinh, Tày, Thái, Mường, Hmông, Ê-đê, Khmer… '
            'Mỗi dân tộc có trang phục, tiếng nói và lễ hội riêng rất đẹp.',
        'Việt Nam có bao nhiêu dân tộc anh em?',
        '54 dân tộc',
        ['10 dân tộc', '100 dân tộc'],
        'Việt Nam có 54 dân tộc anh em.'),
  ]),
  VnTopic('culture', '🎎', 'Văn hóa', 'Phong tục và lễ hội', [
    VnCard(
        'tet',
        '🧧',
        'Tết Nguyên Đán',
        'Tết Nguyên Đán là Tết lớn nhất trong năm. Nhà nhà gói bánh chưng, trang trí hoa đào (miền Bắc) hay '
            'hoa mai (miền Nam). Trẻ em mặc áo mới, chúc Tết ông bà và được lì xì.',
        'Ngày Tết, miền Nam thường chưng hoa gì?',
        'Hoa mai vàng',
        ['Hoa sen', 'Hoa cúc trắng'],
        'Tết ở miền Bắc có hoa đào, miền Nam có hoa mai.'),
    VnCard(
        'banh_chung',
        '🟩',
        'Sự tích bánh chưng',
        'Truyền thuyết kể rằng hoàng tử Lang Liêu dùng gạo nếp, đậu xanh, thịt lợn gói lá dong làm bánh chưng '
            'vuông tượng trưng cho đất, dâng vua cha. Vua khen ngợi và truyền ngôi cho Lang Liêu.',
        'Theo truyền thuyết, ai làm ra bánh chưng?',
        'Hoàng tử Lang Liêu',
        ['Thánh Gióng', 'Mai An Tiêm'],
        'Theo truyền thuyết, Lang Liêu là người làm ra bánh chưng.'),
    VnCard(
        'trung_thu',
        '🏮',
        'Tết Trung thu',
        'Tết Trung thu vào rằm tháng Tám âm lịch, khi trăng tròn và sáng nhất. Các bạn nhỏ rước đèn ông sao, '
            'xem múa lân, phá cỗ với bánh nướng, bánh dẻo và nghe kể chuyện chú Cuội, chị Hằng.',
        'Tết Trung thu vào ngày nào?',
        'Rằm tháng Tám âm lịch',
        ['Mùng 1 tháng Giêng', 'Ngày 1 tháng 6'],
        'Tết Trung thu là rằm tháng Tám âm lịch.'),
    VnCard(
        'ao_dai',
        '👘',
        'Áo dài',
        'Áo dài là trang phục truyền thống rất duyên dáng của người Việt. Các cô giáo, các bạn nữ sinh hay mặc '
            'áo dài trong ngày lễ, ngày khai giảng và ngày Tết.',
        'Trang phục truyền thống của người Việt là gì?',
        'Áo dài',
        ['Áo khoác', 'Áo mưa'],
        'Áo dài là trang phục truyền thống của người Việt.'),
    VnCard(
        'non_la',
        '👒',
        'Nón lá',
        'Nón lá được làm từ lá nón phơi khô, khâu thật khéo trên khung tre. Nón che nắng, che mưa. Ở Huế có nón '
            'bài thơ – soi lên ánh nắng sẽ thấy hình và chữ ẩn bên trong.',
        'Nón lá được làm từ gì?',
        'Lá nón và khung tre',
        ['Vải và nhựa', 'Giấy và keo'],
        'Nón bài thơ xứ Huế có hình ẩn bên trong khi soi lên nắng.'),
    VnCard(
        'roi_nuoc',
        '🎭',
        'Múa rối nước',
        'Múa rối nước là nghệ thuật dân gian độc đáo của Việt Nam. Các con rối biểu diễn ngay trên mặt nước, '
            'nghệ nhân điều khiển từ phía sau tấm mành. Nhân vật vui nhộn nhất là chú Tễu.',
        'Múa rối nước biểu diễn ở đâu?',
        'Trên mặt nước',
        ['Trên bầu trời', 'Trên bãi cát'],
        'Múa rối nước có nhân vật chú Tễu vui nhộn.'),
    VnCard(
        'quan_ho',
        '🎶',
        'Dân ca Quan họ',
        'Quan họ là dân ca của vùng Kinh Bắc, nay là Bắc Ninh. Liền anh, liền chị hát đối đáp với nhau rất hay. '
            'Quan họ được UNESCO ghi danh là Di sản văn hóa phi vật thể của nhân loại.',
        'Dân ca Quan họ là của vùng nào?',
        'Bắc Ninh (Kinh Bắc)',
        ['Cà Mau', 'Lâm Đồng'],
        'Dân ca Quan họ Bắc Ninh là Di sản văn hóa của nhân loại.'),
    VnCard(
        'cong_chieng',
        '🥁',
        'Cồng chiêng Tây Nguyên',
        'Ở Tây Nguyên, tiếng cồng chiêng vang lên trong các lễ hội, bên ngọn lửa nhà rông. Không gian văn hóa '
            'Cồng chiêng Tây Nguyên là Di sản văn hóa của nhân loại.',
        'Cồng chiêng nổi tiếng ở vùng nào?',
        'Tây Nguyên',
        ['Đồng bằng sông Hồng', 'Hải đảo'],
        'Cồng chiêng Tây Nguyên là Di sản văn hóa của nhân loại.'),
    VnCard(
        'van_mieu',
        '📚',
        'Văn Miếu – Quốc Tử Giám',
        'Ở Hà Nội có Văn Miếu – Quốc Tử Giám. Quốc Tử Giám được lập năm 1076, là trường đại học đầu tiên của '
            'nước ta. Tên các tiến sĩ được khắc trên bia đá đặt trên lưng rùa.',
        'Quốc Tử Giám là gì?',
        'Trường đại học đầu tiên của nước ta',
        ['Một khu chợ lớn', 'Một cung điện của vua'],
        'Quốc Tử Giám (1076) là trường đại học đầu tiên của nước ta.'),
    VnCard(
        'le_phep',
        '🙇',
        'Lời chào và lễ phép',
        'Người Việt rất coi trọng lễ phép. Gặp người lớn, em khoanh tay chào hỏi; nhận quà thì nói cảm ơn bằng '
            'hai tay. Ông bà ta dạy: "Lời chào cao hơn mâm cỗ".',
        'Khi gặp người lớn, em nên làm gì?',
        'Khoanh tay chào hỏi lễ phép',
        ['Chạy đi chỗ khác', 'Giả vờ không thấy'],
        '"Lời chào cao hơn mâm cỗ" – ông bà ta dạy phải lễ phép.'),
  ]),
];

/// Thẻ "Bạn có biết?" của hôm nay (đổi mỗi ngày).
VnCard factOfTheDay([DateTime? now]) {
  final all = [for (final t in vnTopics) ...t.cards];
  final d = now ?? DateTime.now();
  final dayIndex = DateTime(d.year, d.month, d.day).difference(DateTime(2026)).inDays;
  return all[dayIndex.abs() % all.length];
}

VnTopic topicOf(VnCard c) => vnTopics.firstWhere((t) => t.cards.contains(c));
