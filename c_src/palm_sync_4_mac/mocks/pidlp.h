#pragma once

/*
 * Test override for pidlp.h — replaces the Unifex/ErlNIF chain.
 * When compiling for tests, -I mocks/ comes before -I palm_sync_4_mac/,
 * so #include "pidlp.h" picks up THIS file instead of the real one.
 * Contract: §5 Unifex Env Stub
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>

#include "unifex_stubs.h"
#include "pisock_mocks.h"

struct pilot_user_t {
    uint64_t password_length;
    char *username;
    char *password;
    uint64_t user_id;
    uint64_t viewer_id;
    uint64_t last_sync_pc;
    uint64_t successful_sync_date;
    uint64_t last_sync_date;
};
typedef struct pilot_user_t pilot_user;

struct sys_info_t {
    uint64_t rom_version;
    uint64_t locale;
    unsigned int prod_id_length;
    char *prod_id;
    unsigned int dlp_major_version;
    unsigned int dlp_minor_version;
    unsigned int compat_major_version;
    unsigned int compat_minor_version;
    uint64_t max_rec_size;
};
typedef struct sys_info_t sys_info;

struct timehtm_t {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};
typedef struct timehtm_t timehtm;

struct appointment_t {
    int event;
    timehtm begin;
    timehtm end;
    int alarm;
    int alarm_advance;
    int alarm_advance_units;
    int repeat_type;
    int repeat_forever;
    timehtm repeat_end;
    int repeat_frequency;
    int repeat_day;
    int *repeat_days;
    unsigned int repeat_days_length;
    int repeat_weekstart;
    int exceptions_count;
    timehtm *exceptions_actual;
    unsigned int exceptions_actual_length;
    char *description;
    char *note;
    char *location;
    int rec_id;
};
typedef struct appointment_t appointment;

bool is_blank(const char *str);
struct tm timehtm_to_tm(timehtm t);
struct tm *timehtm_list_to_tm_list(timehtm *src, unsigned int count);

UNIFEX_TERM pilot_connect(UnifexEnv *env, char *port, int wait_timeout);
UNIFEX_TERM pilot_disconnect(UnifexEnv *env, int client_sd, int parent_sd);
UNIFEX_TERM open_conduit(UnifexEnv *env, int client_sd);
UNIFEX_TERM open_db(UnifexEnv *env, int client_sd, int card_no, int mode, char *dbname);
UNIFEX_TERM close_db(UnifexEnv *env, int client_sd, int db_handle);
UNIFEX_TERM end_of_sync(UnifexEnv *env, int client_sd, int status);
UNIFEX_TERM read_sysinfo(UnifexEnv *env, int client_sd);
UNIFEX_TERM get_sys_date_time(UnifexEnv *env, int client_sd);
UNIFEX_TERM set_sys_date_time(UnifexEnv *env, int client_sd, uint64_t palm_date_time);
UNIFEX_TERM read_user_info(UnifexEnv *env, int client_sd);
UNIFEX_TERM write_user_info(UnifexEnv *env, int client_sd, pilot_user user_info);
UNIFEX_TERM write_datebook_record(UnifexEnv *env, int client_sd, int db_handle, appointment record_data);
UNIFEX_TERM write_calendar_record(UnifexEnv *env, int client_sd, int db_handle, appointment record_data);

UNIFEX_TERM pilot_connect_result_ok(UnifexEnv *env, int client_sd, int parent_sd);
UNIFEX_TERM pilot_connect_result_error(UnifexEnv *env, int client_sd, int parent_sd, char const *message);
UNIFEX_TERM pilot_disconnect_result_ok(UnifexEnv *env, int client_sd, int parent_sd);
UNIFEX_TERM open_conduit_result_ok(UnifexEnv *env, int client_sd, int result);
UNIFEX_TERM open_conduit_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM open_db_result_ok(UnifexEnv *env, int client_sd, int db_handle);
UNIFEX_TERM open_db_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM close_db_result_ok(UnifexEnv *env, int client_sd);
UNIFEX_TERM end_of_sync_result_ok(UnifexEnv *env, int client_sd, int result);
UNIFEX_TERM end_of_sync_result_error(UnifexEnv *env, int client_sd, int result);
UNIFEX_TERM read_sysinfo_result_ok(UnifexEnv *env, int client_sd, sys_info sys_info);
UNIFEX_TERM read_sysinfo_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM get_sys_date_time_result_ok(UnifexEnv *env, int client_sd, uint64_t palm_date_time);
UNIFEX_TERM get_sys_date_time_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM set_sys_date_time_result_ok(UnifexEnv *env, int client_sd);
UNIFEX_TERM set_sys_date_time_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM read_user_info_result_ok(UnifexEnv *env, int client_sd, pilot_user user_info);
UNIFEX_TERM read_user_info_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM write_user_info_result_ok(UnifexEnv *env, int client_sd);
UNIFEX_TERM write_user_info_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM write_datebook_record_result_ok(UnifexEnv *env, int client_sd, int result, int rec_id);
UNIFEX_TERM write_datebook_record_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
UNIFEX_TERM write_calendar_record_result_ok(UnifexEnv *env, int client_sd, int result, int rec_id);
UNIFEX_TERM write_calendar_record_result_error(UnifexEnv *env, int client_sd, int result, char const *message);
