#!/usr/bin/env python3
r"""audio_license_check.py - every shipped audio file is named in License.txt, and the
credit EMBEDDED IN THE FILE agrees with the section that licenses it.

WHY THIS EXISTS.

plant-tower-defense-muyk was filed because five audio files landed in
`assets/audio/` and nobody could say where they came from. Answering it took a
hand-rolled Vorbis-comment dump, and the thing that cracked it was metadata the
files were carrying the whole time: every Kenney file says `ARTIST=Kenney`, the
bought music track says `TPE1=pegonthetrack & ELVGames`, and two cues said
neither -- they carried `TITLE=place10` / `TITLE=place6` and MP3GAIN batch tags,
which is the usual fingerprint of a numbered pack. (They turned out to be the
owner's own take-numbering; License.txt now records that, and this tool's
WAIVER below is how that answer is expressed to the machine.)

So the provenance evidence is IN THE FILES and it was never read by anything.
That is the hole this closes.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT.

  * `lint_project.gd` validates scenes, UIDs, duplicate ids and shaders. It never
    opens `License.txt` and has no concept of provenance.
  * `name_check.py` resolves identifiers. A filename in a licence document is not
    an identifier and is not in any script.
  * `sfx_call_check.py` is the closest neighbour and is about a DIFFERENT set: it
    reconciles the event ids the game plays against the `Sfx.SOUNDS` table. A
    file can be perfectly wired into SOUNDS, played on every run, and completely
    unlicensed -- which is exactly the state this repo shipped in.
  * The test suite cannot help either. A licence is not a runtime property, so
    there is nothing for a test to observe.

WHAT IT CHECKS. Four rules, and one advisory.

  A. SECTION AGREEMENT (gates). All files carrying the SAME embedded artist
     string must be listed in the SAME section of License.txt. Sharp, needs no
     prose reading, and fires the moment a Kenney file is dropped into the
     hand-made section or vice versa -- the shape of drift the bead worried
     about. Note that reading the section's PROSE for the artist name would not
     work: the "CUES WRITTEN FOR THIS GAME" heading contains the word "Kenney"
     (in "not Kenney's"), so a Kenney file misfiled there would match on text
     and read clean. That near-miss is why rule A is structural.

  B. CREDITED SOMEWHERE (gates). A file whose embedded artist string is present
     must have every token of that string (length >= 3) appear somewhere in
     License.txt. Catches a file arriving credited to a party the document has
     never heard of, which rule A cannot see when it is the only file from them.

  C. EVERY FILE IS NAMED (gates). Every audio file on disk appears in
     License.txt. This is the plain form of the bead's own defect.

  D. EVERY NAME IS A FILE (gates). Every listing row in License.txt names a file
     that exists. A stale row is a licence claim about nothing, and it is how a
     document drifts into being read as complete when it is not.

  E. PACK FINGERPRINT (advisory NOTE, exit 0). A file listed in a section whose
     heading claims the project made it, while carrying pack-shaped metadata --
     a TITLE ending in digits, or an MP3GAIN_* tag. WAIVED when the section text
     quotes the tag verbatim (`TITLE=place10`), because writing down the
     suspicious tag and explaining it IS the answer. Advisory rather than
     gating because the honest response to it is sometimes "yes, and here is
     why", which is a document edit and not a defect.

READING THE PROSE. License.txt is written by hand, in a plain-text editor,
rendered by nothing -- so it rewards no markup at all and there are no backticks
to key off. Two conventions, measured against the real file rather than assumed:

  * DISK -> DOC is not parsed at all. Each on-disk filename is searched for as a
    literal substring at word boundaries. No grammar to get wrong. The one hazard
    is a filename that is a suffix of another; the tool detects that case and
    reports it rather than silently mis-attributing.
  * DOC -> DISK needs a grammar, and the convention is a listing row: a line
    whose FIRST whitespace-delimited token ends in an audio extension. Measured
    on the shipped file: 19 of 19 audio files are reachable this way. The tool
    prints that ratio every run, because a denominator over SECTIONS would not
    measure the extraction -- only a count of what the extraction found does.

SECTIONS ARE A REGION, SO THE REGION IS A DENOMINATOR TOO. Sections split on a
rule of 20+ dashes. The shipped file has 6. A collapsed split would make every
file share one section and rule A would pass over everything, so the section
count is printed on every run and a file named in more than one section is
reported rather than resolved.

THE FIXTURE IS KEPT: `python tools/audio_license_check.py --self-test`, 12 cases.
Run it after ANY edit to this file. It asserts on the substring that identifies
each finding, not on a count -- a count going 6 -> 6 while one rule fell silent
and another double-fired is exactly what a count cannot see -- and it asserts the
count too, so an EXTRA finding fails as a false positive. The four mutations
below were re-run against it: each goes red naming the rule it broke, and the
restore returns 12 of 12.

WHAT IT COST TO GET RIGHT. Baseline 2 note(s), 6 finding(s).
Three separate times the fixture SILENCED the rule it was built to prove, by
naming the thing in its own explanatory prose -- `orphan.wav`, then `chop.ogg`,
then an artist tag of `Nobody` written into the very line that described it.
Every one read as a working checker with one rule quietly absent. If you rebuild
this fixture: the document must never spell the name it is testing the absence
of.

# fixture:   bigchop.ogg listed, chop.ogg on disk and listed
#              NOWHERE but as a suffix of it                     (rule C + the
#              ambiguity guard, and the only case M1 can fail on)
#            bong_001.ogg (ARTIST=Kenney) in the made-here sect. (rule A)
#            stranger.ogg, chop.ogg byte-patched to
#              ARTIST=Zorbat -- same length, so no Vorbis
#              length field is disturbed                         (rule B)
#            orphan.wav on disk, named nowhere at all            (rule C)
#            a listing row for ghost.ogg, which does not exist   (rule D)
#            dual.wav listed in BOTH sections                    (ambiguity, and
#              the only case M4 can fail on)
#            plant-place.ogg (TITLE=place10) in the made-here
#              section, with and without the tag quoted          (rule E + waiver)
# mutations: M1 `names_file` -> plain `filename in text`   -> RED, 6->5. chop.ogg
#              stops being reported, satisfied by the row for bigchop.ogg.
#              SURVIVES on a fixture with no suffix pair, which is what the
#              first version of this fixture was.
#            M2 rule A greps section PROSE for the artist
#              instead of grouping structurally           -> RED, 6->5. This is
#              the design being defended: "CUES WRITTEN FOR THIS GAME -- not
#              Kenney's" CONTAINS "Kenney", so a prose match clears a misfiled
#              Kenney file. Read WHICH finding went quiet, not the total.
#            M3 rule E appends to findings not notes      -> RED the other way,
#              1 note / 7 findings: the answered place6/place10 case becomes a
#              permanently-red gate, which is worse than no gate.
#            M4 drop the multi-section report             -> RED, 6->5. Silently
#              picks hits[0], so a file licensed twice reads clean.
#            M5 drop a `.replace("\r\n","\n")` on the doc  -> SURVIVED, verified
#              applied, against a fixture converted to CRLF: identical 4
#              sections, 2 notes, 6 findings. `read_text` is text mode and
#              universal newlines had already done it. The call is GONE rather
#              than the fixture strengthened -- see main().
#
# Watch the needle, not the exit code: M5 first reported NOT-APPLIED twice, once
# to a grep BRE reading `\r` as `r` and once to shell backslash mangling, and
# both looked exactly like a survivor. And run the restore: the run that caught
# a truncated fixture here was the restore coming back 1 section / 11 findings.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "assets" / "audio"
LICENCE = AUDIO_DIR / "License.txt"

AUDIO_EXTS = (".ogg", ".wav", ".mp3", ".flac", ".opus")

# A rule of dashes is the document's own section break. Most-specific first, per
# .claude/skills/house-static-checker: a generic marker winning where a specific
# one appears later means the generic one matched INSIDE the block.
SECTION_RULE = re.compile(r"\n[ \t]*-{20,}[ \t]*\n")

# Pack fingerprints: a title that is a numbered take out of a set, or a tag left
# behind by a batch gain-normalisation pass.
NUMBERED_TITLE = re.compile(r"^(.*?)(\d+)$")
MADE_HERE = re.compile(r"WRITTEN FOR THIS GAME", re.I)


def read_vorbis_tags(data: bytes) -> dict:
    """Vorbis comment block out of an Ogg container. {} when there is none."""
    i = data.find(b"\x03vorbis")
    if i < 0:
        return {}
    q = i + 7
    try:
        (vlen,) = struct.unpack("<I", data[q:q + 4])
        q += 4 + vlen
        (count,) = struct.unpack("<I", data[q:q + 4])
        q += 4
        out = {}
        for _ in range(count):
            (blen,) = struct.unpack("<I", data[q:q + 4])
            q += 4
            key, _, val = data[q:q + blen].decode("utf-8", "replace").partition("=")
            q += blen
            out[key.upper()] = val
        return out
    except (struct.error, IndexError):
        return {}


def read_id3_tags(data: bytes) -> dict:
    """ID3v2 text frames out of an MP3. {} when there is none."""
    if data[:3] != b"ID3":
        return {}
    size = 0
    for byte in data[6:10]:
        size = (size << 7) | (byte & 0x7F)
    q, end, out = 10, 10 + size, {}
    while q + 10 <= end:
        fid = data[q:q + 4]
        if not fid.strip(b"\x00"):
            break
        fsize = int.from_bytes(data[q + 4:q + 8], "big")
        q += 10
        body = data[q:q + fsize]
        q += fsize
        if not body:
            continue
        enc, text = body[:1], body[1:]
        codec = "utf-16" if enc == b"\x01" else "utf-8" if enc == b"\x03" else "latin-1"
        out[fid.decode("latin-1")] = text.decode(codec, "replace").strip("\x00").strip()
    return out


def read_riff_tags(data: bytes) -> dict:
    """RIFF LIST/INFO chunk out of a WAV. {} when there is none -- which is the
    case for every WAV this repo ships, and the tool says so rather than
    pretending a WAV was checked as thoroughly as an Ogg."""
    i = data.find(b"LIST")
    if i < 0 or data[i + 8:i + 12] != b"INFO":
        return {}
    try:
        (size,) = struct.unpack("<I", data[i + 4:i + 8])
    except struct.error:
        return {}
    q, end, out = i + 12, min(len(data), i + 8 + size), {}
    while q + 8 <= end:
        cid = data[q:q + 4].decode("latin-1", "replace")
        (clen,) = struct.unpack("<I", data[q + 4:q + 8])
        out[cid] = data[q + 8:q + 8 + clen].decode("latin-1", "replace").strip("\x00").strip()
        q += 8 + clen + (clen & 1)
    return out


# The tag that names the rights holder, per container. Ogg says ARTIST, ID3 says
# TPE1, RIFF says IART. One concept, three spellings.
ARTIST_KEYS = ("ARTIST", "TPE1", "IART")
TITLE_KEYS = ("TITLE", "TIT2", "INAM")


def tags_for(path: Path) -> dict:
    data = path.read_bytes()
    for reader in (read_vorbis_tags, read_id3_tags, read_riff_tags):
        got = reader(data)
        if got:
            return got
    return {}


def first_of(tags: dict, keys) -> str:
    for k in keys:
        if tags.get(k):
            return tags[k]
    return ""


def names_file(text: str, filename: str) -> bool:
    """Is `filename` named in `text` at a word boundary? Substring alone would let
    `chop.ogg` be satisfied by a row for `bigchop.ogg`."""
    return re.search(r"(?:^|[\s\"'(\[])" + re.escape(filename) + r"(?:$|[\s\"')\].,;:])",
                     text, re.M) is not None


def listing_rows(text: str):
    """Filenames in the document's own listing convention: a line that OPENS with
    a filename ending in an audio extension, followed by whitespace or the line
    end.

    Two things this got wrong on its first run against the real file, both of
    which the DOC -> DISK ratio printed at the bottom is what caught:

      * splitting on a single space missed every filename that CONTAINS one --
        `Farm Frolics.ogg`, `Mission Plausible.ogg`, `Cute Loops - Summer
        Sun.mp3`. Three of nineteen, all of them music, i.e. the expensive ones.
        So the filename runs up to the extension and stops there, non-greedily.
      * a bare extension is not a filename. The line "The two .ogg cues carry
        Vorbis comments..." wraps so that `.ogg` opens a line, and rule D duly
        reported a missing file called `.ogg`. Hence the leading `[^\s.]`.

    And allowing spaces immediately opened the opposite hole: a prose line ending
    "...not of a pack. The three .wav" matched as one enormous filename, because
    nothing stopped the non-greedy run crossing a sentence. A filename's only dot
    is its extension's and it holds no sentence punctuation, so the body excludes
    `.,;:` -- which still admits `Cute Loops - Summer Sun.mp3`. Loosening the
    grammar and tightening it are the same edit made twice, in opposite
    directions, and only the ratio printed at the bottom showed either.

    The fixture then found the same hole a third time, smaller: a prose line
    opening "One .wav on disk is deliberately unnamed..." matched, because
    nothing required the extension to be ATTACHED to the name. So the character
    immediately before the extension must itself be a name character -- which
    still admits `Farm Frolics.ogg` (`s.ogg`) and rejects `One .wav`."""
    pattern = re.compile(
        r"^[ \t]*(?P<f>[^\s.,;:](?:[^\t.,;:]*[^\s.,;:])?(?:%s))(?=\s|$)"
        % "|".join(re.escape(e) for e in AUDIO_EXTS),
        re.I)
    found = []
    for lineno, line in enumerate(text.splitlines(), 1):
        m = pattern.match(line)
        if m:
            found.append((lineno, m.group("f")))
    return found


def heading_of(section: str) -> str:
    for line in section.splitlines():
        if line.strip():
            return line.strip()
    return "(no heading)"


def analyse(audio_dir: Path, licence: Path, root: Path, quiet: bool = False,
            report: bool = True):
    """The whole check, over a nominated tree rather than this repo's.

    Parameterised for one reason: `--self-test` below runs it against a fixture it
    builds in a temp directory, so the fixture that proved this checker can fail
    is KEPT and re-runnable rather than written once and deleted. Returns
    `(exit_code, findings, notes)` so the self-test can assert on the lists and
    not on a printed line.

    `quiet` drops the per-file table; `report` drops ALL output. They are not the
    same switch and conflating them is why the first --self-test printed the
    fixture's six findings into the middle of its own PASS lines, which reads
    like a checker failing over the real repo.
    """
    def emit(*parts):
        if report:
            print(*parts)
    # Locally shadow the module constants so the body reads the same whether it
    # is looking at this repo or at a fixture.
    AUDIO_DIR, LICENCE, ROOT = audio_dir, licence, root

    if not AUDIO_DIR.is_dir():
        emit("audio_license_check: COULD NOT RUN -- no %s" % AUDIO_DIR.relative_to(ROOT))
        return 2, [], []
    if not LICENCE.is_file():
        emit("audio_license_check: COULD NOT RUN -- no %s" % LICENCE.relative_to(ROOT))
        return 2, [], []

    # No `.replace("\r\n", "\n")` here, deliberately. One was written, and
    # mutating it away against a fixture converted to CRLF changed nothing at
    # all -- `read_text` opens in text mode, and universal newlines have already
    # done it. Deleting redundant code beats strengthening a fixture to lock in
    # a redundancy and call it coverage. The invariant holding this up is
    # `read_text`'s own contract, not anything in this file, so it is written
    # down here rather than left to be re-derived.
    text = LICENCE.read_text(encoding="utf-8", errors="replace")
    sections = SECTION_RULE.split(text)

    files = sorted((p for p in AUDIO_DIR.iterdir()
                    if p.is_file() and p.suffix.lower() in AUDIO_EXTS),
                   key=lambda p: p.name.lower())
    if not files:
        emit("audio_license_check: NOTE: nothing to check -- %s holds no audio file."
              % AUDIO_DIR.relative_to(ROOT))
        emit("      That is a clean result only if you expected none.")
        emit("NOT COVERED: see below.")
        return 0, [], []

    findings, notes = [], []

    # --- ambiguity guards, before any rule trusts a name -------------------
    for a in files:
        for b in files:
            if a is not b and a.name.lower().endswith(b.name.lower()):
                notes.append("AMBIGUOUS: %s ends with %s -- a listing row for the "
                             "longer name would satisfy a substring test for the "
                             "shorter. Rules below use a word-boundary match."
                             % (a.name, b.name))

    # --- which section names each file -------------------------------------
    where = {}
    for path in files:
        hits = [i for i, sec in enumerate(sections) if names_file(sec, path.name)]
        where[path.name] = hits
        if len(hits) > 1:
            findings.append(
                "FINDING: %s is named in %d sections (%s) -- the section it is "
                "licensed under is ambiguous.\n"
                "  fix: name it once, in the section whose terms actually apply; "
                "mention it elsewhere by role rather than by filename.\n"
                "  waive: none -- an ambiguous licence claim is the defect."
                % (path.name, len(hits), ", ".join(heading_of(sections[i])[:40] for i in hits)))

    tags = {p.name: tags_for(p) for p in files}
    artists = {n: first_of(t, ARTIST_KEYS) for n, t in tags.items()}
    tagged = {n: a for n, a in artists.items() if a}

    # --- rule C: every file on disk is named -------------------------------
    for path in files:
        if not where[path.name]:
            findings.append(
                "FINDING: %s/%s is on disk and named nowhere in License.txt.\n"
                "  fix: add a listing row under the section whose terms apply. If "
                "it came from a pack, name the pack and its licence; if it was made "
                "for this game, say so explicitly -- \"we do not know\" is not a "
                "licence. See the CUES WRITTEN FOR THIS GAME section for the shape.\n"
                "  waive: none -- delete the file instead."
                % (AUDIO_DIR.relative_to(ROOT).as_posix(), path.name))

    # --- rule D: every listing row is a file -------------------------------
    on_disk = {p.name for p in files}
    rows = listing_rows(text)
    for lineno, token in rows:
        if token not in on_disk:
            findings.append(
                "FINDING: %s:%d lists %s, which is not in %s.\n"
                "  fix: delete the row, or restore the file. A row for a file that "
                "is gone reads as a complete document and is not one.\n"
                "  waive: none."
                % (LICENCE.relative_to(ROOT).as_posix(), lineno, token,
                   AUDIO_DIR.relative_to(ROOT).as_posix()))

    # --- rule A: same embedded artist, same section -------------------------
    by_artist = {}
    for name, artist in tagged.items():
        by_artist.setdefault(artist, []).append(name)
    for artist, names in sorted(by_artist.items()):
        secs = {where[n][0] for n in names if where[n]}
        if len(secs) > 1:
            findings.append(
                "FINDING: %d file(s) carry the embedded credit \"%s\" but are listed "
                "in %d different sections: %s.\n"
                "  fix: one rights holder, one section. Move the odd file out, or if "
                "its section really is right, the embedded tag is wrong and the file "
                "should be re-tagged rather than the document bent around it.\n"
                "  waive: none -- this is the drift the check exists for."
                % (len(names), artist, len(secs),
                   "; ".join("%s -> %s" % (n, heading_of(sections[where[n][0]])[:44])
                             for n in sorted(names) if where[n])))

    # --- rule B: the credit appears somewhere -------------------------------
    lowered = text.lower()
    for name, artist in sorted(tagged.items()):
        missing = [t for t in re.split(r"[^A-Za-z0-9]+", artist)
                   if len(t) >= 3 and t.lower() not in lowered]
        if missing:
            findings.append(
                "FINDING: %s carries the embedded credit \"%s\" and License.txt "
                "never says %s.\n"
                "  fix: name the rights holder and their terms. A file that credits "
                "somebody the licence document has never heard of is the clearest "
                "sighting there is of an unlicensed asset.\n"
                "  waive: none."
                % (name, artist, " or ".join('"%s"' % t for t in missing)))

    # --- rule E: pack fingerprint in a made-here section (advisory) ---------
    for path in files:
        name = path.name
        if not where[name]:
            continue
        section = sections[where[name][0]]
        if not MADE_HERE.search(heading_of(section)):
            continue
        title = first_of(tags[name], TITLE_KEYS)
        gain = [k for k in tags[name] if k.startswith("MP3GAIN")]
        marks = []
        if title and NUMBERED_TITLE.match(title) and not artists[name]:
            marks.append("TITLE=%s (a numbered take out of a set)" % title)
        if gain:
            marks.append("%s (a batch gain-normalisation pass)" % ", ".join(sorted(gain)))
        if not marks:
            continue
        quoted = title and ("TITLE=%s" % title) in section
        if quoted:
            continue
        notes.append(
            "NOTE: %s is listed as made for this game and carries %s.\n"
            "      That is the usual fingerprint of a pack file. If it IS the "
            "project's own work, quote the tag verbatim (TITLE=%s) in that section "
            "with the explanation -- writing the suspicious tag down is what stops "
            "the question being re-opened, and is what waives this note."
            % (name, " and ".join(marks), title or "<none>"))

    # --- report -------------------------------------------------------------
    if not quiet:
        for path in files:
            secs = where[path.name]
            emit("  %-32s %-28s %s"
                  % (path.name,
                     (artists[path.name] or "(no embedded credit)")[:28],
                     heading_of(sections[secs[0]])[:44] if secs else "*** NAMED NOWHERE ***"))
    for note in notes:
        emit(note)
    for finding in findings:
        emit(finding)

    reachable = sum(1 for p in files if any(t == p.name for _, t in rows))
    emit("audio_license_check: %d audio file(s) in %s, %d with an embedded credit, "
          "%d section(s) in License.txt, %d listing row(s) reaching %d of %d file(s), "
          "%d note(s), %d finding(s)"
          % (len(files), AUDIO_DIR.relative_to(ROOT).as_posix(), len(tagged),
             len(sections), len(rows), reachable, len(files), len(notes), len(findings)))
    if reachable < len(files):
        emit("      %d file(s) are named in prose but not by a listing row -- the "
              "DOC -> DISK grammar sees less than the DISK -> DOC substring test does."
              % (len(files) - reachable))
    emit("NOT COVERED: this reads file metadata and one text document. It cannot "
          "tell whether a stated licence is TRUE -- a file listed under the CC0 "
          "heading that actually came from a paid pack reads clean, because nothing "
          "in the bytes disputes it. Untagged files (every .wav here) carry no "
          "provenance at all, so rules A and B are silent on them and only C and D "
          "apply. It covers assets/audio/ only, not assets/sprites/, which ships "
          "with no licence file of any kind. Nor does it compile anything -- only "
          "import_check.py and lint_project.gd do that, and neither is "
          "parallel-safe.")
    return (1 if findings else 0), findings, notes


# -- the fixture, KEPT -------------------------------------------------------
#
# `.claude/skills/house-static-checker` says write a fixture, watch it go red,
# then delete it. `rng_seed_check.py --self-test` and `group_leak_check.py
# --fixture` both keep theirs instead, and this keeps its for the same reason:
# the mutations recorded in the docstring are re-run after every edit to this
# file, and re-deriving the fixture each time is most of the cost of having
# written it. Deleted, the mutation block is prose.
#
# Nothing here is a real Ogg or MP3 stream. The readers above scan for a
# `\x03vorbis` block, an `ID3` header or a `LIST`/`INFO` chunk wherever it sits,
# so a synthetic blob exercises exactly the parsing path a real file does
# without vendoring binary test data into the repo.

def _ogg_with(tags) -> bytes:
    """Bytes carrying a Vorbis comment block, as `read_vorbis_tags` reads one."""
    body = b"\x03vorbis"
    vendor = b"self-test"
    body += struct.pack("<I", len(vendor)) + vendor
    body += struct.pack("<I", len(tags))
    for key, val in tags:
        entry = ("%s=%s" % (key, val)).encode("utf-8")
        body += struct.pack("<I", len(entry)) + entry
    return b"OggS\x00\x02" + body + b"\x00" * 8


def _wav_bare() -> bytes:
    """A WAV with no LIST/INFO chunk -- the shape every .wav in this repo has,
    and the reason rules A and B are silent on three of nineteen files."""
    return b"RIFF\x24\x00\x00\x00WAVEfmt " + b"\x10\x00\x00\x00" + b"\x01\x00\x02\x00" \
           + b"\x44\xac\x00\x00" + b"\x10\xb1\x02\x00\x04\x00\x10\x00data\x00\x00\x00\x00"


_FIXTURE_LICENCE = """\
\tFixture licence document

\t\t\t------------------------------

\tKenney portion -- created/distributed by Kenney (www.kenney.nl), CC0

\t  bigchop.ogg                 clean. A shorter file on disk is a SUFFIX of
\t                              this name and is listed nowhere -- RULE C, and
\t                              only a word-boundary match can see it.
\t  stranger.ogg                RULE B: credited to a party this document never names
\t  ghost.ogg                   RULE D: no such file on disk
\t  dual.wav                    listed here AND below -- ambiguity guard

\t\t\t------------------------------

\tCUES WRITTEN FOR THIS GAME -- not Kenney's, not CC0

\t  bong_001.ogg                RULE A: tagged Kenney but listed in this section
\t  plant-place.ogg             RULE E: pack fingerprint, tag NOT quoted here
\t  dual.wav                    the second sighting
%s
\tOne .wav on disk is deliberately unnamed anywhere here -- RULE C. Naming it
\teven in prose would satisfy the word-boundary test and silence the rule.

\t\t\t------------------------------

\tEnd of fixture.
"""

# Every finding the fixture must produce, as (rule, a substring that identifies
# it). Asserting on substrings rather than on a COUNT is deliberate: a count
# going from 6 to 6 while one rule fell silent and another double-fired is
# exactly the result a count cannot see.
_EXPECT = [
    ("ambiguity", "dual.wav is named in 2 sections"),
    ("C", "chop.ogg is on disk and named nowhere"),
    ("C", "orphan.wav is on disk and named nowhere"),
    ("D", "lists ghost.ogg, which is not in"),
    ("A", 'the embedded credit "Kenney" but are listed in 2 different sections'),
    ("B", 'stranger.ogg carries the embedded credit "Zorbat"'),
]
_EXPECT_NOTES = [
    ("suffix guard", "bigchop.ogg ends with chop.ogg"),
    ("E", "plant-place.ogg is listed as made for this game"),
]


def _build_fixture(root: Path, quote_the_tag: bool) -> tuple:
    audio = root / "assets" / "audio"
    audio.mkdir(parents=True, exist_ok=True)
    kenney = [("ARTIST", "Kenney"), ("COMMENT", "www.kenney.nl")]
    (audio / "bigchop.ogg").write_bytes(_ogg_with(kenney))
    (audio / "chop.ogg").write_bytes(_ogg_with(kenney))
    (audio / "bong_001.ogg").write_bytes(_ogg_with(kenney))
    (audio / "stranger.ogg").write_bytes(_ogg_with([("ARTIST", "Zorbat")]))
    (audio / "plant-place.ogg").write_bytes(
        _ogg_with([("TITLE", "place10"), ("MP3GAIN_UNDO", "+002,+002,N")]))
    (audio / "orphan.wav").write_bytes(_wav_bare())
    (audio / "dual.wav").write_bytes(_wav_bare())
    waiver = ("\n\tplant-place.ogg carries TITLE=place10 from our own take numbering.\n"
              if quote_the_tag else "")
    licence = audio / "License.txt"
    licence.write_text(_FIXTURE_LICENCE % waiver, encoding="utf-8")
    return audio, licence


def self_test() -> int:
    import tempfile

    bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        audio, licence = _build_fixture(root, quote_the_tag=False)
        code, findings, notes = analyse(audio, licence, root, quiet=True, report=False)
        blob, noteblob = "\n".join(findings), "\n".join(notes)

        for rule, needle in _EXPECT:
            ok = needle in blob
            bad += 0 if ok else 1
            print("  %-14s rule %-10s %s" % ("PASS" if ok else "FAIL", rule, needle))
        for rule, needle in _EXPECT_NOTES:
            ok = needle in noteblob
            bad += 0 if ok else 1
            print("  %-14s note %-10s %s" % ("PASS" if ok else "FAIL", rule, needle))

        exact = len(findings) == len(_EXPECT)
        bad += 0 if exact else 1
        print("  %-14s %d finding(s), expected exactly %d -- an EXTRA finding is a "
              "false positive and fails too"
              % ("PASS" if exact else "FAIL", len(findings), len(_EXPECT)))

        gates = code == 1
        bad += 0 if gates else 1
        print("  %-14s exit %d over the fixture, expected 1" % ("PASS" if gates else "FAIL", code))

    # The waiver half: quoting the tag inside the made-here section must drop the
    # rule E note and change nothing else. Without this the waiver is untested and
    # rule E could be unwaivable, i.e. a permanently-red advisory.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        audio, licence = _build_fixture(root, quote_the_tag=True)
        _, findings2, notes2 = analyse(audio, licence, root, quiet=True, report=False)
        waived = not any("listed as made for this game" in n for n in notes2)
        same = len(findings2) == len(_EXPECT)
        bad += 0 if waived else 1
        bad += 0 if same else 1
        print("  %-14s rule E waived by quoting TITLE=place10 in its section"
              % ("PASS" if waived else "FAIL"))
        print("  %-14s waiving E left the %d finding(s) alone (got %d)"
              % ("PASS" if same else "FAIL", len(_EXPECT), len(findings2)))

    total = len(_EXPECT) + len(_EXPECT_NOTES) + 4
    print("audio_license_check --self-test: %d of %d case(s) passed." % (total - bad, total))
    print("NOT COVERED: the fixture is synthetic. It proves the RULES fire and the "
          "waiver works; it does not prove the tag readers cope with a real "
          "container's framing, because it hands them a hand-built comment block "
          "rather than a genuine Ogg page or ID3 frame. Run without --self-test to "
          "exercise those against the shipped files.")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--quiet", action="store_true", help="findings and totals only")
    ap.add_argument("--self-test", action="store_true",
                    help="run the kept fixture and assert every rule fires")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    return analyse(AUDIO_DIR, LICENCE, ROOT, args.quiet)[0]


if __name__ == "__main__":
    sys.exit(main())
