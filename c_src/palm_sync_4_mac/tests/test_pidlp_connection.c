/*
 * test_pidlp_connection.c — Connection flow tests.
 * Contract: §6 C4 (19 tests)
 */

#include "unity.h"
#include "pidlp.h"
#include "unifex_stubs.h"
#include "pisock_mocks.h"
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static char *saved_pilotport = NULL;

void connection_setUp(void) {
    mock_state_reset();
    reset_result_recorder();
    saved_pilotport = NULL;
    char *env_val = getenv("PILOTPORT");
    if (env_val) {
        saved_pilotport = strdup(env_val);
    }
    unsetenv("PILOTPORT");
}

void connection_tearDown(void) {
    if (saved_pilotport) {
        setenv("PILOTPORT", saved_pilotport, 1);
        free(saved_pilotport);
        saved_pilotport = NULL;
    }
}

void test_pilot_connect_null_port_uses_default(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = 0;
    mock_state.pi_listen_return = 0;
    mock_state.pi_accept_to_return = 5;
    mock_state.dlp_OpenConduit_return = 0;

    UNIFEX_TERM result = pilot_connect(&env, NULL, 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
}

void test_pilot_connect_stat_fails(void) {
    UnifexEnv env;
    unsetenv("PILOTPORT");
    mock_state.pi_socket_return = 3;

    UNIFEX_TERM result = pilot_connect(&env, NULL, 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
}

void test_pilot_connect_socket_fails(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = -1;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(0, mock_state.pi_bind_call_count);
}

void test_pilot_connect_bind_fails_enoent(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = -1;
    errno = ENOENT;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_bind_fails_eacces(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = -1;
    errno = EACCES;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_bind_fails_enodev(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = -1;
    errno = ENODEV;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_bind_fails_eisdir(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = -1;
    errno = EISDIR;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_bind_fails_closes_sockets(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = -1;
    errno = ENOENT;

    pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_listen_fails(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = 0;
    mock_state.pi_listen_return = -1;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_accept_fails(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = 0;
    mock_state.pi_listen_return = 0;
    mock_state.pi_accept_to_return = -1;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
}

void test_pilot_connect_success(void) {
    UnifexEnv env;
    mock_state.pi_socket_return = 3;
    mock_state.pi_bind_return = 0;
    mock_state.pi_listen_return = 0;
    mock_state.pi_accept_to_return = 5;
    mock_state.dlp_OpenConduit_return = 0;

    UNIFEX_TERM result = pilot_connect(&env, "/dev/pilot", 0);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_OpenConduit_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
    TEST_ASSERT_EQUAL(3, result_recorder.last_result.data.parent_sd);
}

void test_pilot_disconnect(void) {
    UnifexEnv env;

    UNIFEX_TERM result = pilot_disconnect(&env, 5, 3);

    TEST_ASSERT_EQUAL(2, mock_state.pi_close_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
    TEST_ASSERT_EQUAL(3, result_recorder.last_result.data.parent_sd);
}

void test_open_conduit_success(void) {
    UnifexEnv env;
    mock_state.dlp_OpenConduit_return = 0;

    UNIFEX_TERM result = open_conduit(&env, 5);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_OpenConduit_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
}

void test_open_conduit_error(void) {
    UnifexEnv env;
    mock_state.dlp_OpenConduit_return = -1;

    UNIFEX_TERM result = open_conduit(&env, 5);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_OpenConduit_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}

void test_open_db_success(void) {
    UnifexEnv env;
    mock_state.dlp_OpenDB_return = 0;

    UNIFEX_TERM result = open_db(&env, 5, 0, 1, "TestDB");

    TEST_ASSERT_EQUAL(1, mock_state.dlp_OpenDB_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
}

void test_open_db_error(void) {
    UnifexEnv env;
    mock_state.dlp_OpenDB_return = -1;

    UNIFEX_TERM result = open_db(&env, 5, 0, 1, "TestDB");

    TEST_ASSERT_EQUAL(1, mock_state.dlp_OpenDB_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}

void test_close_db(void) {
    UnifexEnv env;
    mock_state.dlp_CloseDB_return = 0;

    UNIFEX_TERM result = close_db(&env, 5, 1);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_CloseDB_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
}

void test_end_of_sync_success(void) {
    UnifexEnv env;
    mock_state.dlp_EndOfSync_return = 0;

    UNIFEX_TERM result = end_of_sync(&env, 5, 0);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_EndOfSync_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(5, result_recorder.last_result.data.client_sd);
}

void test_end_of_sync_error(void) {
    UnifexEnv env;
    mock_state.dlp_EndOfSync_return = -1;

    UNIFEX_TERM result = end_of_sync(&env, 5, 0);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_EndOfSync_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}
