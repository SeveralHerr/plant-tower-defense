#!/usr/bin/env python3
"""meta_key_check.py - node metadata keys are a cross-script contract; resolve both ends.

Why this exists: `set_meta`/`get_meta` is the one cross-script contract in a Godot project
that carries no declaration anywhere. `game/sticky_sundew.gd` keeps a slowed pest's entire
correctness in two entries it hangs off the `Pest` node -- a saved base speed and a source
refcount -- written by one script and read by another, addressed by a *string*. Nothing in
this toolchain can see a string used that way:

  * `tools/name_check.py` resolves identifiers. `META_SOURCES` resolves; the
    `"sundew_slow_sources"` it stands for is just text to it, and a bare `"speed"` literal
    is not even an identifier.
  * `lint_project.gd` and `tools/import_check.py` type-check declarations. A metadata key
    is not declared.
  * `tools/coverage_check.py` enumerates eight defect classes -- UI layout, UI
    reachability, unconnected signals, orphan growth, input path, scene validation, shader
    compile, name resolution. None of them is about this.

So a typo in a key is silent in every gate and at runtime produces a plant that simply does
nothing: `get_meta("sundew_slow_sorces", 0)` answers 0, which reads as "not slowed", which
reads as "working". This tool asks the one question those gates cannot: does every key that
is *read* have a writer, and does every key that is *written* have a reader.

Both directions are defects, for different reasons:

    read with no writer     the typo. The value is whatever the default is, forever -- or,
                            with no default, a runtime error and a null.
    written with no reader  dead weight, and usually a rename that was only half applied:
                            the writer was updated, the reader was not, or vice versa.

The API surface it covers is Object's whole metadata API as of Godot 4 (`set_meta`,
`get_meta`, `has_meta`, `remove_meta`, `get_meta_list`) -- Node, Resource and everything
else inherit it unchanged, and there is no second spelling. Two behaviours of that API are
handled explicitly rather than assumed, because both change the answer:

  * `set_meta(key, null)` is documented as *equivalent to remove_meta(key)*. It is counted
    as a delete, never as a write, so a key whose only "write" is a null still reports as
    never written.
  * `get_meta_list()` reads every key on an object without naming any of them. Its presence
    anywhere in the project makes "written and never read" unprovable, so every such
    finding is demoted to advisory and the reason is printed. This project calls it zero
    times, which is why the count is printed rather than left out.

**It never opens the Godot project.** No `godot` invocation, no `--import`, no write to
`.godot/`. Same property `name_check.py` and `coverage_check.py` have and for the same
reason: N agents can run it at once on one checkout, and it works in a git worktree that
has never been imported.

What it deliberately does NOT do -- see NOT_COVERED below for the version printed next to
every verdict:

  * It does not guess at a key it cannot read. `set_meta(some_var, x)` is reported as an
    advisory finding *with its location* and counted in the denominator. A checker that
    silently skips what it cannot parse overstates its own coverage, and this is the only
    construct here that can hide a key.
  * It never harvests a key from a bare string literal. Keys come only from the argument
    position of a metadata call, so `add_to_group("speed")`, `entry["offset"]` and
    `sprite.offset` contribute nothing -- which matters in `game/title_screen.gd`, where
    the same word is a Dictionary key, a Sprite2D property and a metadata key within five
    lines.
  * Comments and docstrings contribute nothing: the scan runs over text with every comment
    and every string *body* blanked to spaces of the same length, ported from
    `name_check.py` rather than reinvented so the two gates agree about what is code. The
    literal is then read back out of the raw source at the identical offsets (blanking is
    length-preserving), which is why a comment mentioning `META_SOURCES` -- there is one,
    in `game/placement_preview.gd` -- is not a use.

Exit codes follow the harness convention (`name_check.py`, `coverage_check.py`,
`lint_project.gd`, `run_tests.gd`):
    0  scanned clean (no errors; no warnings either, under --strict)
    1  findings that count -- errors, plus warnings under --strict
    2  could not run: no project.godot, or an unreadable project root

Usage:
    python tools/meta_key_check.py                 # check the project in .
    python tools/meta_key_check.py -p ../other-game
    python tools/meta_key_check.py --strict         # warnings count towards the exit code
    python tools/meta_key_check.py --only game/     # report only findings under a prefix
    python tools/meta_key_check.py --no-scenes      # ignore .tscn/.tres `metadata/` writes
    python tools/meta_key_check.py --json           # machine-readable verdict

(`python` on Windows -- `python3` there is a Microsoft Store alias stub that satisfies
`command -v` and then refuses to run.)
"""

import argparse
import json
import re
import sys
from bisect import bisect_right
from pathlib import Path

import gdsource

TOOL_VERSION = "1.0.0"

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_CANNOT_RUN = 2

SEVERITY_ERROR = "error"
SEVERITY_WARNING = "warning"
SEVERITY_ADVISORY = "advisory"

SEVERITY_ORDER = {SEVERITY_ERROR: 0, SEVERITY_WARNING: 1, SEVERITY_ADVISORY: 2}
SEVERITY_LABEL = {SEVERITY_ERROR: "ERROR", SEVERITY_WARNING: "WARN",
                  SEVERITY_ADVISORY: "ADVISORY"}

# Printed even on a clean run, next to the verdict -- the convention name_check.py's
# NOT_COVERED establishes. A checker that says "0 findings" and nothing else has handed the
# reader a stronger claim than it made.
NOT_COVERED = (
    "a clean run means every key spelled in source has both ends. It does NOT check the "
    "VALUE (a key written as a float and read as an int is invisible here), the ORDER (a "
    "reader that runs before its writer looks identical), or the OBJECT (two scripts can "
    "agree on a key and hang it off different nodes). Keys built at runtime, and keys "
    "crossing into C#/GDExtension/an editor plugin, are outside what any static pass can "
    "see - the unresolved count above is how many of those there are."
)

# ---------------------------------------------------------------------------
# Source scanning
#
# Ported from name_check.py deliberately, not re-invented, exactly as coverage_check.py
# does: the three tools scan the same .gd text and must agree about what is code. A token
# inside a comment or a string is the single most common way a text scan produces a
# confident finding about nothing.
#
# One property is load-bearing here beyond what those two need: the blanking is
# LENGTH-PRESERVING (a comment becomes spaces of its own length, a string body becomes
# spaces, an escape pair becomes two spaces, newlines stay newlines). So an offset found in
# the blanked text indexes the same character in `raw`, and the key literal can be read
# back out of the raw source at the identical span -- no matching literals up by line
# number, which mis-pairs the moment two metadata calls share a line.
# ---------------------------------------------------------------------------

GDIGNORE = ".gdignore"


class SourceText:
    """A .gd file with comments and string bodies blanked out, positions preserved."""

    def __init__(self, text):
        self.raw = text
        self.code = _blank_strings_and_comments(text)
        assert len(self.code) == len(self.raw), "blanking must preserve offsets"
        self._line_starts = [0]
        for i, ch in enumerate(self.code):
            if ch == "\n":
                self._line_starts.append(i + 1)

    def line_of(self, pos):
        return bisect_right(self._line_starts, pos)

    def line_text(self, line):
        lines = self.raw.splitlines()
        return lines[line - 1].strip() if 0 < line <= len(lines) else ""


def _blank_strings_and_comments(text):
    """Return the source with comments and string bodies replaced by spaces.

    Now one line over tools/gdsource.py, whose BLANK mode is this transform: it keeps
    the quote *delimiters*, which is what lets the key extractor below recognise a
    literal argument at all. Verified byte-identical to the implementation that used to
    sit here over all 60 .gd files in the repo before the swap, which is the only
    evidence that matters for a move like this.

    Everything the docstring here used to promise is now promised, and TESTED, there:
    ''' and \"\"\" blocks, ' and " strings, the r"" raw prefix and the &"" / ^"" prefixes,
    backslash escapes outside raw strings (so a literal containing a quote does not end
    the string early and leave the rest of the file parsed as code), a backslash-newline
    continuation that keeps its line break, and an unterminated single-line literal that
    stops at the newline instead of swallowing the file. `python tools/gdsource.py`.
    """
    return gdsource.strip_comments(text, gdsource.BLANK)


def _match_paren(code, open_pos):
    """Index just past the `)` closing the `(` at open_pos, or -1.

    A metadata call wraps across lines in real code and GDScript needs no continuation
    backslash inside parens, so a line-oriented match would silently truncate the argument
    list -- which reads as a call with no key, not as a call that was skipped.
    """
    depth = 0
    i = open_pos
    n = len(code)
    while i < n:
        c = code[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def _split_args(code, start, end):
    """Top-level comma-separated argument spans (absolute offsets) between start and end."""
    spans = []
    depth = 0
    arg_start = start
    for i in range(start, end):
        ch = code[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            spans.append((arg_start, i))
            arg_start = i + 1
    if code[arg_start:end].strip():
        spans.append((arg_start, end))
    return spans


# ---------------------------------------------------------------------------
# Literals and constants
# ---------------------------------------------------------------------------

RE_STRING_LITERAL = re.compile(
    r"""^[ \t]*(r|&|\^)?("""
    r'''"""(?P<td>(?:[^\\]|\\.)*?)"""'''
    r"""|'''(?P<ts>(?:[^\\]|\\.)*?)'''"""
    r'''|"(?P<d>(?:[^"\\\n]|\\.)*)"'''
    r"""|'(?P<s>(?:[^'\\\n]|\\.)*)')[ \t]*$""",
    re.S)

RE_IDENT_PATH = re.compile(r"^[ \t]*([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)*)[ \t]*$")

_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "a": "\a", "b": "\b",
            "f": "\f", "v": "\v", '"': '"', "'": "'", "\\": "\\"}


def _unescape(body, raw):
    if raw:
        return body
    out = []
    i = 0
    while i < len(body):
        if body[i] == "\\" and i + 1 < len(body):
            nxt = body[i + 1]
            out.append(_ESCAPES.get(nxt, nxt))
            i += 2
            continue
        out.append(body[i])
        i += 1
    return "".join(out)


def literal_value(text):
    """The string a literal expression denotes, or None when it is not one literal.

    `&"foo"` (StringName) and `"foo"` denote the same metadata key -- Godot converts the
    argument to a StringName either way -- so the prefix is stripped rather than treated as
    a different spelling. `"a" + b` and `"%s" % x` fall through to None: this returns a key
    or it declines, and never a fragment of one.
    """
    m = RE_STRING_LITERAL.match(text)
    if not m:
        return None
    body = next(g for g in (m.group("td"), m.group("ts"), m.group("d"), m.group("s"))
                if g is not None)
    return _unescape(body, m.group(1) == "r")


RE_CONST = re.compile(
    r"(?m)^[ \t]*const[ \t]+([A-Za-z_]\w*)[ \t]*"
    r"(?::[ \t]*[^=\n]+?)?[ \t]*:?=[ \t]*(.*)$")
RE_CLASS_NAME = re.compile(r"(?m)^[ \t]*class_name[ \t]+([A-Za-z_]\w*)")
RE_EXTENDS_TOP = re.compile(r"(?m)^extends[ \t]+(.+?)[ \t]*$")
RE_CLASS_NAME_EXTENDS = re.compile(
    r"(?m)^[ \t]*class_name[ \t]+[A-Za-z_]\w*[ \t]+extends[ \t]+(.+?)[ \t]*$")
RE_PRELOAD_CONST = re.compile(r"^[ \t]*preload[ \t]*\([ \t]*[\"']")

# The complete Object metadata API in Godot 4. Node/Resource/everything else inherit it
# unchanged; there is no second spelling and no per-class variant.
#   set_meta(name, value)      write   -- but a null value is documented as remove_meta
#   get_meta(name[, default])  read    -- default makes the missing case legal, not absent
#   has_meta(name)             probe   -- a read of whether the key exists
#   remove_meta(name)          delete
#   get_meta_list()            bulk read of every key, naming none of them
OPS = {
    "set_meta": "write",
    "get_meta": "read",
    "has_meta": "probe",
    "remove_meta": "delete",
    "get_meta_list": "enumerate",
}

# `\b` already prevents matching the tail of `_set_meta`; the negative lookbehind on `func`
# keeps a *declaration* of a same-named method from being read as a call site.
RE_META_CALL = re.compile(r"(?<!func )\b(%s)[ \t]*\(" % "|".join(sorted(OPS)))


class GDFile:
    def __init__(self, res_path, fs_path):
        self.res_path = res_path
        self.fs_path = fs_path
        self.class_name = None
        self.extends_name = None
        self.extends_path = None
        self.consts = {}          # name -> raw value text
        self.const_preloads = {}  # name -> res path (for `Foo.KEY` through a preload const)
        self.sites = []           # dicts, see scan_file
        self.read_error = None


def scan_file(res_path, fs_path):
    gd = GDFile(res_path, fs_path)
    try:
        text = fs_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = fs_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        gd.read_error = str(exc)
        return gd

    src = SourceText(text)
    code = src.code

    m = RE_CLASS_NAME.search(code)
    if m:
        gd.class_name = m.group(1)

    m = RE_CLASS_NAME_EXTENDS.search(code) or RE_EXTENDS_TOP.search(code)
    if m:
        extends_raw = m.group(1).strip()
        if extends_raw[:1] in "\"'":
            value = literal_value(extends_raw)
            if value and value.startswith("res://"):
                gd.extends_path = value[len("res://"):]
        elif re.match(r"^[A-Za-z_][\w.]*$", extends_raw):
            gd.extends_name = extends_raw

    for cm in RE_CONST.finditer(code):
        value_raw = src.raw[cm.start(2):cm.end(2)]
        gd.consts[cm.group(1)] = value_raw
        if RE_PRELOAD_CONST.match(cm.group(2) or ""):
            inner = literal_value(src.raw[cm.start(2):cm.end(2)].strip()[len("preload("):-1])
            if inner and inner.startswith("res://"):
                gd.const_preloads[cm.group(1)] = inner[len("res://"):]

    for mm in RE_META_CALL.finditer(code):
        verb = mm.group(1)
        open_pos = mm.end() - 1
        close = _match_paren(code, open_pos)
        line = src.line_of(mm.start())
        if close < 0:
            gd.sites.append({"file": res_path, "line": line, "verb": verb,
                             "op": OPS[verb], "arg_raw": "", "key": None,
                             "defaulted": False, "argc": 0,
                             "why": "unterminated argument list",
                             "text": src.line_text(line)})
            continue
        spans = _split_args(code, open_pos + 1, close - 1)
        arg_raw = src.raw[spans[0][0]:spans[0][1]].strip() if spans else ""
        gd.sites.append({"file": res_path, "line": line, "verb": verb, "op": OPS[verb],
                         "arg_raw": arg_raw, "key": None, "argc": len(spans),
                         "defaulted": verb == "get_meta" and len(spans) >= 2,
                         # `set_meta(k, null)` is documented as equivalent to remove_meta,
                         # so it is a delete. Counting it as a write would report a key
                         # that is only ever cleared as "written".
                         "null_write": (verb == "set_meta" and len(spans) >= 2
                                        and src.raw[spans[1][0]:spans[1][1]].strip()
                                        == "null"),
                         "why": None,
                         "text": src.line_text(line)})
    return gd


# ---------------------------------------------------------------------------
# Project model
# ---------------------------------------------------------------------------

class Project:
    def __init__(self, root):
        self.root = root
        self.files = []
        self.by_path = {}
        self.by_class = {}
        self.autoloads = {}
        self.vendored_dirs = []
        self.unreadable = []
        self.scene_files = []
        self.scenes_skipped = False

    def scan(self, with_scenes=True):
        self.vendored_dirs = _vendored_dirs(self.root)
        for fs_path in _walk(self.root, ".gd"):
            res_path = fs_path.relative_to(self.root).as_posix()
            gd = scan_file(res_path, fs_path)
            if gd.read_error:
                self.unreadable.append((res_path, gd.read_error))
            self.files.append(gd)
            self.by_path[res_path] = gd
            if gd.class_name and gd.class_name not in self.by_class:
                self.by_class[gd.class_name] = gd
        self.autoloads = _read_autoloads(self.root)
        if with_scenes:
            self.scene_files = [p for suffix in (".tscn", ".tres")
                                for p in _walk(self.root, suffix)]

    def is_vendored(self, res_path):
        return any(res_path.startswith(v + "/") for v in self.vendored_dirs)

    def base_of(self, gd):
        if gd.extends_path:
            return self.by_path.get(gd.extends_path)
        if gd.extends_name:
            root = gd.extends_name.split(".")[0]
            if root in gd.const_preloads:
                return self.by_path.get(gd.const_preloads[root])
            return self.by_class.get(root)
        return None

    def const_in_chain(self, gd, name, depth=0):
        """A const's raw value text, looked up through the extends chain.

        Without the chain walk, a subclass using a key its base declares looks like a key
        that resolves to nothing -- reported as an unresolved advisory on correct code,
        which is exactly how a checker teaches a project to ignore it.
        """
        cur = gd
        seen = set()
        while cur is not None and cur.res_path not in seen and depth < 32:
            seen.add(cur.res_path)
            if name in cur.consts:
                return cur.consts[name], cur.res_path
            cur = self.base_of(cur)
            depth += 1
        return None, None

    def resolve_key(self, gd, arg_raw):
        """(key, spelling, why) for one metadata argument.

        Returns (None, None, reason) rather than a guess whenever the argument is not a
        literal and does not resolve to a const holding one. A static checker that guesses
        at a key is worse than no checker: it invents both halves of a contract.
        """
        if not arg_raw:
            return None, None, "no argument"
        value = literal_value(arg_raw)
        if value is not None:
            return value, '"%s"' % value, None
        m = RE_IDENT_PATH.match(arg_raw)
        if not m:
            return None, None, "not a literal (an expression built at runtime)"
        path = m.group(1)
        parts = path.split(".")
        if len(parts) == 1:
            raw, where = self.const_in_chain(gd, parts[0])
            if raw is None:
                return None, None, ("`%s` is not a const in this file or its base classes"
                                    % path)
            value = literal_value(raw)
            if value is None:
                return None, None, ("`%s` (%s:%s) is a const but not a string literal"
                                    % (path, where, raw.strip()[:40]))
            return value, "%s (%s)" % (path, where), None
        if len(parts) == 2:
            owner = None
            if parts[0] in gd.const_preloads:
                owner = self.by_path.get(gd.const_preloads[parts[0]])
            elif parts[0] in self.by_class:
                owner = self.by_class[parts[0]]
            elif parts[0] in self.autoloads:
                owner = self.by_path.get(self.autoloads[parts[0]])
            elif parts[0] == "self":
                owner = gd
            if owner is None:
                return None, None, "`%s` does not resolve to a script in this project" % parts[0]
            raw, where = self.const_in_chain(owner, parts[1])
            if raw is None:
                return None, None, "`%s` has no const `%s`" % (parts[0], parts[1])
            value = literal_value(raw)
            if value is None:
                return None, None, "`%s` is a const but not a string literal" % path
            return value, "%s (%s)" % (path, where), None
        return None, None, "`%s` is nested deeper than Class.CONST" % path


def _vendored_dirs(root):
    """addons/<name> holding a plugin.cfg: third-party, exempt from FINDINGS.

    Their call sites are still collected. A vendored addon that legitimately writes a key
    this project reads is a real writer, and dropping it would manufacture the exact
    false "read with no writer" this tool exists to report truthfully.
    """
    out = []
    addons = root / "addons"
    if not addons.is_dir():
        return out
    for child in sorted(addons.iterdir()):
        if child.is_dir() and (child / "plugin.cfg").is_file():
            out.append("addons/%s" % child.name)
    return out


def _walk(root, suffix):
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            entries = sorted(current.iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.is_dir():
                if entry.name.startswith("."):
                    continue
                if (entry / GDIGNORE).is_file():
                    continue
                stack.append(entry)
            elif entry.suffix == suffix:
                yield entry


def _read_autoloads(root):
    out = {}
    try:
        text = (root / "project.godot").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return out
    in_section = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_section = stripped == "[autoload]"
            continue
        if not in_section or "=" not in stripped:
            continue
        name, _, value = stripped.partition("=")
        value = value.strip().strip('"').lstrip("*")
        if name.strip():
            out[name.strip()] = (value[len("res://"):] if value.startswith("res://")
                                 else value)
    return out


# A `metadata/<key> = <value>` line inside a .tscn/.tres node block: a key written by the
# editor, with no GDScript writer anywhere. Without this pass, every scene-authored key
# would be reported as "read with no writer" -- a confident finding about nothing, on the
# one construct a .gd-only scan structurally cannot see.
RE_SCENE_META = re.compile(r"(?m)^metadata/([^ \t=\[\]]+)[ \t]*=")

# `_edit_lock_`, `_editor_description_` and friends are the editor's own bookkeeping. They
# are never read by game code and reporting them would be noise on every project.
SCENE_META_INTERNAL_PREFIX = "_"


def scan_scene_meta(paths, root):
    sites = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = path.relative_to(root).as_posix()
        line_starts = [0]
        for i, ch in enumerate(text):
            if ch == "\n":
                line_starts.append(i + 1)
        for m in RE_SCENE_META.finditer(text):
            key = m.group(1)
            if key.startswith(SCENE_META_INTERNAL_PREFIX):
                continue
            sites.append({"file": rel, "line": bisect_right(line_starts, m.start()),
                          "verb": "metadata/", "op": "write", "arg_raw": key,
                          "key": key, "defaulted": False, "null_write": False,
                          "argc": 1, "why": None, "scene": True,
                          "text": '%s = ...' % m.group(0).rstrip("=").strip()})
    return sites


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

RULE_NEVER_WRITTEN = "meta_key_never_written"
RULE_NEVER_READ = "meta_key_never_read"
RULE_UNRESOLVED = "meta_key_unresolved"
RULES = [RULE_NEVER_WRITTEN, RULE_NEVER_READ, RULE_UNRESOLVED]


def _verb_label(site):
    """How a site is spelled in a findings list.

    `set_meta(key, null)` has to say so: listed as a bare `set_meta` it reads as the very
    writer the finding claims does not exist.
    """
    if site.get("null_write"):
        return "set_meta(..., null) [a removal]"
    return site["verb"]


def finding(file, line, rule, severity, subject, message):
    return {"file": file, "line": line, "rule": rule, "severity": severity,
            "subject": subject, "message": message}


class KeyRecord:
    def __init__(self, key):
        self.key = key
        self.writes = []
        self.reads = []      # get_meta
        self.probes = []     # has_meta
        self.deletes = []    # remove_meta, and set_meta(k, null)
        self.spellings = set()

    @property
    def files(self):
        out = []
        for site in self.writes + self.reads + self.probes + self.deletes:
            if site["file"] not in out:
                out.append(site["file"])
        return out

    @property
    def consumers(self):
        return self.reads + self.probes

    @property
    def cross_script(self):
        return len(self.files) > 1


def check(project, sites, enum_sites, only_prefixes):
    keys = {}
    findings = []
    for site in sites:
        if site["key"] is None:
            continue
        rec = keys.setdefault(site["key"], KeyRecord(site["key"]))
        if site.get("spelling"):
            rec.spellings.add(site["spelling"])
        op = site["op"]
        if op == "write":
            (rec.deletes if site.get("null_write") else rec.writes).append(site)
        elif op == "read":
            rec.reads.append(site)
        elif op == "probe":
            rec.probes.append(site)
        elif op == "delete":
            rec.deletes.append(site)

    # An unresolved key is reported once per call site, at its own location: the whole
    # point is that the reader can go look at the line the tool could not decide.
    for site in sites:
        if site["key"] is not None or site.get("scene"):
            continue
        findings.append(finding(
            site["file"], site["line"], RULE_UNRESOLVED, SEVERITY_ADVISORY,
            site["arg_raw"] or site["verb"],
            "%s(%s) - the key could not be resolved statically: %s. This call site is "
            "counted in the denominator, not skipped: any key it names is invisible to "
            "both halves of this check."
            % (site["verb"], site["arg_raw"] or "", site["why"])))

    for key in sorted(keys):
        rec = keys[key]
        scope = ("cross-script (%s)" % ", ".join(rec.files)) if rec.cross_script \
            else "single file"
        if not rec.writes and (rec.consumers or rec.deletes):
            hard = [s for s in rec.reads if not s["defaulted"]]
            site = (hard or rec.consumers or rec.deletes)[0]
            if hard:
                severity = SEVERITY_ERROR
                why = ("`get_meta(\"%s\")` with no default on an object that never had it "
                       "set is a runtime error and a null" % key)
            elif rec.consumers:
                # A default does NOT make this legal, only quiet. The key is written
                # nowhere in the project, so the default is the only value the read can
                # ever produce -- which is precisely the typo this rule exists for, and
                # the shape it takes in real code (`get_meta(META_SOURCES, 0)` answering
                # 0 forever reads as "not slowed", which reads as "working"). It gates.
                severity = SEVERITY_ERROR
                why = ("every read is defaulted or guarded, so nothing crashes and the "
                       "read silently returns the default forever - a feature that does "
                       "nothing, which is why this gates rather than warns")
            else:
                # Only ever removed. Redundant cleanup, not a wrong answer.
                severity = SEVERITY_WARNING
                why = ("the key is only ever removed, never written or read - dead "
                       "cleanup rather than a wrong answer")
            findings.append(finding(
                site["file"], site["line"], RULE_NEVER_WRITTEN, severity, key,
                'metadata key "%s" is never written: %d read(s), %d probe(s), '
                "%d removal(s)%s - %s. Sites: %s"
                % (key, len(rec.reads), len(rec.probes), len(rec.deletes),
                   " (scenes were not scanned; re-run without --no-scenes)"
                   if project.scenes_skipped else "",
                   why,
                   ", ".join("%s:%d %s" % (s["file"], s["line"], _verb_label(s))
                             for s in (rec.consumers + rec.deletes)[:6]))))
        elif rec.writes and not rec.consumers:
            if enum_sites:
                severity = SEVERITY_ADVISORY
                tail = (" - DEMOTED to advisory because %s calls get_meta_list(), which "
                        "reads every key without naming one, so no static pass can prove "
                        "this has no reader"
                        % ", ".join("%s:%d" % (s["file"], s["line"])
                                    for s in enum_sites[:3]))
            else:
                severity = SEVERITY_WARNING
                tail = (" - nothing in the project calls get_meta_list(), so this key has "
                        "no reader at all")
            site = rec.writes[0]
            findings.append(finding(
                site["file"], site["line"], RULE_NEVER_READ, severity, key,
                'metadata key "%s" is written in %d place(s) and never read%s. Dead '
                "weight, or a rename applied to one end only. Writers: %s. Scope: %s"
                % (key, len(rec.writes), tail,
                   ", ".join("%s:%d" % (s["file"], s["line"]) for s in rec.writes[:6]),
                   scope)))

    if only_prefixes:
        findings = [f for f in findings
                    if any(f["file"].startswith(p) for p in only_prefixes)]
    # Vendored addons are third-party; their keys are collected (so they can satisfy a
    # project-side read) but never reported against.
    findings = [f for f in findings if not project.is_vendored(f["file"])]
    return keys, findings


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def report(project, keys, findings, counts, stats):
    print("meta_key_check %s - node metadata keys as a cross-script contract, no engine "
          "launched" % TOOL_VERSION)
    print("project: %s" % project.root)
    print("scanned: %d .gd file(s)%s%s; %s"
          % (stats["gd_files"],
             ", %d unreadable" % len(project.unreadable) if project.unreadable else "",
             ", %d vendored dir(s) exempt from findings" % len(project.vendored_dirs)
             if project.vendored_dirs else "",
             "%d .tscn/.tres file(s) read for `metadata/` entries" % stats["scene_files"]
             if not project.scenes_skipped
             else "scene `metadata/` entries SKIPPED (--no-scenes): an editor-authored "
                  "key will look unwritten"))
    print("call sites: %s" % (", ".join("%s %d" % (verb, stats["verbs"][verb])
                                        for verb in sorted(OPS)) or "none"))
    print("Checked: %d of %d metadata call site(s) resolved to a key, %d unresolved"
          % (stats["resolved"], stats["sites"], stats["unresolved"]))
    print("")

    if keys:
        print("metadata keys (%d):" % len(keys))
        for key in sorted(keys):
            rec = keys[key]
            # Never truncated: a key silently cut to fit a column is a key the reader
            # cannot grep for, on the one line that names it.
            print("  %-24s W%-2d R%-2d P%-2d D%-2d  %-13s %s"
                  % (key, len(rec.writes), len(rec.reads), len(rec.probes),
                     len(rec.deletes),
                     "CROSS-SCRIPT" if rec.cross_script else "single file",
                     ", ".join(rec.files[:3])))
            if rec.spellings:
                print("  %-24s spelled: %s" % ("", ", ".join(sorted(rec.spellings)[:3])))
    else:
        print("metadata keys: NONE resolved - this project addresses no metadata by a "
              "name this pass could read (which is not the same as using none).")
    print("")

    if not findings:
        print("No findings.")
    else:
        by_file = {}
        for f in findings:
            by_file.setdefault(f["file"], []).append(f)
        for path in sorted(by_file):
            print(path)
            for f in sorted(by_file[path],
                            key=lambda f: (SEVERITY_ORDER[f["severity"]], f["line"])):
                print("  %-9s %s:%d  %s"
                      % (SEVERITY_LABEL[f["severity"]], f["rule"], f["line"], f["message"]))
            print("")

    print("errors: %d | warnings: %d | advisory: %d"
          % (counts["error"], counts["warning"], counts["advisory"]))
    # Every rule prints its count, including the zeros. A check that ran and found nothing
    # has to be a 0 here, never an absent line -- an absent line is indistinguishable from
    # a check that never ran, which is the failure mode a consolidated report invites.
    print("By check: %s" % " | ".join("%s %d" % (rule, stats["by_rule"][rule])
                                      for rule in RULES))
    for note in stats["skipped"]:
        print("SKIPPED: %s" % note)
    print("NOT COVERED: %s" % NOT_COVERED)


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Resolve both ends of every node-metadata key in a Godot project.\n"
                    "\n"
                    "A metadata key is a cross-script contract with no declaration: a\n"
                    "string written by one script and read by another. name_check resolves\n"
                    "identifiers, lint and import_check type-check declarations, and none\n"
                    "of them can see a string used as a key -- so a typo in one is silent\n"
                    "everywhere and produces a feature that simply does nothing.\n"
                    "\n"
                    "NEVER OPENS THE PROJECT: no godot invocation, no --import, no write\n"
                    "to .godot/. Safe to run with N agents on one checkout.",
        epilog="Exit codes: 0 clean, 1 findings that count, 2 could not run.\n"
               "\n"
               "Reported both ways: a key read with no writer is the typo; a key written\n"
               "with no reader is dead weight or a half-finished rename.")
    parser.add_argument("--project", "-p", default=".", help="Path to the Godot project")
    parser.add_argument("--only", action="append", default=[], metavar="PREFIX",
                        help="Report only findings whose path starts with this prefix "
                             "(repeatable). The whole project is always scanned, so "
                             "cross-file keys still pair up.")
    parser.add_argument("--no-scenes", action="store_true",
                        help="Do not read .tscn/.tres for `metadata/` entries. Editor-"
                             "authored keys will then look like reads with no writer.")
    parser.add_argument("--strict", action="store_true",
                        help="Count warnings towards the exit code")
    parser.add_argument("--json", action="store_true", help="Emit the verdict as JSON")
    args = parser.parse_args()

    root = Path(args.project).expanduser().resolve()
    if not (root / "project.godot").is_file():
        print("Error: no project.godot in %s. Run from the project root or pass "
              "--project/-p." % root, file=sys.stderr)
        return EXIT_CANNOT_RUN

    project = Project(root)
    project.scenes_skipped = args.no_scenes
    try:
        project.scan(with_scenes=not args.no_scenes)
    except OSError as exc:
        print("Error: could not scan %s: %s" % (root, exc), file=sys.stderr)
        return EXIT_CANNOT_RUN

    sites = []
    enum_sites = []
    for gd in project.files:
        for site in gd.sites:
            if site["op"] == "enumerate":
                enum_sites.append(site)
                continue
            key, spelling, why = project.resolve_key(gd, site["arg_raw"])
            site["key"] = key
            site["spelling"] = spelling
            if why:
                site["why"] = why
            sites.append(site)
    scene_sites = scan_scene_meta(project.scene_files, root) if not args.no_scenes else []
    sites.extend(scene_sites)

    only_prefixes = [p.replace("res://", "") for p in args.only]
    keys, findings = check(project, sites, enum_sites, only_prefixes)

    counts = {SEVERITY_ERROR: 0, SEVERITY_WARNING: 0, SEVERITY_ADVISORY: 0}
    by_rule = {rule: 0 for rule in RULES}
    for f in findings:
        counts[f["severity"]] += 1
        by_rule[f["rule"]] += 1

    verbs = {verb: 0 for verb in OPS}
    for gd in project.files:
        for site in gd.sites:
            verbs[site["verb"]] += 1

    skipped = []
    if project.unreadable:
        skipped.append("%d file(s) could not be read, so their keys are absent from both "
                       "halves of this check: %s"
                       % (len(project.unreadable),
                          ", ".join("%s (%s)" % p for p in project.unreadable[:3])))
    if args.no_scenes:
        skipped.append("`metadata/` entries in .tscn/.tres (--no-scenes): an editor-"
                       "authored key will be reported as read with no writer")

    resolvable = [s for s in sites if not s.get("scene")]
    stats = {
        "gd_files": len(project.files),
        "scene_files": len(project.scene_files),
        "sites": len(resolvable),
        "resolved": sum(1 for s in resolvable if s["key"] is not None),
        "unresolved": sum(1 for s in resolvable if s["key"] is None),
        "verbs": verbs,
        "by_rule": by_rule,
        "skipped": skipped,
    }

    gating_errors = counts[SEVERITY_ERROR]
    exit_code = EXIT_OK
    if gating_errors or (args.strict and counts[SEVERITY_WARNING]):
        exit_code = EXIT_FINDINGS

    if args.json:
        print(json.dumps({
            "tool": "meta_key_check",
            "version": TOOL_VERSION,
            "project": str(root),
            "scanned": {"gd_files": stats["gd_files"],
                        "scene_files": stats["scene_files"],
                        "unreadable": project.unreadable,
                        "vendored_skipped": project.vendored_dirs},
            "call_sites": {"total": stats["sites"], "resolved": stats["resolved"],
                           "unresolved": stats["unresolved"], "by_verb": verbs},
            "keys": [{
                "key": key,
                "cross_script": keys[key].cross_script,
                "files": keys[key].files,
                "spellings": sorted(keys[key].spellings),
                "writes": [(s["file"], s["line"]) for s in keys[key].writes],
                "reads": [(s["file"], s["line"]) for s in keys[key].reads],
                "probes": [(s["file"], s["line"]) for s in keys[key].probes],
                "deletes": [(s["file"], s["line"]) for s in keys[key].deletes],
            } for key in sorted(keys)],
            "counts": counts,
            "by_rule": by_rule,
            "skipped": skipped,
            # A machine reader of an all-zero `counts` needs the same caveat the human
            # report prints, or it draws the stronger conclusion silently.
            "not_covered": NOT_COVERED,
            "findings": findings,
            "exit": exit_code,
        }, indent=2))
    else:
        report(project, keys, findings, counts, stats)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
