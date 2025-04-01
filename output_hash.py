from starkware.cairo.lang.vm.crypto import poseidon_hash_many

def compute_cairo_output_hash(output_values: list[int]) -> int:
    """
    Computes the Cairo-compatible Poseidon hash of a program's output array.

    Args:
        output_values (List[int]): List of felt outputs from the program.

    Returns:
        int: Poseidon hash of the output array.
    """
    return poseidon_hash_many(output_values)

outputs = [0, 1, 1, 10, 89, 144]
output_hash = compute_cairo_output_hash(outputs)
print(f"Output hash: {output_hash}")