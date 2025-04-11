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
from poseidon_merkle_tree import merkle_tree_poseidon
from keccak_merkle_tree import merkle_tree_keccak




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
    let c = Uint256(low=195143356298950239236390551223274915282, high=253627162908404395944762862209573068050); // beced09521047d05b8960b7e7bcc1d1292cf3e4b2a6b63f48335cbde5f7545d2

    
    

//     // Call your hashing function
//     let (hash: Uint256) = commutative_keccak256{
//        pedersen_ptr=pedersen_ptr,
//        range_check_ptr=range_check_ptr,
//        bitwise_ptr=bitwise_ptr
//     }(b, a);

//      %{
//     # Access low and high parts
//     low = ids.hash.low
//     high = ids.hash.high

//     # Combine to full 256-bit integer
//     full_hash = (high << 128) + low

//     print(f"Keccak256 hash (uint256): {full_hash}")
//   %}

  // Example data: [1, 2, 3, 4, 5]
    let leaves: felt* = alloc();
    assert leaves[0] = 111;
    assert leaves[1] = 222;
    assert leaves[2] = 333;
    assert leaves[3] = 444;
    assert leaves[4] = 555;

     let leaf_count = 5;

     let (root) = merkle_tree_poseidon(leaf_count, leaves, 0, 0);

     %{
print("==== Merkle Root Node ====")

root_hex = f"{ids.root:032x}"
print(f"Merkle root       : 0x{root_hex}")
print("===========================")
%}


    // Example array of 5 felts (leaf nodes)
    // let (local leaves : Uint256*) = alloc();
    // assert leaves[0] = Uint256(low=42, high=0);  // leaf 0
    // assert leaves[1] = Uint256(low=999, high=0);  // leaf 1
    // assert leaves[2] = Uint256(low=7, high=0); // leaf 2
    // assert leaves[3] = Uint256(low=7, high=0); // leaf 3
    // assert leaves[4] = Uint256(low=1000, high=0);  // leaf 4
    //  assert leaves[5] = Uint256(low=3, high=0);  // leaf 4
    //   assert leaves[6] = Uint256(low=7, high=0);  // leaf 4

    //       assert leaves[7] = Uint256(low=42, high=0);  // leaf 0
    // assert leaves[8] = Uint256(low=999, high=0);  // leaf 1
    // assert leaves[9] = Uint256(low=7, high=0); // leaf 2
    // assert leaves[10] = Uint256(low=7, high=0); // leaf 3
    // assert leaves[11] = Uint256(low=1000, high=0);  // leaf 4
    //  assert leaves[12] = Uint256(low=3, high=0);  // leaf 4
    //   assert leaves[13] = Uint256(low=7, high=0);  // leaf 4

    // Compute Merkle root (leaves are not yet hashed)
//     let (root) = merkle_tree(6, leaves, 0);
// %{
// print("==== Merkle Root Node ====")
// print("Merkle root       :", ids.root)

// print("===========================")
// %}


//  let (root) = merkle_tree_keccak(14, leaves, 0);

//      %{
//     # Access low and high parts
//     low = ids.root.low
//     high = ids.root.high

//     # Combine to full 256-bit integer
//     full_hash = (high << 128) + low

//     print(f"Keccak256 merkle root (uint256): {full_hash}")
//   %}

//   %{
//         # Convert low and high parts to hex strings
//         low_hex = f"{ids.root.low:032x}"
//         high_hex = f"{ids.root.high:032x}"
        
//         # Combine to full 64-character hex string
//         full_hash_hex = high_hex + low_hex
        
//         # Print input and output
//         print(f"Merkle Root Keccak hash: 0x{full_hash_hex}")
//     %}
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


    
//       let a1 = 333;
//       let b1 = 777;

//       let (hash1) = commutative_poseidon{poseidon_ptr=poseidon_ptr}(a1, b1);

//     %{
   

//     print(f"Poseidon hash (felt252): {ids.hash1}")
//  %}




    // You can return just the low part for demo
    return ();

}

