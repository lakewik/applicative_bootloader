import os
import json
from objects import NodeClaim
import tempfile
from utils import cairo_run, stone_prove
from objects import ApplicativeBootloaderInput
from starkware.cairo.bootloaders.simple_bootloader.objects import (
    RunProgramTask,
    Program,
)

INPUT_FOLDER = "inputs"
PROOF_FOLDER = "proofs"
VERIFIER_PROGRAM = "cairo_verifier.compiled.json"
NODE1_PROOF_FILE = "node1.proof.json"
NODE2_PROOF_FILE = "node2.proof.json"
NODE1_AR_PROGRAM_INPUT_FILE = "node1_ar.input.json"
NODE2_AR_PROGRAM_INPUT_FILE = "node2_ar.input.json"
APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE = "applicative_bootloader.input.json"
NODE1_PROGRAM_INPUT_FILE = "node1.input.json"
NODE2_PROGRAM_INPUT_FILE = "node2.input.json"
LAYOUT = "recursive_with_poseidon"
NODE_PROGRAM = "node.compiled.json"
DEFAULT_AGGREGATOR_PROGRAM = "default_aggregator.compiled.json"
DEFAULT_AGGREGATOR_PROGRAM_INPUT_FILE = "default_aggregator.input.json"
APPLICATIVE_BOOTLOADER_PROGRAM = "applicative_bootloader_multiple_nodes.compiled.json"
APPLICATIVE_BOOTLOADER_HASH = 1002739126764932141686192315730668396057451740662147624852550207088289098496



def main():
    # Create inputs and run the nodes
    print ("Preparing inputs, generating traceand proving the children programs...")
    # with open(os.path.join(INPUT_FOLDER, NODE1_PROGRAM_INPUT_FILE), "w") as f:
    #     f.write(json.dumps(NodeClaim.Schema().dump(NodeClaim(1, 1, 10))))

    # with open(os.path.join(INPUT_FOLDER, NODE2_PROGRAM_INPUT_FILE), "w") as f:
    #     f.write(json.dumps(NodeClaim.Schema().dump(NodeClaim(89, 144, 10))))
    
    # with tempfile.TemporaryDirectory() as tmpdir:
    #     cairo_run(
    #         tmpdir=tmpdir,
    #         layout=LAYOUT,
    #         program=NODE_PROGRAM,
    #         program_input=os.path.join(INPUT_FOLDER, NODE1_PROGRAM_INPUT_FILE),
    #     )

    #     stone_prove(tmpdir=tmpdir, out_file="./proofs/node1.proof.json")

    # with tempfile.TemporaryDirectory() as tmpdir:
    #     cairo_run(
    #         tmpdir=tmpdir,
    #         layout=LAYOUT,
    #         program=NODE_PROGRAM,
    #         program_input=os.path.join(INPUT_FOLDER, NODE2_PROGRAM_INPUT_FILE),
    #     )

    #     stone_prove(tmpdir=tmpdir, out_file="./proofs/node2.proof.json")


    # Prepare inputs to applicative bootloader
    print ("Preparing inputs for default applicative bootloader execution...")
    with open(
        os.path.join(INPUT_FOLDER, APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE), "w"
    ) as f:
        f.write(
            json.dumps(
                ApplicativeBootloaderInput.Schema().dump(
                    ApplicativeBootloaderInput(
                        aggregator_task=RunProgramTask(
                            program=Program.Schema().load(
                                json.loads(open(DEFAULT_AGGREGATOR_PROGRAM, "r").read())
                            ),
                            program_input={
                                "bootloader_hash": APPLICATIVE_BOOTLOADER_HASH,
                                "child_hashes": [2557027888828840286493295052495263447296531023603501824658462648621573665939, 2557027888828840286493295052495263447296531023603501824658462648621573665939],
                                "child_outputs": [
                                    [0, 1, 1, 10, 89, 144],
                                    [0, 89, 144, 10, 10946, 17711]
                                ]
                            },
                            use_poseidon=True,
                        ),
                        tasks=[
                            RunProgramTask(
                                program=Program.Schema().load(
                                    json.loads(open(VERIFIER_PROGRAM, "r").read())
                                ),
                                program_input={
                                    "proof": json.loads(
                                        open(
                                            os.path.join(PROOF_FOLDER, NODE1_PROOF_FILE),
                                            "r",
                                        ).read()
                                    )
                                },
                                use_poseidon=True,
                            ),
                            RunProgramTask(
                                program=Program.Schema().load(
                                    json.loads(open(VERIFIER_PROGRAM, "r").read())
                                ),
                                program_input={
                                    "proof": json.loads(
                                        open(
                                            os.path.join(PROOF_FOLDER, NODE2_PROOF_FILE),
                                            "r",
                                        ).read()
                                    )
                                },
                                use_poseidon=True,
                            ),
                        ],
                    )
                )
            )
        )

        print ("Running the defaultn applicative bootloader with children nodes proofs and aggregator children nodes inputs...")
        with tempfile.TemporaryDirectory() as tmpdir:
            cairo_run(
                tmpdir=tmpdir,
                layout=LAYOUT,
                program=APPLICATIVE_BOOTLOADER_PROGRAM,
                program_input=os.path.join(
                    INPUT_FOLDER, APPLICATIVE_BOOTLOADER_PROGRAM_INPUT_FILE
                ),
            )

        # stone_prove(
        #     tmpdir=tmpdir, out_file="./proofs/applicative_bootloader.proof.json"
        # )




main()





