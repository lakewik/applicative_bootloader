use std::any::Any;
use std::collections::HashMap;

use crate::hints::types::ProgramIdentifiers;
use cairo_vm::serde::deserialize_program::Identifier;
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::program::Program;
use cairo_vm::types::relocatable::{MaybeRelocatable, Relocatable};
use cairo_vm::vm::errors::hint_errors::HintError;
use cairo_vm::vm::errors::memory_errors::MemoryError;
use cairo_vm::vm::vm_core::VirtualMachine;

#[macro_export]
macro_rules! maybe_relocatable_box {
    ($val:expr) => {
        Box::new(MaybeRelocatable::from($val)) as Box<dyn Any>
    };
}

/// Retrieves program identifiers from the execution scopes.
///
/// # Arguments
/// * `exec_scopes` - A reference to `ExecutionScopes`, which holds the execution environment
///   variables.
/// * `program` - A `&str` representing the name of the program whose identifiers are being sought.
///
/// # Returns
/// * `Result<ProgramIdentifiers, HintError>` - Returns a `HashMap` containing the program
///   identifiers (each as a key-value pair where both key and value are cloned as `String`), or a
///   `HintError` if the specified program is not found in `exec_scopes`.
///
/// # Errors
/// * `HintError::VariableNotInScopeError` - Returned if the specified `program` is not found in
///   `exec_scopes`.
pub fn get_program_identifies(
    exec_scopes: &ExecutionScopes,
    program: &str,
) -> Result<ProgramIdentifiers, HintError> {
    if let Ok(program) = exec_scopes.get::<Program>(program) {
        return Ok(program
            .iter_identifiers()
            .map(|(k, v)| (k.to_string(), v.clone()))
            .collect());
    }

    Err(HintError::VariableNotInScopeError(
        program.to_string().into_boxed_str(),
    ))
}

/// Fetches a specific identifier's program counter (PC) from a given identifiers map.
///
/// # Arguments
/// * `identifiers` - A reference to a `HashMap` where each key is an identifier's name and each
///   value is an `Identifier` containing details about that identifier.
/// * `name` - A `&str` representing the name of the identifier whose program counter is being
///   sought.
///
/// # Returns
/// * `Result<usize, HintError>` - Returns the program counter (`pc`) of the specified identifier if
///   it exists and has an associated `pc`, otherwise returns a `HintError`.
///
/// # Errors
/// * `HintError::VariableNotInScopeError` - Returned if the specified `name` is not found in
///   `identifiers` or does not contain a program counter.
pub fn get_identifier(
    identifiers: &HashMap<String, Identifier>,
    name: &str,
) -> Result<usize, HintError> {
    if let Some(identifier) = identifiers.get(name) {
        if let Some(pc) = identifier.pc {
            return Ok(pc);
        }
    }

    Err(HintError::VariableNotInScopeError(
        name.to_string().into_boxed_str(),
    ))
}

/// Mimics the behaviour of the Python VM `gen_arg`.
///
/// Creates a new segment for each vector encountered in `args`. For each new
/// segment, the pointer to the segment will be added to the current segment.
///
/// Example: `vec![1, 2, vec![3, 4]]`
/// -> Allocates segment N, starts writing at offset 0:
/// (N, 0): 1       # Write the values of the vector one by one
/// (N, 1): 2
/// -> a vector is encountered, allocate a new segment
/// (N, 2): N+1     # Pointer to the new segment
/// (N+1, 0): 3     # Write the values of the nested vector
/// (N+1, 1): 4
pub fn gen_arg(
    vm: &mut VirtualMachine,
    args: &Vec<Box<dyn Any>>,
) -> Result<Relocatable, MemoryError> {
    let base = vm.segments.add();
    let mut ptr = base;
    for arg in args {
        if let Some(value) = arg.downcast_ref::<MaybeRelocatable>() {
            ptr = vm.segments.load_data(ptr, &[value.clone()])?;
        } else if let Some(vector) = arg.downcast_ref::<Vec<Box<dyn Any>>>() {
            let nested_base = gen_arg(vm, vector)?;
            ptr = vm.segments.load_data(ptr, &[nested_base.into()])?;
        } else {
            return Err(MemoryError::GenArgInvalidType);
        }
    }

    Ok(base)
}
