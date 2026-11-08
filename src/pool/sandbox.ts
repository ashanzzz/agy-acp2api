import fs from "node:fs";
import path from "node:path";
import os from "node:os";

export interface WorkerSandboxEnv {
  workerId: string;
  relAppDataDir: string;
  absAppDataDir: string;
  jailCwd: string;
}

const EXCLUDED_WORKER_FILES = new Set([
  "conversation_summaries.db",
  "conversation_summaries.db-wal",
  "conversation_summaries.db-shm",
  "cli.log",
  "history.jsonl",
]);

const EXCLUDED_WORKER_DIRS = new Set([
  "annotations",
  "bin",
  "brain",
  "builtin",
  "cache",
  "conversations",
  "crashes",
  "implicit",
  "log",
  "presence",
  "updater",
]);

/**
 * Synchronizes all auth, token, and configuration files from `~/.gemini/antigravity-cli`
 * into the worker's isolated `~/.gemini/agy2api-worker-{id}` directory.
 * On headless Linux (SSH / no desktop keyring), `agy` stores OAuth tokens using
 * file-based token storage (`cliFileTokenStorage`) inside `antigravity-cli`.
 */
export function syncWorkerSandboxAuth(absAppDataDir: string): void {
  const geminiBaseDir = path.join(os.homedir(), ".gemini");
  const primaryCliDir = path.join(geminiBaseDir, "antigravity-cli");
  if (!fs.existsSync(primaryCliDir)) return;

  try {
    const entries = fs.readdirSync(primaryCliDir, { withFileTypes: true });
    for (const entry of entries) {
      const srcPath = path.join(primaryCliDir, entry.name);
      const destPath = path.join(absAppDataDir, entry.name);
      if (entry.isFile()) {
        if (EXCLUDED_WORKER_FILES.has(entry.name)) continue;
        try {
          fs.copyFileSync(srcPath, destPath);
        } catch {
          // Ignore if file is transiently locked
        }
      } else if (entry.isDirectory()) {
        if (EXCLUDED_WORKER_DIRS.has(entry.name)) continue;
        try {
          fs.cpSync(srcPath, destPath, { recursive: true, force: true });
        } catch {
          // Ignore transient copy errors
        }
      }
    }
  } catch {
    // Ignore directory read errors
  }
}

/**
 * Creates an isolated runtime environment for an `agy acp` worker process:
 * 1. `~/.gemini/agy2api-worker-{id}` with cloned OAuth credentials & CLI token files
 *    so each worker has its own isolated SQLite DB (`conversation_summaries.db`) and logs.
 * 2. An empty read-only temporary directory (`jailCwd`) used as `cwd` for `session/new`.
 */
export function createWorkerSandbox(workerId: string): WorkerSandboxEnv {
  const geminiBaseDir = path.join(os.homedir(), ".gemini");

  const relAppDataDir = `agy2api-worker-${workerId}`;
  const absAppDataDir = path.join(geminiBaseDir, relAppDataDir);
  fs.mkdirSync(absAppDataDir, { recursive: true });

  syncWorkerSandboxAuth(absAppDataDir);

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
