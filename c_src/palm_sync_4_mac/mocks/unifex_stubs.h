#pragma once

/*
 * unifex_stubs.h — Minimal stubs for Unifex/ErlNIF types and result builders.
 *
 * For C unit tests, we provide stub implementations of the *_result_ok and
 * *_result_error functions that record which result variant was called and
 * the parameters, so tests can verify the NIF function took the correct branch.
 * Contract: §5 Unifex Env Stub
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    RESULT_NONE = 0,
    RESULT_OK,
    RESULT_ERROR
} ResultKind;

typedef struct {
    ResultKind kind;
    int client_sd;
    int parent_sd;
    int result;
    int db_handle;
    int rec_id;
    uint64_t palm_date_time;
    char *message;
} ResultData;

typedef struct UnifexEnv {
    int _placeholder;
} UnifexEnv;

typedef struct UNIFEX_TERM {
    ResultData data;
} UNIFEX_TERM;

typedef struct {
    UNIFEX_TERM last_result;
    int result_ok_call_count;
    int result_error_call_count;
} ResultRecorder;

extern ResultRecorder result_recorder;

void reset_result_recorder(void);

UNIFEX_TERM make_ok_term(int client_sd, int parent_sd, int result,
                         int db_handle, int rec_id, uint64_t palm_date_time);
UNIFEX_TERM make_error_term(int client_sd, int parent_sd, int result,
                            const char *message);

struct sys_info_t;
struct pilot_user_t;

extern struct sys_info_t *captured_sys_info;
extern struct pilot_user_t *captured_pilot_user;

void free_captured_data(void);
