%builtins output pedersen range_check bitwise poseidon

from starkware.cairo.bootloaders.simple_bootloader.run_simple_bootloader import (
    run_simple_bootloader,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin,  BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.cairo_verifier.objects import CairoVerifierOutput
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from objects import BootloaderOutput, bootloader_output_extract_output_hashes
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_uint256s_bigend, cairo_keccak_uint256s, finalize_keccak
from starkware.cairo.common.uint256 import (
    uint256_lt,
    felt_to_uint256
)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.math import (
    assert_in_range,
    assert_le,
    assert_nn_le,
    assert_not_zero,
    split_felt,
)


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


    // assert hash_input[0] = Uint256(raw_leaf.low,raw_leaf.high);

    let raw_leaf = [data + index*2];
    //let swapped_leaf = Uint256(low=raw_leaf.high, high=raw_leaf.low);
    assert hash_input[0] = raw_leaf;

  //  assert hash_input[1] = ;
    
    // Compute Keccak hash
    let (hash) = cairo_keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(
        n_elements=1, 
        elements=hash_input, 
       // keccak_ptr=keccak_ptr_start
    );

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    

         %{
    # Access low and high parts
    low = ids.hash.low
    high = ids.hash.high

    # Combine to full 256-bit integer
    full_hash = (high << 128) + low

    print(f"LEaf keccak (uint256): {full_hash}")
  %}

     %{
        # Convert low and high parts to hex strings
        low_hex = f"{ids.hash.low:032x}"
        high_hex = f"{ids.hash.high:032x}"
        
        # Combine to full 64-character hex string
        full_hash_hex = high_hex + low_hex
        
        # Print input and output
        print(f"Input leaf [{ids.index}]: low=0x{ids.raw_leaf.low:032x}, high=0x{ids.raw_leaf.high:032x}")
        print(f"Keccak hash: 0x{full_hash_hex}")
    %}


%{
 #   print(f"Expected low: {ids.hash.low} high: {ids.hash.high}")
%}

%{
  # actual = memory[ids.hashed_data + ids.hashed_data_len]
 #   print(f"Actual low: {actual.low}, high: {actual.high}")
%}
%{
   # print(f"Hash struct: low={ids.hash.low}, high={ids.hash.high}")
%}
    // Store the hash result (Uint256)
    assert [hashed_data + hashed_data_len* 2] = hash;
    %{
   # print(f"Hash struct2: low={ids.hash.low}, high={ids.hash.high}")
%}
    // Continue with next leaf
    return hash_leaves_keccak(
        data_len, data, index + 1, hashed_data, hashed_data_len + 1
    );
}

func build_next_level_keccak{pedersen_ptr: HashBuiltin*, range_check_ptr,  bitwise_ptr: BitwiseBuiltin*}(
    data_len : felt, data : Uint256*, index : felt, next_level : Uint256*, next_level_len : felt
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
        return build_next_level_keccak(data_len, data, index + 1, next_level, next_level_len + 1);
    } else {
        // Pair elements and hash
        // let (low) = bigint_to_bytes32([data + index]);
        // let (high) = bigint_to_bytes32([data + index + 1]);
        // let (hash) = keccak_256(low, high);
        let left_node = [data + index * 2];
        let right_node = [data + index *2 + 2];
        let (hash: Uint256) = non_commutative_keccak256(left_node, right_node);

  %{
        low_hex = f"{ids.left_node.low:032x}"
        high_hex = f"{ids.left_node.high:032x}"
        
        # Combine to full 64-character hex string
        full_hash_hex = high_hex + low_hex
        
        # Print input and output
        print(f"Left node Keccak hash: 0x{full_hash_hex}")

        low_hex = f"{ids.right_node.low:032x}"
        high_hex = f"{ids.right_node.high:032x}"
        
        # Combine to full 64-character hex string
        full_hash_hex = high_hex + low_hex
        
        # Print input and output
        print(f"Right node Keccak hash: 0x{full_hash_hex}")
        # Convert low and high parts to hex strings
        low_hex = f"{ids.hash.low:032x}"
        high_hex = f"{ids.hash.high:032x}"
        
        # Combine to full 64-character hex string
        full_hash_hex = high_hex + low_hex
        
        # Print input and output
        print(f"Parent Keccak hash: 0x{full_hash_hex}")
    %}
        assert [next_level + next_level_len *2] = hash;
        return build_next_level_keccak(data_len, data, index + 2, next_level, next_level_len + 1);
    }
}

func merkle_tree_keccak{pedersen_ptr: HashBuiltin*, range_check_ptr,  bitwise_ptr: BitwiseBuiltin*}(
    data_len : felt, data : Uint256*, already_hashed : felt
) -> (root : Uint256) {
    alloc_locals;
    
   // 1) Hash all leaves if not already hashed
    if (already_hashed == 0) {
      //  let ( hashed_data : Uint256*) = alloc();
      let (hashed_data: Uint256*) = alloc_uint256_array(data_len);
        let (hashed_data_len) = hash_leaves_keccak(data_len, data, 0, hashed_data, 0);
        return merkle_tree_keccak(hashed_data_len, hashed_data, 1);
    }

    // 2) Base case: single element → root
    if (data_len == 1) {
        return ([data],);
    }

    // 3) Build the next level
    let (local next_level : Uint256*) = alloc();
    let (next_level_len) = build_next_level_keccak(data_len, data, 0, next_level, 0);
    
    // Recursively build tree
    return merkle_tree_keccak(next_level_len, next_level, 1);
}


///////////////// POSEIDON TREE /////////


func hash_leaves{poseidon_ptr: PoseidonBuiltin*}(
    data_len : felt, data : felt*, index : felt, hashed_data : felt*, hashed_data_len : felt
) -> (hashed_data_len : felt) {
    alloc_locals;
    if (index == data_len) {
        return (hashed_data_len,);
    }

    let raw_leaf = [data + index];
    let (hash_input: felt*) = alloc();
    assert hash_input[0] = raw_leaf;
    let (hash) = poseidon_hash_many(n=1, elements=hash_input);


     %{
     print(f"Leaf: {ids.raw_leaf} hash: {ids.hash}")
  %}

    
    assert [hashed_data + hashed_data_len] = hash;
    return hash_leaves(data_len, data, index + 1, hashed_data, hashed_data_len + 1);
}

func build_next_level{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(
    data_len : felt, data : felt*, index : felt, next_level : felt*, next_level_len : felt
) -> (next_level_len : felt) {
    alloc_locals;
    if (index == data_len) {
        return (next_level_len,);
    }

    local doubled = index + 1;
    if (doubled == data_len) {
        // Odd element, carry it over
        assert [next_level + next_level_len] = [data + index];
        return build_next_level(data_len, data, index + 1, next_level, next_level_len + 1);
    } else {
        // Pair elements and hash
        // let (low) = bigint_to_bytes32([data + index]);
        // let (high) = bigint_to_bytes32([data + index + 1]);
        // let (hash) = keccak_256(low, high);
        let (hash) = non_commutative_poseidon{poseidon_ptr=poseidon_ptr}([data + index], [data + index + 1]);
        assert [next_level + next_level_len] = hash;
        return build_next_level(data_len, data, index + 2, next_level, next_level_len + 1);
    }
}



func merkle_tree{poseidon_ptr: PoseidonBuiltin*, range_check_ptr}(
    data_len : felt, data : felt*, already_hashed : felt
) -> (root : felt) {
    alloc_locals;
    
   // 1) Hash all leaves if not already hashed
    if (already_hashed == 0) {
        let (local hashed_data : felt*) = alloc();
        let (hashed_data_len) = hash_leaves(data_len, data, 0, hashed_data, 0);
        return merkle_tree(hashed_data_len, hashed_data, 1);
    }

    // 2) Base case: single element → root
    if (data_len == 1) {
        return ([data],);
    }

    // 3) Build the next level
    let (local next_level : felt*) = alloc();
    let (next_level_len) = build_next_level(data_len, data, 0, next_level, 0);
    
    // Recursively build tree
    return merkle_tree(next_level_len, next_level, 1);
}


func hash_verified_program_hashes{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(elements: felt*, n: felt, accumulated_hash: felt) -> (hash: felt) {
    if (n == 0) {
        return (accumulated_hash,);
    }

    let (new_hash) = poseidon_hash_many(n=1, elements=elements);
    let (final_hash) = hash_verified_program_hashes(
        elements=elements + 1,
        n=n - 1,
        accumulated_hash=new_hash,
    );
    return (final_hash,);
}

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let (__fp__, _) = get_fp_and_pc();

    //let a: felt = 123;
    //let b: felt = 456;

    //let (hash: Uint256) = commutative_keccak256_from_felts(a, b);
    //
    //
    //// Example Uint256 values
    //let a = Uint256(low=5, high=0);
    //let b = Uint256(low=10, high=0);

    let a = Uint256(low=195143356298950239236390551223274915282, high=253627162908404395944762862209573068050); // beced09521047d05b8960b7e7bcc1d1292cf3e4b2a6b63f48335cbde5f7545d2
    let b = Uint256(low=116212811495271821619858470105682406356, high=322612437423141795915263170940894428234); // f2b4e536bd23bd6782833c997983bc4a576dc5faca807b4000f207eec069ebd4

    

    // Call your hashing function
    let (hash: Uint256) = commutative_keccak256{
       pedersen_ptr=pedersen_ptr,
       range_check_ptr=range_check_ptr,
       bitwise_ptr=bitwise_ptr
    }(b, a);

     %{
    # Access low and high parts
    low = ids.hash.low
    high = ids.hash.high

    # Combine to full 256-bit integer
    full_hash = (high << 128) + low

    print(f"Keccak256 hash (uint256): {full_hash}")
  %}

  // Example data: [1, 2, 3, 4, 5]
    // let leaves: felt* = alloc();
    // assert leaves[0] = 1;
    // assert leaves[1] = 2;
    // assert leaves[2] = 3;
    // assert leaves[3] = 4;
    // assert leaves[4] = 5;

    // let leaf_count = 5;

    // let (root) = merkle_tree(leaves, leaf_count, 0);


    // Example array of 5 felts (leaf nodes)
    let (local leaves : Uint256*) = alloc();
    assert leaves[0] = Uint256(low=42, high=0);  // leaf 0
    assert leaves[1] = Uint256(low=999, high=0);  // leaf 1
    assert leaves[2] = Uint256(low=7, high=0); // leaf 2
    assert leaves[3] = Uint256(low=7, high=0); // leaf 3
    assert leaves[4] = Uint256(low=1000, high=0);  // leaf 4
     assert leaves[5] = Uint256(low=3, high=0);  // leaf 4
      assert leaves[6] = Uint256(low=7, high=0);  // leaf 4

          assert leaves[7] = Uint256(low=42, high=0);  // leaf 0
    assert leaves[8] = Uint256(low=999, high=0);  // leaf 1
    assert leaves[9] = Uint256(low=7, high=0); // leaf 2
    assert leaves[10] = Uint256(low=7, high=0); // leaf 3
    assert leaves[11] = Uint256(low=1000, high=0);  // leaf 4
     assert leaves[12] = Uint256(low=3, high=0);  // leaf 4
      assert leaves[13] = Uint256(low=7, high=0);  // leaf 4

    // Compute Merkle root (leaves are not yet hashed)
//     let (root) = merkle_tree(6, leaves, 0);
// %{
// print("==== Merkle Root Node ====")
// print("Merkle root       :", ids.root)

// print("===========================")
// %}


 let (root) = merkle_tree_keccak(14, leaves, 0);

     %{
    # Access low and high parts
    low = ids.root.low
    high = ids.root.high

    # Combine to full 256-bit integer
    full_hash = (high << 128) + low

    print(f"Keccak256 merkle root (uint256): {full_hash}")
  %}

  %{
        # Convert low and high parts to hex strings
        low_hex = f"{ids.root.low:032x}"
        high_hex = f"{ids.root.high:032x}"
        
        # Combine to full 64-character hex string
        full_hash_hex = high_hex + low_hex
        
        # Print input and output
        print(f"Merkle Root Keccak hash: 0x{full_hash_hex}")
    %}
// //# Number of leaf nodes
// let len = 4;

// //# Allocate space for 4 nodes (4 felts each = 16 felts total)
// let nodes: felt* = alloc();

// //# Manually initialize each leaf node
// //# Node 0
// let node0: felt* = nodes + 0 * 4;
// assert node0[0] = 1;                     // hash
// assert node0[1] = 0;                     // left = null
// assert node0[2] = 0;                     // right = null
// assert node0[3] = 0;                     // is_root = false

// //# Node 1
// let node1: felt* = nodes + 1 * 4;
// assert node1[0] = 2;
// assert node1[1] = 0;
// assert node1[2] = 0;
// assert node1[3] = 0;

// //# Node 2
// let node2: felt* = nodes + 2 * 4;
// assert node2[0] = 3;
// assert node2[1] = 0;
// assert node2[2] = 0;
// assert node2[3] = 0;

// //# Node 3
// let node3: felt* = nodes + 3 * 4;
// assert node3[0] = 4;
// assert node3[1] = 0;
// assert node3[2] = 0;
// assert node3[3] = 0;

// //# Build Merkle Tree
// let (root: Node*) = construct_tree{poseidon_ptr=poseidon_ptr}(nodes, len);

// let root_felt: felt* = cast(root, felt*);
// let hash2 = root_felt[0];
// let left_ptr = root_felt[1];
// let right_ptr = root_felt[2];
// let is_root = root_felt[3];

// %{
// print("==== Merkle Root Node ====")
// print("Hash       :", ids.hash2)
// print("Left ptr   :", ids.left_ptr)
// print("Right ptr  :", ids.right_ptr)
// print("Is Root    :", ids.is_root)
// print("===========================")
// %}


    //
    //   let a = 456;
    //   let b = 123;

    //   let (hash) = commutative_poseidon{poseidon_ptr=poseidon_ptr}(a, b);

    // %{
   

    // print(f"Poseidon hash (felt252): {ids.hash}")
 // %}




    // You can return just the low part for demo
    return ();

}


func compute_fact_hashes{
    poseidon_ptr: PoseidonBuiltin*,
}(
    child_outputs_hashes: felt*,
    child_hashes: felt*,
    aggregator_hash: felt,
    fact_hashes: felt*,
    remaining: felt,
    index: felt
) -> (fact_hashes: felt*) {
    alloc_locals;

    if (remaining == 0) {
        return (fact_hashes=fact_hashes);
    }


    let (hash_input: felt*) = alloc();
    assert hash_input[0] = aggregator_hash;
    assert hash_input[1] = child_hashes[index];
    assert hash_input[2] = child_outputs_hashes[index];

    let (fact_hash) = poseidon_hash_many(
        n=3,
        elements=hash_input
    );

    %{
        print("calculatig fact hash for child at index", ids.index)
        print("fact hash hash", ids.fact_hash)
    %}


    assert fact_hashes[index] = fact_hash;

    with poseidon_ptr {
        return compute_fact_hashes(
            child_outputs_hashes=child_outputs_hashes,
            child_hashes=child_hashes,
            aggregator_hash=aggregator_hash,
            fact_hashes=fact_hashes,
            remaining=remaining - 1,
            index=index + 1
        );
    }
}


// func commutative_keccak256{range_check_ptr}(a: felt, b: felt) -> (hash_val: felt) {
//     // Compare a, b
//     let (is_a_le_b) = is_le(a, b);

//     // If a <= b, is_a_le_b == 1; else is_a_le_b == 0
//     if (is_a_le_b == 1) {
//         let (res) = efficient_keccak2(a, b);
//         return (res);
//     } else {
//         let (res) = efficient_keccak2(b, a);
//         return (res);
//     }
// }



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

// Splits a 128-bit felt into 16 bytes (big-endian) using a hint.
func split_128_to_bytes{range_check_ptr}(val: felt) -> (bytes: felt*) {
    alloc_locals;
    let bytes: felt* = alloc();
    %{
        val = ids.val
        bytes = []
        for i in range(16):
            shift = 120 - 8 * i
            divisor = 1 << shift
            byte = (val // divisor) & 0xFF
            bytes.append(byte)
            val = val % divisor
        segments.write_arg(ids.bytes, bytes)
    %}
    return (bytes=bytes);
}

// Converts a Uint256 into 32 bytes (big-endian) by splitting high and low parts.
func split_uint256_to_bytes{range_check_ptr}(val: Uint256) -> (bytes: felt*) {
    alloc_locals;
    // Split high and low 128-bit parts into bytes.
    let (high_bytes: felt*) = split_128_to_bytes(val.high);
    let (low_bytes: felt*) = split_128_to_bytes(val.low);
    let bytes: felt* = alloc();
    %{
        high = segments.get(ids.high_bytes, 16)
        low = segments.get(ids.low_bytes, 16)
        combined = high + low
        segments.write_arg(ids.bytes, combined)
    %}
    return (bytes=bytes);
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


func non_commutative_keccak256{
    pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(a: Uint256, b: Uint256) -> (result: Uint256) {
    alloc_locals;

        let ordered_a = a;
        let ordered_b = b;
        let (hash: Uint256) = getKeccakOnlyUint{
            pedersen_ptr=pedersen_ptr,
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr
        }(ordered_a, ordered_b);
        return (hash,);
   
}


func commutative_keccak256_from_felts{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}(a: felt, b: felt) -> (result: Uint256) {
    alloc_locals;

    let a_uint256 = Uint256(low=a, high=0);
    let b_uint256 = Uint256(low=b, high=0);

    let (result: Uint256) = commutative_keccak256{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr
    }(a_uint256, b_uint256);

    return (result,);
}


// Commutative poseidon

func commutative_poseidon{
    poseidon_ptr: PoseidonBuiltin*,
    range_check_ptr
}(a: felt, b: felt) -> (res: felt) {
    alloc_locals;

    %{
        print("a", ids.a)
        print("b", ids.b)
    %}

    // Sort inputs: ensure smaller one comes first
    let a_le_b = is_le_felt(a, b);

    if (a_le_b == 1) {
        let (hash_input: felt*) = alloc();
        assert hash_input[0] = a;
        assert hash_input[1] = b;

        let (res) = poseidon_hash_many(
            n=2,
            elements=hash_input
        );

        return (res,);
    } else {
         let (hash_input: felt*) = alloc();
        assert hash_input[0] = b;
        assert hash_input[1] = a;

        let (res) = poseidon_hash_many(
            n=2,
            elements=hash_input
        );

        return (res,);
    }
}


func non_commutative_poseidon{
    poseidon_ptr: PoseidonBuiltin*,
    range_check_ptr
}(a: felt, b: felt) -> (res: felt) {
    alloc_locals;

    %{
        print("a", ids.a)
        print("b", ids.b)
    %}


        let (hash_input: felt*) = alloc();
        assert hash_input[0] = a;
        assert hash_input[1] = b;

        let (res) = poseidon_hash_many(
            n=2,
            elements=hash_input
        );

        return (res,);
    
}
 // // Serialize Uint256s to byte arrays.
    // let (first_bytes: felt*) = split_uint256_to_bytes(first);
    // let (second_bytes: felt*) = split_uint256_to_bytes(second);

    // // Concatenate the byte arrays.
    // let buffer: felt* = alloc();
    // %{
    //     first_part = segments.get(ids.first_bytes, 32)
    //     second_part = segments.get(ids.second_bytes, 32)
    //     segments.write_arg(ids.buffer, first_part + second_part)
    // %}

    // // Compute and return the Keccak256 hash.
    // let (hash: Uint256) = keccak(buffer, 64);
