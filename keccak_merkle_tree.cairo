
from starkware.cairo.common.cairo_builtins import HashBuiltin,  BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.math import (
    assert_in_range,
    assert_le,
    assert_nn_le,
    assert_not_zero,
    split_felt,
)
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_uint256s_bigend, cairo_keccak_uint256s, finalize_keccak
from starkware.cairo.common.uint256 import (
    uint256_lt,
    felt_to_uint256
)

// Core functions for Keccak Merkle Tree with carrying over odd nodes //

func hash_leaves_keccak{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    data_len : felt, data : Uint256*, index : felt, hashed_data : Uint256*, hashed_data_len : felt
) -> (hashed_data_len : felt) {
    alloc_locals;
    
    if (index == data_len) {
        return (hashed_data_len,);
    }

    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;


    let (hash_input_felt: felt*) = alloc();
    let tmp1 = alloc();  // second felt for full Uint256

    let hash_input: Uint256* = cast(hash_input_felt, Uint256*);
    let raw_leaf = [data + index*2];
    assert hash_input[0] = raw_leaf;
    
    let (hash) = cairo_keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(
        n_elements=1, 
        elements=hash_input, 
    );

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    %{
        low_hex = f"{ids.hash.low:032x}"
        high_hex = f"{ids.hash.high:032x}"
        full_hash_hex = high_hex + low_hex
        print(f"Input leaf [{ids.index}]: low=0x{ids.raw_leaf.low:032x}, high=0x{ids.raw_leaf.high:032x}")
        print(f"Keccak hash: 0x{full_hash_hex}")
    %}

    // Store the hash result (Uint256)
    assert [hashed_data + hashed_data_len* 2] = hash;

    // Continue with next leaf
    return hash_leaves_keccak(
        data_len, data, index + 1, hashed_data, hashed_data_len + 1
    );
}

func build_next_level_keccak{pedersen_ptr: HashBuiltin*, range_check_ptr,  bitwise_ptr: BitwiseBuiltin*}(
    data_len : felt, data : Uint256*, index : felt, next_level : Uint256*, next_level_len : felt, commutative: felt
) -> (next_level_len : felt) {
    alloc_locals;
    if (index == data_len) {
        return (next_level_len,);
    }

    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;

    local doubled = index + 1;
    if (doubled == data_len) {
        // Odd element, carry it over
        assert [next_level + next_level_len *2] = [data + index *2];
        return build_next_level_keccak(data_len, data, index + 1, next_level, next_level_len + 1, commutative);
    } else {
        // Pair elements and hash
        // let (low) = bigint_to_bytes32([data + index]);
        // let (high) = bigint_to_bytes32([data + index + 1]);
        // let (hash) = keccak_256(low, high);
        let left_node = [data + index * 2];
        let right_node = [data + index *2 + 2];
        if (commutative == 1) {
            let (hash: Uint256) = commutative_keccak256(left_node, right_node);
        } else {
            let (hash: Uint256) = non_commutative_keccak256(left_node, right_node);
        }

        %{
            low_hex = f"{ids.left_node.low:032x}"
            high_hex = f"{ids.left_node.high:032x}"
            full_hash_hex = high_hex + low_hex
            print(f"Left node Keccak hash: 0x{full_hash_hex}")
            low_hex = f"{ids.right_node.low:032x}"
            high_hex = f"{ids.right_node.high:032x}"
            full_hash_hex = high_hex + low_hex
            print(f"Right node Keccak hash: 0x{full_hash_hex}")
            low_hex = f"{ids.hash.low:032x}"
            high_hex = f"{ids.hash.high:032x}"
            full_hash_hex = high_hex + low_hex
            print(f"Parent Keccak hash: 0x{full_hash_hex}")
        %}
        assert [next_level + next_level_len *2] = hash;
        return build_next_level_keccak(data_len, data, index + 2, next_level, next_level_len + 1, commutative);
    }
}

func merkle_tree_keccak{pedersen_ptr: HashBuiltin*, range_check_ptr,  bitwise_ptr: BitwiseBuiltin*}(
    data_len : felt, data : Uint256*, already_hashed : felt, commutative: felt
) -> (root : Uint256) {
    alloc_locals;
    
    if (already_hashed == 0) {
      //  let ( hashed_data : Uint256*) = alloc();
      let (hashed_data: Uint256*) = alloc_uint256_array(data_len);
      let (hashed_data_len) = hash_leaves_keccak(data_len, data, 0, hashed_data, 0);
      return merkle_tree_keccak(hashed_data_len, hashed_data, 1, commutative);
    }

    if (data_len == 1) {
        return ([data],);
    }

    let (local next_level : Uint256*) = alloc();
    let (next_level_len) = build_next_level_keccak(data_len, data, 0, next_level, 0, commutative);
    
    return merkle_tree_keccak(next_level_len, next_level, 1, commutative);
}


// Helper functions //
// Keccak hash calculation functions //

func non_commutative_keccak256{
    pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(a_uint256: Uint256, b_uint256: Uint256) -> (hash: Uint256) {
    alloc_locals;
    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;

    let (data_uint: Uint256*) = alloc();
    assert data_uint[0] = a_uint256;
    assert data_uint[1] = b_uint256;

    // Compute the hash
    let (hash) = cairo_keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(n_elements=2, elements=data_uint);

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    return (hash,);
}



// Computes the commutative Keccak256 hash of two Uint256 values.
func commutative_keccak256{
    pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(a: Uint256, b: Uint256) -> (result: Uint256) {
    alloc_locals;

    let (is_lt) = uint256_lt(a, b);

    if (is_lt == 1) {
        let ordered_a = a;
        let ordered_b = b;
        let (hash: Uint256) = getKeccakOnlyUint{
            pedersen_ptr=pedersen_ptr,
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr
        }(ordered_a, ordered_b);
        return (hash,);
    } else {
        let ordered_a = b;
        let ordered_b = a;
        let (hash: Uint256) = getKeccakOnlyUint{
            pedersen_ptr=pedersen_ptr,
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr
        }(ordered_a, ordered_b);
        return (hash,);
    }
}


func getKeccakOnlyUint{
    pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(a_uint256: Uint256, b_uint256: Uint256) -> (hash: Uint256) {
    alloc_locals;
    let (local keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;

    let (data_uint: Uint256*) = alloc();
    assert data_uint[0] = a_uint256;
    assert data_uint[1] = b_uint256;

    // Compute the hash
    let (hash) = cairo_keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(n_elements=2, elements=data_uint);

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    return (hash,);
}


// Helpers

func alloc_uint256_array_rec(len: felt, i: felt, ptr: felt*) -> (ptr: felt*) {
    if (i == len) {
        return (ptr,);
    }

    // Allocate 2 felts for one Uint256
    let _a = alloc();
    let _b = alloc();

    return alloc_uint256_array_rec(len, i + 1, ptr);
}

func alloc_uint256_array(len: felt) -> (ptr: Uint256*) {
    alloc_locals;

    // Initial base pointer
    let (base_ptr: felt*) = alloc();
    let _b = alloc();  // allocate second felt for the first Uint256

    let (_final_ptr) = alloc_uint256_array_rec(len=len, i=1, ptr=base_ptr);
    return (cast(base_ptr, Uint256*),);
}
