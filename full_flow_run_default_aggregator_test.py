import os
import json
import logging
import tempfile
import time

from objects import (
    NodeClaim,
    StarkVerifier,
    ChildProof,
    ApplicativeBootloaderInput
)
from utils import cairo_run, stone_prove, cairo_run_modified
from starkware.cairo.bootloaders.simple_bootloader.objects import (
    RunProgramTask,
    Program
)

# Configure logging to include timestamp
logging.basicConfig(
    format="%(asctime)s %(levelname)-8s %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S"
)

INPUT_FOLDER = "inputs"
PROOF_FOLDER = "proofs"
VERIFIER_PROGRAM = "cairo_verifier.compiled.json"
NODE1_PROOF_FILE = "node1.proof.json"
NODE2_PROOF_FILE = "node2.proof.json"
NODE3_PROOF_FILE = "node3.proof.json"

APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE = "applicative_bootloader.input.json"
DEFAULT_AGGREGATOR_PROGRAM = "default_aggregator.compiled.json"
VERIFIER_PROGRAM = "cairo_verifier.compiled.json"
APPLICATIVE_BOOTLOADER_PROGRAM = "applicative_bootloader_multiple_nodes.compiled.json"

LAYOUT = "recursive_with_poseidon"
OUTPUT_MERKLE_TREE_HASHER_CHOICE = "KECCAK"  # or "POSEIDON"


def main():
    start_time = time.time()
    logging.info("Script started.")

    # === Child programs preparation ===
    logging.info("Preparing inputs and generating proofs for child programs...")

    # Example for node1 (uncomment and adjust as needed)
    # with open(os.path.join(INPUT_FOLDER, "node1.input.json"), "w") as f:
    #     json.dump(NodeClaim.Schema().dump(NodeClaim(1, 1, 10)), f)
    #
    # with tempfile.TemporaryDirectory() as tmpdir:
    #     cairo_run(
    #         tmpdir=tmpdir,
    #         layout=LAYOUT,
    #         program="node.compiled.json",
    #         program_input=os.path.join(INPUT_FOLDER, "node1.input.json"),
    #     )
    #     stone_prove(tmpdir=tmpdir, out_file=os.path.join(PROOF_FOLDER, NODE1_PROOF_FILE))
    # logging.info("Child program 1 proved.")

    # (Repeat for node2, node3 as needed)
    # ...

    logging.info("Child programs preparation complete.")

    # === Applicative bootloader input ===
    logging.info("Preparing inputs for applicative bootloader execution.")
    t0 = time.time()
    with open(os.path.join(INPUT_FOLDER, APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE), "w") as f:
        appl_input = ApplicativeBootloaderInput.Schema().dump(
            ApplicativeBootloaderInput(
                aggregator_task=RunProgramTask(
                    program=Program.Schema().load(
                        json.loads(open(DEFAULT_AGGREGATOR_PROGRAM, "r").read())
                    ),
                    program_input={
                        "child_outputs": [
                            [0, 1, 1, 10, 89, 144],
                            [0, 89, 144, 10, 10946, 17711],
                            [0, 10946, 17711, 10, 1346269, 2178309]
                        ]
                    },
                    use_poseidon=True,
                ),
                stark_verifier=StarkVerifier(
                    program=Program.Schema().load(
                        json.loads(open(VERIFIER_PROGRAM, "r").read())
                    ),
                    use_poseidon=True,
                ),
                childs_proofs=[
                    ChildProof(proof=json.load(open(os.path.join(PROOF_FOLDER, NODE1_PROOF_FILE), "r"))),
                    ChildProof(proof=json.load(open(os.path.join(PROOF_FOLDER, NODE2_PROOF_FILE), "r"))),
                    ChildProof(proof=json.load(open(os.path.join(PROOF_FOLDER, NODE3_PROOF_FILE), "r"))),
                ],
                output_merkle_tree_hasher_choice=OUTPUT_MERKLE_TREE_HASHER_CHOICE
            )
        )
        f.write(json.dumps(appl_input))
    logging.info(f"Applicative bootloader input written (took {time.time() - t0:.2f}s).")

    # === Run applicative bootloader ===
    logging.info("Running the applicative bootloader with children proofs and aggregator inputs.")
    t1 = time.time()
    with tempfile.TemporaryDirectory() as tmpdir:
        cairo_run_modified(
            tmpdir=tmpdir,
            layout=LAYOUT,
            program=APPLICATIVE_BOOTLOADER_PROGRAM,
            program_input=os.path.join(INPUT_FOLDER, APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE),
        )
    logging.info(f"Applicative bootloader execution finished (took {time.time() - t1:.2f}s).")

    total_time = time.time() - start_time
    logging.info(f"Script completed in {total_time:.2f}s.")


if __name__ == "__main__":
    main()
