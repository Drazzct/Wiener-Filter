# Bộ Lọc Wiener – Triển khai cho Lọc và Dự đoán Tín Hiệu

## 🎯 Tổng quan

Triển khai **bộ lọc Wiener** cho bài toán **lọc và dự đoán tín hiệu**, với mục tiêu **giảm thiểu sai số bình phương trung bình (MSE)** giữa tín hiệu mong muốn và tín hiệu bị nhiễu quan sát được.

Bộ lọc Wiener là **bộ lọc tuyến tính tối ưu**, cho phép ước lượng tốt nhất của tín hiệu mong muốn trong điều kiện có nhiễu cộng.

### 🌟 Tính năng nổi bật

* ✅ Lọc tín hiệu tối ưu theo tiêu chí **MMSE (Minimum Mean Square Error)**
* ✅ Hỗ trợ nhiều loại nhiễu (nhiễu trắng, nhiễu hồng)
* ✅ Tính toán hiệu quả **tự tương quan** và **tương quan chéo**
* ✅ Xây dựng **ma trận Toeplitz** và giải bằng **khử Gauss**
* ✅ Bộ kiểm thử đầy đủ sử dụng **pytest**
* ✅ Xử lý hàng loạt tín hiệu 500 mẫu

### Ứng dụng thực tế

* Giảm nhiễu trong tín hiệu âm thanh
* Cải thiện tín hiệu trong hệ thống thông tin
* Xử lý tín hiệu y sinh
* Khử nhiễu ảnh (mở rộng sang 2D)
* Lọc dự đoán (Predictive Filtering)

---

## 📐 Cơ sở Toán học

### Mô hình bài toán

Cho:

* **Tín hiệu mong muốn**: `d(n)` – tín hiệu sạch cần khôi phục
* **Tín hiệu vào**: `x(n) = s(n) + w(n)`

  * `s(n)`: thành phần tín hiệu gốc
  * `w(n)`: nhiễu cộng
* **Đầu ra của bộ lọc**: `y(n)` – tín hiệu được ước lượng

### Phương trình bộ lọc Wiener

Bộ lọc có đầu ra:

```
y(n) = Σ(k=0 → M-1) h_k * x(n-k)
```

với:

* `h_k`: hệ số bộ lọc
* `M`: độ dài bộ lọc

### Hệ số tối ưu

Hệ số tối ưu `h_opt` được xác định bằng **phương trình Wiener–Hopf**:

```
R_M * h_opt = γ_d
```

Trong đó:

* `R_M`: ma trận tự tương quan (Toeplitz, kích thước M×M)
* `γ_d`: vector tương quan chéo giữa tín hiệu mong muốn và tín hiệu vào

**Dạng ma trận:**

```
[r(0)    r(1)    ... r(M-1)]   [h_0]   [γ_dx(0)]
[r(1)    r(0)    ... r(M-2)] * [h_1] = [γ_dx(1)]
[...     ...     ...  ...  ]   [...]   [...]
[r(M-1)  ...     ...  r(0)]   [h_M-1] [γ_dx(M-1)]
```

### Tự tương quan

```
r(l) = (1/N) * Σ(n=0 → N-l-1) x(n) * x(n-l)
```

### Tương quan chéo

```
γ_dx(l) = (1/N) * Σ(n=0 → N-l-1) d(n) * x(n-l)
```

### Sai số bình phương trung bình tối thiểu (MMSE)

```
MMSE = (1/N) * Σ(n=0 → N-1) [d(n) - y(n)]²
```

Đại lượng này thể hiện mức sai khác trung bình giữa tín hiệu thật và tín hiệu được lọc.

---

## 🔨 Chi tiết triển khai

### Các hàm chính

#### 1. `computeAutocorrelation()`

Tính dãy tự tương quan của tín hiệu, dùng để xây dựng ma trận Toeplitz.
Độ phức tạp: O(N × maxLag)

#### 2. `computeCrosscorrelation()`

Tính tương quan chéo giữa tín hiệu mong muốn và tín hiệu nhiễu.
Độ phức tạp: O(N × maxLag)

#### 3. `createToeplitzMatrix()`

Tạo ma trận Toeplitz M×M từ dãy tự tương quan.
Tính chất: đối xứng, nửa xác định dương.

#### 4. `solveLinearSystem()`

Giải hệ phương trình tuyến tính bằng **khử Gauss có chọn pivot**.
Độ phức tạp: O(M³).

#### 5. `computeWienerCoefficients()`

Kết hợp các bước trên để tính vector hệ số tối ưu `h`.

#### 6. `applyWienerFilter()`

Áp dụng bộ lọc FIR cho tín hiệu vào:

```
y(n) = Σ h_k * x(n-k)
```

#### 7. `computeMMSE()`

Tính sai số bình phương trung bình giữa `d(n)` và `y(n)`.

### Luồng thuật toán

```
1. Đọc d(n) từ desired.txt  
2. Đọc x(n) từ input.txt  
3. Kiểm tra kích thước  
4. Tính tự tương quan r(l)  
5. Tính tương quan chéo γ_dx(l)  
6. Xây dựng ma trận Toeplitz R  
7. Giải R * h = γ_d  
8. Áp dụng bộ lọc để thu y(n)  
9. Tính MMSE  
10. Ghi kết quả ra output.txt
```

### Thông số mặc định

* **Độ dài bộ lọc (M)**: 10

  * M nhỏ → nhanh, lọc nhẹ
  * M lớn → lọc mượt, chậm hơn
  * Khuyến nghị: 5–20

### Hiệu năng

| Tham số        | Giá trị              |
| -------------- | -------------------- |
| Số mẫu         | 500                  |
| Thời gian tính | < 1s (M=10)          |
| Bộ nhớ         | O(M² + N)            |
| Ổn định số     | Tốt khi SNR > -10 dB |

---

## 📊 Ví dụ minh họa

### 1️⃣ Sóng sin + nhiễu trắng

```
M = 10  
MMSE = 0.0451  
Giảm nhiễu ~85%
```

### 2️⃣ Tín hiệu đa tần số

```
M = 10  
MMSE = 0.0824  
Giữ được các thành phần tần số chính
```

### 3️⃣ Tỉ số SNR cao

```
M = 10  
MMSE = 0.0032  
Tín hiệu khôi phục gần như hoàn hảo
```

---

## 🎓 Ghi chú lý thuyết

### Vì sao dùng bộ lọc Wiener?

1. **Tối ưu theo MSE**
2. **Có công thức đóng** – dễ tính toán
3. **Thích nghi với thống kê tín hiệu**
4. **Tính toán hiệu quả, phù hợp xử lý thời gian thực**

### Giả định

* Tín hiệu **dừng** (stationary)
* Biết **thống kê nhiễu**
* Hệ thống **tuyến tính, nhiễu cộng**

### Hạn chế

* Hiệu quả giảm với tín hiệu **không dừng**
* Cần dữ liệu huấn luyện với tín hiệu sạch
* Không xử lý được nhiễu **phi tuyến**
* Có **độ trễ pha nhỏ**

### Hướng mở rộng

* **Adaptive Wiener Filter**: cập nhật hệ số theo thời gian (LMS, RLS)
* **FFT-based Wiener Filter**: làm việc trong miền tần số
* **2D Wiener Filter**: mở rộng sang xử lý ảnh
* **Kalman Filter**: cho hệ thống biến thiên theo thời gian

---

## 📚 Tài liệu tham khảo

**Sách và công trình kinh điển**

1. Wiener, N. (1949). *Extrapolation, Interpolation, and Smoothing of Stationary Time Series*
2. Hayes, M. H. (1996). *Statistical Digital Signal Processing and Modeling*
3. Oppenheim & Schafer (2009). *Discrete-Time Signal Processing*
4. Haykin, S. (2013). *Adaptive Filter Theory*

**Tài nguyên trực tuyến**

* [Wikipedia: Wiener Filter](https://en.wikipedia.org/wiki/Wiener_filter)
* [DSP Guide](http://www.dspguide.com/)

* Stanford CS229 – Linear Filtering
