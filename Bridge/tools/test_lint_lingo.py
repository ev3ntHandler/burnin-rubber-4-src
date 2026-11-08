#!/usr/bin/env python3
"""Regression tests for the static Lingo checks (not a Director compiler)."""
import unittest

from lint_lingo import analyse, strip_comments


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
