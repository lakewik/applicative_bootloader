use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::error::Error;
use tempfile::tempdir;

use cairo_program_runner_lib::cairo_run_program;
use cairo_program_runner_lib::types::RunMode;
use cairo_vm::types::layout_name::LayoutName;
use cairo_vm::types::program::Program;
use cairo_vm::vm::errors::vm_exception::VmException;
//use cairo_program_runner_lib::CairoRunError;
use cairo_vm::vm::errors::cairo_run_errors::CairoRunError;

fn main() -> Result<(), Box<dyn Error>> {
    let project_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
   // let input_folder = project_dir.join("inputs");
    let proof_folder = project_dir.join("proofs");

    // Load all necessary compiled programs
    let bootloader_program_path = project_dir.join("resources/compiled_programs/applicative_bootloader_multiple_nodes.compiled.json");
    let aggregator_program_path = project_dir.join("resources/compiled_programs/default_aggregator.compiled.json");
    let verifier_program_path = project_dir.join("resources/compiled_programs/verifiers/cairo_verifier_compiled_recursive_with_poseidon.json");
    println!("Bootloader program path:\n{:?}", bootloader_program_path);
    let bootloader_program = Program::from_file(&bootloader_program_path, Some("main"))?;
    println!("Generating bootloader input");

    // Read and prepare the input JSON for the aggregator program
    let aggregator_input = serde_json::json!({
        "child_outputs": [
            [0, 1, 1, 10, 89, 144],
            [0, 89, 144, 10, 10946, 17711],
            [0, 10946, 17711, 10, 1346269, 2178309]
        ]
    });

    // Read proofs
    let proof1 = fs::read_to_string(proof_folder.join("node1.proof.json"))?;

    let proof2 = fs::read_to_string(proof_folder.join("node2.proof.json"))?;

    let proof3 = fs::read_to_string(proof_folder.join("node3.proof.json"))?;
   // println!("Bootloader program path:\n{:?}", proof_folder.join("node1.proof.json"));

   let verifier_program_str = fs::read_to_string(&verifier_program_path)?;
//    println!("Verifier Program raw JSON:\n{}", verifier_program_str);


    let bootloader_input = serde_json::json!({
        "aggregator_task": {
            "type": "RunProgramTask",
            "path": aggregator_program_path,
            "program_input": aggregator_input,
            "program_hash_function": 1 // Use Poseidon
        },
        "stark_verifier": {
            "program": verifier_program_str,
            "use_poseidon": true
        },
        "childs_proofs": [
            { "proof": serde_json::from_str::<serde_json::Value>(&proof1)? },
            { "proof": serde_json::from_str::<serde_json::Value>(&proof2)? },
            { "proof": serde_json::from_str::<serde_json::Value>(&proof3)? }
        ],
        "output_merkle_tree_hasher_choice": "KECCAK"
    });

    println!("Generated bootloader input");

    // Write temporary input JSON file
    let tmpdir = tempdir()?;
    let input_file_path = tmpdir.path().join("bootloader_input.json");
    let mut input_file = File::create(&input_file_path)?;
    writeln!(input_file, "{}", serde_json::to_string_pretty(&bootloader_input)?)?;

    // Set up Cairo run config
    let run_mode = RunMode::Proof {
        layout: LayoutName::recursive_with_poseidon,
        dynamic_layout_params: None,
        disable_trace_padding: false,
    }
    .create_config();

    // Execute the program
    // let mut runner = cairo_run_program(
    //     &bootloader_program,
    //     Some(fs::read_to_string(&input_file_path)?),
    //     run_mode,
    // )?;

    match cairo_run_program(&bootloader_program, Some(fs::read_to_string(&input_file_path)?), run_mode) {
        Ok(mut runner) => {
            let mut output = String::new();
            runner.vm.write_output(&mut output)?;
            println!("Bootloader output:\n{output}");
        }
        Err(err) => {
            eprintln!("💥 Cairo run failed: {err}");
    
            // If you want to try to recover hint location, you can't unless you patch cairo_program_runner-lib.
            // Just print the error fully
        }
    }
    
    // let mut output = String::new();
    // runner.vm.write_output(&mut output)?;
    // println!("Bootloader output:\n{output}");

    Ok(())
}
