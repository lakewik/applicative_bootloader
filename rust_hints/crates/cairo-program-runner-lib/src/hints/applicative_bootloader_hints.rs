use std::collections::HashMap;

use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::hint_utils::{get_ptr_from_var_name, insert_value_from_var_name},
        hint_processor_definition::HintReference,
    },
    serde::deserialize_program::{
        deserialize_and_parse_program, ApTracking
    },
    types::exec_scope::ExecutionScopes,
    vm::{
        errors::hint_errors::HintError, runners::builtin_runner::OutputBuiltinState,
        vm_core::VirtualMachine,
    },
};
use serde_json::{Value, to_vec};

use crate::hints::{
    fact_topologies::{
        add_consecutive_output_pages, write_to_fact_topologies_file, GPS_FACT_TOPOLOGY,
    },
    types::BOOTLOADER_CONFIG_SIZE,
};

use super::{
    fact_topologies::FactTopology, vars, ApplicativeBootloaderInput, CustomApplicativeBootloaderInput, BootloaderInput,
    SimpleBootloaderInput, APPLICATIVE_BOOTLOADER_INPUT, PROGRAM_INPUT
};

use cairo_vm::types::program::Program;

use crate::hints::types::{ProgramWithInput, Task, TaskSpec, HashFunc};
use cairo_vm::Felt252;

use cairo_vm::{

    types::relocatable::MaybeRelocatable,
};
use cairo_vm::types::relocatable::Relocatable;

use std::any::type_name;

fn type_of<T>(_: &T) -> &'static str {
    type_name::<T>()
}


pub const POSEIDON_HASH_FUNCTION_CHOICE: u64 = 0;
pub const KECCAK_HASH_FUNCTION_CHOICE: u64 = 1;

// const POSEIDON_HASH_FUNCTION_CHOICE: Felt252 = Felt252::from(0).into();
// const KECCAK_HASH_FUNCTION_CHOICE: Felt252 = Felt252::from(1).into();

/// Implements
/// %{
///     from starkware.cairo.bootloaders.applicative_bootloader.objects import (
///         ApplicativeBootloaderInput,
///     )
///     from starkware.cairo.bootloaders.simple_bootloader.objects import SimpleBootloaderInput
///
///     # Create a segment for the aggregator output.
///     ids.aggregator_output_ptr = segments.add()
///
///     # Load the applicative bootloader input and the aggregator task.
///     applicative_bootloader_input = ApplicativeBootloaderInput.Schema().load(program_input)
///     # TODO(Rei, 01/06/2024): aggregator_task gets use_poseidon from outside? Think about this.
///     aggregator_task = applicative_bootloader_input.aggregator_task
///
///     # Create the simple bootloader input.
///     simple_bootloader_input = SimpleBootloaderInput(
///         tasks=[aggregator_task], fact_topologies_path=None, single_page=True
///     )
///
///     # Change output builtin state to a different segment in preparation for running the
///     # aggregator task.
///     applicative_output_builtin_state = output_builtin.get_state()
///     output_builtin.new_state(base=ids.aggregator_output_ptr)
/// %}
pub fn prepare_aggregator_simple_bootloader_output_segment(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {
    let program_input: &String = exec_scopes.get_ref(vars::PROGRAM_INPUT)?;
    let applicative_bootloader_input: ApplicativeBootloaderInput =
        serde_json::from_str(program_input).unwrap();
    // Python: ids.aggregator_output_ptr = segments.add()
    let new_segment_base = vm.add_memory_segment();
    insert_value_from_var_name(
        "aggregator_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Python:
    // applicative_bootloader_input = ApplicativeBootloaderInput.Schema().load(program_input)
    // simple_bootloader_input = SimpleBootloaderInput(
    //     tasks=[aggregator_task], fact_topologies_path=None, single_page=True
    // )

    let simple_bootloader_input: SimpleBootloaderInput = SimpleBootloaderInput {
        tasks: vec![applicative_bootloader_input.aggregator_task.clone()],
        fact_topologies_path: None,
        single_page: true,
    };

    exec_scopes.insert_value(APPLICATIVE_BOOTLOADER_INPUT, applicative_bootloader_input);
    exec_scopes.insert_value(vars::SIMPLE_BOOTLOADER_INPUT, simple_bootloader_input);

    // Python:
    // applicative_output_builtin_state = output_builtin.get_state()
    // output_builtin.new_state(base=ids.aggregator_output_ptr)
    let output_builtin = vm.get_output_builtin_mut()?;
    let applicative_output_builtin_state = output_builtin.get_state();
    output_builtin.new_state(new_segment_base.segment_index as usize, true);
    exec_scopes.insert_value(
        vars::APPLICATIVE_OUTPUT_BUILTIN_STATE,
        applicative_output_builtin_state,
    );

    insert_value_from_var_name(
        "aggregator_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    Ok(())
}


pub fn custom_prepare_aggregator_simple_bootloader_output_segment(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {

    if let Some(current_scope) = exec_scopes.data.last() {
        for key in current_scope.keys() {
            println!("Available exec_scopes variable: {}", key);
        }
    }


    let program_input: &String = exec_scopes.get_ref(vars::PROGRAM_INPUT)?;
    let applicative_bootloader_input: CustomApplicativeBootloaderInput =
        serde_json::from_str(program_input).unwrap();
    // Python: ids.aggregator_output_ptr = segments.add()
    let new_segment_base = vm.add_memory_segment();
    insert_value_from_var_name(
        "aggregator_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Python:
    // applicative_bootloader_input = ApplicativeBootloaderInput.Schema().load(program_input)
    // simple_bootloader_input = SimpleBootloaderInput(
    //     tasks=[aggregator_task], fact_topologies_path=None, single_page=True
    // )

    let simple_bootloader_input: SimpleBootloaderInput = SimpleBootloaderInput {
        tasks: vec![applicative_bootloader_input.aggregator_task.clone()],
        fact_topologies_path: None,
        single_page: true,
    };

    exec_scopes.insert_value(APPLICATIVE_BOOTLOADER_INPUT, applicative_bootloader_input);
    exec_scopes.insert_value(vars::SIMPLE_BOOTLOADER_INPUT, simple_bootloader_input);

    // Python:
    // applicative_output_builtin_state = output_builtin.get_state()
    // output_builtin.new_state(base=ids.aggregator_output_ptr)
    let output_builtin = vm.get_output_builtin_mut()?;
    let applicative_output_builtin_state = output_builtin.get_state();
    output_builtin.new_state(new_segment_base.segment_index as usize, true);
    exec_scopes.insert_value(
        vars::APPLICATIVE_OUTPUT_BUILTIN_STATE,
        applicative_output_builtin_state,
    );

    insert_value_from_var_name(
        "aggregator_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    Ok(())
}



/// Implements
///%{
///    from starkware.cairo.bootloaders.bootloader.objects import BootloaderInput
///
///    # Save the aggregator's fact_topologies before running the bootloader.
///    aggregator_fact_topologies = fact_topologies
///    fact_topologies = []
///
///    # Create a segment for the bootloader output.
///    ids.bootloader_output_ptr = segments.add()
///
///    # Create the bootloader input.
///    bootloader_input = BootloaderInput(
///        tasks=applicative_bootloader_input.tasks,
///        fact_topologies_path=None,
///        bootloader_config=applicative_bootloader_input.bootloader_config,
///        packed_outputs=applicative_bootloader_input.packed_outputs,
///        single_page=True,
///    )
///
///    # Change output builtin state to a different segment in preparation for running the
///    # bootloader.
///    output_builtin.new_state(base=ids.bootloader_output_ptr)
///%}
pub fn prepare_root_task_unpacker_bootloader_output_segment(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {
    // Python: aggregator_fact_topologies = fact_topologies
    //    fact_topologies = []
    let fact_topologies: Vec<FactTopology> = exec_scopes.get(vars::FACT_TOPOLOGIES)?;
    exec_scopes.insert_value(vars::AGGREGATOR_FACT_TOPOLOGIES, fact_topologies);
    exec_scopes.insert_value(vars::FACT_TOPOLOGIES, Vec::<FactTopology>::new());

    // Python: ids.bootloader_output_ptr = segments.add()
    let new_segment_base = vm.add_memory_segment();
    insert_value_from_var_name(
        "bootloader_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    let applicative_bootloader_input: &ApplicativeBootloaderInput =
        exec_scopes.get_ref(vars::APPLICATIVE_BOOTLOADER_INPUT)?;

    //    Python: bootloader_input = BootloaderInput(
    //        tasks=applicative_bootloader_input.tasks,
    //        fact_topologies_path=None,
    //        bootloader_config=applicative_bootloader_input.bootloader_config,
    //        packed_outputs=applicative_bootloader_input.packed_outputs,
    //        single_page=True,
    //    )

    let simple_bootloader_input = SimpleBootloaderInput {
        tasks: applicative_bootloader_input
            .bootloader_input
            .simple_bootloader_input
            .tasks
            .clone(),
        fact_topologies_path: None,
        single_page: true,
    };

    let bootloader_input = BootloaderInput {
        simple_bootloader_input,
        bootloader_config: applicative_bootloader_input
            .bootloader_input
            .bootloader_config
            .clone(),
        packed_outputs: applicative_bootloader_input
            .bootloader_input
            .packed_outputs
            .clone(),
    };

    exec_scopes.insert_value(vars::BOOTLOADER_INPUT, bootloader_input);

    // Python: output_builtin.new_state(base=ids.bootloader_output_ptr)
    let output_builtin = vm.get_output_builtin_mut()?;
    output_builtin.new_state(new_segment_base.segment_index as usize, true);

    Ok(())
}

/// Implements
///%{
///     # Restore the output builtin state.
///     output_builtin.set_state(applicative_output_builtin_state)
/// %}
pub fn restore_applicative_output_state(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
) -> Result<(), HintError> {
    let output_builtin_state: OutputBuiltinState =
        exec_scopes.get(vars::APPLICATIVE_OUTPUT_BUILTIN_STATE)?;
    vm.get_output_builtin_mut()?.set_state(output_builtin_state);

    Ok(())
}

/// Implements
///%{
///    from starkware.cairo.bootloaders.fact_topology import GPS_FACT_TOPOLOGY, FactTopology
///    from starkware.cairo.bootloaders.simple_bootloader.utils import (
///        add_consecutive_output_pages,
///        write_to_fact_topologies_file,
///    )
///
///    assert len(aggregator_fact_topologies) == 1
///    # Subtract the bootloader output length from the first page's length. Note that the
///    # bootloader output is always fully contained in the first page.
///    original_first_page_length = aggregator_fact_topologies[0].page_sizes[0]
///    # The header contains the program hash and bootloader config.
///    header_size = 1 + ids.BOOTLOADER_CONFIG_SIZE
///    first_page_length = (
///        original_first_page_length - ids.bootloader_tasks_output_length + header_size
///    )
///
///    # Update the first page's length to account for the removed bootloader output, and the
///    # added program hash and bootloader config.
///    fact_topology = FactTopology(
///        tree_structure=aggregator_fact_topologies[0].tree_structure,
///        page_sizes=[first_page_length] + aggregator_fact_topologies[0].page_sizes[1:]
///    )
///    output_builtin.add_attribute(
///        attribute_name=GPS_FACT_TOPOLOGY,
///        attribute_value=aggregator_fact_topologies[0].tree_structure
///    )
///
///    # Configure the memory pages in the output builtin, based on plain_fact_topologies.
///    add_consecutive_output_pages(
///        page_sizes=fact_topology.page_sizes[1:],
///        output_builtin=output_builtin,
///        cur_page_id=1,
///        output_start=ids.output_start + fact_topology.page_sizes[0],
///    )
///
///    # Dump fact topologies to a json file.
///    if applicative_bootloader_input.fact_topologies_path is not None:
///        write_to_fact_topologies_file(
///            fact_topologies_path=applicative_bootloader_input.fact_topologies_path,
///            fact_topologies=[fact_topology],
///        )
///%}
pub fn finalize_fact_topologies_and_pages(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {
   

    let aggregator_fact_topologies: Vec<FactTopology> =
        exec_scopes.get(vars::AGGREGATOR_FACT_TOPOLOGIES)?;

    if aggregator_fact_topologies.len() != 1 {
        return Err(HintError::CustomHint(
            "Expected exactly one fact topology for the aggregator task".into(),
        ));
    }
    let aggregator_fact_topology = aggregator_fact_topologies.first().unwrap();
    let original_first_page_length = aggregator_fact_topology.page_sizes[0];
    let header_size = 1 + BOOTLOADER_CONFIG_SIZE;
    let bootloader_output_end =
        get_ptr_from_var_name("bootloader_output_end", vm, ids_data, ap_tracking)?;
    let bootloader_output_start =
        get_ptr_from_var_name("bootloader_tasks_output_ptr", vm, ids_data, ap_tracking)?;

    // Because of how limited the LambdaClass reference parser is, we can't take the value straight
    // from the reference "bootloader_tasks_output_length" and have to calculate it manually
    // with simple references that the parser can handle.
    // i.e. fn `parse_value`` can't handle the reference `cast([fp + 14] - ([fp + 3] + 3), felt)`,
    // so we take [fp + 14] and ([fp + 3] + 3) separately and calculate the value manually.
    // Think if we want to invest time in fixing this.
    let bootloader_tasks_output_length =
        bootloader_output_end.offset - bootloader_output_start.offset;

    let first_page_length =
        original_first_page_length - bootloader_tasks_output_length + header_size;

    let fact_topology = vec![FactTopology {
        tree_structure: aggregator_fact_topology.tree_structure.clone(),
        page_sizes: vec![first_page_length]
            .into_iter()
            .chain(aggregator_fact_topology.page_sizes[1..].to_vec())
            .collect(),
    }];

    let output_start = get_ptr_from_var_name("output_start", vm, ids_data, ap_tracking)?;
    let output_builtin = vm.get_output_builtin_mut()?;
    output_builtin.add_attribute(
        GPS_FACT_TOPOLOGY.into(),
        fact_topology[0].tree_structure.clone(),
    );

    let output_start = (output_start + fact_topology[0].page_sizes[0])?;
    let _ = add_consecutive_output_pages(
        &fact_topology[0].page_sizes[1..],
        output_builtin,
        1, // Starting page ID
        output_start,
    )?;

    let applicative_bootloader_input: &ApplicativeBootloaderInput =
        exec_scopes.get_ref(vars::APPLICATIVE_BOOTLOADER_INPUT)?;

    if let Some(path) = &applicative_bootloader_input
        .bootloader_input
        .simple_bootloader_input
        .fact_topologies_path
    {
        write_to_fact_topologies_file(path.as_path(), &fact_topology)
            .map_err(Into::<HintError>::into)?;
    }

    Ok(())
}


pub fn custom_prepare_verifier_tasks_and_bootloader_output_segment(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {
    println!("meow");
    if let Some(current_scope) = exec_scopes.data.last() {
        for key in current_scope.keys() {
            println!("Available exec_scopes variable: {}", key);
        }
    }
// Borrow exec_scopes immutably for getting the applicative_bootloader_input
// Immutable borrow for fetching values




let input_ref: &CustomApplicativeBootloaderInput =
    exec_scopes.get_ref(vars::APPLICATIVE_BOOTLOADER_INPUT)?;


let fact_topologies: Vec<FactTopology> = exec_scopes.get(vars::FACT_TOPOLOGIES)?;
// … clone into an owned value …
let applicative_bootloader_input = input_ref.clone();
// … drop the &‑borrow so it won’t conflict
drop(input_ref);

// now it’s safe to mutably borrow exec_scopes
exec_scopes.insert_value(vars::AGGREGATOR_FACT_TOPOLOGIES, fact_topologies);

exec_scopes.insert_value(
    vars::FACT_TOPOLOGIES,
    Vec::<FactTopology>::new(),
);
//exec_scopes.insert_value(vars::FACT_TOPOLOGIES, Vec::new());

    // Create new segment for bootloader output.
    let new_segment_base = vm.add_memory_segment();
    insert_value_from_var_name(
        "bootloader_output_ptr",
        new_segment_base,
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Extract verifier & child proofs
    let stark_verifier_program = &applicative_bootloader_input.stark_verifier;
    let childs_proofs = &applicative_bootloader_input.childs_proofs;

    // let program: Program = serde_json::from_value(stark_verifier_program.clone())
    // .map_err(|e| HintError::CustomHint(format!("Failed to parse Program: {e}").into()))?;  // Deserialize it into Program

    // !! This should be taken from program input but for debug purposes we are getting it here from file directly
    let file_content = std::fs::read("resources/compiled_programs/verifiers/cairo_verifier_compiled_recursive_with_poseidon.json").unwrap();

    // let stark_verifier_program_bytes: Vec<u8> = to_vec(&stark_verifier_program).
    // map_err(|e| HintError::CustomHint(format!("Failed to parse Program: {e}").into()))?;

    // let stark_verifier_program_deserialized = deserialize_and_parse_program(&stark_verifier_program_bytes, Some("main"));

    let stark_verifier_program_deserialized = deserialize_and_parse_program(&file_content, Some("main"));

    match &stark_verifier_program_deserialized {
        Ok(program) => {
            println!("✅ Successfully deserialized Program:");
           // println!("{:#?}", program);
        }
        Err(err) => {
            println!("❌ Failed to deserialize Program:");
            //println!("{:#?}", stark_verifier_program_bytes);
        }
    }

    //  let program_json = &stark_verifier.program; // serde_json::Value
    //  let program: Program = serde_json::from_value(program_json.clone())

    //    .map_err(|e| HintError::CustomHint(format!("Failed to parse Program: {e}").into()))?;

    // Build RunProgramTask list
    let tasks: Vec<TaskSpec> = childs_proofs
    .iter()
    .map(|child_proof| {
        let program_input_json = serde_json::json!({
            "proof": child_proof.proof.clone()
        });

        let program_ref = stark_verifier_program_deserialized.as_ref().unwrap();


        TaskSpec {
            task: Task::Program(ProgramWithInput {
                program: program_ref.clone(), // Loaded from file or already pre-parsed
                program_input: Some(program_input_json.to_string()),
            }),
            program_hash_function: HashFunc::Poseidon,
            // program_hash_function: if stark_verifier_program.use_poseidon {
            //     HashFunc::Poseidon
            // } else {
            //     HashFunc::Keccak
            // },
        }
    })
    .collect();

    // Select correct hasher type
    let hasher_choice = &applicative_bootloader_input.output_merkle_tree_hasher_choice;
    let hasher_const = match hasher_choice.as_str() {
        "POSEIDON" => POSEIDON_HASH_FUNCTION_CHOICE,
        "KECCAK" => KECCAK_HASH_FUNCTION_CHOICE,
        _ => {
            return Err(HintError::CustomHint(format!(
                "Unknown hasher choice: {hasher_choice}"
            ).into()));
        }
    };

    insert_value_from_var_name(
        "output_merkle_tree_hasher_choice",
        0,
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Build simple bootloader input
    let simple_bootloader_input = SimpleBootloaderInput {
        tasks,
        fact_topologies_path: None,
        single_page: true,
    };

    exec_scopes.insert_value(vars::SIMPLE_BOOTLOADER_INPUT, simple_bootloader_input);

    // Switch output builtin to new segment for output
    let output_builtin = vm.get_output_builtin_mut()?;
    output_builtin.new_state(new_segment_base.segment_index as usize, true);

    Ok(())
}


pub fn custom_prepare_default_aggregator(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    ids_data: &HashMap<String, HintReference>,
    ap_tracking: &ApTracking,
) -> Result<(), HintError> {
    if let Some(current_scope) = exec_scopes.data.last() {
        for key in current_scope.keys() {
            println!("Variable: {key}");
    
            if let Some(value) = current_scope.get(key) {
                println!("program_input exists!");
            
                if let Some(string_val) = value.downcast_ref::<String>() {
                    println!("program_input is String:\n{}", string_val);
                } else if let Some(json_val) = value.downcast_ref::<serde_json::Value>() {
                    println!("program_input is serde_json::Value:\n{}", serde_json::to_string_pretty(json_val).unwrap());
                } else {
                    println!("program_input type unknown — trying to print type_name...");
                    println!("Rust type: {}", type_of(value));
                }
            }
        }
    }
    // Step 1: Read program_input from execution scopes
    let program_input_str: &String = exec_scopes.get_ref(PROGRAM_INPUT)?;

    let program_input: serde_json::Value = serde_json::from_str(program_input_str)
    .map_err(|e| HintError::CustomHint(format!("Failed to parse program_input JSON: {e}").into()))?;

    //let program_input: &serde_json::Value = exec_scopes.get_ref("program_object")?;

    let child_outputs = program_input
        .get("child_outputs")
        .ok_or_else(|| HintError::CustomHint("Missing child_outputs in program_input".into()))?
        .as_array()
        .ok_or_else(|| HintError::CustomHint("child_outputs is not an array".into()))?;

    // Step 2: For each sublist, allocate memory and store pointer
    let mut child_outputs_ptrs = Vec::new();
    let mut child_output_lengths = Vec::new();

    for sublist in child_outputs.iter() {
        let sublist_array = sublist
            .as_array()
            .ok_or_else(|| HintError::CustomHint("Each child_output must be an array".into()))?;

        let base = vm.add_memory_segment();

        for (i, elem) in sublist_array.iter().enumerate() {
            let value = elem
                .as_i64()
                .ok_or_else(|| HintError::CustomHint("child_output element is not an integer".into()))?;

                vm.insert_value(Relocatable::from((base.segment_index, i)), Felt252::from(value))?;
            }

        child_outputs_ptrs.push(MaybeRelocatable::RelocatableValue(base));
        child_output_lengths.push(sublist_array.len());
    }

    // Step 3: Allocate child_outputs_ptrs array itself
    let child_outputs_array_base = vm.add_memory_segment();
    for (i, ptr) in child_outputs_ptrs.iter().enumerate() {
        vm.insert_value(Relocatable::from((child_outputs_array_base.segment_index, i)), ptr.clone())?;
    }

    insert_value_from_var_name(
        "child_outputs",
        MaybeRelocatable::RelocatableValue(child_outputs_array_base),
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Step 4: Allocate child_output_lengths array
    let child_output_lengths_base = vm.add_memory_segment();
    for (i, length) in child_output_lengths.iter().enumerate() {
        vm.insert_value(
            Relocatable::from((child_output_lengths_base.segment_index, i)),
            Felt252::from(*length as i64),
        )?;
    }

    insert_value_from_var_name(
        "child_output_lengths",
        MaybeRelocatable::RelocatableValue(child_output_lengths_base),
        vm,
        ids_data,
        ap_tracking,
    )?;

    // Step 5: Set num_child_outputs
    insert_value_from_var_name(
        "num_child_outputs",
        Felt252::from(child_outputs.len() as i64),
        vm,
        ids_data,
        ap_tracking,
    )?;

    Ok(())
}

