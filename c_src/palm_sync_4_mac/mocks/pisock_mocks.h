#pragma once

/*
 * pisock_mocks.h — Mock state for pilot-link API stubs.
 * Contract: §5 Mock Implementation
 */

#include <pi-dlp.h>
#include <pi-socket.h>
#include <pi-datebook.h>
#include <pi-calendar.h>
#include <pi-buffer.h>
#include <pi-sockaddr.h>
#include <pi-macros.h>

typedef struct {
    int pi_socket_return;
    int pi_bind_return;
    int pi_listen_return;
    int pi_accept_to_return;
    int pi_close_return;
    int dlp_OpenConduit_return;
    int dlp_OpenDB_return;
    int dlp_CloseDB_return;
    int dlp_EndOfSync_return;
    int dlp_ReadSysInfo_return;
    int dlp_GetSysDateTime_return;
    int dlp_SetSysDateTime_return;
    int dlp_ReadUserInfo_return;
    int dlp_WriteUserInfo_return;
    int dlp_WriteRecord_return;
    int pack_Appointment_return;
    int pack_CalendarEvent_return;

    struct SysInfo mock_sys_info;
    struct PilotUser mock_pilot_user;
    time_t mock_sys_date_time;
    recordid_t mock_new_rec_id;

    int pi_socket_call_count;
    int pi_bind_call_count;
    int pi_listen_call_count;
    int pi_accept_to_call_count;
    int pi_close_call_count;
    int dlp_OpenConduit_call_count;
    int dlp_OpenDB_call_count;
    int dlp_CloseDB_call_count;
    int dlp_EndOfSync_call_count;
    int dlp_ReadSysInfo_call_count;
    int dlp_GetSysDateTime_call_count;
    int dlp_SetSysDateTime_call_count;
    int dlp_ReadUserInfo_call_count;
    int dlp_WriteUserInfo_call_count;
    int dlp_WriteRecord_call_count;
    int pack_Appointment_call_count;
    int pack_CalendarEvent_call_count;
    int new_CalendarEvent_call_count;
    int free_CalendarEvent_call_count;
    int pi_buffer_new_call_count;
    int pi_buffer_free_call_count;
} PilotLinkMockState;

extern PilotLinkMockState mock_state;
void mock_state_reset(void);
