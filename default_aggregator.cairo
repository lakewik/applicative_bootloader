%builtins output pedersen range_check bitwise poseidon

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many


struct AggregatedOutput {
    fact_hashes: felt*,
    child_outputs_hashes: felt*,
    num_facts: felt,
}

func main{
    output_ptr: felt*,
    pedersen_ptr: felt*,
    range_check_ptr: felt*,
    bitwise_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local child_outputs: felt**;
    local child_output_lengths: felt*;
    local child_hashes: felt*;
    local num_child_outputs: felt;
    local bootloader_hash: felt;

    %{
        child_outputs = program_input["child_outputs"]
        child_hashes = program_input["child_hashes"]

        child_outputs_ptrs = [segments.gen_arg(sublist) for sublist in child_outputs]

        ids.child_outputs = segments.gen_arg(child_outputs_ptrs)

        ids.child_output_lengths = segments.gen_arg([len(sublist) for sublist in child_outputs])

        ids.child_hashes = segments.gen_arg(child_hashes)
        ids.bootloader_hash = program_input["bootloader_hash"]
        ids.num_child_outputs = len(child_outputs)
    %}

    %{
        print("starting default aggregator execution")
    %}


    let (fact_hashes: felt*) = alloc();
    let (child_outputs_hashes: felt*) = alloc();
    with poseidon_ptr {
        let (fact_hashes, child_outputs_hashes) = compute_fact_hashes(
            child_outputs=child_outputs,
            child_output_lengths=child_output_lengths,
            child_hashes=child_hashes,
            bootloader_hash=bootloader_hash,
            fact_hashes=fact_hashes,
            child_outputs_hashes=child_outputs_hashes,
            remaining=num_child_outputs,
            index=0
        );
    }
    

    let aggregated_output = AggregatedOutput(
        fact_hashes=fact_hashes,
        child_outputs_hashes=child_outputs_hashes,
        num_facts=num_child_outputs,
    );

    let (input_hash: felt) = poseidon_hash_many(n=num_child_outputs, elements=child_outputs_hashes);

    %{
        print("input_hash calculated in aggregator from childs outputs hashes", ids.input_hash)
    %}

    assert output_ptr[0] = input_hash;
    let output_ptr = &output_ptr[1];

    memcpy(
        dst=output_ptr,
        src=fact_hashes,
        len=num_child_outputs,
    );
    let output_ptr = &output_ptr[num_child_outputs];


    //let (output_struct: AggregatedOutput*) = alloc();
   // assert output_struct.fact_hashes = fact_hashes;
   // assert output_struct.num_facts = num_child_outputs;

    //memcpy(dst=output_ptr, src=output_struct, len=1);
    return ();
}


func compute_fact_hashes{
    poseidon_ptr: PoseidonBuiltin*,
}(
    child_outputs: felt**,
    child_output_lengths: felt*,
    child_hashes: felt*,
    bootloader_hash: felt,
    fact_hashes: felt*,
    child_outputs_hashes: felt*,
    remaining: felt,
    index: felt
) -> (fact_hashes: felt*, child_outputs_hashes: felt*) {
    alloc_locals;

    if (remaining == 0) {
        return (fact_hashes=fact_hashes,child_outputs_hashes=child_outputs_hashes);
    }

    let output_ptr = child_outputs[index];
    let output_len = child_output_lengths[index];

    let (output_hash) = poseidon_hash_many(
        n=output_len,
        elements=output_ptr
    );

    let (hash_input: felt*) = alloc();
    assert hash_input[0] = bootloader_hash;
    assert hash_input[1] = child_hashes[index];
    assert hash_input[2] = output_hash;

    let (fact_hash) = poseidon_hash_many(
        n=3,
        elements=hash_input
    );

    %{
        print("aggregator processing child at index", ids.index)
        print("child output hash", ids.output_hash)
    %}
    

    assert fact_hashes[index] = fact_hash;
    assert child_outputs_hashes[index] = output_hash;

    with poseidon_ptr {
        return compute_fact_hashes(
            child_outputs=child_outputs,
            child_output_lengths=child_output_lengths,
            child_hashes=child_hashes,
            bootloader_hash=bootloader_hash,
            fact_hashes=fact_hashes,
            child_outputs_hashes=child_outputs_hashes,
            remaining=remaining - 1,
            index=index + 1
        );
    }
}
