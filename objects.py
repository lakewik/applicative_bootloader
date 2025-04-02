from typing import List
import marshmallow_dataclass
from dataclasses import field
import marshmallow.fields as mfields
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from starkware.starkware_utils.marshmallow_dataclass_fields import additional_metadata
from starkware.cairo.bootloaders.simple_bootloader.objects import TaskSpec, TaskSchema
from starkware.cairo.lang.compiler.program import Program

@marshmallow_dataclass.dataclass(frozen=True)
class NodeClaim(ValidatedMarshmallowDataclass):
    a_start: int
    b_start: int
    n: int


@marshmallow_dataclass.dataclass(frozen=True)
class NodeResult(ValidatedMarshmallowDataclass):
    a_start: int
    b_start: int
    n: int
    a_end: int
    b_end: int


@marshmallow_dataclass.dataclass(frozen=True)
class ApplicativeResult(ValidatedMarshmallowDataclass):
    path_hash: int
    node_result: NodeResult


@marshmallow_dataclass.dataclass(frozen=True)
class AggregatorClaim(ValidatedMarshmallowDataclass):
    nodes: List[ApplicativeResult]


@marshmallow_dataclass.dataclass(frozen=True)
class AggregatorResult(ValidatedMarshmallowDataclass):
    nodes_hash: int
    node_result: ApplicativeResult


@marshmallow_dataclass.dataclass(frozen=True)
class StarkVerifier(ValidatedMarshmallowDataclass):
    program: Program = field(
        metadata=additional_metadata(marshmallow_field=mfields.Nested(Program.Schema))
    )
    use_poseidon: bool

@marshmallow_dataclass.dataclass(frozen=True)
class ChildProof(ValidatedMarshmallowDataclass):
    proof: dict = field(
        metadata=additional_metadata(marshmallow_field=mfields.Dict())
    )

@marshmallow_dataclass.dataclass(frozen=True)
class ApplicativeBootloaderInput(ValidatedMarshmallowDataclass):
    aggregator_task: TaskSpec = field(
        metadata=additional_metadata(marshmallow_field=mfields.Nested(TaskSchema))
    )
    stark_verifier: StarkVerifier = field(
        metadata=additional_metadata(marshmallow_field=mfields.Nested(StarkVerifier.Schema))
    )
    childs_proofs: List[ChildProof] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(ChildProof.Schema))
        )
    )
