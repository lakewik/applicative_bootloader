from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.cairo_verifier.objects import CairoVerifierOutput
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many

const CAIRO_VERIFIER_HASH = 1124484076121087675506348512821615562376526669646204108987754749252053847251;

struct NodeClaim {
    a_start: felt,
    b_start: felt,
    n: felt,
}

struct NodeResult {
    a_start: felt,
    b_start: felt,
    n: felt,
    a_end: felt,
    b_end: felt,
}

struct ApplicativeResult {
    path_hash: felt,
    node_result: NodeResult*,
}

struct ApplicativeBootloaderOutput {
    aggregator_program_hash: felt,
    merkle_tree_root_low: felt,
    merkle_tree_root_high: felt,
}

func applicative_result_serialize(obj: ApplicativeResult*) -> felt* {
    let (serialized: felt*) = alloc();

    assert serialized[0] = obj.path_hash;
    assert serialized[1] = obj.node_result.a_start;
    assert serialized[2] = obj.node_result.b_start;
    assert serialized[3] = obj.node_result.n;
    assert serialized[4] = obj.node_result.a_end;
    assert serialized[5] = obj.node_result.b_end;

    return serialized;
}

func applicative_bootloader_output_serialize(obj: ApplicativeBootloaderOutput*) -> felt* {
    let (serialized: felt*) = alloc();

    assert serialized[0] = obj.aggregator_program_hash;
    assert serialized[1] = obj.merkle_tree_root_low;
    assert serialized[2] = obj.merkle_tree_root_high;

    return serialized;
}

struct BootloaderOutput {
    output_length: felt,
    program_hash: felt,
    program_output: CairoVerifierOutput,
}

func bootloader_output_extract_output_hashes(
    list: BootloaderOutput*, len: felt, verified_program_hashes: felt*, output_hashes: felt*
) {
    if (len == 0) {
        return ();
    }

    // Assert that the bootloader ran cairo0 verifiers.
    assert list[0].program_hash = CAIRO_VERIFIER_HASH;

    // extract only output_hash of node
    assert verified_program_hashes[0] = list[0].program_output.program_hash;
    assert output_hashes[0] = list[0].program_output.output_hash;
    return bootloader_output_extract_output_hashes(
        list=&list[1],
        len=len - 1,
        verified_program_hashes=&verified_program_hashes[1],
        output_hashes=&output_hashes[1],
    );
}

func applicative_results_calculate_hashes{poseidon_ptr: PoseidonBuiltin*}(
    list: ApplicativeResult*, len: felt, output: felt*
) {
    if (len == 0) {
        return ();
    }

    let (hash) = poseidon_hash_many(
        n=ApplicativeResult.SIZE + NodeResult.SIZE - 1,
        elements=applicative_result_serialize(obj=list),
    );
    assert output[0] = hash;
    return applicative_results_calculate_hashes(list=&list[1], len=len - 1, output=&output[1]);
}
