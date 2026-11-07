import fs from "node:fs";
import path from "node:path";
import os from "node:os";

export interface WorkerSandboxEnv {
  workerId: string;
  relAppDataDir: string;
  absAppDataDir: string;
  jailCwd: string;
}

const AUTH_FILES_TO_CLONE = [
  "jetski_state.pbtxt",
  "settings.json",
  "installation_id",
];

/**
 * Creates an isolated runtime environment for an `agy acp` worker process:
 * 1. `~/.gemini/agy2api-worker-{id}` with cloned OAuth credentials (`jetski_state.pbtxt`)
 *    so each worker has its own isolated SQLite DB (`conversation_summaries.db`) and logs.
 * 2. An empty read-only temporary directory (`jailCwd`) used as `cwd` for `session/new`.
 */
export function createWorkerSandbox(workerId: string): WorkerSandboxEnv {
  const geminiBaseDir = path.join(os.homedir(), ".gemini");
  const primaryCliDir = path.join(geminiBaseDir, "antigravity-cli");

  const relAppDataDir = `agy2api-worker-${workerId}`;
  const absAppDataDir = path.join(geminiBaseDir, relAppDataDir);
  fs.mkdirSync(absAppDataDir, { recursive: true });

  // Clone lightweight auth & config files from primary antigravity-cli dir
  for (const fileName of AUTH_FILES_TO_CLONE) {
    const srcPath = path.join(primaryCliDir, fileName);
    const destPath = path.join(absAppDataDir, fileName);
    if (fs.existsSync(srcPath)) {
      try {
        fs.copyFileSync(srcPath, destPath);
      } catch {
        // Ignore if file is transiently locked
      }
    }
  }

  // Create empty read-only jail directory for `session/new` cwd
  const jailCwd = fs.mkdtempSync(path.join(os.tmpdir(), `agy2api-jail-${workerId}-`));
  try {
    fs.chmodSync(jailCwd, 0o555);
  } catch {
    // Ignore chmod differences on Windows ACLs
  }

  return {
    workerId,
    relAppDataDir,
    absAppDataDir,
    jailCwd,
  };
}

/**
 * Cleans up the worker's temporary app-data directory and empty jail directory.
 */
export function cleanupWorkerSandbox(sandbox: WorkerSandboxEnv): void {
  try {
    fs.chmodSync(sandbox.jailCwd, 0o777);
  } catch {}
  try {
    fs.rmSync(sandbox.jailCwd, { recursive: true, force: true });
  } catch {}
  try {
    fs.rmSync(sandbox.absAppDataDir, { recursive: true, force: true });
  } catch {}
}

/**
 * Sweeps any leftover `agy2api-worker-*` directories from previous ungraceful exits.
 */
export function sweepStaleSandboxes(): void {
  try {
    const geminiBaseDir = path.join(os.homedir(), ".gemini");
    if (fs.existsSync(geminiBaseDir)) {
      for (const entry of fs.readdirSync(geminiBaseDir)) {
        if (entry.startsWith("agy2api-worker-")) {
          fs.rmSync(path.join(geminiBaseDir, entry), { recursive: true, force: true });
        }
      }
    }
  } catch {}
}
