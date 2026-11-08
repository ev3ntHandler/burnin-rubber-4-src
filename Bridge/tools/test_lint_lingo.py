#!/usr/bin/env python3
"""Regression tests for the static Lingo checks (not a Director compiler)."""
import re
import unittest
from pathlib import Path

from lint_lingo import analyse, blank_strings, strip_comments


def missing_bridge_globals(source):
    """Check the bridge's gName naming convention against its script-level declarations.

    This deliberately checks bridge scripts, not arbitrary Lingo: another project could use
    local variables with a g prefix. Ignore comments, strings, properties and symbols.
    """
    declared = set()
    used = set()
    in_handler = False
    for line in source.splitlines():
        code = blank_strings(strip_comments(line)[0]).strip()
        if re.match(r'^(?:on|function)\b', code, re.I):
            in_handler = True
        elif re.match(r'^end\s*$', code, re.I):
            in_handler = False
        if not in_handler and re.match(r'^global\b', code, re.I):
            declared.update(name.lower() for name in re.findall(r'\bg[A-Z]\w*\b', code))
        else:
            used.update(name.lower() for name in re.findall(r'(?<![\w.#])g[A-Z]\w*\b', code))
    return used - declared


class LingoLintTests(unittest.TestCase):
    def problems(self, body):
        return analyse('test.ls', 'on example me\n' + body + '\nend\n')[0]

    def test_case_with_nested_if_and_multiple_labels(self):
        self.assertEqual([], self.problems('''case tVerb of
    "SNAP", "DELTA":
        if tReady then
            exit
        end if
    otherwise:
        return 0
end case'''))

    def test_rejects_foreign_switch(self):
        problems = self.problems('switch tVerb\n    case "SNAP":\n        exit\n    default:\n        exit\nendswitch')
        self.assertEqual(3, sum('is not Lingo' in p for p in problems))

    def test_rejects_repeated_case_and_colonless_otherwise(self):
        problems = self.problems('case tVerb of\n    case "SNAP":\n        exit\n    otherwise\n        exit\nend case')
        self.assertTrue(any('bare `label:`' in p for p in problems))
        self.assertTrue(any('wants a colon' in p for p in problems))

    def test_bad_substring_and_valid_chunk(self):
        self.assertTrue(any('not a Lingo chunk' in p for p in self.problems('return the chars of tText, 1, 3')))
        self.assertEqual([], self.problems('return char tFrom to tTo of tText'))
        self.assertEqual([], self.problems('return "the chars of tText, 1, 3"'))

    def test_inline_conditional_expressions(self):
        bad = [
            'tPath = BridgeRequest(0, "sub", [tPath, voidp(tRate) = 1 then 0 else tRate], VOID, VOID)',
            'return BridgeRequest(0, "snap", [string(voidp(tRate) = 1 then 0 else tRate)], VOID, VOID)',
            'if tReady then put 1 else put 0',
        ]
        for line in bad:
            with self.subTest(line=line):
                self.assertTrue(any('inline' in p for p in self.problems(line)))
        self.assertEqual([], self.problems('''if voidp(tRate) = 1 then
    tRate = 0
else
    tRate = tRate + 1
end if
return tRate'''))
        self.assertEqual([], self.problems('put "then else" -- then else'))
        self.assertEqual([], self.problems('if tReady then return 1'))

    def test_string_prefix_operator(self):
        for operator in ('begins with', 'starts with'):
            with self.subTest(operator=operator):
                problems = self.problems('if _movie.movieURL ' + operator + ' "http" then\n    exit\nend if')
                self.assertTrue(any("use Lingo's `starts` operator" in p for p in problems))
        self.assertEqual([], self.problems('if _movie.movieURL starts "http" then\n    exit\nend if'))
        self.assertEqual([], self.problems('put "begins with" -- begins with'))

    def test_bridge_globals_declared(self):
        fixture = '''global gGame
on example me
    put gGame
    put gSound
    put gGame.gProperty
    put #gSymbol
    put "gString" -- gComment
end'''
        self.assertEqual({'gsound'}, missing_bridge_globals(fixture))
        self.assertEqual(set(), missing_bridge_globals(fixture.replace('global gGame', 'global gGame, gSound')))
        director = Path(__file__).resolve().parent.parent / 'Director'
        scripts = sorted(director.glob('*.ls'))
        self.assertEqual(3, len(scripts))
        for script in scripts:
            with self.subTest(script=script.name):
                self.assertEqual(set(), missing_bridge_globals(script.read_text(encoding='utf-8')))

    def test_director_file_transport_uses_protocol_marker_paths(self):
        # Structural regression only; BridgeMarkerPath must also be checked in Director itself.
        source = (Path(__file__).resolve().parent.parent / 'Director' /
                  '[M] Shockwave Bridge Transport.ls').read_text(encoding='utf-8')
        helper = re.search(r'(?ms)^on BridgeMarkerPath\b.*?^end\s*$', source).group()
        self.assertIn('BridgeChars(0, tPath, tPath.length - 3, tPath.length) = ".txt"', helper)
        self.assertIn('BridgeChars(0, tPath, 1, tPath.length - 4) & ".seq"', helper)
        for handler in ('BridgeFilesWrite', 'BridgeFilesPoll'):
            body = re.search(r'(?ms)^on ' + handler + r'\b.*?^end\s*$', source).group()
            self.assertIn('tMarker = BridgeMarkerPath(0, tPayload)', body)
            self.assertNotIn('tPayload & ".seq"', body)

    def test_backslash_is_not_an_escape(self):
        code, problems = strip_comments('tSep = "\\" -- a path separator')
        self.assertEqual([], problems)
        self.assertEqual('tSep = "\\" ', code)
        self.assertEqual([], self.problems('tSep = "\\"'))

    def test_doubled_quotes_and_comments(self):
        self.assertEqual([], self.problems('put "hello ""world"" -- not a comment"'))
        self.assertTrue(self.problems('put "unterminated'))


if __name__ == '__main__':
    unittest.main()
