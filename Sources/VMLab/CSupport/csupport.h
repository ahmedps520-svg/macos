#ifndef VMLAB_CSUPPORT_H
#define VMLAB_CSUPPORT_H

#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

/// True if the kernel reports CS_DEBUGGED for this process (a debugger is or was attached).
/// This is the flag JIT enablers such as StikDebug rely on.
bool vmlab_is_debugged(void);

/// Returns the raw code-signing status flags (csops CS_OPS_STATUS), or 0 on failure.
uint32_t vmlab_cs_flags(void);

/// True if the running binary carries the boolean entitlement `name` set to true.
/// Uses the Security framework task API; returns false on any error.
bool vmlab_has_entitlement(const char *name);

/// Tries to map one 16 KiB RWX page with MAP_JIT. Returns 0 on success, otherwise errno.
/// On devices with TXM this is expected to fail until a debugger prepares the region.
int vmlab_probe_jit_mmap(void);

/// Bytes this process may still allocate before jetsam acts (os_proc_available_memory).
uint64_t vmlab_available_memory(void);

#endif
