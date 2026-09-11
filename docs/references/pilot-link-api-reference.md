# pilot-link C API Reference (v0.12.5)

> **Source**: `/Users/marbury/Projects/Cloned/pilot-link/` (IGNORE `bindings/` directory)
> **Purpose**: RAG-like reference for BUILD stage — NIF implementations must call these functions correctly.
> **Generated**: ADP Phase 1, SPECIFY stage (post-research synthesis)

---

## 1. Architecture Overview

```
Application Layer   (Elixir NIF code — src/pidlp.c)
     |
     v
DLP Layer           (pi-dlp.h)  — Desktop Link Protocol: all sync operations
     |
     v
Socket Layer        (pi-socket.h) — pi_socket, pi_bind, pi_connect/accept, pi_close
     |
     v
Protocol Stack      (pi-source.h) — CMP → PADP/NET → SLP → Device
     |
     v
Device Layer        (pi-serial.h, pi-usb.h) — serial, USB, darwin USB
```

---

## 2. Connection Management (pi-socket.h)

### 2.1 Socket Lifecycle

```c
int pi_socket(int domain, int type, int protocol);
  // domain: PI_AF_PILOT (0x00)
  // type:   PI_SOCK_STREAM (0x0010) for DLP, PI_SOCK_RAW (0x0030) for debug
  // protocol: PI_PF_DLP (0x06) for normal sync
  // Returns: socket descriptor (int), negative on error

PI_ERR pi_bind(int pi_sd, const char *port);
  // port strings: "serial:/dev/ttyS0", "usb:", "net:any"
  // Returns: 0 on success, negative on error

PI_ERR pi_listen(int pi_sd, int backlog);
  // backlog: typically 1

PI_ERR pi_accept(int pi_sd, struct sockaddr *remote_addr, size_t *namelen);
  // Blocks until device connects. Pass NULL for both addr params.

PI_ERR pi_accept_to(int pi_sd, struct sockaddr *remote_addr, size_t *namelen, int timeout);
  // timeout: seconds (0 = wait forever)

PI_ERR pi_connect(int pi_sd, const char *port);
  // For initiating network connections

int pi_close(int pi_sd);
  // Closes socket, disposes all internal structures, interrupts connection

int pi_socket_connected(int pi_sd);
  // Returns != 0 if connection is established
```

### 2.2 Error Management

```c
int pi_error(int pi_sd);
  // Returns last error code (0 = no error, PI_ERR_SOCK_INVALID if socket not found)

int pi_palmos_error(int pi_sd);
  // After PI_ERR_DLP_PALMOS, call this to get the device's error code
  // Returns dlpErrors enum value or Palm OS error code

void pi_reset_errors(int sd);
int pi_set_error(int pi_sd, int error_code);
int pi_set_palmos_error(int pi_sd, int error_code);
```

### 2.3 Keepalive

```c
PI_ERR pi_tickle(int pi_sd);
  // Sends keepalive to prevent timeout during lengthy operations

int pi_watchdog(int pi_sd, int interval);
  // Sets SIGALRM-based watchdog calling pi_tickle() every interval seconds
```

### 2.4 Protocol Version

```c
PI_ERR pi_version(int pi_sd);
  // Returns DLP version after connection (e.g., 0x0104 for DLP 1.4)

unsigned long pi_maxrecsize(int pi_sd);
  // Returns max record transfer size (0xFFFF for DLP < 1.4, larger for 1.4+)
```

---

## 3. DLP System Functions (pi-dlp.h)

```c
void dlp_set_protocol_version(int major, int minor);
  // Call BEFORE connection. Default: 1.4. Use 2.1 for Palm OS 6.

PI_ERR dlp_ReadSysInfo(int sd, struct SysInfo *sysinfo);
PI_ERR dlp_ReadUserInfo(int sd, struct PilotUser *user);
PI_ERR dlp_WriteUserInfo(int sd, const struct PilotUser *INPUT);
PI_ERR dlp_ResetLastSyncPC(int sd);

PI_ERR dlp_OpenConduit(int sd);
  // MANDATORY: Must be called after connection, before any DB operations.
  // Also the only reliable way to detect user pressing Cancel on device.

PI_ERR dlp_EndOfSync(int sd, int status);
  // MANDATORY: Terminate session. status from dlpEndStatus enum.
  //   dlpEndCodeNormal (0), dlpEndCodeOutOfMemory (1),
  //   dlpEndCodeUserCan (2), dlpEndCodeOther (3+)

PI_ERR dlp_AbortSync(int sd);
  // DANGEROUS: Terminate WITHOUT notifying Palm. Palm times out.
  // Loses changes to unclosed databases. Never use normally.

PI_ERR dlp_AddSyncLogEntry(int sd, char *string);
PI_ERR dlp_GetSysDateTime(int sd, time_t *palm_time);
PI_ERR dlp_SetSysDateTime(int sd, time_t palm_time);
```

---

## 4. DLP Database Operations (pi-dlp.h)

### 4.1 Discovery and Lifecycle

```c
PI_ERR dlp_ReadDBList(int sd, int cardno, int flags, int start, pi_buffer_t *dblist);
  // flags: dlpDBListRAM (0x80), dlpDBListROM (0x40), dlpDBListMultiple (0x20)
  // When exhausted: returns PI_ERR_DLP_PALMOS, pi_palmos_error() == dlpErrNotFound

PI_ERR dlp_FindDBByName(int sd, int cardno, const char *dbname,
    unsigned long *localid, int *dbhandle,
    struct DBInfo *dbInfo, struct DBSizeInfo *dbSize);

PI_ERR dlp_OpenDB(int sd, int cardno, int mode, const char *dbname, int *dbhandle);
  // mode: dlpOpenRead (0x80), dlpOpenWrite (0x40),
  //       dlpOpenExclusive (0x20), dlpOpenSecret (0x10),
  //       dlpOpenReadWrite (0xC0 = Read|Write)
  // dbhandle: returned handle for all subsequent DB calls

PI_ERR dlp_CloseDB(int sd, int dbhandle);
PI_ERR dlp_CloseDB_All(int sd);

PI_ERR dlp_CreateDB(int sd, unsigned long creator, unsigned long type,
    int cardno, int flags, unsigned int version, const char *dbname, int *dbhandle);
  // DB is OPEN after creation — must call dlp_CloseDB() when done

PI_ERR dlp_DeleteDB(int sd, int cardno, const char *dbname);
  // DB must be closed first

PI_ERR dlp_ReadOpenDBInfo(int sd, int dbhandle, int *numrecs);
PI_ERR dlp_ResetSyncFlags(int sd, int dbhandle);
PI_ERR dlp_CleanUpDatabase(int sd, int dbhandle);
PI_ERR dlp_ResetDBIndex(int sd, int dbhandle);
```

### 4.2 Record Operations (CRITICAL FOR NIFs)

```c
PI_ERR dlp_ReadRecordById(int sd, int dbhandle, recordid_t recuid,
    pi_buffer_t *retbuf, int *recindex, int *recattrs, int *category);

PI_ERR dlp_ReadRecordByIndex(int sd, int dbhandle, int recindex,
    pi_buffer_t *retbuf, recordid_t *recuid, int *recattrs, int *category);

PI_ERR dlp_ReadNextModifiedRec(int sd, int dbhandle, pi_buffer_t *retbuf,
    recordid_t *recuid, int *recindex, int *recattrs, int *category);
  // Iterator: call dlp_ResetDBIndex() first
  // When exhausted: PI_ERR_DLP_PALMOS + pi_palmos_error() == dlpErrNotFound

PI_ERR dlp_WriteRecord(int sd, int dbhandle, int flags, recordid_t recuid,
    int catid, const void *databuf, size_t datasize, recordid_t *newrecuid);
  // CRITICAL: recuid = 0 means "new record" — Palm assigns actual ID on write
  //           newrecuid returns the actual assigned ID

PI_ERR dlp_DeleteRecord(int sd, int dbhandle, int all, recordid_t recuid);
  // all = 1: delete ALL records (recuid ignored)
  // all = 0: delete specific record by recuid

PI_ERR dlp_ReadRecordIDList(int sd, int dbhandle, int sort, int start,
    int max, recordid_t *recuids, int *count);
```

### 4.3 AppInfo Blocks

```c
PI_ERR dlp_ReadAppBlock(int sd, int dbhandle, int offset, int reqbytes, pi_buffer_t *retbuf);
PI_ERR dlp_WriteAppBlock(int sd, int dbhandle, const void *databuf, size_t datasize);
```

---

## 5. Key Data Structures

### 5.1 struct PilotUser

```c
struct PilotUser {
    size_t  passwordLength;
    char    username[128];       // ISO-8859-1, NOT UTF-8
    char    password[128];
    unsigned long userID;        // Palm device integer user ID
    unsigned long viewerID;
    unsigned long lastSyncPC;
    time_t successfulSyncDate;
    time_t lastSyncDate;
};
```

**IMPORTANT**: `PilotUser.userID` (Palm integer) ≠ `PalmUser.id` (Ash UUID). In all contracts, `palm_user_id` = `PalmUser.id`.

### 5.2 struct SysInfo

```c
struct SysInfo {
    unsigned long romVersion;       // 0xMMmmffssbb
    unsigned long locale;
    unsigned char prodIDLength;
    char    prodID[128];
    unsigned short dlpMajorVersion;
    unsigned short dlpMinorVersion;
    unsigned short compatMajorVersion;
    unsigned short compatMinorVersion;
    unsigned long  maxRecSize;
};
```

### 5.3 struct DBInfo

```c
struct DBInfo {
    int     more;
    char    name[34];           // 32 chars max + null
    unsigned int flags;         // dlpDBFlags enum
    unsigned int miscFlags;
    unsigned int version;
    unsigned long type;         // four-char code (e.g. 'DATA')
    unsigned long creator;      // four-char code
    unsigned long modnum;
    unsigned int index;
    time_t  createDate;
    time_t  modifyDate;
    time_t  backupDate;
};
```

### 5.4 pi_buffer_t — Used by most read functions

```c
typedef struct pi_buffer_t {
    unsigned char *data;
    size_t allocated;
    size_t used;
} pi_buffer_t;

pi_buffer_t* pi_buffer_new(size_t capacity);
pi_buffer_t* pi_buffer_expect(pi_buffer_t *buf, size_t new_capacity);
pi_buffer_t* pi_buffer_append(pi_buffer_t *buf, const void *data, size_t len);
void pi_buffer_clear(pi_buffer_t *buf);
void pi_buffer_free(pi_buffer_t *buf);
```

### 5.5 recordid_t

```c
typedef unsigned long recordid_t;
// rec_id = 0 means "new record" — Palm assigns actual ID on write
```

### 5.6 Appointment_t (Classic DatebookDB)

```c
typedef struct Appointment {
    int event;                      // timeless event?
    struct tm begin, end;
    int alarm, advance, advanceUnits;
    enum repeatTypes repeatType;
    int repeatForever;
    struct tm repeatEnd;
    int repeatFrequency;
    enum DayOfMonthType repeatDay;
    int repeatDays[7];
    int repeatWeekstart;
    int exceptions;
    struct tm *exception;
    char *description;              // ISO-8859-1
    char *note;                     // ISO-8859-1
} Appointment_t;
```

### 5.7 CalendarEvent_t (CalendarDB-PDat, Palm OS 5.2+)

```c
typedef struct CalendarEvent {
    int event;
    struct tm begin, end;
    int alarm, advance, advanceUnits;
    enum calendarRepeatType repeatType;
    int repeatForever;
    struct tm repeatEnd;
    int repeatFrequency;
    enum calendarDayOfMonthType repeatDay;
    int repeatDays[7];
    int repeatWeekstart;
    int exceptions;
    struct tm *exception;
    char *description, *note, *location;  // ISO-8859-1
    Blob_t *blob[MAX_BLOBS];
    Timezone_t *tz;
} CalendarEvent_t;
```

### 5.8 Unpack/Pack Functions

Every app data type has the same 4-function pattern:

```c
// Appointment (DatebookDB)
void free_Appointment(struct Appointment *);
int  unpack_Appointment(struct Appointment *, const pi_buffer_t *record, datebookType type);
int  pack_Appointment(const struct Appointment *, pi_buffer_t *record, datebookType type);

// CalendarEvent (CalendarDB-PDat)
void free_CalendarEvent(CalendarEvent_t *event);
int  unpack_CalendarEvent(CalendarEvent_t *event, const pi_buffer_t *record, calendarType type);
int  pack_CalendarEvent(const CalendarEvent_t *event, pi_buffer_t *record, calendarType type);
```

---

## 6. Enums and Constants

### 6.1 Record Attributes (dlpRecAttributes)

```c
dlpRecAttrDeleted  = 0x80   // Tagged for deletion during next sync
dlpRecAttrDirty    = 0x40   // Record modified since last sync
dlpRecAttrBusy     = 0x20   // Record locked (in use)
dlpRecAttrSecret   = 0x10   // Record is secret (private)
dlpRecAttrArchived = 0x08   // Tagged for archival during next sync
```

### 6.2 End Status (dlpEndStatus)

```c
dlpEndCodeNormal      = 0
dlpEndCodeOutOfMemory = 1
dlpEndCodeUserCan     = 2    // User pressed Cancel on device
dlpEndCodeOther       = 3+
```

### 6.3 DLP Device Errors (dlpErrors) — via pi_palmos_error()

```c
dlpErrNoError   = 0       dlpErrNotFound   = 5      dlpErrReadOnly  = 0x0f
dlpErrSystem    = 1       dlpErrNoneOpen   = 6      dlpErrSpace     = 0x10
dlpErrIllegalReq= 2       dlpErrAlreadyOpen= 7      dlpErrLimit     = 0x11
dlpErrMemory    = 3       dlpErrTooManyOpen= 8      dlpErrSync      = 0x12
dlpErrParam     = 4       dlpErrExists     = 9      dlpErrWrapper   = 0x13
                            dlpErrOpen       = 0x0a  dlpErrArgument  = 0x14
                            dlpErrDeleted    = 0x0b  dlpErrSize      = 0x15
                            dlpErrBusy       = 0x0c
                            dlpErrNotSupp    = 0x0d
dlpErrUnknown   = 127
```

### 6.4 Library Error Codes (pi-error.h)

```c
// Protocol level (-100 to -199)
PI_ERR_PROT_ABORTED      = -100
PI_ERR_PROT_INCOMPATIBLE = -101
PI_ERR_PROT_BADPACKET    = -102

// Socket level (-200 to -299)
PI_ERR_SOCK_DISCONNECTED = -200
PI_ERR_SOCK_INVALID      = -201
PI_ERR_SOCK_TIMEOUT      = -202
PI_ERR_SOCK_CANCELED     = -203
PI_ERR_SOCK_IO           = -204
PI_ERR_SOCK_LISTENER     = -205

// DLP level (-300 to -399)
PI_ERR_DLP_BUFSIZE       = -300
PI_ERR_DLP_PALMOS        = -301    // Check pi_palmos_error() for device error
PI_ERR_DLP_UNSUPPORTED   = -302
PI_ERR_DLP_SOCKET        = -303
PI_ERR_DLP_DATASIZE      = -304
PI_ERR_DLP_COMMAND       = -305

// File level (-400 to -499)
PI_ERR_FILE_INVALID      = -400
PI_ERR_FILE_ERROR        = -401
PI_ERR_FILE_ABORTED      = -402
PI_ERR_FILE_NOT_FOUND    = -403
PI_ERR_FILE_ALREADY_EXISTS = -404

// Generic (-500 to -599)
PI_ERR_GENERIC_MEMORY    = -500
PI_ERR_GENERIC_ARGUMENT  = -501
PI_ERR_GENERIC_SYSTEM    = -502
```

### 6.5 Error Check Macros

```c
IS_PROT_ERR(error)    // -100 to -199
IS_SOCK_ERR(error)    // -200 to -299
IS_DLP_ERR(error)     // -300 to -399
IS_FILE_ERR(error)    // -400 to -499
IS_GENERIC_ERR(error) // -500 to -599
```

---

## 7. Return Value Convention

```
>= 0                Success (some functions return byte count or 0)
< 0                 Error — check specific error code
PI_ERR_DLP_PALMOS   Device returned an error — call pi_palmos_error(sd)
```

**CRITICAL NIF ERROR HANDLING PATTERN:**

```c
PI_ERR result = dlp_WriteRecord(sd, dbhandle, flags, recuid, catid, data, len, &newid);
if (result < 0) {
    if (result == PI_ERR_DLP_PALMOS) {
        int palm_err = pi_palmos_error(sd);
        // palm_err is from dlpErrors enum or Palm OS error codes
        // Map to {:error, {:palmos, palm_err}} in Elixir
    } else if (IS_SOCK_ERR(result)) {
        // Socket error — connection lost, recoverable with reconnect
        // Map to {:error, {:socket, result}}
    } else if (IS_PROT_ERR(result)) {
        // Protocol error — mismatch, bad packet
        // Map to {:error, {:protocol, result}}
    } else {
        // Other library error
        // Map to {:error, result}
    }
}
```

---

## 8. Typical HotSync Session Flow

### 8.1 Canonical Sequence

```c
// 1. Create socket
int sd = pi_socket(PI_AF_PILOT, PI_SOCK_STREAM, PI_PF_DLP);

// 2. Bind to port
pi_bind(sd, port);

// 3. Listen + Accept (blocks until device connects)
pi_listen(sd, 1);
sd = pi_accept(sd, NULL, NULL);

// 4. Read system info (validates connection, gets DLP version)
struct SysInfo sys_info;
dlp_ReadSysInfo(sd, &sys_info);

// 5. Open conduit (MANDATORY — checks for user cancel)
dlp_OpenConduit(sd);

// 6. Read user info
struct PilotUser user;
dlp_ReadUserInfo(sd, &user);

// ---- SYNC OPERATIONS ----

// 7. Open database
int dbhandle;
dlp_OpenDB(sd, 0, dlpOpenReadWrite, "DatebookDB", &dbhandle);

// 8. Read modified records (fast sync)
dlp_ResetDBIndex(sd, dbhandle);
pi_buffer_t *buf = pi_buffer_new(0xFFFF);
recordid_t recuid;
int recindex, recattrs, category;

while (dlp_ReadNextModifiedRec(sd, dbhandle, buf, &recuid, &recindex, &recattrs, &category) >= 0) {
    Appointment_t apt;
    unpack_Appointment(&apt, buf, datebook_v1);
    // ... process appointment ...
    free_Appointment(&apt);
}
// Loop ends with PI_ERR_DLP_PALMOS + pi_palmos_error() == dlpErrNotFound

// 9. Write new records
recordid_t newid;
dlp_WriteRecord(sd, dbhandle, 0, 0, 0, data, datalen, &newid);
// recuid=0 → Palm assigns ID, returned in newid

// 10. Delete records
dlp_DeleteRecord(sd, dbhandle, 0, recuid_to_delete);

// 11. Reset sync flags + close DB
dlp_ResetSyncFlags(sd, dbhandle);
dlp_CloseDB(sd, dbhandle);

// ---- END SYNC OPERATIONS ----

// 12. Write user info (update sync timestamps)
dlp_WriteUserInfo(sd, &user);

// 13. End sync session (MANDATORY)
dlp_EndOfSync(sd, dlpEndCodeNormal);

// 14. Close socket
pi_close(sd);
```

### 8.2 Slow Sync (Full Database Read)

```c
int numrecs;
dlp_ReadOpenDBInfo(sd, dbhandle, &numrecs);

for (int i = 0; i < numrecs; i++) {
    pi_buffer_clear(buf);
    if (dlp_ReadRecordByIndex(sd, dbhandle, i, buf, &recuid, &recattrs, &category) < 0)
        break;
    // process record
}
```

---

## 9. Byte-Order and Time Macros (pi-macros.h)

Palm data is big-endian. These macros read/write big-endian values:

```c
get_long(ptr)    / set_long(ptr, val)     // unsigned 32-bit
get_slong(ptr)   / set_slong(ptr, val)    // signed 32-bit
get_short(ptr)   / set_short(ptr, val)    // unsigned 16-bit
get_sshort(ptr)  / set_sshort(ptr, val)   // signed 16-bit
get_treble(ptr)  / set_treble(ptr, val)   // unsigned 24-bit
get_byte(ptr)    / set_byte(ptr, val)     // unsigned 8-bit
get_sbyte(ptr)   / set_sbyte(ptr, val)    // signed 8-bit
char4(c1,c2,c3,c4)                        // make 4-char code

// struct tm ↔ Palm date buffer:
getBufTm(struct tm *t, const void *buf, int setTime);
setBufTm(void *buf, const struct tm *t);
// NOTE: tm_mon is 0-11 (NOT 1-12), tm_year is years since 1900
```

### Time Conversion (pi-file.h)

```c
unsigned long unix_time_to_pilot_time(time_t t);
time_t pilot_time_to_unix_time(unsigned long raw_time);
  // Palm epoch: 01-JAN-1904 00:00
  // Unix epoch: 01-JAN-1970 00:00
  // Undefined Palm date: 0x83DAC000
```

---

## 10. Character Encoding (pi-util.h)

```c
int convert_ToPilotChar(const char *charset, const char *text, int bytes, char **ptext);
int convert_FromPilotChar(const char *charset, const char *ptext, int bytes, char **text);
```

**CRITICAL**: Palm encoding is **ISO-8859-1**, NOT UTF-8. Use `codepagex` in Elixir NIF layer for conversion.

---

## 11. Database Types

| DB Name | Creator | Palm App | pilot-link Header | Palm OS |
|---------|---------|----------|-------------------|---------|
| `DatebookDB` | 'date' | Date Book | pi-datebook.h | < 5.2 |
| `CalendarDB-PDat` | 'PDat' | Calendar | pi-calendar.h | 5.2+ |
| `AddressDB` | 'addr' | Address | pi-address.h | < 5.0 |
| `ContactsDB-PAdd` | 'PAdd' | Contacts | pi-contact.h | 5.0+ |
| `ToDoDB` | 'todo' | ToDo | pi-todo.h | All |
| `MemoDB` | 'memo' | Memo | pi-memo.h | All |

---

## 12. Resource Cleanup Rules for NIFs

1. **pi_buffer_t**: Always call `pi_buffer_free()` after use. DLP read functions write into caller-provided buffers.
2. **dbhandle**: Always pair `dlp_OpenDB()` with `dlp_CloseDB()`. Use `dlp_CloseDB_All()` in error paths.
3. **sd (socket)**: Always pair `pi_socket()` with `pi_close()`.
4. **Application structs**: Call `free_*` functions (`free_CalendarEvent`, `free_Appointment`, etc.) after processing. These free internal `char*` members.
5. **Session termination**: ALWAYS call `dlp_EndOfSync()` before `pi_close()`.
6. **rec_id = 0**: Means "new record". After `dlp_WriteRecord()`, the actual assigned ID is in `newrecuid`.

---

## 13. Current NIF Boundary (PalmSync4Mac)

### Existing NIF Functions (src/pidlp.c → pidlp.spec.exs)

| # | C Function | pilot-link Call | Elixir Call | Return |
|---|---|---|---|---|
| 1 | `pilot_connect` | pi_socket + pi_bind + pi_listen + pi_accept_to + dlp_OpenConduit | `Pidlp.pilot_connect(port, wait_timeout)` | `{:ok, client_sd, parent_sd} \| {:error, ...}` |
| 2 | `pilot_disconnect` | pi_close (x2) | `Pidlp.pilot_disconnect(client_sd, parent_sd)` | `{:ok, client_sd, parent_sd}` |
| 3 | `open_conduit` | dlp_OpenConduit | `Pidlp.open_conduit(client_sd)` | `{:ok, ...} \| {:error, ...}` |
| 4 | `open_db` | dlp_OpenDB | `Pidlp.open_db(client_sd, card_no, mode, dbname)` | `{:ok, client_sd, db_handle} \| {:error, ...}` |
| 5 | `close_db` | dlp_CloseDB | `Pidlp.close_db(client_sd, db_handle)` | `{:ok, client_sd}` |
| 6 | `end_of_sync` | dlp_EndOfSync | `Pidlp.end_of_sync(client_sd, status)` | `{:ok, ...} \| {:error, ...}` |
| 7 | `read_sysinfo` | dlp_ReadSysInfo | `Pidlp.read_sysinfo(client_sd)` | `{:ok, client_sd, sys_info} \| {:error, ...}` |
| 8 | `get_sys_date_time` | dlp_GetSysDateTime | `Pidlp.get_sys_date_time(client_sd)` | `{:ok, ...} \| {:error, ...}` |
| 9 | `set_sys_date_time` | dlp_SetSysDateTime | `Pidlp.set_sys_date_time(client_sd, palm_date_time)` | `{:ok, ...} \| {:error, ...}` |
| 10 | `read_user_info` | dlp_ReadUserInfo | `Pidlp.read_user_info(client_sd)` | `{:ok, client_sd, pilot_user} \| {:error, ...}` |
| 11 | `write_user_info` | dlp_WriteUserInfo | `Pidlp.write_user_info(client_sd, user_info)` | `{:ok, client_sd} \| {:error, ...}` |
| 12 | `write_datebook_record` | pack_Appointment + dlp_WriteRecord | `Pidlp.write_datebook_record(client_sd, db_handle, record_data)` | `{:ok, client_sd, result, rec_id} \| {:error, ...}` |
| 13 | `write_calendar_record` | pack_CalendarEvent + dlp_WriteRecord | `Pidlp.write_calendar_record(client_sd, db_handle, record_data)` | `{:ok, client_sd, result, rec_id} \| {:error, ...}` |

### NIF Gaps (Missing for Multi-Device Sync)

| Priority | pilot-link Function | Purpose | Needed By |
|---|---|---|---|
| **P0** | `dlp_ReadRecordByID` + `unpack_Appointment` | Read record by rec_id | AppointmentWorker (conflict detection) |
| **P0** | `dlp_ReadRecordByIndex` + `unpack_Appointment` | Read record by index | Full iteration, slow sync |
| **P0** | `dlp_ReadNextModifiedRec` + `unpack_Appointment` | Iterate dirty records | Fast sync (Palm→Mac) |
| **P1** | `dlp_DeleteRecord` | Delete record by rec_id | Deletion sync |
| **P1** | `dlp_ResetDBIndex` | Reset record cursor | Before iteration |
| **P1** | `dlp_ResetSyncFlags` | Clear dirty flags | Post-sync cleanup |
| **P2** | `dlp_ReadAppBlock` | Read AppInfo/category block | Category management |

### Known Bugs in Current NIF Code

1. **Debug printf in production** (pidlp.c lines 613-626): Must be removed.
2. **Memory leak in write_datebook_record**: `strdup`'d `description` and `note` never freed. `write_calendar_record` correctly frees but `write_datebook_record` does not.
3. **SysInfo struct unmapped**: `PilotSysInfo` module doesn't exist; `read_sysinfo` returns a bare map.
4. **Double open_conduit**: `pilot_connect` already calls `dlp_OpenConduit` internally; separate `open_conduit` NIF could cause double-call.

---

## 14. Sync Modes (pi-sync.h)

| Mode | Function | Description |
|------|----------|-------------|
| CopyToPilot | `sync_CopyToPilot()` | Overwrite Palm DB with all desktop records |
| CopyFromPilot | `sync_CopyFromPilot()` | Overwrite desktop with all Palm records |
| MergeToPilot | `sync_MergeToPilot()` | Send modified desktop records to Palm |
| MergeFromPilot | `sync_MergeFromPilot()` | Receive modified Palm records to desktop |
| Synchronize | `sync_Synchronize()` | Full bidirectional sync |

### Fast vs Slow Sync
- **Fast sync**: `dlp_ReadNextModifiedRec()` — only dirty records (dlpRecAttrDirty)
- **Slow sync**: `dlp_ReadRecordByIndex()` — all records, then compare

---

## 15. Port String Formats

```
Serial:  "serial:/dev/ttyUSB0"    (Unix), "serial:/dev/cu.IrDA-IrCOMM" (macOS)
USB:     "usb:"                    (auto-detect), "usb:/dev/ttyUSB0"
Network: "net:any"                (listen on any interface)
         "net:hostname:port"      (connect to specific host)
```

---

## 16. DLP Version Compatibility

| DLP Version | Palm OS | Key Features |
|-------------|---------|--------------|
| 1.0 | 1.0 | Basic record I/O |
| 1.1 | 2.0 | ReadNextRecInCategory, AppPreferences, NetSyncInfo |
| 1.2 | 3.0 | FindDB, SetDBInfo |
| 1.3 | 4.0 | VFS, Expansion manager |
| 1.4 | 5.2+ | >64k records, default in pilot-link |
| 2.1 | 6 (Cobalt) | Schema databases |

Default: DLP 1.4 (PI_DLP_VERSION_MAJOR=1, PI_DLP_VERSION_MINOR=4).
