/*
 * pisock_mocks.c — Stub implementations for all 21 pilot-link API functions.
 *
 * Contract: §5 Mock Implementation
 * Each stub reads from mock_state for return values and increments call counts.
 * For read functions, populates output structs from mock_state.
 * For pi_buffer_new, allocates a real pi_buffer_t struct.
 */

#include "pisock_mocks.h"
#include <pi-dlp.h>
#include <pi-socket.h>
#include <pi-datebook.h>
#include <pi-calendar.h>
#include <pi-buffer.h>
#include <pi-sockaddr.h>
#include <stdlib.h>
#include <string.h>

PilotLinkMockState mock_state;

void mock_state_reset(void) {
    memset(&mock_state, 0, sizeof(mock_state));
}

int pi_socket(int domain, int type, int protocol) {
    (void)domain;
    (void)type;
    (void)protocol;
    mock_state.pi_socket_call_count++;
    return mock_state.pi_socket_return;
}

int pi_bind(int sd, const char *port) {
    (void)sd;
    (void)port;
    mock_state.pi_bind_call_count++;
    return mock_state.pi_bind_return;
}

int pi_listen(int sd, int backlog) {
    (void)sd;
    (void)backlog;
    mock_state.pi_listen_call_count++;
    return mock_state.pi_listen_return;
}

int pi_accept_to(int sd, struct sockaddr *addr, size_t *addrlen, int timeout) {
    (void)sd;
    (void)addr;
    (void)addrlen;
    (void)timeout;
    mock_state.pi_accept_to_call_count++;
    return mock_state.pi_accept_to_return;
}

int pi_close(int sd) {
    (void)sd;
    mock_state.pi_close_call_count++;
    return mock_state.pi_close_return;
}

int dlp_OpenConduit(int sd) {
    (void)sd;
    mock_state.dlp_OpenConduit_call_count++;
    return mock_state.dlp_OpenConduit_return;
}

int dlp_OpenDB(int sd, int cardno, int mode, const char *dbname, int *dbhandle) {
    (void)sd;
    (void)cardno;
    (void)mode;
    (void)dbname;
    mock_state.dlp_OpenDB_call_count++;
    if (dbhandle && mock_state.dlp_OpenDB_return >= 0) {
        *dbhandle = 1;
    }
    return mock_state.dlp_OpenDB_return;
}

int dlp_CloseDB(int sd, int dbhandle) {
    (void)sd;
    (void)dbhandle;
    mock_state.dlp_CloseDB_call_count++;
    return mock_state.dlp_CloseDB_return;
}

int dlp_EndOfSync(int sd, int status) {
    (void)sd;
    (void)status;
    mock_state.dlp_EndOfSync_call_count++;
    return mock_state.dlp_EndOfSync_return;
}

int dlp_ReadSysInfo(int sd, struct SysInfo *sysinfo) {
    (void)sd;
    mock_state.dlp_ReadSysInfo_call_count++;
    if (sysinfo && mock_state.dlp_ReadSysInfo_return >= 0) {
        *sysinfo = mock_state.mock_sys_info;
    }
    return mock_state.dlp_ReadSysInfo_return;
}

int dlp_GetSysDateTime(int sd, time_t *t) {
    (void)sd;
    mock_state.dlp_GetSysDateTime_call_count++;
    if (t && mock_state.dlp_GetSysDateTime_return >= 0) {
        *t = mock_state.mock_sys_date_time;
    }
    return mock_state.dlp_GetSysDateTime_return;
}

int dlp_SetSysDateTime(int sd, time_t t) {
    (void)sd;
    (void)t;
    mock_state.dlp_SetSysDateTime_call_count++;
    return mock_state.dlp_SetSysDateTime_return;
}

int dlp_ReadUserInfo(int sd, struct PilotUser *user) {
    (void)sd;
    mock_state.dlp_ReadUserInfo_call_count++;
    if (user && mock_state.dlp_ReadUserInfo_return >= 0) {
        *user = mock_state.mock_pilot_user;
    }
    return mock_state.dlp_ReadUserInfo_return;
}

int dlp_WriteUserInfo(int sd, const struct PilotUser *user) {
    (void)sd;
    (void)user;
    mock_state.dlp_WriteUserInfo_call_count++;
    return mock_state.dlp_WriteUserInfo_return;
}

int dlp_WriteRecord(int sd, int dbhandle, int flags, recordid_t recuid,
                    int catid, const void *databuf, size_t datasize,
                    recordid_t *newrecuid) {
    (void)sd;
    (void)dbhandle;
    (void)flags;
    (void)recuid;
    (void)catid;
    (void)databuf;
    (void)datasize;
    mock_state.dlp_WriteRecord_call_count++;
    if (newrecuid && mock_state.dlp_WriteRecord_return >= 0) {
        *newrecuid = mock_state.mock_new_rec_id;
    }
    return mock_state.dlp_WriteRecord_return;
}

int pack_Appointment(const struct Appointment *a, pi_buffer_t *buf, datebookType type) {
    (void)a;
    (void)type;
    mock_state.pack_Appointment_call_count++;
    if (buf && mock_state.pack_Appointment_return >= 0) {
        buf->used = 16;
        if (buf->allocated < 16) {
            free(buf->data);
            buf->data = (unsigned char *)malloc(16);
            buf->allocated = 16;
        }
        if (buf->data) {
            memset(buf->data, 0xAB, 16);
        }
    }
    return mock_state.pack_Appointment_return;
}

int pack_CalendarEvent(const CalendarEvent_t *e, pi_buffer_t *buf, calendarType type) {
    (void)e;
    (void)type;
    mock_state.pack_CalendarEvent_call_count++;
    if (buf && mock_state.pack_CalendarEvent_return >= 0) {
        buf->used = 16;
        if (buf->allocated < 16) {
            free(buf->data);
            buf->data = (unsigned char *)malloc(16);
            buf->allocated = 16;
        }
        if (buf->data) {
            memset(buf->data, 0xCD, 16);
        }
    }
    return mock_state.pack_CalendarEvent_return;
}

void new_CalendarEvent(CalendarEvent_t *event) {
    mock_state.new_CalendarEvent_call_count++;
    if (event) {
        memset(event, 0, sizeof(CalendarEvent_t));
    }
}

void free_CalendarEvent(CalendarEvent_t *event) {
    mock_state.free_CalendarEvent_call_count++;
    if (event) {
        if (event->description) { free(event->description); event->description = NULL; }
        if (event->note) { free(event->note); event->note = NULL; }
        if (event->location) { free(event->location); event->location = NULL; }
        if (event->exception) { free(event->exception); event->exception = NULL; }
        if (event->tz) { free(event->tz); event->tz = NULL; }
    }
}

pi_buffer_t *pi_buffer_new(size_t capacity) {
    (void)capacity;
    mock_state.pi_buffer_new_call_count++;
    pi_buffer_t *buf = (pi_buffer_t *)malloc(sizeof(pi_buffer_t));
    if (buf) {
        buf->allocated = capacity;
        buf->used = 0;
        buf->data = (unsigned char *)malloc(capacity);
        if (!buf->data) {
            free(buf);
            return NULL;
        }
    }
    return buf;
}

void pi_buffer_free(pi_buffer_t *buf) {
    mock_state.pi_buffer_free_call_count++;
    if (buf) {
        if (buf->data) {
            free(buf->data);
            buf->data = NULL;
        }
        free(buf);
    }
}
