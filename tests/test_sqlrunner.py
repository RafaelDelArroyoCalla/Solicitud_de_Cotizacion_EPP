import os, re, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
from sqlrunner import split_script

SQL = os.path.join(os.path.dirname(__file__), "..", "sql", "sistema_cotizaciones_completo.sql")


class SplitTests(unittest.TestCase):
    def test_basico(self):
        s = split_script("SELECT 1; -- c\nSELECT 'a;b'; /* x; */ SELECT \"q;\";")
        self.assertEqual(s, ["SELECT 1", "SELECT 'a;b'", 'SELECT "q;"'])

    def test_delimiter(self):
        s = split_script("DELIMITER $$\nCREATE PROCEDURE p() BEGIN SELECT 1; SELECT 2; END$$\nDELIMITER ;\nSELECT 3;")
        self.assertEqual(len(s), 2)
        self.assertTrue(s[0].startswith("CREATE PROCEDURE") and s[0].endswith("END"))
        self.assertEqual(s[1], "SELECT 3")

    def test_comilla_escapada(self):
        self.assertEqual(split_script("INSERT INTO t VALUES ('it''s;ok');"), ["INSERT INTO t VALUES ('it''s;ok')"])

    def test_script_real(self):
        text = open(SQL, encoding="utf-8").read()
        st = split_script(text)
        count = lambda pat: sum(1 for x in st if re.match(pat, x, re.I))
        self.assertEqual(count(r"CREATE PROCEDURE"), len(re.findall(r"^CREATE PROCEDURE", text, re.M)))
        self.assertEqual(count(r"CREATE TRIGGER"), len(re.findall(r"^CREATE TRIGGER", text, re.M)))
        self.assertEqual(count(r"CREATE FUNCTION"), 2)
        self.assertEqual(count(r"INSERT INTO"), 7)
        self.assertEqual(count(r"CREATE TABLE"), 8)
        self.assertTrue(all("DELIMITER" not in x.upper().split()[:1] for x in st))
        print("sentencias:", len(st), "procs:", count(r"CREATE PROCEDURE"), "triggers:", count(r"CREATE TRIGGER"))

if __name__ == "__main__":
    unittest.main()
