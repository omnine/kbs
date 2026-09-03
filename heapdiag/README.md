# heapdiag — JVM heap-leak diagnostics for DualShield

Four PowerShell scripts for finding a slow heap leak in the DualShield Tomcat
JVM on a Windows server, and for arming the JVM so the *next* crash leaves
evidence behind.

Built for the September 2026 investigation into a 4 GB heap exhausted in about
four days with no user traffic
([sso/dualshield-sso#15](https://gitlab.deepnetsecurity.com/sso/dualshield-sso/-/issues/15)).
They are general-purpose, not specific to that bug.

---

## Why these exist

A Java OOM stack trace usually names Tomcat and Spring plumbing and nothing of
yours, so it does not tell you what leaked. Two things do:

- **A live-set trend.** Heap usage measured *immediately after a forced full GC*
  is retained memory, not garbage. On a healthy JVM it returns to a flat
  baseline; on a leaking one it steps up and never comes back.
- **An allocation stack for objects that survive.** JFR's `jdk.OldObjectSample`
  event samples long-lived objects and records where they were allocated. A class
  histogram tells you *what* grew; this tells you *which line put it there*.

`heap-sample.ps1` gives you the first. `enable-heapdump.ps1` + `verify-and-dump.ps1`
give you the second.

---

## Prerequisites

### A JDK, because the DualShield JRE has none

`C:\Program Files\Deepnet DualShield\jre` is a JRE-only image, so it ships no
`jcmd.exe`. Copy a full JDK **matching the service's JVM** next to these scripts
as `jdk25`:

```
C:\Program Files\Zulu\zulu-25   ->   <this folder>\jdk25
```

No install, no PATH change, and the DualShield service is untouched. The scripts
find `<this folder>\jdk25\bin\jcmd.exe` automatically; otherwise pass
`-JcmdPath '<path to jcmd.exe>'`.

Check the build matches — attach across major versions is not guaranteed:

```powershell
& 'C:\Program Files\Deepnet DualShield\jre\bin\java.exe' -version
& '.\jdk25\bin\java.exe' -version
```

An extracted Zulu zip often nests one level; if `.\jdk25\bin\jcmd.exe` is
missing, look for `.\jdk25\zulu25*\bin\jcmd.exe` and flatten it.

Only `enable-heapdump.ps1` works without a JDK — it edits configuration and
never attaches.

### Run as the service's identity

HotSpot attach requires the target's account or `SeDebugPrivilege`. The
DualShield service normally runs as LocalSystem, so use Sysinternals PsExec:

```powershell
.\psexec -s powershell -ExecutionPolicy Bypass -File <script>
```

If the service's logon account is not LocalSystem — the scripts print it — use
`psexec -u <account>` instead.

### Do not expect `jcmd -l` to list the service

procrun (`prunsrv.exe`) hosts the JVM in-process via `JNI_CreateJavaVM` rather
than launching `java.exe`, so the service never registers as a Java launcher and
**will not appear in `jcmd -l` under any account**. Attach *by pid* is
unaffected: it injects a thread into the target and calls into its loaded
`jvm.dll`, needing neither hsperfdata nor a recognisable process name.

The scripts therefore ask the service control manager for the pid, and fall back
to `jcmd -l` only for plain `java.exe` deployments. An empty `jcmd -l` is normal
here, not a problem.

### Drive layout

Every path defaults to the folder the script lives in, so the whole `heapdiag`
folder can sit on any drive (`C:\temp\heapdiag`, `D:\heapdiag`, …) and work
unchanged.

---

## The scripts

### `heap-sample.ps1` — the leak curve

Every `-IntervalMin` minutes: forces two full GCs, records the live-set, and
writes a full class histogram.

```powershell
.\psexec -s powershell -ExecutionPolicy Bypass -File C:\temp\heapdiag\heap-sample.ps1 -IntervalMin 15
```

| Parameter | Default | Notes |
| --- | --- | --- |
| `-OutDir` | script folder | Where the CSV and histograms go |
| `-IntervalMin` | `15` | Minutes between samples |
| `-TopClasses` | `40` | How many rows to echo per sample |
| `-PidTarget` | auto | Skip discovery, attach to this pid |
| `-JcmdPath` | auto | Full path to `jcmd.exe` |

Runs until you stop it (Ctrl+C). Outputs:

- **`heap-samples.csv`** — one row per sample:
  `timestamp,uptime_s,heap_used_mb,heap_committed_mb,heap_max_mb,threads,loaded_classes`
- **`hist-<timestamp>.txt`** — a `GC.class_histogram` per sample, for diffing.

Read `heap_used_mb` as the live set, and **ignore the first few samples** — a
freshly started JVM holds startup transients that drain once. Measure the slope
from the post-startup trough. `threads` is worth watching in its own right:
monotone growth there is a separate leak.

The CSV **appends**, so archive it before restarting the service. Mixing rows
from two JVMs corrupts the slope (`uptime_s` resetting marks the boundary).

### `heap-diff.ps1` — what grew

Diffs two histograms and ranks classes by bytes gained.

```powershell
powershell -ExecutionPolicy Bypass -File .\heap-diff.ps1 `
    -Before .\hist-20260902-172642.txt `
    -After  .\hist-20260902-220243.txt -Top 25
```

`-Before` and `-After` are required; `-Top` defaults to 30. Runs anywhere the
files have been copied — no JDK, no server access.

It sorts by **bytes, not instance count**, deliberately: a leak of a few large
arrays shows a *falling* instance count while consuming hundreds of megabytes.
Use the first and last histogram of a run for the clearest signal.

Interpretation: look for a family of related classes moving together. In the case
above, `java.util.regex.Pattern` plus `Pattern$SliceI`, `Pattern$Start` and `[I`
rising in lockstep pinned it to compiled regexes — and `SliceI` specifically is
the node type for a case-insensitive literal, which identified the exact
`Pattern.compile(..., CASE_INSENSITIVE)` call.

### `enable-heapdump.ps1` — arm the JVM for the next crash

Adds crash-capture JVM flags so the next OOM leaves a heap dump, a JFR recording
and a GC log. **Dry-run by default** — it reports the current configuration and
the exact change it would make, and writes nothing:

```powershell
powershell -ExecutionPolicy Bypass -File .\enable-heapdump.ps1          # report only
powershell -ExecutionPolicy Bypass -File .\enable-heapdump.ps1 -Apply   # commit
```

| Parameter | Default | Notes |
| --- | --- | --- |
| `-DumpDir` | `<script folder>\dumps` | Heap dumps and the JFR recording |
| `-GcLogDir` | `C:\Program Files\Deepnet DualShield\tomcat\logs` | Must already exist |
| `-ServiceName` | auto | Procrun service name, if ambiguous |
| `-NoJfr` | off | Omit the JFR flags |
| `-Apply` | off | Actually write the change |

Flags added:

| Flag | Why |
| --- | --- |
| `-XX:+HeapDumpOnOutOfMemoryError` | The artifact you otherwise never get |
| `-XX:HeapDumpPath=<DumpDir>` | Keep dumps off the system drive |
| `-XX:+ExitOnOutOfMemoryError` | After a heap OOM the JVM is unusable; exit so the service manager restarts it cleanly. The dump is written first. |
| `-Xlog:gc*,gc+heap=debug:…` | The GC curve, 20 × 20 MB rotating |
| `-XX:StartFlightRecording=…` | JFR with `jdk.OldObjectSample` enabled |
| `-XX:FlightRecorderOptions=stackdepth=128` | Deep enough stacks to be useful |

Safety behaviour: backs up the previous options to a timestamped file and prints
the rollback command; refuses to arm a dump if the target volume has less free
space than `Xmx` (it reads `Xmx` from the service config rather than assuming);
requires `-GcLogDir` to exist, and warns if it holds no `catalina*.log`, since
that suggests the wrong path.

It **never restarts the service** — the flags load only on JVM start, so restart
in a window you choose.

Two consequences to know about. `ExitOnOutOfMemoryError` changes failure
behaviour, so check the service's Recovery settings if that box must self-heal.
And `settings=profile` costs roughly 1–2% CPU and produced a 327 MB recording
over five hours — fine for an investigation; consider `settings=default` or
removing it afterwards.

### `verify-and-dump.ps1` — confirm the flags are live, pull the recording

```powershell
.\psexec -s powershell -ExecutionPolicy Bypass -File .\verify-and-dump.ps1          # verify
.\psexec -s powershell -ExecutionPolicy Bypass -File .\verify-and-dump.ps1 -Dump    # + dump JFR
```

| Parameter | Default | Notes |
| --- | --- | --- |
| `-OutDir` | script folder | Where the `.jfr` is written |
| `-JcmdPath` | auto | Full path to `jcmd.exe` |
| `-PidTarget` | auto | Skip discovery |
| `-Dump` | off | Write the JFR recording out |

Verify mode reads the **running** JVM's effective command line and reports each
expected flag present or MISSING, shows `JFR.check`, and confirms `gc.log` is
being written. Run it after any restart: "the service came back up" does not
prove the registry edit reached the service that is actually running. Expect
`gc.log.00` alongside a 0-byte `gc.log` — that is normal rotation.

`-Dump` writes the recording without stopping it, so you can dump repeatedly and
never have to wait for another OOM.

---

## The workflow

1. **Copy a matching JDK** to `.\jdk25` (above).
2. **Start sampling.** No restart needed, so this can begin immediately:
   ```powershell
   .\psexec -s powershell -ExecutionPolicy Bypass -File .\heap-sample.ps1 -IntervalMin 15
   ```
3. **Arm the JVM**, in parallel: dry-run `enable-heapdump.ps1`, review, `-Apply`,
   restart when convenient. Then `verify-and-dump.ps1` to confirm.
4. **Wait.** Four to six hours is enough to establish a slope at tens of MB/h.
   Note that `jdk.OldObjectSample` accumulates slowly — about 160 samples in five
   hours — so an early dump will be near-empty. That is expected, not a fault.
5. **Diff the histograms**, first against last, with `heap-diff.ps1`.
6. **Get the allocation stack.** `verify-and-dump.ps1 -Dump`, then on any machine
   with a JDK:
   ```powershell
   jfr summary leak-<timestamp>.jfr
   jfr print --events jdk.OldObjectSample leak-<timestamp>.jfr
   ```
   Each event carries `objectSize`, `objectAge`, `allocationTime` and a full
   `stackTrace`. Filter for your own packages and the culprit usually appears
   directly. Or open the file in JDK Mission Control → Automated Analysis.
7. **Cross-check.** Confirm the histogram's byte growth per hour roughly matches
   the live-set slope, and that both predict the observed time-to-OOM. If they
   agree you have the leak; if the numbers do not add up, something else is
   growing too.

Note that a restart resets the heap, which is useful: a known `t=0` turns the
`uptime_s` column into a real leak rate.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `jcmd.exe not found` | The DualShield JRE has none. Copy a JDK to `.\jdk25`, or pass `-JcmdPath`. |
| `jcmd -l` lists only itself | Normal for procrun. The scripts use the service control manager instead; if it still fails, pass `-PidTarget`. |
| Attach fails with the right pid | Wrong identity — use `psexec -s`, or `psexec -u <account>` if the printed logon account is not LocalSystem. |
| Attach fails as SYSTEM too | Check the wrong process was picked: `Get-Process -Id <pid> -Module \| Where-Object ModuleName -eq 'jvm.dll'`. Also check the service options for `-XX:+DisableAttachMechanism`, which blocks all attach — JFR is then the only route. |
| Histogram file nearly empty | The heap walk failed. The script retries once with `-parallel=1` and prints the raw `jcmd` output. |
| Procrun registry root not found | The keys are under `Wow6432Node` on x64 (32-bit installer, 64-bit JVM). Handled automatically; the script prints which root it used. |
| `heap_committed_mb` is `-1` | Unrecognised `GC.heap_info` format on this JVM. G1 on JDK 25 prints `total reserved …K, committed …K, used …K`. |
| Flags show MISSING after a restart | The edit landed on a different procrun service. Re-run the `enable-heapdump.ps1` dry run and check the service name matches the one `verify-and-dump.ps1` reports. |
| Curve is flat over 6h | The leak is not reproducing here. A quiet test VM may not run the same tickers — no LDAP pool, no replication engine, fewer webapps — so a flat curve does not clear the production configuration. |

---

## A note on paths and secrets

These scripts print service names, logon accounts, file paths and JVM flags.
Redact before pasting into a ticket if any flag carries a credential — JVM
arguments sometimes hold keystore passwords. The heap dumps and JFR recordings
contain **application memory**, so treat them as sensitive: they can hold
tokens, passwords and user data, and should not leave controlled storage.
