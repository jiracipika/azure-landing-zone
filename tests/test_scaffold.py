from pathlib import Path
import re
import unittest

root = Path(__file__).resolve().parents[1]


class Tests(unittest.TestCase):
    def test_agent_docs(self):
        self.assertTrue((root / "AGENTS.md").exists())
        self.assertTrue((root / "docs/GLM_TASKS.md").exists())

    def test_safety_gate(self):
        self.assertRegex(
            (root / "infra/terraform/variables.tf").read_text(),
            r'"deploy_enabled"\s*\{[^}]*default\s*=\s*false',
        )
        self.assertNotIn("terraform apply", (root / ".github/workflows/validate.yml").read_text())

    def test_offline_status_output(self):
        self.assertIn("offline-scaffold-only", (root / "infra/terraform/outputs.tf").read_text())

    def test_diagram_exists(self):
        self.assertIn("flowchart", (root / "diagrams/architecture.mmd").read_text())


if __name__ == "__main__":
    unittest.main()
