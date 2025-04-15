from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.math import (
    assert_in_range,
    assert_le,
    assert_nn_le,
    assert_not_zero,
    split_felt,
)

// Core functions for Poseidon Merkle Tree with carrying over odd nodes //

func hash_leaves{poseidon_ptr: PoseidonBuiltin*}(
    data_len: felt, data: felt*, index: felt, hashed_data: felt*, hashed_data_len: felt
) -> (hashed_data_len: felt) {
    alloc_locals;
    if (index == data_len) {
        return (hashed_data_len,);
    }

    let raw_leaf = [data + index];
    let (hash_input: felt*) = alloc();
    assert hash_input[0] = raw_leaf;
    let (hash) = poseidon_hash_many(n=1, elements=hash_input);

    %{ print(f"Leaf: {ids.raw_leaf} hash: {ids.hash}") %}

    assert [hashed_data + hashed_data_len] = hash;
    return hash_leaves(data_len, data, index + 1, hashed_data, hashed_data_len + 1);
}

func build_next_level{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(
    data_len: felt,
    data: felt*,
    index: felt,
    next_level: felt*,
    next_level_len: felt,
    commutative: felt,
) -> (next_level_len: felt) {
    alloc_locals;
    if (index == data_len) {
        return (next_level_len,);
    }

    local doubled = index + 1;
    if (doubled == data_len) {
        // Odd element, carry it over
        assert [next_level + next_level_len] = [data + index];
        return build_next_level(
            data_len, data, index + 1, next_level, next_level_len + 1, commutative
        );
    } else {
        // Pair elements and hash
        if (commutative == 1) {
            let (hash) = commutative_poseidon{poseidon_ptr=poseidon_ptr}(
                [data + index], [data + index + 1]
            );
        } else {
            let (hash) = non_commutative_poseidon{poseidon_ptr=poseidon_ptr}(
                [data + index], [data + index + 1]
            );
        }
        assert [next_level + next_level_len] = hash;
        return build_next_level(
            data_len, data, index + 2, next_level, next_level_len + 1, commutative
        );
    }
}

func merkle_tree_poseidon{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(
    data_len: felt, data: felt*, already_hashed: felt, commutative: felt
) -> (root: felt) {
    alloc_locals;

    if (already_hashed == 0) {
        let (local hashed_data: felt*) = alloc();
        let (hashed_data_len) = hash_leaves(data_len, data, 0, hashed_data, 0);
        return merkle_tree_poseidon(hashed_data_len, hashed_data, 1, commutative);
    }

    if (data_len == 1) {
        return ([data],);
    }

    let (local next_level: felt*) = alloc();
    let (next_level_len) = build_next_level(data_len, data, 0, next_level, 0, commutative);

    return merkle_tree_poseidon(next_level_len, next_level, 1, commutative);
}

// Commutative poseidon
func commutative_poseidon{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(a: felt, b: felt) -> (
    res: felt
) {
    alloc_locals;
    let a_le_b = is_le_felt(a, b);

    if (a_le_b == 1) {
        let (hash_input: felt*) = alloc();
        assert hash_input[0] = a;
        assert hash_input[1] = b;

        let (res) = poseidon_hash_many(n=2, elements=hash_input);

        return (res,);
    } else {
        let (hash_input: felt*) = alloc();
        assert hash_input[0] = b;
        assert hash_input[1] = a;

        let (res) = poseidon_hash_many(n=2, elements=hash_input);

        return (res,);
    }
}

func non_commutative_poseidon{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(
    a: felt, b: felt
) -> (res: felt) {
    alloc_locals;

    let (hash_input: felt*) = alloc();
    assert hash_input[0] = a;
    assert hash_input[1] = b;

    let (res) = poseidon_hash_many(n=2, elements=hash_input);

    return (res,);
}
