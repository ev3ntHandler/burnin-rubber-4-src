#!/usr/bin/env python3
"""Structural checker for Director Lingo source -- ``Bridge/Director/*.ls`` and the movie's own scripts.

Director has no headless mode and no CLI, so a Lingo file cannot be "run" to see whether it is
well-formed the way a Python module can. This checks the things a missing ``end if`` or a call to a
handler that does not exist would break, and nothing else: Lingo is whitespace-insensitive and its
block structure is carried entirely by keywords, so those are mechanical to verify, and they are
also the mistakes that cost the most time to find inside a running movie.

Checks, in the order they can bite you:

1. ``on``/``end`` pairing, per handler, and no handler defined twice in one movie (Director's
   "more than one handler named X in the movie" error is a load-time failure).
2. ``if``/``end if``, ``repeat``/``end repeat``, ``case``/``end case`` balance -- inline
   ``if x then return 1`` is recognised as not opening a block. And the two shapes that *look*
   balanced but are not Lingo: a ``switch``/``endswitch`` pair (Director has no switch statement,
   so ``switch x`` / ``case "a":`` / ``endswitch`` never compiles -- it has to be
   ``case x of`` / ``"a":`` / ``end case``), and a branch that repeats the keyword inside a real
   ``case … of``, which is the ActionScript tell. ``otherwise`` without its colon joins them.
3. Balanced parentheses and brackets, and properly closed strings: Lingo uses doubled quotes
   inside strings and does not treat backslashes as escapes. Also flag the invalid comma-separated
   ``the chars of text, start, end`` form; character slices use chunk expressions.
4. Every called ``Name(...)`` resolves to a handler defined in one of the files given, to a known
   Lingo/SpriteLingo builtin, or to a member access (``x.y(...)`` is not a handler call). Handler
   names defined twice across scripts are tolerated when they are Lingo *events* (``enterFrame`` and
   friends), because every script may implement an event; a custom handler defined twice is not.
5. Comment dialect: ``--`` only. ``//`` is JavaScript, and Director reads it as code.

    python3 lint_lingo.py Bridge/Director       # the bridge's modules; the game's handler names
                                                # are in scope automatically, from either position
    python3 lint_lingo.py . --report Bridge/Director   # whole repo, only the bridge's problems count
    python3 lint_lingo.py "Director Movie File (.dcr)" --no-calls   # the game's own 155 scripts

`--movie DIR` supplies a different folder of scripts to take definitions from, `--no-movie` refuses
any, and `--report PREFIX` restricts *reporting* (not name resolution) to files under a prefix.

Exits non-zero when anything is wrong. ``--no-calls`` skips check 4, which is the only one that
reports against a partial file set: the movie's own scripts call handlers that live in the .dir
binary, so the "undefined" list is advisory there.
"""

from __future__ import annotations

import re
import sys
from typing import Dict, List, Tuple

HANDLER = re.compile(r"^\s*(on|function)\s+([A-Za-z_][\w]*)", re.M)
CALL = re.compile(r"(?<![.\w])([A-Za-z_]\w*)\s*\(")
BLOCKS = [
    (re.compile(r"^\s*if\b", re.I), "if"),
    (re.compile(r"^\s*else\s+if\b", re.I), "if"),
    (re.compile(r"^\s*repeat\b", re.I), "repeat"),
    (re.compile(r"^\s*case\b.*\bof\s*$", re.I), "case"),
    (re.compile(r"^\s*tell\b", re.I), "tell"),
    (re.compile(r"^\s*try\b", re.I), "try"),
]
# Two mistakes that a *balanced* file can still contain, both of them the result of writing Lingo
# like another language, and both of them Director's compiler refusing:
#   `switch x` / `case "a":` / `endswitch`   -- ActionScript. Lingo has no switch statement.
#   `case "a":` inside a real `case x of`    -- a branch does not repeat the keyword.
NOT_LINGO = re.compile(r"^\s*(?:(?:switch|end\s*switch)\b|default\s*:)", re.I)
CASE_LABEL = re.compile(r"^\s*case\b\s+.*:\s*$", re.I)
OTHERWISE = re.compile(r"^\s*otherwise\s*$", re.I)
BAD_CHAR_SLICE = re.compile(r"\bthe\s+chars\s+of\s+[A-Za-z_]\w*\s*,", re.I)

CLOSERS = {
    "if": re.compile(r"^\s*end if\b", re.I),
    "repeat": re.compile(r"^\s*end repeat\b", re.I),
    "case": re.compile(r"^\s*end case\b", re.I),
    "tell": re.compile(r"^\s*end tell\b", re.I),
    "try": re.compile(r"^\s*end try\b", re.I),
}
INLINE = re.compile(r"\bthen\b\s+\S", re.I)  # `if x then return 1` closes itself


# Everything below is either stock Lingo, an xtra the game already registers, or a name the .dir
# binary itself provides. It is a deny-list for "is this call ours to define", not a language model.
# Lingo's own event and lifecycle handlers. Every script in a movie may implement these, so two
# scripts sharing `enterFrame` is not Director's "more than one handler named X" load-time failure --
# only a shared *custom* handler name is. The bridge therefore legitimately owns one of these names.
EVENT_NAMES = {
    name.lower()
    for name in """
    prepareFrame enterFrame exitFrame keyDown keyUp keypress mousedown mouseup mouseDown mouseUp
    mouseWithin mouseEnter mouseLeave mouseUpInWorld animate getAnimationFrame puppetDraw timeout
    collide collided enterWorld exitWorld withinWorld beginTransition doneTransition movieStart
    movieStop moviePause pause resume getPreLoadFrame spriteRangeBound executeLandmark prepareStage
    onMessage idle
    """.split()
}

BUILTINS = set(
    """
    put get set value voidp string symbol integer number charToNum numToChar paramCount
    the alert beep cancel click closeWindow copyToClipBoard createMember deleteMember describe
    do dragMovie duplicate enableMenuItem exportFile find fontNames forward goto gotoNetMovie
    gotoNetPage hatch fill hover image importFileInto irInterpolate launchURL line locV locH
    makeNewPath max member min movieCount netDone netError netTextResult newMember numToChar
    open openURL pause play playDonePoint random rect region round runPath script seek setProp
    the timer startApp stop stopMovie system beep tan the timer trace urlEncode value vector
    waitForRedraw within the platform the moviePath the milliSeconds the itemDelimiter the
    lineDelimiter the trim of the number of the chars of getProp setPropLocally getPropAt
    propNames addProp deleteProp sortList repeat while until exit return if else then case
    otherwise for each in to down by not and or xor mod with doAnimation
    fileOpen fileClose fileWrite fileLength filePosition fileRead fileExists
    getNthFileNameInFolder registeredXtras xtra externalParamValue externalParamName
    getStreamStatus netTextDone netTextResult newNetText getNetText netAbort sendAllSprites sendSprite postMovieEvent
    the URL windowOffset desktopRectList machineType platformType sound volume the sound
    mouseLoc mouseLocR mouseChar mouseLine the clickLoc the mouse
    """.split()
)
KEYWORDS = set(
    """on end if then else repeat while until case switch tell try return exit global property
    local script member sprite movie rect point vector color list propList string symbol integer
    float void true false and or not mod div to down by with each for function me super of the
    """.split()
)


def strip_comments(line: str) -> Tuple[str, List[str]]:
    """Return (code, comment-dialect problems). Lingo comments are ``--`` outside a string."""
    out: List[str] = []
    problems: List[str] = []
    i = 0
    in_string = False
    while i < len(line):
        ch = line[i]
        if in_string:
            if ch == '"' and i + 1 < len(line) and line[i + 1] == '"':
                out.extend(('"', '"'))
                i += 2
                continue
            if ch == '"':
                in_string = False
            out.append(ch)
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if line.startswith("--", i):
            break
        if line.startswith("//", i):
            problems.append("`//` is not a Lingo comment (use `--`): " + line.strip()[:70])
            break
        out.append(ch)
        i += 1
    if in_string:
        problems.append("unterminated string: " + line.strip()[:70])
    return "".join(out), problems


def blank_strings(line: str) -> str:
    """The same line with every string literal's contents replaced by spaces.

    `"["` is a bracket *inside* a string, and `member("x").y` is a call *inside* a string: both
    matter for reading Lingo and neither matters for checking its structure.
    """
    out: List[str] = []
    in_string = False
    for ch in line:
        if in_string:
            if ch == '"':
                in_string = False
                out.append(ch)
            else:
                out.append(" ")
            continue
        if ch == '"':
            in_string = True
        out.append(ch)
    return "".join(out)


def balance(line: str) -> List[str]:
    problems = []
    for open_ch, close_ch, name in (("[", "]", "bracket"), ("(", ")", "paren")):
        depth = 0
        for ch in line:
            if ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
                if depth < 0:
                    problems.append("unbalanced %s: %s" % (name, line.strip()[:70]))
                    break
        if depth > 0:
            problems.append("unclosed %s: %s" % (name, line.strip()[:70]))
    return problems


def analyse(path: str, source: str) -> Tuple[List[str], Dict[str, int], List[str]]:
    """-> (problems, handlers defined, handler names)."""
    problems: List[str] = []
    defined: Dict[str, int] = {}
    lines = source.split("\n")
    stack: List[Tuple[str, int]] = []
    depth_open = 0
    for number, raw in enumerate(lines, 1):
        code, comment_problems = strip_comments(raw)
        problems += ["%s:%d: %s" % (path, number, text) for text in comment_problems]
        problems += ["%s:%d: %s" % (path, number, text) for text in balance(blank_strings(code))]
        stripped = blank_strings(code).strip()
        if not stripped:
            continue
        if BAD_CHAR_SLICE.search(stripped):
            problems.append("%s:%d: `the chars of text, start, end` is not a Lingo chunk expression"
                            " -- use `char start to end of text`" % (path, number))
        if NOT_LINGO.match(stripped):
            problems.append(
                "%s:%d: `%s` is not Lingo -- Director has no switch statement; write"
                " `case <expr> of` ... `end case`" % (path, number, stripped.split()[0])
            )
        case_depth = sum(1 for name, _line in stack if name == "case")
        if case_depth and CASE_LABEL.match(stripped):
            problems.append(
                "%s:%d: a `case <expr> of` branch is a bare `label:`, not `case \"label\":`"
                " -- %s" % (path, number, raw.strip()[:50])
            )
        if case_depth and OTHERWISE.match(stripped):
            problems.append("%s:%d: `otherwise` wants a colon: `otherwise:`" % (path, number))
        handler = re.match(r"^(on|function)\s+([A-Za-z_]\w*)", stripped)
        if handler:
            name = handler.group(2)
            if name in defined:
                problems.append("%s:%d: handler `%s` is already defined on line %d" % (path, number, name, defined[name]))
            defined[name] = number
            depth_open += 1
            continue
        if re.match(r"^end\s*$", stripped):
            depth_open -= 1
            if depth_open < 0:
                problems.append("%s:%d: `end` with no open handler" % (path, number))
                depth_open = 0
            continue
        if depth_open <= 0:
            if re.match(r"^(global|property|import)\b", stripped) or stripped.startswith("--"):
                continue
            problems.append("%s:%d: statement outside any handler: %s" % (path, number, stripped[:60]))
            continue
        for pattern, name in BLOCKS:
            if pattern.match(stripped):
                if name == "if" and INLINE.search(stripped) and not stripped.lower().endswith("then"):
                    continue  # a one-line if: no block, so nothing to end
                stack.append((name, number))
                break
        for name, pattern in CLOSERS.items():
            if pattern.match(stripped):
                if stack and stack[-1][0] == name:
                    stack.pop()
                    break
                index = len(stack) - 1
                while index >= 0 and stack[index][0] != name:
                    index -= 1
                if index < 0:
                    problems.append("%s:%d: `end %s` with no open %s" % (path, number, name, name))
                else:
                    problems.append("%s:%d: `end %s` closes a %s opened at line %d (innermost open is %s from line %d)"
                                    % (path, number, name, name, stack[index][1], stack[-1][0], stack[-1][1]))
                    del stack[index:]
                break
    for name, number in stack:
        problems.append("%s:%d: `%s` block is never closed" % (path, number, name))
    if depth_open != 0:
        problems.append("%s: %d handler(s) never ended" % (path, depth_open))
    return problems, defined, list(defined)


def main(argv: List[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    no_calls = "--no-calls" in argv
    use_movie = "--no-movie" not in argv
    if not args:
        print(__doc__)
        return 2
    import os

    # `--movie DIR` (repeatable) adds a folder whose handler *names* are known without being checked;
    # `--report PREFIX` counts problems only for files under it. Both exist for the same reason: the
    # bridge calls handlers that live in the movie (`PutMessage`, `LogMessage`, `event`), so a check of
    # the bridge's files alone would report the movie's API as missing. Scope is therefore not the cwd's
    # business -- the game's own scripts are found next to *this* file, so the tool works from anywhere.
    here = os.path.dirname(os.path.abspath(__file__))
    movie_dirs: List[str] = []
    report_only = ""
    index = 0
    while index < len(argv):
        item = argv[index]
        if item == "--movie" and index + 1 < len(argv):
            movie_dirs.append(argv[index + 1])
            index += 1
        elif item.startswith("--movie="):
            movie_dirs.append(item.split("=", 1)[1])
        elif item == "--report" and index + 1 < len(argv):
            report_only = argv[index + 1]
            index += 1
        elif item.startswith("--report="):
            report_only = item.split("=", 1)[1]
        index += 1
    args = [a for a in args if a not in movie_dirs and a != report_only]
    if not movie_dirs and use_movie:
        default = os.path.normpath(os.path.join(here, "..", "..", "Director Movie File (.dcr)"))
        if os.path.isdir(default):
            movie_dirs = [default]

    def ours(path: str) -> bool:
        if not report_only:
            return True
        return os.path.abspath(path).startswith(os.path.abspath(report_only))

    files: List[str] = []
    for entry in args:
        if os.path.isdir(entry):
            for root, _dirs, names in os.walk(entry):
                files += [os.path.join(root, n) for n in sorted(names) if n.endswith(".ls") or n.endswith(".dir.txt")]
        else:
            files.append(entry)

    all_defined: Dict[str, str] = {}
    # files whose handler names are context only: known to exist, never judged here
    movie_files: set = set()
    if use_movie:
        import glob
        for movie_dir in movie_dirs:
            for extra in sorted(glob.glob(os.path.join(movie_dir, "*.ls"))):
                movie_files.add(extra)
                try:
                    with open(extra, "r", encoding="utf-8", errors="replace") as handle:
                        for found in HANDLER.finditer(handle.read()):
                            all_defined.setdefault(found.group(2), extra)
                except OSError:
                    pass
    problems: List[str] = []
    per_file: Dict[str, List[str]] = {}
    for path in files:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            source = handle.read()
        found, defined, _names = analyse(path, source)
        if ours(path):
            problems += found
        per_file[path] = list(defined)
        for name in defined:
            first = all_defined.setdefault(name, path)
            # Director refuses to load a movie that has two custom handlers of one name, and the
            # bridge is about to add 137 global names to a movie that already has ~759 -- which is
            # the collision worth catching before the editor says so. Events are exempt: every
            # script may implement one (see EVENT_NAMES).
            if first != path and name.lower() not in EVENT_NAMES and ours(path):
                problems.append(
                    "%s: handler `%s` is also defined in %s -- Director will not load a movie with two"
                    " custom handlers of one name" % (path, name, first)
                )

    calls: Dict[str, int] = {}
    if not no_calls:
        for path in files:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                for number, raw in enumerate(handle.read().split("\n"), 1):
                    code, _ = strip_comments(raw)
                    for match in CALL.finditer(blank_strings(code)):
                        name = match.group(1)
                        if name.lower() in KEYWORDS or name in BUILTINS or name in all_defined:
                            continue
                        if not ours(path):
                            continue
                        calls.setdefault(name, 0)
                        calls[name] += 1
                        problems.append("%s:%d: call to undefined handler `%s`" % (path, number, name))

    for text in problems:
        print("LINGO " + text)
    print("---")
    external = {name for name, where in all_defined.items() if where in movie_files and os.path.abspath(where) not in {os.path.abspath(f) for f in files}}
    known = "%d handler name(s) known" % len(all_defined)
    if external:
        known += " (%d of them from %s, whose own problems are not counted here)" % (
            len(external),
            ", ".join(os.path.basename(d.rstrip(os.sep)) for d in movie_dirs),
        )
    print("%d file(s) checked, %s%s" % (len(files), known, ", %d unresolved call(s)" % len(calls) if calls else ""))
    if not problems:
        print("structure ok")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
