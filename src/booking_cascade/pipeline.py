"""Pipeline orchestrator: wires every stage of the cascade together.

``intent`` -> ``fast_path`` -> ``gate`` -> (``slow_path`` if escalated) ->
``normalize`` -> ``grounding`` -> ``state.merge`` -> ``validate`` ->
``followup``.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Literal, Optional, Union

import yaml

from booking_cascade import fast_path, gate, slow_path, state as state_module, validate as validate_module
from booking_cascade.followup import generate_followup
from booking_cascade.grounding import GroundingConfig, SpaData, ground, load_spa_data
from booking_cascade.intent import detect_intent
from booking_cascade.normalize import normalize_slot_update
from booking_cascade.schema import BookingState

# project root: src/booking_cascade/pipeline.py -> src -> <project root>
_PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG_PATH = _PROJECT_ROOT / "config.yaml"


def load_config(config_path: Union[str, Path] = DEFAULT_CONFIG_PATH) -> dict[str, Any]:
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


@dataclass(frozen=True)
class TurnResult:
    state: BookingState
    reply: str
    path: Literal["fast", "slow"]
    gate_reasons: list[str] = field(default_factory=list)
    timing_ms: dict[str, float] = field(default_factory=dict)


class BookingPipeline:
    """Stateful per-conversation pipeline.

    Holds the conversation history (for slow-path prompts) and the loaded
    config/spa roster/models, and exposes ``process_turn`` as the public
    entry point.
    """

    def __init__(
        self,
        config: Optional[dict[str, Any]] = None,
        config_path: Union[str, Path] = DEFAULT_CONFIG_PATH,
        spa_data_path: Optional[Union[str, Path]] = None,
        spa_data: Optional[SpaData] = None,
        fast_path_model: Optional[fast_path.EntityModel] = None,
        ollama_client: Optional[slow_path.HTTPClient] = None,
    ):
        self.config = config if config is not None else load_config(config_path)

        self.fast_path_config = fast_path.FastPathConfig.from_dict(self.config.get("fast_path", {}))
        self.gate_config = gate.GateConfig.from_dict(
            self.config.get("gate", {}),
            escalation_log_path=self.config.get("logging", {}).get("escalation_log_path"),
        )
        self.slow_path_config = slow_path.SlowPathConfig.from_dict(self.config.get("slow_path", {}))
        self.grounding_config = GroundingConfig.from_dict(
            self.config.get("grounding", {}),
            grounding_log_path=self.config.get("logging", {}).get("grounding_log_path"),
        )

        if spa_data is not None:
            self.spa_data = spa_data
        else:
            path = spa_data_path or self.config.get("spa_data_path", "data/spa.yaml")
            path = Path(path)
            if not path.is_absolute():
                path = _PROJECT_ROOT / path
            self.spa_data = load_spa_data(path)

        self._fast_path_model = fast_path_model
        self._ollama_client = ollama_client
        self.history: list[dict[str, str]] = []

    def process_turn(
        self, message: str, state: BookingState, reference: Optional[datetime] = None
    ) -> TurnResult:
        reference = reference or datetime.now()
        timing_ms: dict[str, float] = {}
        total_start = time.perf_counter()

        intent_result = _timed(timing_ms, "intent", lambda: detect_intent(message))

        fast_result = _timed(
            timing_ms,
            "fast_path",
            lambda: fast_path.extract(
                message, intent_result.intent, self.fast_path_config, model=self._fast_path_model
            ),
        )

        gate_decision = _timed(
            timing_ms,
            "gate",
            lambda: gate.evaluate(message, fast_result, reference, self.gate_config),
        )

        path: Literal["fast", "slow"] = "fast"
        extraction_result = fast_result
        if gate_decision.escalate:
            path = "slow"
            extraction_result = _timed(
                timing_ms,
                "slow_path",
                lambda: slow_path.extract(
                    message,
                    state,
                    self.history,
                    intent_result.intent,
                    reference,
                    self.slow_path_config,
                    client=self._ollama_client,
                ),
            )

        slot_update = extraction_result.slot_update

        slot_update, normalize_warnings = _timed(
            timing_ms, "normalize", lambda: normalize_slot_update(slot_update, reference)
        )

        grounding_result = _timed(
            timing_ms, "grounding", lambda: ground(slot_update, self.spa_data, self.grounding_config)
        )
        slot_update = grounding_result.slot_update

        new_state = state_module.merge_slot_update(state, slot_update, provenance=path)
        new_state.warnings = [*normalize_warnings, *grounding_result.warnings]

        new_state = _timed(
            timing_ms, "validate", lambda: validate_module.validate(new_state, self.spa_data, reference)
        )

        reply = _timed(timing_ms, "followup", lambda: generate_followup(new_state, slot_update))

        # Warnings are surfaced in this turn's reply; don't repeat them next turn.
        new_state.warnings = []

        self.history.append({"role": "user", "text": message})
        self.history.append({"role": "assistant", "text": reply})

        timing_ms["total"] = (time.perf_counter() - total_start) * 1000

        return TurnResult(
            state=new_state,
            reply=reply,
            path=path,
            gate_reasons=gate_decision.reasons,
            timing_ms=timing_ms,
        )


def _timed(timing_ms: dict[str, float], name: str, fn):
    start = time.perf_counter()
    result = fn()
    timing_ms[f"{name}_ms"] = (time.perf_counter() - start) * 1000
    return result
