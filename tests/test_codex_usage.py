import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "scripts" / "codex_usage.py"
spec = importlib.util.spec_from_file_location("codex_usage", MODULE_PATH)
codex_usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(codex_usage)


class CodexUsageTests(unittest.TestCase):
    def test_weekly_limit_is_rendered_as_custom_waybar_json(self):
        result = {
            "rateLimits": {
                "primary": {
                    "usedPercent": 37,
                    "windowDurationMins": 10080,
                    "resetsAt": 1785323947,
                },
                "planType": "pro",
            }
        }

        payload = codex_usage.make_waybar_payload(result, now=1785000000)

        self.assertEqual(payload["text"], "󰚩 W 37%")
        self.assertEqual(payload["class"], "normal")
        self.assertIn("Weekly usage: 37%", payload["tooltip"])
        self.assertIn("Plan: pro", payload["tooltip"])

    def test_high_weekly_usage_is_warning(self):
        result = {"rateLimits": {"primary": {"usedPercent": 85, "windowDurationMins": 10080}}}

        payload = codex_usage.make_waybar_payload(result, now=0)

        self.assertEqual(payload["class"], "warning")

    def test_exhausted_weekly_usage_is_critical(self):
        result = {"rateLimits": {"primary": {"usedPercent": 100, "windowDurationMins": 10080}}}

        payload = codex_usage.make_waybar_payload(result, now=0)

        self.assertEqual(payload["class"], "critical")

    def test_non_weekly_limit_is_rejected(self):
        result = {"rateLimits": {"primary": {"usedPercent": 1, "windowDurationMins": 300}}}

        with self.assertRaisesRegex(ValueError, "weekly"):
            codex_usage.make_waybar_payload(result, now=0)


if __name__ == "__main__":
    unittest.main()
