#!/usr/bin/env python3
"""Offline render tests for the dbt-bqai macros.

These render the macros with a plain Jinja2 environment that mimics the pieces
of dbt the macros depend on (the `bqai` package namespace, `var()`, and
`exceptions`). They assert on the generated BigQuery SQL, so they catch
template and logic regressions without needing a live BigQuery connection.

Run: python3 tests/render_test.py   (requires jinja2)
"""
import glob
import os
import sys

import jinja2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_VARS = {}


def _var(name, default=None):
    return _VARS.get(name, default)


class _Exceptions:
    def raise_compiler_error(self, msg):
        raise jinja2.exceptions.TemplateError("COMPILER_ERROR: " + msg)


def _build_env():
    env = jinja2.Environment(undefined=jinja2.StrictUndefined)
    sources = []
    for path in sorted(glob.glob(os.path.join(ROOT, "macros", "**", "*.sql"), recursive=True)):
        with open(path) as fh:
            sources.append(fh.read())
    combined = "\n".join(sources)
    # Jinja hides underscore-prefixed macros from a module's exported namespace;
    # dbt does not. Rename them (definitions and call sites alike) so the test
    # harness can resolve them. The real macro files are untouched.
    combined = combined.replace("_bqai_", "zbqai_")

    class NS:
        module = None

        def __getattr__(self, name):
            return getattr(NS.module, name)

    bqai = NS()
    env.globals.update(var=_var, exceptions=_Exceptions(), bqai=bqai)
    NS.module = env.from_string(combined).make_module()
    return env


_ENV = _build_env()

FULL_VARS = {
    "bqai_connection": "my-project.us.my-connection",
    "bqai_endpoint": "gemini-2.5-flash",
    "bqai_embedding_endpoint": "text-embedding-005",
    "bqai_model_params": '{"generation_config":{"thinking_config":{"thinking_budget":0}}}',
    "bqai_max_error_ratio": 0.2,
}


def render(call, scenario_vars=None):
    global _VARS
    _VARS = scenario_vars if scenario_vars is not None else FULL_VARS
    return _ENV.from_string("{{ " + call + " }}").render().strip()


_failures = []


def check(name, call, must_contain=(), must_not_contain=(), scenario_vars=None):
    try:
        out = render(call, scenario_vars)
    except Exception as e:  # noqa: BLE001
        _failures.append(f"{name}: raised {e!r}")
        return
    for needle in must_contain:
        if needle not in out:
            _failures.append(f"{name}: expected {needle!r} in:\n    {out}")
    for needle in must_not_contain:
        if needle in out:
            _failures.append(f"{name}: did NOT expect {needle!r} in:\n    {out}")


def check_raises(name, call, marker, scenario_vars=None):
    try:
        render(call, scenario_vars)
    except Exception as e:  # noqa: BLE001
        if marker not in str(e):
            _failures.append(f"{name}: raised but missing {marker!r}: {e}")
        return
    _failures.append(f"{name}: expected an error but none was raised")


# --- generate family --------------------------------------------------------
check("generate extracts .result", 'bqai.generate("body")',
      must_contain=["AI.GENERATE(body", ").result",
                    "connection_id => 'my-project.us.my-connection'",
                    "endpoint => 'gemini-2.5-flash'",
                    "model_params => JSON '''"])

check("generate extract=false keeps struct", 'bqai.generate("body", extract=False)',
      must_not_contain=[").result"])

check("generate output_schema drops .result", 'bqai.generate("body", output_schema="a STRING, b INT64")',
      must_contain=["output_schema => 'a STRING, b INT64'"],
      must_not_contain=[").result"])

check("generate_bool", 'bqai.generate_bool("body")',
      must_contain=["AI.GENERATE_BOOL(body", ").result"])
check("generate_int", 'bqai.generate_int("body")',
      must_contain=["AI.GENERATE_INT(body", ").result"])
check("generate_double", 'bqai.generate_double("body")',
      must_contain=["AI.GENERATE_DOUBLE(body", ").result"])

check("generate minimal (no vars) emits bare call", 'bqai.generate("body")',
      must_contain=["(AI.GENERATE(body)).result"], scenario_vars={})

check("per-call endpoint override wins", "bqai.generate(\"body\", endpoint='gemini-3.0-pro')",
      must_contain=["endpoint => 'gemini-3.0-pro'"])

# --- classify ---------------------------------------------------------------
check("classify list -> array literal", 'bqai.classify("review", ["positive", "negative"])',
      must_contain=["AI.CLASSIFY(review", "categories => ['positive', 'negative']"])

check("classify escapes single quotes", 'bqai.classify("body", ["children\'s"])',
      must_contain=["'children''s'"])

check("classify raw array passthrough", "bqai.classify(\"body\", \"['a', 'b']\")",
      must_contain=["categories => ['a', 'b']"])

check("classify multi output_mode", 'bqai.classify("body", ["a"], output_mode="multi")',
      must_contain=["output_mode => 'multi'"])

check("classify embeddings suppresses max_error_ratio",
      "bqai.classify(\"body\", [\"a\"], embeddings='emb')",
      must_contain=["embeddings => emb"], must_not_contain=["max_error_ratio"])

# --- score / ai_if ----------------------------------------------------------
check("score", 'bqai.score("(\'x: \', body)")',
      must_contain=["AI.SCORE(('x: ', body)", "max_error_ratio => 0.2"])

check("ai_if", 'bqai.ai_if("(\'x: \', review)")',
      must_contain=["AI.IF(('x: ', review)", "max_error_ratio => 0.2"])

check("ai_if embeddings suppresses max_error_ratio",
      "bqai.ai_if(\"('x: ', review)\", embeddings='emb')",
      must_contain=["embeddings => emb"], must_not_contain=["max_error_ratio"])

# --- embed ------------------------------------------------------------------
check("embed uses embedding endpoint, not model_params",
      'bqai.embed("body", task_type="SEMANTIC_SIMILARITY")',
      must_contain=["AI.EMBED(body", "endpoint => 'text-embedding-005'",
                    "task_type => 'SEMANTIC_SIMILARITY'"],
      must_not_contain=["model_params"])

check_raises("embed without endpoint raises", 'bqai.embed("body")', "COMPILER_ERROR",
             scenario_vars={})

# --- report -----------------------------------------------------------------
if _failures:
    print("FAILED ({} checks):".format(len(_failures)))
    for f in _failures:
        print("  - " + f)
    sys.exit(1)
print("All render tests passed.")
