.data
input_file:   .asciiz "input.txt"
desired_file: .asciiz "desired.txt"
output_file:  .asciiz "output.txt"
buf_size:     .word 32768
buffer:       .space 32768
NUM_SAMPLES:  .word 10
desired:      .space 40
input:        .space 40
crosscorr:    .space 40
autocorr:     .space 40
R:            .space 400
coeff:        .space 40
ouput:        .space 40
mmse:         .float 0.0
zero_f:       .float 0.0
one_f:        .float 1.0
ten:          .float 10.0
hundred:      .float 100.0
half:         .float 0.5
minus_half:   .float -0.5
zero:         .float 0.0
epsilon_f:    .float 1e-10
header_filtered: .asciiz "Filtered output: "
header_mmse:  .asciiz "\nMMSE: "
space_str:    .asciiz " "
newline_str:  .asciiz "\n"
error_msg:    .asciiz "Error: size not match"
str_buf:      .space 32
temp_str:     .space 32
error_open:   .asciiz "Error: Can not open file"
error_size:   .asciiz "Error: size not match"

.text
.globl main

main:
    # --- Check if input and desired have same size ---
    # Read input file to count numbers
    li   $v0, 13              # open file
    la   $a0, input_file
    li   $a1, 0               # read mode
    li   $a2, 0
    syscall
    bltz $v0, error_size_label      # if error opening file
    move $s0, $v0             # save file descriptor
    
    # Read file content
    li   $v0, 14              # read file
    move $a0, $s0
    la   $a1, buffer
    lw   $a2, buf_size
    syscall
    move $s1, $v0             # save bytes read
    
    # Close file
    li   $v0, 16
    move $a0, $s0
    syscall
    
    # Parse input file and count floats
    la   $a0, buffer
    move $a1, $s1             # bytes read
    la   $a2, input           # destination array
    jal  parse_floats
    move $s2, $v0             # input count
    
    # --- Open and read desired file ---
    li   $v0, 13              # open file
    la   $a0, desired_file
    li   $a1, 0               # read mode
    li   $a2, 0
    syscall
    bltz $v0, error_size_label      # if error opening file
    move $s0, $v0             # save file descriptor
    
    # Read file content
    li   $v0, 14              # read file
    move $a0, $s0
    la   $a1, buffer
    lw   $a2, buf_size
    syscall
    move $s1, $v0             # save bytes read
    
    # Close file
    li   $v0, 16
    move $a0, $s0
    syscall
    
    # Parse desired file and count floats
    la   $a0, buffer
    move $a1, $s1             # bytes read
    la   $a2, desired         # destination array
    jal  parse_floats
    move $s3, $v0             # desired count
    
    # Check if sizes match
    bne  $s2, $s3, error_size_label
    
    # Update NUM_SAMPLES
    sw   $s2, NUM_SAMPLES

    # --- compute crosscorrelation ---
    la   $a0, desired
    la   $a1, input
    la   $a2, crosscorr
    lw   $a3, NUM_SAMPLES
    jal  computeCrosscorrelation

    # --- compute autocorrelation ---
    la   $a0, input
    la   $a1, autocorr
    lw   $a3, NUM_SAMPLES
    jal  computeAutocorrelation

    # --- create Toeplitz matrix ---
    la   $a0, autocorr
    la   $a1, R
    lw   $a3, NUM_SAMPLES
    jal  createToeplitzMatrix

    # --- solveLinearSystem ---
    la   $a0, R
    la   $a1, crosscorr
    la   $a2, coeff
    lw   $a3, NUM_SAMPLES
    jal  solveLinearSystem

    # --- applyWienerFilter ---
    la   $a0, input
    la   $a1, coeff
    la   $a2, ouput
    lw   $a3, NUM_SAMPLES
    jal  applyWienerFilter

    # --- compute MMSE ---
    la   $a0, desired
    la   $a1, ouput
    lw   $a2, NUM_SAMPLES
    jal  computeMMSE
    swc1 $f0, mmse

    # --- Open output file ---
    li   $v0, 13
    la   $a0, output_file
    li   $a1, 1               # write mode
    li   $a2, 0
    syscall
    move $s0, $v0             # save file descriptor
    
    # --- Write "Filtered output: " ---
    li   $v0, 15
    move $a0, $s0
    la   $a1, header_filtered
    li   $a2, 17
    syscall
    
    # --- Write filtered outputs with 1 decimal ---
    lw   $s4, NUM_SAMPLES
    li   $s5, 0               # counter
    la   $s6, ouput           # output array address
    
write_output_loop:
    beq  $s5, $s4, write_mmse
    
    # Load output[i]
    lwc1 $f12, 0($s6)
    
    # Convert to string (with rounding built-in)
    la   $a0, str_buf
    li   $a1, 1               # 1 decimal
    jal  float_to_str
    
    # Write to file
    li   $v0, 15
    move $a0, $s0
    la   $a1, str_buf
    move $a2, $v1             # length from float_to_str
    syscall
    
    # Write space (except for last element)
    addi $t0, $s5, 1
    beq  $t0, $s4, skip_space
    li   $v0, 15
    move $a0, $s0
    la   $a1, space_str
    li   $a2, 1
    syscall
    
skip_space:
    addi $s6, $s6, 4          # next float
    addi $s5, $s5, 1
    j    write_output_loop
    
write_mmse:
    # --- Write "\nMMSE: " ---
    li   $v0, 15
    move $a0, $s0
    la   $a1, header_mmse
    li   $a2, 7
    syscall
    
    # Write MMSE value (with rounding built-in)
    lwc1 $f12, mmse
    
    la   $a0, str_buf
    li   $a1, 1
    jal  float_to_str
    
    li   $v0, 15
    move $a0, $s0
    la   $a1, str_buf
    move $a2, $v1
    syscall
    
    # --- Close output file ---
    li   $v0, 16
    move $a0, $s0
    syscall

    li   $v0, 10
    syscall

error_size_label:
    # Open output file
    li   $v0, 13
    la   $a0, output_file
    li   $a1, 1               # write mode
    li   $a2, 0
    syscall
    move $s0, $v0
    
    # Write error message
    li   $v0, 15
    move $a0, $s0
    la   $a1, error_msg
    li   $a2, 21
    syscall
    
    # Close file
    li   $v0, 16
    move $a0, $s0
    syscall
    
    # Exit
    li   $v0, 10
    syscall

# ---------------------------------------------------------
# parse_floats(buffer $a0, length $a1, dest_array $a2) -> count $v0
# Parse space-separated floats from buffer
# ---------------------------------------------------------
parse_floats:
    addi $sp, $sp, -32
    sw   $ra, 0($sp)        
    sw   $s0, 4($sp)          # buffer pointer
    sw   $s1, 8($sp)          # end of buffer
    sw   $s2, 12($sp)         # destination array
    sw   $s3, 16($sp)         # count
    sw   $s4, 20($sp)         # temp for parsing
    
    move $s0, $a0             # buffer start
    add  $s1, $a0, $a1        # buffer end
    move $s2, $a2             # dest array
    li   $s3, 0               # count = 0
    
parse_loop:
    bge  $s0, $s1, parse_done
    
    # Skip whitespace
    lb   $t0, 0($s0)
    beq  $t0, 32, parse_skip  # space: ' '
    beq  $t0, 9, parse_skip   # tab: '  ' 
    beq  $t0, 10, parse_skip  # newline: '\n'
    beq  $t0, 13, parse_skip  # carriage return: '\r'
    beqz $t0, parse_done      # null terminator: '\null'
    
    # Parse float
    move $a0, $s0             # pass current pointer 
    move $a1, $s1             # pass end pointer
    jal  parse_single_float
    swc1 $f0, 0($s2)          # store float in the memory
    addi $s2, $s2, 4    # shift to next index of destination array in the memory
    addi $s3, $s3, 1    # increase count
    move $s0, $v0             # update pointer: because parse_single_float return $v0 which the pointer point positionn after the float number it read
    j    parse_loop 
    
parse_skip:
    addi $s0, $s0, 1    # skip whitespace character
    j    parse_loop
    
parse_done:
    move $v0, $s3             # return count
    
    lw   $ra, 0($sp)    
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addi $sp, $sp, 32
    jr   $ra

# ---------------------------------------------------------
# parse_single_float(str $a0, end $a1) -> float $f0, next_ptr $v0
# Parse a single float from string
# ---------------------------------------------------------
parse_single_float:
    addi $sp, $sp, -28
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)          # string pointer
    sw   $s1, 8($sp)          # end pointer
    sw   $s2, 12($sp)         # decimal_count
    sw   $s3, 16($sp)         # after_decimal flag
    sw   $s4, 20($sp)         # sign
    
    move $s0, $a0             # str pointer: poin to current character
    move $s1, $a1             # end pointer
    li   $s2, 0               # decimal_count = 0
    li   $s3, 0               # after_decimal = false
    li   $s4, 1               # sign = 1 (positive)
    
    # Initialize result = 0.0
    lwc1 $f0, zero_f
    lwc1 $f8, ten             # 10.0 for multiplication
    
    # Check for negative sign
    lb   $t0, 0($s0)    # check current character which sigh of the number
    bne  $t0, 45, psf_loop    # '-' = 45
    li   $s4, -1    # negative sigh
    addi $s0, $s0, 1    # move to next character
    
psf_loop:
    bge  $s0, $s1, psf_end  
    lb   $t0, 0($s0)
    
    # Check for decimal point
    beq  $t0, 46, psf_decimal # '.' = 46
    
    # Check if digit (48-57)
    blt  $t0, 48, psf_end     # < '0'
    bgt  $t0, 57, psf_end     # > '9'
    
    # Process digit
    subi $t1, $t0, 48         # convert ASCII to number
    mtc1 $t1, $f2
    cvt.s.w $f2, $f2          # convert to float
    
    # result = result * 10 + digit
    mul.s $f0, $f0, $f8
    add.s $f0, $f0, $f2
    
    # If after decimal, increment decimal_count
    beqz $s3, psf_next  # check if the current digit is after '.' or not
    addi $s2, $s2, 1
    
psf_next:
    addi $s0, $s0, 1
    j    psf_loop
    
psf_decimal:
    li   $s3, 1               # after_decimal = true
    addi $s0, $s0, 1    
    j    psf_loop
    
psf_end:
    # Adjust for decimal places
    beqz $s2, psf_apply_sign    # if s2 == 0 => no decimal part (after ".") => apply sign
    
    # Calculate 10^decimal_count
    li   $t2, 1
    mtc1 $t2, $f4
    cvt.s.w $f4, $f4          # f4 = 1.0
    
# Calculate 10^s2
psf_divide_loop:
    beqz $s2, psf_divide_done
    mul.s $f4, $f4, $f8
    subi $s2, $s2, 1
    j    psf_divide_loop
# Calculate result / 10^2 => float number
psf_divide_done:
    div.s $f0, $f0, $f4
    
psf_apply_sign:
    # Apply sign
    beq  $s4, 1, psf_return
    neg.s $f0, $f0
    
psf_return:
    move $v0, $s0             # return updated pointer
    
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addi $sp, $sp, 28
    jr   $ra

# ---------------------------------------------------------
# computeCrosscorrelation(desired[], input[], result[], N)
# ---------------------------------------------------------
computeCrosscorrelation:
    addi $sp, $sp, -32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # k (outer loop)
    sw   $s1, 8($sp)     # n (inner loop)
    sw   $s2, 12($sp)    # N
    sw   $s3, 16($sp)    # desired address
    sw   $s4, 20($sp)    # input address
    sw   $s5, 24($sp)    # result address
    
    move $s3, $a0        # desired address
    move $s4, $a1        # input address
    move $s5, $a2        # result address
    move $s2, $a3        # N
    
    li   $s0, 0          # k = 0
cross_k_loop:
    bge  $s0, $s2, cross_end
    
    # result[k] = 0.0
    lwc1 $f0, zero_f
    
    li   $s1, 0          # n = 0
cross_n_loop:
    sub  $t0, $s2, $s0   # N - k
    bge  $s1, $t0, cross_store
    
    # load desired[n + k]
    add  $t1, $s1, $s0   # n + k
    sll  $t1, $t1, 2     # (n + k) * 4
    add  $t2, $s3, $t1   # t2 = address of desired[n+k]
    lwc1 $f2, 0($t2)     # f2 = desired[n+k]
    
    # load input[n]
    sll  $t3, $s1, 2     # n * 4
    add  $t4, $s4, $t3   # t4 = address of input[n]
    lwc1 $f4, 0($t4)     # f4 = input[n]
    
    # result[k] += desired[n + k] * input[n]
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    
    addi $s1, $s1, 1     # n++
    j    cross_n_loop

cross_store:
    # store result[k]
    sll  $t5, $s0, 2
    add  $t6, $s5, $t5   # t6 = address of result[k]
    swc1 $f0, 0($t6)     # store in memory result[k]
    
    addi $s0, $s0, 1     # k++
    j    cross_k_loop

cross_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 32
    jr   $ra

# ---------------------------------------------------------
# computeAutocorrelation(input[], result[], N)
# ---------------------------------------------------------
computeAutocorrelation:
    addi $sp, $sp, -28
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # k (outer loop)
    sw   $s1, 8($sp)     # n (inner loop)
    sw   $s2, 12($sp)    # N
    sw   $s3, 16($sp)    # input address
    sw   $s4, 20($sp)    # result address
    
    move $s3, $a0        # input address
    move $s4, $a1        # result address
    move $s2, $a3        # N
    
    li   $s0, 0          # k = 0
auto_k_loop:
    bge  $s0, $s2, auto_end
    
    # result[k] = 0.0
    lwc1 $f0, zero_f
    
    li   $s1, 0          # n = 0
auto_n_loop:
    sub  $t0, $s2, $s0   # N - k
    bge  $s1, $t0, auto_store
    
    # load input[n + k]
    add  $t1, $s1, $s0   # n + k
    sll  $t1, $t1, 2     # (n + k) * 4
    add  $t2, $s3, $t1   # t2 = address of input[n+k]
    lwc1 $f2, 0($t2)     # f2 = input[n+k]
    
    # load input[n]
    sll  $t3, $s1, 2     # n * 4
    add  $t4, $s3, $t3   # t4 = address of input[n]
    lwc1 $f4, 0($t4)     # f4 = input[n]
    
    # result[k] += input[n + k] * input[n]
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    
    addi $s1, $s1, 1     # n++
    j    auto_n_loop

auto_store:
    # store result[k]
    sll  $t5, $s0, 2
    add  $t6, $s4, $t5   # t6 = address of result[k]
    swc1 $f0, 0($t6)     # store in memory result[k]
    
    addi $s0, $s0, 1     # k++
    j    auto_k_loop

auto_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addi $sp, $sp, 28
    jr   $ra

# ---------------------------------------------------------
# createToeplitzMatrix(autocorr[], R[], N)
# ---------------------------------------------------------
createToeplitzMatrix:
    addi $sp, $sp, -24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # i (row)
    sw   $s1, 8($sp)     # j (column)
    sw   $s2, 12($sp)    # N
    sw   $s3, 16($sp)    # autocorr address
    sw   $s4, 20($sp)    # R address
    
    move $s3, $a0        # autocorr address
    move $s4, $a1        # R address
    move $s2, $a3        # N
    
    li   $s0, 0          # i = 0
toep_i_loop:
    bge  $s0, $s2, toep_end
    
    li   $s1, 0          # j = 0
toep_j_loop:
    bge  $s1, $s2, toep_next_i
    
    # Calculate |i - j|
    sub  $t0, $s0, $s1   # i - j
    abs  $t0, $t0        # |i - j|
    
    # Load autocorr[|i-j|]
    sll  $t1, $t0, 2     # |i-j| * 4
    add  $t2, $s3, $t1   # address of autocorr[|i-j|]
    lwc1 $f0, 0($t2)     # f0 = autocorr[|i-j|]
    
    # Store in R[i*N + j]
    mul  $t3, $s0, $s2   # i * N
    add  $t3, $t3, $s1   # i * N + j
    sll  $t3, $t3, 2     # (i*N + j) * 4
    add  $t4, $s4, $t3   # address of R[i*N + j]
    swc1 $f0, 0($t4)     # store
    
    addi $s1, $s1, 1     # j++
    j    toep_j_loop

toep_next_i:
    addi $s0, $s0, 1     # i++
    j    toep_i_loop

toep_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addi $sp, $sp, 24
    jr   $ra

# ---------------------------------------------------------
# solveLinearSystem(R[], b[], x[], N)
# Using Gaussian elimination with partial pivoting
# ---------------------------------------------------------
solveLinearSystem:
    addi $sp, $sp, -48
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # k (pivot row)
    sw   $s1, 8($sp)     # i (current row)
    sw   $s2, 12($sp)    # j (column)
    sw   $s3, 16($sp)    # N
    sw   $s4, 20($sp)    # R address
    sw   $s5, 24($sp)    # b address
    sw   $s6, 28($sp)    # x address
    sw   $s7, 32($sp)    # temp
    
    move $s4, $a0        # R address
    move $s5, $a1        # b address
    move $s6, $a2        # x address
    move $s3, $a3        # N
    
    # Forward elimination
    li   $s0, 0          # k = 0
solve_forward_k:
    bge  $s0, $s3, solve_backward
    
    # Partial pivoting: find row with largest |R[i][k]|
    move $t0, $s0        # max_row = k
    mul  $t1, $s0, $s3   # k * N
    add  $t1, $t1, $s0   # k * N + k
    sll  $t1, $t1, 2     # offset
    add  $t2, $s4, $t1   # address of R[k][k]
    lwc1 $f0, 0($t2)     # max_val = R[k][k]
    abs.s $f0, $f0
    
    addi $t3, $s0, 1     # i = k + 1
solve_find_pivot:
    bge  $t3, $s3, solve_pivot_done
    
    mul  $t4, $t3, $s3   # i * N
    add  $t4, $t4, $s0   # i * N + k
    sll  $t4, $t4, 2
    add  $t5, $s4, $t4   # address of R[i][k]
    lwc1 $f2, 0($t5)     # R[i][k]
    abs.s $f2, $f2
    
    c.le.s $f2, $f0      # if |R[i][k]| <= max_val, skip
    bc1t   solve_pivot_next
    
    mov.s $f0, $f2       # max_val = |R[i][k]|
    move $t0, $t3        # max_row = i
    
solve_pivot_next:
    addi $t3, $t3, 1
    j    solve_find_pivot

solve_pivot_done:
    # Swap rows k and max_row if needed
    beq  $t0, $s0, solve_no_swap
    
    # Swap R[k][:] with R[max_row][:]
    li   $s2, 0
solve_swap_loop:
    bge  $s2, $s3, solve_swap_b
    
    # Get addresses
    mul  $t1, $s0, $s3
    add  $t1, $t1, $s2
    sll  $t1, $t1, 2
    add  $t1, $s4, $t1   # address of R[k][j]
    
    mul  $t2, $t0, $s3
    add  $t2, $t2, $s2
    sll  $t2, $t2, 2
    add  $t2, $s4, $t2   # address of R[max_row][j]
    
    # Swap
    lwc1 $f2, 0($t1)
    lwc1 $f4, 0($t2)
    swc1 $f4, 0($t1)
    swc1 $f2, 0($t2)
    
    addi $s2, $s2, 1
    j    solve_swap_loop

solve_swap_b:
    # Swap b[k] with b[max_row]
    sll  $t1, $s0, 2
    add  $t1, $s5, $t1
    sll  $t2, $t0, 2
    add  $t2, $s5, $t2
    lwc1 $f2, 0($t1)
    lwc1 $f4, 0($t2)
    swc1 $f4, 0($t1)
    swc1 $f2, 0($t2)

solve_no_swap:
    # Get pivot R[k][k]
    mul  $t1, $s0, $s3
    add  $t1, $t1, $s0
    sll  $t1, $t1, 2
    add  $t1, $s4, $t1
    lwc1 $f10, 0($t1)    # f10 = pivot = R[k][k]
    
    # Check for zero pivot
    lwc1 $f12, epsilon_f
    abs.s $f14, $f10
    c.lt.s $f14, $f12
    bc1t   solve_end     # if |pivot| < epsilon, singular matrix
    
    # Eliminate column k in rows below k
    addi $s1, $s0, 1     # i = k + 1
solve_elim_i:
    bge  $s1, $s3, solve_next_k
    
    # factor = R[i][k] / R[k][k]
    mul  $t2, $s1, $s3
    add  $t2, $t2, $s0
    sll  $t2, $t2, 2
    add  $t2, $s4, $t2
    lwc1 $f2, 0($t2)     # R[i][k]
    div.s $f2, $f2, $f10 # factor
    
    # R[i][j] -= factor * R[k][j] for j = k to N-1
    move $s2, $s0        # j = k
solve_elim_j:
    bge  $s2, $s3, solve_elim_b
    
    # R[i][j] -= factor * R[k][j]
    mul  $t3, $s0, $s3
    add  $t3, $t3, $s2
    sll  $t3, $t3, 2
    add  $t3, $s4, $t3
    lwc1 $f4, 0($t3)     # R[k][j]
    
    mul  $t4, $s1, $s3
    add  $t4, $t4, $s2
    sll  $t4, $t4, 2
    add  $t4, $s4, $t4
    lwc1 $f6, 0($t4)     # R[i][j]
    
    mul.s $f8, $f2, $f4  # factor * R[k][j]
    sub.s $f6, $f6, $f8  # R[i][j] -= factor * R[k][j]
    swc1 $f6, 0($t4)
    
    addi $s2, $s2, 1
    j    solve_elim_j

solve_elim_b:
    # b[i] -= factor * b[k]
    sll  $t5, $s0, 2
    add  $t5, $s5, $t5
    lwc1 $f4, 0($t5)     # b[k]
    
    sll  $t6, $s1, 2
    add  $t6, $s5, $t6
    lwc1 $f6, 0($t6)     # b[i]
    
    mul.s $f8, $f2, $f4
    sub.s $f6, $f6, $f8
    swc1 $f6, 0($t6)
    
    addi $s1, $s1, 1
    j    solve_elim_i

solve_next_k:
    addi $s0, $s0, 1
    j    solve_forward_k

solve_backward:
    # Back substitution
    subi $s0, $s3, 1     # i = N - 1
solve_back_loop:
    bltz $s0, solve_end
    
    # x[i] = b[i]
    sll  $t0, $s0, 2
    add  $t0, $s5, $t0
    lwc1 $f0, 0($t0)     # f0 = b[i]
    
    # x[i] -= sum(R[i][j] * x[j]) for j = i+1 to N-1
    addi $s2, $s0, 1     # j = i + 1
solve_back_sum:
    bge  $s2, $s3, solve_back_div
    
    # R[i][j]
    mul  $t1, $s0, $s3
    add  $t1, $t1, $s2
    sll  $t1, $t1, 2
    add  $t1, $s4, $t1
    lwc1 $f2, 0($t1)     # R[i][j]
    
    # x[j]
    sll  $t2, $s2, 2
    add  $t2, $s6, $t2
    lwc1 $f4, 0($t2)     # x[j]
    
    mul.s $f6, $f2, $f4
    sub.s $f0, $f0, $f6
    
    addi $s2, $s2, 1
    j    solve_back_sum

solve_back_div:
    # x[i] /= R[i][i]
    mul  $t3, $s0, $s3
    add  $t3, $t3, $s0
    sll  $t3, $t3, 2
    add  $t3, $s4, $t3
    lwc1 $f8, 0($t3)     # R[i][i]
    div.s $f0, $f0, $f8
    
    # Store x[i]
    sll  $t4, $s0, 2
    add  $t4, $s6, $t4
    swc1 $f0, 0($t4)
    
    subi $s0, $s0, 1
    j    solve_back_loop

solve_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    lw   $s6, 28($sp)
    lw   $s7, 32($sp)
    addi $sp, $sp, 48
    jr   $ra

# ---------------------------------------------------------
# applyWienerFilter(input[], coefficients[], output[], N)
# ---------------------------------------------------------
applyWienerFilter:
    addi $sp, $sp, -28
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # n (outer loop)
    sw   $s1, 8($sp)     # k (inner loop)
    sw   $s2, 12($sp)    # N
    sw   $s3, 16($sp)    # input address
    sw   $s4, 20($sp)    # coefficients address
    sw   $s5, 24($sp)    # output address
    
    move $s3, $a0        # input address
    move $s4, $a1        # coefficients address
    move $s5, $a2        # output address
    move $s2, $a3        # N
    
    li   $s0, 0          # n = 0
wiener_n_loop:
    bge  $s0, $s2, wiener_end
    
    # output[n] = 0.0
    lwc1 $f0, zero_f    
    
    li   $s1, 0          # k = 0
wiener_k_loop:
    bgt  $s1, $s0, wiener_store    # k <= n
    bge  $s1, $s2, wiener_store    # k < N
    
    # load coefficients[k]
    sll  $t0, $s1, 2    # k * 4
    add  $t1, $s4, $t0  # t1 = address of coeff[k]
    lwc1 $f2, 0($t1)    # f2 = coeff[k] 
    
    # load input[n - k]
    sub  $t2, $s0, $s1  # n - k
    sll  $t2, $t2, 2    # (n - k) * 4
    add  $t3, $s3, $t2  # t3 = address of input[n-k]
    lwc1 $f4, 0($t3)    # f4 = input[n-k]
    
    # output[n] += coefficients[k] * input[n - k]
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    
    addi $s1, $s1, 1    # increase k
    j    wiener_k_loop

wiener_store:
    # store output[n]
    sll  $t4, $s0, 2
    add  $t5, $s5, $t4  # t5 = address of output[n]
    swc1 $f0, 0($t5)    # store in memory output[n]
    
    addi $s0, $s0, 1    # n++
    j    wiener_n_loop

wiener_end:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 28
    jr   $ra

# ---------------------------------------------------------
# computeMMSE(desired[], output[], N) -> $f0
# ---------------------------------------------------------
computeMMSE:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # counter
    sw   $s1, 8($sp)     # N
    
    move $s1, $a2        # N
    li   $s0, 0          # counter = 0
    lwc1 $f0, zero_f     # sum = 0.0
    
mmse_loop:
    bge  $s0, $s1, mmse_done
    
    # Load desired[i]
    sll  $t0, $s0, 2
    add  $t1, $a0, $t0
    lwc1 $f2, 0($t1)
    
    # Load output[i]
    add  $t2, $a1, $t0
    lwc1 $f4, 0($t2)
    
    # Calculate (desired[i] - output[i])^2
    sub.s $f6, $f2, $f4
    mul.s $f6, $f6, $f6
    add.s $f0, $f0, $f6
    
    addi $s0, $s0, 1
    j    mmse_loop
    
mmse_done:
    # Divide by N
    mtc1 $s1, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 16
    jr   $ra

# ---------------------------------------------------------
# float_to_str(buffer $a0, value $f12, decimals $a1) -> length $v1
# ---------------------------------------------------------
float_to_str:
    addi $sp, $sp, -24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # buffer
    sw   $s1, 8($sp)     # decimals
    sw   $s2, 12($sp)    # position
    sw   $s3, 16($sp)    # is_negative
    
    move $s0, $a0        # buffer
    move $s1, $a1        # decimals
    li   $s2, 0          # position = 0
    li   $s3, 0          # is_negative = 0
    
    # Check if negative
    lwc1 $f0, zero_f
    li   $s3, 0          # assume positive initially
    c.lt.s $f12, $f0
    bc1f fts_positive
    
    # Negative number - remember but don't print minus yet
    li   $s3, 1
    neg.s $f12, $f12     # make positive
    
fts_positive:
    # Apply rounding: add 0.5 * 10^(-decimals) to round correctly
    # For 1 decimal: add 0.05
    lwc1 $f16, ten
    lwc1 $f18, half      # 0.5
    
    # Calculate 10^decimals
    li   $t4, 1
    move $t5, $s1
    mtc1 $t4, $f20
    cvt.s.w $f20, $f20   # f20 = 1.0
fts_power_loop:
    beqz $t5, fts_power_done
    mul.s $f20, $f20, $f16
    subi $t5, $t5, 1
    j    fts_power_loop
    
fts_power_done:
    # Add rounding offset: value += 0.5 / 10^decimals
    div.s $f22, $f18, $f20
    add.s $f12, $f12, $f22
    
    # Get integer part
    cvt.w.s $f2, $f12
    cvt.s.w $f4, $f2     # integer part as float
    sub.s $f6, $f12, $f4 # decimal part
    
    # NOW check if we should print minus: only if was negative AND result is not zero
    beqz $s3, fts_convert_int  # if was positive, skip
    
    # Was negative: check if result will be "0.0...0"  
    mfc1 $t6, $f2
    bnez $t6, fts_print_minus   # if integer != 0, definitely print minus
    
    # Integer is 0. Check if all decimal digits will be 0
    # Extract first N digits and see if any is non-zero
    mov.s $f28, $f6         # f28 = decimal part
    li    $t7, 0            # digit counter
    li    $t8, 0            # any_nonzero flag
    
fts_check_decimals:
    bge   $t7, $s1, fts_check_result
    mul.s $f28, $f28, $f16  # decimal *= 10
    cvt.w.s $f30, $f28      # get digit
    mfc1  $t9, $f30
    bnez  $t9, fts_has_nonzero
    cvt.s.w $f30, $f30
    sub.s $f28, $f28, $f30  # remove digit
    addi  $t7, $t7, 1
    j     fts_check_decimals
    
fts_has_nonzero:
    li    $t8, 1            # mark as having non-zero digit
    
fts_check_result:
    beqz  $t8, fts_convert_int  # if all decimals are 0, suppress minus
    
fts_print_minus:
    # Print minus sign at current buffer position
    li   $t0, 45         # '-' character
    sb   $t0, 0($s0)
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    
fts_convert_int:
    
    # Convert integer part to string
    mfc1 $t0, $f2
    move $a0, $s0
    move $a1, $t0
    jal  int_to_str
    add  $s0, $s0, $v0
    add  $s2, $s2, $v0
    
    # Add decimal point
    beqz $s1, fts_done
    li   $t0, 46         # '.' character
    sb   $t0, 0($s0)
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    
    # Get decimal digits
    lwc1 $f8, ten
    li   $t1, 0
fts_decimal_loop:
    bge  $t1, $s1, fts_done
    
    mul.s $f6, $f6, $f8  # decimal *= 10
    cvt.w.s $f10, $f6
    mfc1 $t2, $f10       # digit
    
    cvt.s.w $f10, $f10
    sub.s $f6, $f6, $f10 # remove integer part
    
    addi $t2, $t2, 48    # convert to ASCII
    sb   $t2, 0($s0)
    addi $s0, $s0, 1
    addi $s2, $s2, 1
    addi $t1, $t1, 1
    j    fts_decimal_loop
    
fts_done:
    # Null terminate
    sb   $zero, 0($s0)
    move $v1, $s2        # return length
    
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 24
    jr   $ra


# ---------------------------------------------------------
# int_to_str(buffer $a0, value $a1) -> length $v0
# ---------------------------------------------------------
int_to_str:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    
    move $s0, $a0        # buffer
    move $s1, $a1        # value
    
    # Handle 0 specially
    bnez $s1, its_not_zero
    li   $t0, 48         # '0'
    sb   $t0, 0($s0)
    li   $v0, 1
    j    its_done
    
its_not_zero:
    # Count digits
    move $t0, $s1
    li   $t1, 0          # digit count
its_count_loop:
    beqz $t0, its_reverse
    div  $t0, $t0, 10
    addi $t1, $t1, 1
    j    its_count_loop
    
its_reverse:
    move $v0, $t1        # save length
    move $t0, $s1
    add  $s0, $s0, $t1   # point to end
    subi $s0, $s0, 1
    
its_digit_loop:
    beqz $t0, its_done
    
    rem  $t2, $t0, 10    # digit = value % 10
    addi $t2, $t2, 48    # convert to ASCII
    sb   $t2, 0($s0)
    
    div  $t0, $t0, 10    # value /= 10
    subi $s0, $s0, 1
    j    its_digit_loop
    
its_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 16
    jr   $ra