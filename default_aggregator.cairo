%builtins output pedersen range_check bitwise poseidon

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many

struct AggregatedOutput {
    child_outputs_hashes: felt*,
    num_outputs_hashes: felt,
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
    local num_child_outputs: felt;

    %{
        import re

        # pull raw lists (may contain ints or hex‐strings)
        child_outputs = program_input["child_outputs"]

        # helper: convert "0x..." strings to ints, leave other values untouched
        def parse_val(v):
            if isinstance(v, str) and re.fullmatch(r'0[xX][0-9a-fA-F]+', v):
                return int(v, 16)
            return v

        # apply parsing to each element
        parsed_child_outputs = [
            [parse_val(v) for v in sublist]
            for sublist in child_outputs
        ]

        # now generate your segments exactly as before
        child_outputs_ptrs       = [segments.gen_arg(sublist) for sublist in parsed_child_outputs]
        ids.child_outputs        = segments.gen_arg(child_outputs_ptrs)
        ids.child_output_lengths = segments.gen_arg([len(sublist) for sublist in parsed_child_outputs])
        ids.num_child_outputs    = len(parsed_child_outputs)
    %}

    %{ print("starting default aggregator execution") %}

    let (child_outputs_hashes: felt*) = alloc();
    with poseidon_ptr {
        let (child_outputs_hashes) = compute_childs_outputs_hashes(
            child_outputs=child_outputs,
            child_output_lengths=child_output_lengths,
            child_outputs_hashes=child_outputs_hashes,
            remaining=num_child_outputs,
            index=0,
        );
    }

    let aggregated_output = AggregatedOutput(
        child_outputs_hashes=child_outputs_hashes, num_outputs_hashes=num_child_outputs
    );

    let (input_hash: felt) = poseidon_hash_many(n=num_child_outputs, elements=child_outputs_hashes);

    %{ print("input_hash calculated in aggregator from childs outputs hashes", ids.input_hash) %}

    assert output_ptr[0] = input_hash;
    let output_ptr = &output_ptr[1];

    memcpy(dst=output_ptr, src=child_outputs_hashes, len=num_child_outputs);
    let output_ptr = &output_ptr[num_child_outputs];

    // let (output_struct: AggregatedOutput*) = alloc();
    // assert output_struct.fact_hashes = fact_hashes;
    // assert output_struct.num_facts = num_child_outputs;

    // memcpy(dst=output_ptr, src=output_struct, len=1);
    return ();
}

func compute_childs_outputs_hashes{poseidon_ptr: PoseidonBuiltin*}(
    child_outputs: felt**,
    child_output_lengths: felt*,
    child_outputs_hashes: felt*,
    remaining: felt,
    index: felt,
) -> (child_outputs_hashes: felt*) {
    alloc_locals;

    if (remaining == 0) {
        return (child_outputs_hashes=child_outputs_hashes);
    }

    let output_ptr = child_outputs[index];
    let output_len = child_output_lengths[index];

    let (output_hash) = poseidon_hash_many(n=output_len, elements=output_ptr);

    %{
        print("aggregator processing child at index", ids.index)
        print("child output hash", ids.output_hash)
    %}

    assert child_outputs_hashes[index] = output_hash;

    with poseidon_ptr {
        return compute_childs_outputs_hashes(
            child_outputs=child_outputs,
            child_output_lengths=child_output_lengths,
            child_outputs_hashes=child_outputs_hashes,
            remaining=remaining - 1,
            index=index + 1,
        );
    }
}
