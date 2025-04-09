%builtins output pedersen range_check bitwise poseidon

from starkware.cairo.bootloaders.simple_bootloader.run_simple_bootloader import (
    run_simple_bootloader,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.cairo_verifier.objects import CairoVerifierOutput
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from objects import BootloaderOutput, bootloader_output_extract_output_hashes
from poseidon_merkle_tree import merkle_tree_poseidon
from keccak_merkle_tree import merkle_tree_keccak
from starkware.cairo.common.uint256 import Uint256


func hash_verified_program_hashes{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr,
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
    bitwise_ptr,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let KECCAK_HASH_FUNCTION_CHOICE: felt = 497316108213659;
    let POSEIDON_HASH_FUNCTION_CHOICE: felt = 59887982162162102766224430;

    let (__fp__, _) = get_fp_and_pc();

    // A pointer to the aggregator's task output.
    local aggregator_output_ptr: felt*;
    %{
        from objects import ApplicativeBootloaderInput
        from starkware.cairo.bootloaders.simple_bootloader.objects import SimpleBootloaderInput

        # Create a segment for the aggregator output.
        ids.aggregator_output_ptr = segments.add()

        # Load the applicative bootloader input and the aggregator task.
        applicative_bootloader_input = ApplicativeBootloaderInput.Schema().load(program_input)
        aggregator_task = applicative_bootloader_input.aggregator_task.load_task()

        # Create the simple bootloader input.
        simple_bootloader_input = SimpleBootloaderInput(
            tasks=[aggregator_task], fact_topologies_path=None, single_page=True
        )

        # Change output builtin state to a different segment in preparation for running the
        # aggregator task.
        applicative_output_builtin_state = output_builtin.get_state()
        output_builtin.new_state(base=ids.aggregator_output_ptr)
    %}

    %{
        print("applicative bootloader starting aggregator bootloading phase")
    %}

    // Save aggregator output start.
    let aggregator_output_start: felt* = aggregator_output_ptr;

    // Execute the simple bootloader with the aggregator task.
    run_simple_bootloader{output_ptr=aggregator_output_ptr}();
    let range_check_ptr = range_check_ptr;
    let bitwise_ptr = bitwise_ptr;
    let pedersen_ptr: HashBuiltin* = pedersen_ptr;
    let poseidon_ptr: PoseidonBuiltin* = poseidon_ptr;
    local aggregator_output_end: felt* = aggregator_output_ptr;

    // Check that exactly one task was executed.
    assert aggregator_output_start[0] = 1;

    // Extract the aggregator output size and program hash.
    let aggregator_output_length = aggregator_output_start[1];
    let aggregator_program_hash = aggregator_output_start[2];
    let aggregator_input_ptr = &aggregator_output_start[3];

    %{
        print("hash of default applicative aggregator", ids.aggregator_program_hash)
        print("applicative bootloader finished aggregator bootloading phase")
    %}

    // Allocate a segment for the bootloader output.
    local bootloader_output_ptr: felt*;
    local output_merkle_tree_hasher_choice: felt;
    %{
        from starkware.cairo.bootloaders.simple_bootloader.objects import SimpleBootloaderInput, RunProgramTask
        from starkware.cairo.lang.compiler.program import Program
        from objects import ChildProof


        # Save the aggregator's fact_topologies before running the bootloader.
        aggregator_fact_topologies = fact_topologies
        fact_topologies = []

        # Create a segment for the bootloader output.
        ids.bootloader_output_ptr = segments.add()
        
        # Extract verifier compild program and child proofs
        stark_verifier = applicative_bootloader_input.stark_verifier
        childs_proofs = applicative_bootloader_input.childs_proofs

        print("meow2")


        # Build a list of RunProgramTask objects
        tasks = []
        for child in childs_proofs:
            tasks.append(
                RunProgramTask(
                    program=stark_verifier.program,
                    program_input={
                                "proof": child.proof
                    },
                    use_poseidon=stark_verifier.use_poseidon
                )
            )

        print("meow3")

        ids.output_merkle_tree_hasher_choice = applicative_bootloader_input.output_merkle_tree_hasher

        # Create the bootloader input.
        simple_bootloader_input = SimpleBootloaderInput(
            tasks=tasks,
            fact_topologies_path=None,
            single_page=True
        )

        # Change output builtin state to a different segment in preparation for running the
        # bootloader.
        output_builtin.new_state(base=ids.bootloader_output_ptr)
    %}

    %{
        print("applicative bootloader starting verifiers bootloading phase")
    %}

    // Save the bootloader output start.
    let bootloader_output_start = bootloader_output_ptr;

    // Execute the bootloader.
    run_simple_bootloader{output_ptr=bootloader_output_ptr}();
    let range_check_ptr = range_check_ptr;
    let bitwise_ptr = bitwise_ptr;
    let pedersen_ptr: HashBuiltin* = pedersen_ptr;
    let poseidon_ptr: PoseidonBuiltin* = poseidon_ptr;
    local bootloader_output_end: felt* = bootloader_output_ptr;

    let bootloader_output_length = bootloader_output_end - bootloader_output_start - 1;
    let nodes_len = bootloader_output_length / BootloaderOutput.SIZE;

    // Assert that the bootloader output agrees with the aggregator input.
    let (local verified_program_hashes: felt*) = alloc();
    let (local output_hashes: felt*) = alloc();
    bootloader_output_extract_output_hashes(
        list=cast(&bootloader_output_start[1], BootloaderOutput*),
        len=nodes_len,
        verified_program_hashes=verified_program_hashes,
        output_hashes=output_hashes,
    );

    %{
        print("applicative bootloader finished verifiers bootloading phase")
    %}

    %{
        print("=== aggregator_input_ptr[0] ===")
        print("aggregator_input_ptr[0] =", memory[ids.aggregator_input_ptr])

        for i in range(ids.nodes_len):
            base = ids.bootloader_output_start + i * 4  # 4 fields per BootloaderOutput
            output_len = memory[base]
            #program_hash = memory[base + 1]
            output_start = memory[base + 2]
            output_end = memory[base + 3]

            print(f"--- Node {i} ---")
            #print("program_hash", program_hash)
            #print("output_length", output_len)
            print("output_hash", memory[ids.output_hashes + i])
            print("verified_program_hash", memory[ids.verified_program_hashes + i])
    %}

    let (input_hash: felt) = poseidon_hash_many(n=nodes_len, elements=output_hashes);

    %{
        print("input_hash calculated in applicative bootloader", ids.input_hash)
    %}

    %{
        print("input_hash from applicative bootloader calculated on aggregator", memory[ids.aggregator_input_ptr])
    %}

    // Check if aggregator program was ran on correct inputs
    assert aggregator_input_ptr[0] = input_hash;

    %{
        # Restore the output builtin state.
        output_builtin.set_state(applicative_output_builtin_state)
    %}

    let aggregated_output_ptr = aggregator_input_ptr + 1;
    let aggregated_output_length = aggregator_output_end - aggregated_output_ptr;

    let (path_hash_buff: felt*) = alloc();
    tempvar path_hash_buff_size = nodes_len + 2;
    
    // aggregator program path_hash
    assert path_hash_buff[0] = aggregated_output_ptr[0];
    
    // aggregator program hash 
    assert path_hash_buff[1] = aggregator_program_hash;
    
    // copy all verified program hashes
    let (path_hash_ptr: felt*) = alloc();
    let path_hash_ptr = path_hash_buff + 2;
    
    // copy verified program hashes to path_hash_buff
    memcpy(dst=path_hash_ptr, src=verified_program_hashes, len=nodes_len);
    
    // calclate the final path hash
    let (path_hash: felt) = poseidon_hash_many(n=nodes_len + 2, elements=path_hash_buff);

    let (fact_hashes: felt*) = alloc();
    with poseidon_ptr {
        let (fact_hashes) = compute_fact_hashes(
            child_outputs_hashes=output_hashes,
            child_hashes=verified_program_hashes,
            aggregator_hash=aggregator_program_hash,
            fact_hashes=fact_hashes,
            remaining=nodes_len,
            index=0
        );
    }

    assert output_ptr[0] = path_hash;
    let output_ptr = &output_ptr[1];

    %{
        print("path_hash", ids.path_hash)
    %}

    memcpy(dst=output_ptr, src=aggregated_output_ptr, len=aggregated_output_length);
    let output_ptr = output_ptr + aggregated_output_length;

    //memcpy(dst=output_ptr, src=fact_hashes, len=nodes_len);
    if (output_merkle_tree_hasher_choice == POSEIDON_HASH_FUNCTION_CHOICE) {
        let (root) = merkle_tree_poseidon(nodes_len, fact_hashes, 0, 1);
    } 
    
    if (output_merkle_tree_hasher_choice == KECCAK_HASH_FUNCTION_CHOICE) {
        let (local uint256_hashes : Uint256*) = alloc();

         felt_array_to_uint256_array{range_check_ptr=range_check_ptr}(nodes_len, fact_hashes, uint256_hashes, 0);
        
        
        let (root) = merkle_tree_keccak(nodes_len, fact_hashes, 0, 1);
    }
    
    %{
        print("FAct hasher Merkle Tree root: ", ids.root)
    %}
    let output_ptr = output_ptr + nodes_len;

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


func felt_array_to_uint256_array{range_check_ptr}(
    input_len : felt, 
    input : felt*, 
    output : Uint256*, 
    index : felt
) -> () {
    alloc_locals;
    
    if (index == input_len) {
        return ();
    }
    
    // Convert each felt to Uint256 (low = value, high = 0)
    assert [output + index] = Uint256([input + index], 0);
    
    // Process next element
    return felt_array_to_uint256_array{range_check_ptr=range_check_ptr}(input_len, input, output, index + 1);
}