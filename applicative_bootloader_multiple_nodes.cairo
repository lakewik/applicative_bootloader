%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon range_check96 add_mod mul_mod

from starkware.cairo.bootloaders.simple_bootloader.run_simple_bootloader import (
    run_simple_bootloader,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.cairo_verifier.objects import CairoVerifierOutput
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from objects import (
    BootloaderOutput,
    bootloader_output_extract_output_hashes,
    applicative_bootloader_output_serialize,
    ApplicativeBootloaderOutput,
)
from poseidon_merkle_tree import merkle_tree_poseidon
from keccak_merkle_tree import merkle_tree_keccak, alloc_uint256_array, hash_leaves_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.uint256 import felt_to_uint256

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr,
    ec_op_ptr,
    keccak_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr,
    add_mod_ptr,
    mul_mod_ptr,
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

    %{ print("applicative bootloader starting aggregator bootloading phase") %}

    // // Check if the number of childs outputs matches with the number of child proofs provided
    // assert num_proofs_provided = nodes_len;

    // Save aggregator output start.
    let aggregator_output_start: felt* = aggregator_output_ptr;

    // Execute the simple bootloader with the aggregator task.
    run_simple_bootloader{output_ptr=aggregator_output_ptr}();
    local range_check_ptr = range_check_ptr;
    local bitwise_ptr = bitwise_ptr;
    local ecdsa_ptr = ecdsa_ptr;
    local ec_op_ptr = ec_op_ptr;
    local keccak_ptr = keccak_ptr;
    local pedersen_ptr: HashBuiltin* = pedersen_ptr;
    local poseidon_ptr: PoseidonBuiltin* = poseidon_ptr;
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

        POSEIDON_HASH_FUNCTION_CHOICE = ids.POSEIDON_HASH_FUNCTION_CHOICE
        KECCAK_HASH_FUNCTION_CHOICE = ids.KECCAK_HASH_FUNCTION_CHOICE


        # Save the aggregator's fact_topologies before running the bootloader.
        aggregator_fact_topologies = fact_topologies
        fact_topologies = []

        # Create a segment for the bootloader output.
        ids.bootloader_output_ptr = segments.add()

        # Extract verifier compild program and child proofs
        stark_verifier = applicative_bootloader_input.stark_verifier
        childs_proofs = applicative_bootloader_input.childs_proofs


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

        #ids.num_proofs_provided = len(childs_proofs)

        print(f"output_merkle_tree_hasher_choice: {applicative_bootloader_input.output_merkle_tree_hasher_choice}")


        if applicative_bootloader_input.output_merkle_tree_hasher_choice == "POSEIDON":
            ids.output_merkle_tree_hasher_choice = POSEIDON_HASH_FUNCTION_CHOICE
        elif applicative_bootloader_input.output_merkle_tree_hasher_choice == "KECCAK":
            ids.output_merkle_tree_hasher_choice = KECCAK_HASH_FUNCTION_CHOICE
        else:
            raise Exception(f"Unknown hasher choice: {applicative_bootloader_input.output_merkle_tree_hasher_choice}")

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


    %{ print("applicative bootloader starting verifiers bootloading phase") %}

    // Save the bootloader output start.
    let bootloader_output_start = bootloader_output_ptr;

    // Execute the bootloader.
    run_simple_bootloader{output_ptr=bootloader_output_ptr}();
    local range_check_ptr = range_check_ptr;
    local bitwise_ptr = bitwise_ptr;
    local ecdsa_ptr = ecdsa_ptr;
    local ec_op_ptr = ec_op_ptr;
    local keccak_ptr = keccak_ptr;
    local pedersen_ptr: HashBuiltin* = pedersen_ptr;
    local poseidon_ptr: PoseidonBuiltin* = poseidon_ptr;
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

    %{ print("applicative bootloader finished verifiers bootloading phase") %}

    %{
        print("=== aggregator_input_ptr[0] ===")
        print("aggregator_input_ptr[0] =", memory[ids.aggregator_input_ptr])

        for i in range(ids.nodes_len):
            print(f"--- Node {i} ---")

            print("output_hash", memory[ids.output_hashes + i])
            print("verified_program_hash", memory[ids.verified_program_hashes + i])
    %}

    let (input_hash: felt) = poseidon_hash_many(n=nodes_len, elements=output_hashes);

    %{ print("input_hash calculated in applicative bootloader", ids.input_hash) %}

    %{ print("input_hash from applicative bootloader calculated on aggregator", memory[ids.aggregator_input_ptr]) %}

    // Check if aggregator program was ran on correct inputs
    assert aggregator_input_ptr[0] = input_hash;

    %{
        # Restore the output builtin state.
        output_builtin.set_state(applicative_output_builtin_state)
    %}


    let (fact_hashes: felt*) = alloc();
    with poseidon_ptr {
        let (fact_hashes) = compute_fact_hashes(
            child_outputs_hashes=output_hashes,
            child_hashes=verified_program_hashes,
            aggregator_hash=aggregator_program_hash,
            fact_hashes=fact_hashes,
            remaining=nodes_len,
            index=0,
        );
    }

    let range_check_ptr = range_check_ptr;
    let pedersen_ptr = pedersen_ptr;

    let range_check_ptr = range_check_ptr;

    // POSEIDON CHOICE //
    if (output_merkle_tree_hasher_choice == POSEIDON_HASH_FUNCTION_CHOICE) {
        %{ print("startig poseidon Merkle Tree construction") %}

        let (root_poseidon) = merkle_tree_poseidon(nodes_len, fact_hashes, 0, 1);
        let range_check_ptr = range_check_ptr;

        %{ print("Fact hasher Merkle Tree root poseidon: ", ids.root_poseidon) %}

        local applicative_bootloader_output: ApplicativeBootloaderOutput = ApplicativeBootloaderOutput(
            aggregator_program_hash=aggregator_program_hash,
                merkle_tree_root_low=root_poseidon,
                merkle_tree_root_high=0,
            );

        memcpy(
            dst=output_ptr,
            src=applicative_bootloader_output_serialize(obj=&applicative_bootloader_output),
            len=ApplicativeBootloaderOutput.SIZE,
        );
        let output_ptr = &output_ptr[ApplicativeBootloaderOutput.SIZE];

        return ();
    }

    // KECCAK CHOICE //
    if (output_merkle_tree_hasher_choice == KECCAK_HASH_FUNCTION_CHOICE) {
        %{ print("startig keccak256 Merkle Tree construction") %}

        let (uint256_fact_hashes: Uint256*) = alloc();
        let uint256_fact_hashes_end = uint256_fact_hashes + nodes_len * Uint256.SIZE;

        %{ print("converting fact hahes to uint256") %}

        let (uint256_fact_hashes_end) = felt_array_to_uint256_array(
            input_array=fact_hashes, output_array=uint256_fact_hashes, length=nodes_len, index=0
        );

        let bitwise_ptr2 = cast(bitwise_ptr, BitwiseBuiltin*);

        let (root_keccak) = merkle_tree_keccak{bitwise_ptr=bitwise_ptr2}(
            nodes_len, uint256_fact_hashes, 0, 1
        );
        let bitwise_ptr3 = cast(bitwise_ptr2, felt);
        let bitwise_ptr = bitwise_ptr3;

        %{
            # Convert low and high parts to hex strings
            low_hex = f"{ids.root_keccak.low:032x}"
            high_hex = f"{ids.root_keccak.high:032x}"

            # Combine to full 64-character hex string
            full_hash_hex = high_hex + low_hex

            # Print input and output
            print(f"Fact hasher Merkle Root Keccak hash: 0x{full_hash_hex}")
        %}

        local applicative_bootloader_output: ApplicativeBootloaderOutput = ApplicativeBootloaderOutput(
            aggregator_program_hash=aggregator_program_hash,
                merkle_tree_root_low=root_keccak.low,
                merkle_tree_root_high=root_keccak.high,
            );

        memcpy(
            dst=output_ptr,
            src=applicative_bootloader_output_serialize(obj=&applicative_bootloader_output),
            len=ApplicativeBootloaderOutput.SIZE,
        );
        let output_ptr = &output_ptr[ApplicativeBootloaderOutput.SIZE];

        return ();
    }

    return ();
}

func compute_fact_hashes{poseidon_ptr: PoseidonBuiltin*}(
    child_outputs_hashes: felt*,
    child_hashes: felt*,
    aggregator_hash: felt,
    fact_hashes: felt*,
    remaining: felt,
    index: felt,
) -> (fact_hashes: felt*) {
    alloc_locals;

    if (remaining == 0) {
        return (fact_hashes=fact_hashes);
    }

    let (hash_input: felt*) = alloc();
    // assert hash_input[0] = aggregator_hash;
    assert hash_input[0] = child_hashes[index];
    assert hash_input[1] = child_outputs_hashes[index];

    let (fact_hash) = poseidon_hash_many(n=2, elements=hash_input);

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
            index=index + 1,
        );
    }
}

func felt_array_to_uint256_array{pedersen_ptr: HashBuiltin*, range_check_ptr}(
    input_array: felt*, output_array: Uint256*, length: felt, index: felt
) -> (output_array: Uint256*) {
    if (index == length) {
        return (output_array=output_array);
    }

    let current_felt: felt = input_array[index];

    let current_uint256: Uint256 = felt_to_uint256(current_felt);

    assert output_array[0] = current_uint256;

    return felt_array_to_uint256_array(
        input_array=input_array,
        output_array=output_array + Uint256.SIZE,
        length=length,
        index=index + 1,
    );
}
