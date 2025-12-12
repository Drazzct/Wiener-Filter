# Wiener Filter Signal Processing - MIPS Assembly

## 📋 Project Overview

This project implements a **Wiener Filter** for signal filtering and prediction using MIPS assembly language. The Wiener filter is a classic adaptive filtering technique that estimates a desired signal from noisy observations by minimizing the mean square error (MSE).


---

## 🎯 Objectives

After completing this assignment, you will be able to:
- Proficiently use the MARS MIPS simulator
- Implement arithmetic and data transfer instructions
- Use conditional branch and unconditional jump instructions
- Work with procedures in MIPS assembly

---

## 🔬 Technical Background

### What is a Wiener Filter?

The Wiener filter processes an input signal **x(n) = s(n) + w(n)** where:
- **s(n)** = desired signal
- **w(n)** = undesired noise/interference
- **y(n)** = output signal (filtered result)
- **e(n) = d(n) - y(n)** = error sequence

### Filter Types
- **Filtering:** d(n) = s(n)
- **Signal Prediction:** d(n) = s(n + D)
- **Signal Smoothing:** d(n) = s(n - D)

### Mathematical Foundation

The filter minimizes mean-square error using the **Wiener-Hopf equations**:

```
R_M * h_M = γ_d
```

Where:
- **R_M** = Autocorrelation matrix (M×M Hermitian Toeplitz)
- **h_M** = Filter coefficients
- **γ_d** = Cross-correlation vector

**Optimal solution:**
```
h_opt = R_M^(-1) * γ_d
```

**Minimum Mean-Square Error (MMSE):**
```
MMSE = σ²_d - γ_d^t * R_M^(-1) * γ_d
```

---

## 📁 Project Structure

```
project/
├── source_code.asm          # Main MIPS assembly implementation
├── input.txt                # Input signal (desired + noise)
├── desired.txt              # Original desired signal
├── output.txt               # Generated output file
└── report.pdf               # Project documentation
```

---

## 📥 Input Format

**File:** `input.txt`
- Contains **10 floating-point numbers**
- Rounded to **1 decimal place**
- Represents the noisy input signal (desired signal + noise)

**Example:**
```
1.5 2.3 3.1 4.7 5.2 6.8 7.3 8.1 9.5 10.2
```

---

## 📤 Output Format

### Terminal & output.txt
The program generates **2 lines** of output:

1. **Line 1:** Filtered output sequence (10 numbers)
2. **Line 2:** MMSE value

**Example:**
```
Output: 1.4 2.2 3.0 4.6 5.1 6.7 7.2 8.0 9.4 10.1
MMSE: 0.15
```

**Error handling:**
```
Error: size not match
```
(If input and desired signal sizes differ)

---

## 🔧 Required Variables

Your MIPS code must define these variables:

| Variable Name | Type | Description |
|--------------|------|-------------|
| `desired_signal` | Sequence | Desired signal array |
| `input_signal` | Sequence | Input signal array |
| `optimize_coefficient` | Matrix | Wiener filter coefficients |
| `mmse` | Number | Calculated MMSE value |
| `output_signal` | Sequence | Filtered output array |

---

## 🚀 Getting Started

### Prerequisites
- **MARS MIPS Simulator** ([Download](http://courses.missouristate.edu/kenvollmar/mars/))
- Basic understanding of MIPS assembly
- Familiarity with signal processing concepts

### Running the Program
1. Open MARS MIPS simulator
2. Load `source_code.asm`
3. Ensure `input.txt` is in the correct directory
4. Assemble the program (F3)
5. Run the program (F5)
6. Check terminal output and `output.txt`

---
