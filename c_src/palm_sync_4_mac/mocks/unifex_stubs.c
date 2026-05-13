/*
 * unifex_stubs.c — Stub implementations for Unifex result builder functions.
 * Contract: §5 Unifex Env Stub
 *
 * Each *_result_ok and *_result_error function records which result variant
 * was called and the parameters into the result_recorder.
 */

#include "pidlp.h"

ResultRecorder result_recorder;

void reset_result_recorder(void) {
    if (result_recorder.last_result.data.message) {
        free(result_recorder.last_result.data.message);
    }
    memset(&result_recorder, 0, sizeof(result_recorder));
}

UNIFEX_TERM make_ok_term(int client_sd, int parent_sd, int result,
                         int db_handle, int rec_id, uint64_t palm_date_time) {
    UNIFEX_TERM term;
    term.data.kind = RESULT_OK;
    term.data.client_sd = client_sd;
    term.data.parent_sd = parent_sd;
    term.data.result = result;
    term.data.db_handle = db_handle;
    term.data.rec_id = rec_id;
    term.data.palm_date_time = palm_date_time;
    term.data.message = NULL;
    result_recorder.last_result = term;
    result_recorder.result_ok_call_count++;
    return term;
}

UNIFEX_TERM make_error_term(int client_sd, int parent_sd, int result,
                            const char *message) {
    UNIFEX_TERM term;
    term.data.kind = RESULT_ERROR;
    term.data.client_sd = client_sd;
    term.data.parent_sd = parent_sd;
    term.data.result = result;
    term.data.db_handle = 0;
    term.data.rec_id = 0;
    term.data.palm_date_time = 0;
    term.data.message = message ? strdup(message) : NULL;
    result_recorder.last_result = term;
    result_recorder.result_error_call_count++;
    return term;
}

/* pilot_connect */
UNIFEX_TERM pilot_connect_result_ok(UnifexEnv *env, int client_sd, int parent_sd) {
    (void)env;
    return make_ok_term(client_sd, parent_sd, 0, 0, 0, 0);
}

UNIFEX_TERM pilot_connect_result_error(UnifexEnv *env, int client_sd, int parent_sd, char const *message) {
    (void)env;
    return make_error_term(client_sd, parent_sd, 0, message);
}

/* pilot_disconnect */
UNIFEX_TERM pilot_disconnect_result_ok(UnifexEnv *env, int client_sd, int parent_sd) {
    (void)env;
    return make_ok_term(client_sd, parent_sd, 0, 0, 0, 0);
}

/* open_conduit */
UNIFEX_TERM open_conduit_result_ok(UnifexEnv *env, int client_sd, int result) {
    (void)env;
    return make_ok_term(client_sd, -1, result, 0, 0, 0);
}

UNIFEX_TERM open_conduit_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* open_db */
UNIFEX_TERM open_db_result_ok(UnifexEnv *env, int client_sd, int db_handle) {
    (void)env;
    return make_ok_term(client_sd, -1, 0, db_handle, 0, 0);
}

UNIFEX_TERM open_db_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* close_db */
UNIFEX_TERM close_db_result_ok(UnifexEnv *env, int client_sd) {
    (void)env;
    return make_ok_term(client_sd, -1, 0, 0, 0, 0);
}

/* end_of_sync */
UNIFEX_TERM end_of_sync_result_ok(UnifexEnv *env, int client_sd, int result) {
    (void)env;
    return make_ok_term(client_sd, -1, result, 0, 0, 0);
}

UNIFEX_TERM end_of_sync_result_error(UnifexEnv *env, int client_sd, int result) {
    (void)env;
    return make_error_term(client_sd, -1, result, NULL);
}

/* read_sysinfo */
UNIFEX_TERM read_sysinfo_result_ok(UnifexEnv *env, int client_sd, struct sys_info_t sys_info) {
    (void)env;
    (void)sys_info;
    return make_ok_term(client_sd, -1, 0, 0, 0, 0);
}

UNIFEX_TERM read_sysinfo_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* get_sys_date_time */
UNIFEX_TERM get_sys_date_time_result_ok(UnifexEnv *env, int client_sd, uint64_t palm_date_time) {
    (void)env;
    return make_ok_term(client_sd, -1, 0, 0, 0, palm_date_time);
}

UNIFEX_TERM get_sys_date_time_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* set_sys_date_time */
UNIFEX_TERM set_sys_date_time_result_ok(UnifexEnv *env, int client_sd) {
    (void)env;
    return make_ok_term(client_sd, -1, 0, 0, 0, 0);
}

UNIFEX_TERM set_sys_date_time_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* read_user_info */
UNIFEX_TERM read_user_info_result_ok(UnifexEnv *env, int client_sd, struct pilot_user_t user_info) {
    (void)env;
    (void)user_info;
    return make_ok_term(client_sd, -1, 0, 0, 0, 0);
}

UNIFEX_TERM read_user_info_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* write_user_info */
UNIFEX_TERM write_user_info_result_ok(UnifexEnv *env, int client_sd) {
    (void)env;
    return make_ok_term(client_sd, -1, 0, 0, 0, 0);
}

UNIFEX_TERM write_user_info_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* write_datebook_record */
UNIFEX_TERM write_datebook_record_result_ok(UnifexEnv *env, int client_sd, int result, int rec_id) {
    (void)env;
    return make_ok_term(client_sd, -1, result, 0, rec_id, 0);
}

UNIFEX_TERM write_datebook_record_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}

/* write_calendar_record */
UNIFEX_TERM write_calendar_record_result_ok(UnifexEnv *env, int client_sd, int result, int rec_id) {
    (void)env;
    return make_ok_term(client_sd, -1, result, 0, rec_id, 0);
}

UNIFEX_TERM write_calendar_record_result_error(UnifexEnv *env, int client_sd, int result, char const *message) {
    (void)env;
    return make_error_term(client_sd, -1, result, message);
}
