use std::fs;
use std::path::PathBuf;
use std::error::Error;

use cairo_program_runner_lib::cairo_run_program;
use cairo_program_runner_lib::types::RunMode;
use cairo_vm::types::layout_name::LayoutName;
use cairo_vm::types::program::Program;

fn main() -> Result<(), Box<dyn Error>> {
    let project_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let proof_folder = project_dir.join("proofs");

    // Load verifier program
    let verifier_program_path = project_dir
        .join("resources/compiled_programs/verifiers/cairo_verifier_compiled_recursive.json");
    let verifier_program = Program::from_file(&verifier_program_path, Some("main"))?;

    // 1. Read raw proof JSON
    let proof_str = fs::read_to_string(proof_folder.join("proof(10).json"))?;
    let proof_value: serde_json::Value = serde_json::from_str(&proof_str)?;

    // 2. Wrap it in the expected structure
    let wrapped_input = serde_json::json!({
        "proof": proof_value
    });

    // 3. Serialize to a string
    let program_input = serde_json::to_string(&wrapped_input)?;

    // Configure proof‐mode run
    let run_mode = RunMode::Proof {
        layout: LayoutName::recursive_with_poseidon,
        dynamic_layout_params: None,
        disable_trace_padding: false,
    }
    .create_config();

    // Run the verifier
    match cairo_run_program(&verifier_program, Some(program_input), run_mode) {
        Ok(mut runner) => {
            let mut output = String::new();
            runner.vm.write_output(&mut output)?;
            println!("Verifier output:\n{output}");
        }
        Err(err) => eprintln!("💥 Verifier run failed: {err}"),
    }

    Ok(())
}
