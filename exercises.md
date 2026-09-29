# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời trực tiếp dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Ngọc Linh  Mã học viên: 2A202602480

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi triển khai service lên staging hoặc production, người vận hành có thể quên thiết lập biến môi trường `AGENT_API_KEY` trong dashboard. Nếu cấu hình để giá trị mặc định (ví dụ `"changeme"` hoặc chuỗi rỗng), ứng dụng vẫn khởi động thành công và báo trạng thái khỏe mạnh. Khi đó, bot quét Internet hoặc kẻ xấu có thể dùng chính khóa mặc định `"changeme"` này để gọi vào API `/ask`, kích hoạt hàng nghìn lượt gọi mô hình LLM mà lập trình viên không hề hay biết cho đến khi nhận hóa đơn chi phí khổng lồ. Ngược lại, việc không gán giá trị mặc định sẽ khiến Pydantic ném lỗi `ValidationError` và làm ứng dụng crash ngay tại thời điểm khởi động (fail-fast), giúp đội ngũ phát hiện và bổ sung secret ngay trong phiên deploy.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:28:28.692215+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 41, "cost_usd": 0.00002505}
```

Hai việc làm được với log JSON:
1. **Lọc, tổng hợp và tính toán định lượng tự động (Aggregation & Metrics)**: Các hệ thống gom log tập trung (Datadog, Grafana Loki, CloudWatch) có thể parse từng trường dữ liệu JSON để tính tổng chi phí `cost_usd` của từng `user_id` trong ngày, hoặc vẽ biểu đồ biến thiên số lượng token tiêu thụ theo thời gian. Lệnh `print()` dạng văn bản không có cấu trúc nên không thể tính toán tự động.
2. **Cảnh báo tự động theo ngưỡng (Automated Alerting)**: Có thể cấu hình rule cảnh báo ngay lập tức nếu một request có chi phí vượt ngưỡng (ví dụ `cost_usd > 0.05`), hoặc phát hiện tỷ lệ các bản ghi có `level == "error"` tăng đột biến mà không cần con người đọc log thủ công.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1045 MB |
| Multi-stage | 198 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch gần 850 MB bao gồm:
1. Base image: Bản 1 stage dùng `python:3.11` đầy đủ chứa toàn bộ bộ công cụ biên dịch của hệ điều hành (GCC, G++, make, các file header C/C++ và công cụ phát triển không cần thiết ở runtime), trong khi multi-stage dùng `python:3.11-slim` đã loại bỏ các gói này.
2. Quá trình cài đặt: Ở multi-stage, các công cụ build và cache của pip (`/root/.cache/pip`, bánh xe wheel trung gian) chỉ tồn tại tạm thời ở stage `builder` rồi bị hủy bỏ hoàn toàn; chỉ có các thư viện thành phẩm trong `/install` được sao chép sang stage `runtime`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

1. Với Dockerfile hiện tại:
   - Các layer từ base image, `WORKDIR /build`, `COPY requirements.txt .`, và `RUN pip install` ở stage builder đều được tái sử dụng từ cache (`CACHED`).
   - Ở stage runtime: layer copy thư viện đã cài (`COPY --from=builder /install /usr/local`) cũng được lấy từ cache.
   - Chỉ từ layer `COPY app ./app` trở đi mới bị chạy lại do nội dung mã nguồn thay đổi. Thời gian build lại chỉ mất 1-2 giây.
2. Nếu đặt `COPY . .` lên trước `RUN pip install`:
   - Mỗi lần sửa dù chỉ một ký tự trong file mã nguồn, layer `COPY . .` sẽ bị thay đổi checksum, làm mất hiệu lực toàn bộ cache từ điểm đó trở về sau (cache invalidation).
   - Docker sẽ buộc phải chạy lại toàn bộ lệnh `RUN pip install`, tải lại tất cả thư viện qua mạng và cài đặt từ đầu, khiến thời gian build kéo dài nhiều phút mỗi lần sửa code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:
1. Ứng dụng Python có lỗ hổng thực thi mã từ xa (RCE, command injection hoặc deserialization).
2. Kẻ tấn công kích hoạt lỗ hổng để chạy shell bên trong container. Do container mặc định chạy quyền root, tiến trình shell của kẻ tấn công có UID = 0 (root).
3. Kẻ tấn công khai thác lỗ hổng thoát container (container escape qua kernel exploit hoặc qua mount nhầm volume nhạy cảm như `/var/run/docker.sock`). Do UID của container ánh xạ trực tiếp sang UID của nhân Linux trên host, tiến trình thoát ra sẽ ngay lập tức chiếm quyền root (UID 0) trên toàn bộ máy host.

Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay từ bước 2:
Bằng cách chuyển sang người dùng không có đặc quyền (UID 10001), khi kẻ tấn công thực thi được lệnh thì chỉ có quyền hạn chế của `appuser`, không thể sửa file hệ thống trong container, không thể chiếm đặc quyền kernel và ngăn chặn khả năng leo thang quyền lực ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp.

Giải thích:
Với cơ chế đếm theo phút đồng hồ cố định (Fixed Window Counter reset ở giây :00):
- Ở giây 10:00:59 (cuối phút đầu), người dùng gửi dồn 10 request (hợp lệ vì quota của phút 10:00 là 10).
- Đúng 10:01:00, đồng hồ bước sang phút mới và bộ đếm lập tức reset về 0.
- Ở giây 10:01:01 (đầu phút mới), người dùng gửi tiếp 10 request nữa (hợp lệ vì quota của phút 10:01 là 10).
Tổng cộng có tới 20 request được chấp nhận chỉ trong vòng 2 giây (từ 10:00:59 đến 10:01:01), gây áp lực gấp đôi lên hệ thống. Thuật toán Sliding Window Log (ZSET) khắc phục triệt để lỗi này bằng cách luôn xét đúng khoảng thời gian 60 giây trôi ngược từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác biệt cốt lõi:
- **Rate Limiter**: Kiểm soát *tốc độ / số lượng request* trong một cửa sổ thời gian ngắn (ví dụ 10 req/phút) để ngăn chặn tấn công từ chối dịch vụ (DDoS) và chống nghẽn server.
- **Cost Guard**: Kiểm soát *chi phí tài chính / ngân sách tích lũy* trong chu kỳ dài (ví dụ $10/tháng) để ngăn chặn việc tiêu hao quá nhiều token LLM.

Hai tình huống:
1. **Rate limit cho qua nhưng Cost guard chặn**: Người dùng chỉ gửi 1 request trong 10 phút (tần suất rất thấp, rate limit cho qua). Tuy nhiên, người dùng này đã tiêu hết $9.99 / $10.00 ngân sách tháng, và request mới này gửi kèm tài liệu rất dài dự kiến tiêu tốn $0.05. Cost guard tính toán thấy vượt ngân sách tháng nên chặn và trả HTTP 402.
2. **Cost guard cho qua nhưng Rate limit chặn**: Người dùng mới đầu tháng, số tiền đã tiêu là $0.00 (ngân sách còn nguyên $10.00). Người dùng này gửi liên tục 15 câu chào ngắn ("hi") chỉ trong vòng 5 giây. Chi phí phát sinh chưa tới $0.001 nên Cost guard hoàn toàn cho phép, nhưng Rate limit sẽ chặn từ request thứ 11 và trả HTTP 429 vì vi phạm giới hạn tốc độ.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện (Hiệu ứng sập dây chuyền - Cascading Failure):
1. **Giây 0**: Redis gặp sự cố tạm thời hoặc mất kết nối mạng trong 30 giây.
2. **Giây 5-10**: Orchestrator (K8s / Railway / Docker) gửi định kỳ request kiểm tra liveness vào endpoint `/health` của cả 3 container. Do `/health` kiểm tra Redis và Redis đang mất kết nối, cả 3 container đều phản hồi lỗi 503 (Unhealthy).
3. **Giây 15**: Vì `/health` (Liveness) báo lỗi, Orchestrator kết luận cả 3 container đều bị treo/hỏng và ngay lập tức gửi tín hiệu kill rồi khởi động lại (restart) toàn bộ 3 container cùng lúc.
4. **Giây 15-30**: Trong lúc Redis vẫn chưa hồi phục, các container vừa khởi động lại tiếp tục bị kiểm tra liveness và tiếp tục fail, dẫn đến vòng lặp restart liên tục (CrashLoopBackOff). Toàn bộ hệ thống sập hoàn toàn (100% downtime), mọi request của người dùng đều bị ngắt kết nối.
5. Khi tách riêng: `/health` (Liveness) chỉ kiểm tra process sống và trả 200 giúp container không bị restart; còn `/ready` (Readiness) trả 503 để Load Balancer tạm ngừng điều phối traffic đến service cho tới khi Redis phục hồi.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Khi lưu trong Redis (Stateless): Biến `history_length` tăng đều đặn và liên tục qua từng lượt hỏi: 0 -> 2 -> 4 -> 6 -> 8... bất kể request được điều phối tới container nào trong cụm 3 instance.
- Nếu lưu trong dict Python ở RAM (Stateful): Khi Load Balancer phân bổ request theo cơ chế round-robin lần lượt qua 3 container A, B, C, mỗi container chỉ lưu lịch sử trong vùng nhớ riêng của nó:
  - Request 1 vào container A: `history_length` = 0.
  - Request 2 vào container B: `history_length` = 0 (vì B không thấy dữ liệu của A).
  - Request 3 vào container C: `history_length` = 0 (vì C không thấy dữ liệu của A và B).
  - Request 4 vào container A: `history_length` = 2.
  - Request 5 vào container B: `history_length` = 2.
  Người dùng sẽ thấy agent liên tục bị "mất trí nhớ", độ dài lịch sử nhảy thất thường và ngữ cảnh trò chuyện bị chia cắt ngẫu nhiên.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi**: 
  Sau khi chạy `railway up`, container báo `Deploy crashed` kèm dòng log:
  ```text
  /bin/sh: 1: exec: docker-entrypoint.sh: not found
  URL: https://redis-production-7284.up.railway.app
  ```
- **Cách tìm ra nguyên nhân**:
  1. Kiểm tra log từ terminal và quan sát thấy domain tự sinh có tên tiền tố là `redis-production-...`.
  2. Lệnh khởi động container cố thực thi `docker-entrypoint.sh` (đây là script mặc định của Docker image Redis chính thức, không tồn tại trong image Python của app).
  3. Xác định nguyên nhân: Khi tạo Redis bằng CLI, Railway đã tự động gắn context vào service Redis, dẫn đến lệnh `railway up` đã build và deploy đè mã nguồn Python vào chính service Redis thay vì service app độc lập.
- **Cách khắc phục**:
  1. Truy cập Web Dashboard của Railway, tạo một service riêng biệt cho app (tên là `agent`) và khởi tạo một service Database `Redis` riêng.
  2. Dùng lệnh `railway service` trong terminal để trỏ context liên kết vào đúng service `agent`.
  3. Cấu hình biến môi trường `REDIS_URL` trên dashboard bằng cú pháp tham chiếu biến: `${{Redis.REDIS_URL}}`.
  4. Thực hiện `railway up` lại, ứng dụng nhận đúng cổng `$PORT` do Railway cấp phát và hoạt động ổn định.
