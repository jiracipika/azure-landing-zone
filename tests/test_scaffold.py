import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
class TestSafety(unittest.TestCase):
    def test_agent_handoff(self):
        self.assertTrue((R/"AGENTS.md").is_file())
        self.assertTrue((R/"docs/GLM_TASKS.md").is_file())
    def test_no_live_apply(self):
        s=(R/".github/workflows/validate.yml").read_text()
        self.assertNotIn("terraform apply",s)
        self.assertNotIn("id-token: write",s)
    def test_offline_root(self):
        self.assertIn("default = false",(R/"infra/terraform/variables.tf").read_text())
    def test_diagram(self):
        self.assertIn("flowchart",(R/"diagrams/architecture.mmd").read_text())
