"""Exercise timestamp parsing and error handling without changing host services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MonitorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.env = dict(os.environ, TZ="UTC", PATH=f"{self.path}:{os.environ['PATH']}")
        self.env['MONITOR_SYSLOG_FILE'] = str(self.path / 'syslog')
        self.stub('date', 'echo 1767226500')  # 2026-01-01 00:15:00 UTC
        self.stub('systemctl', 'echo active; exit 0')
        self.stub('journalctl', 'echo "last journal entry"; exit 0')
        (self.path / 'syslog').write_text('')

    def stub(self, name, body):
        file = self.path / name
        file.write_text(f'#!/usr/bin/env bash\n{body}\n')
        file.chmod(0o755)

    def run_monitor(self, *args):
        return subprocess.run([str(ROOT / 'scripts/monitor.sh'), *args], env=self.env,
                              capture_output=True, text=True, check=False)

    def test_usage_and_invalid_service(self):
        for args in [(), ('docker', 'extra'), ('docker;echo',), ('--help',)]:
            with self.subTest(args=args):
                result = self.run_monitor(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn('Usage:', result.stderr)

    def test_no_errors(self):
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('last hour: 0', result.stdout)

    def test_rfc3164_new_year_and_time_window(self):
        (self.path / 'syslog').write_text(
            'Dec 31 22:00:00 host app: ERROR old\n'
            'Dec 31 23:45:00 host app: failed recent\n'
            'Jan  1 00:15:00 host app: error now\n'
            'Jan  1 00:16:00 host app: error future\n'
            'Jan  1 00:10:00 host app: no errors detected\n')
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('last hour: 2', result.stdout)

    def test_rfc3339_offsets_and_fractional_seconds(self):
        (self.path / 'syslog').write_text(
            '2026-01-01T03:00:00.123+03:00 host app: ERROR recent\n'
            '2025-12-31T19:05:00-05:00 host app: fatal recent\n'
            '2026-01-01T00:10:00Z host app: failure recent\n'
            '2025-12-31T20:00:00Z host app: error old\n')
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('last hour: 3', result.stdout)

    def test_inactive_shows_journal(self):
        self.stub('systemctl', 'echo inactive; exit 3')
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 1)
        self.assertIn('last journal entry', result.stdout)

    def test_systemd_unavailable(self):
        self.stub('systemctl', 'echo "Cannot connect to bus" >&2; exit 1')
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 2)
        self.assertIn('Cannot query systemd', result.stderr)

    def test_unknown_service(self):
        self.stub('systemctl', 'echo unknown; exit 4')
        result = self.run_monitor('missing.service')
        self.assertEqual(result.returncode, 1)
        self.assertIn('unknown', result.stdout)

    def test_journal_failure(self):
        self.stub('systemctl', 'echo inactive; exit 3')
        self.stub('journalctl', 'echo "Permission denied" >&2; exit 1')
        self.assertEqual(self.run_monitor('docker').returncode, 2)

    def test_no_syslog_falls_back_to_journal(self):
        (self.path / 'syslog').unlink()
        self.stub('journalctl', 'printf "2026-01-01 error\\n2026-01-01 normal\\n"')
        result = self.run_monitor('docker')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('journald during the last hour: 1', result.stdout)

    def test_journal_unavailable_is_not_zero_errors(self):
        (self.path / 'syslog').unlink()
        self.stub('journalctl', 'echo "No journal files were found."; exit 0')
        self.assertEqual(self.run_monitor('docker').returncode, 2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
