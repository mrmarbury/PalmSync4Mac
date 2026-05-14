/*
 * test_pidlp_read.c — DLP read function tests.
 * Contract: §6 C2 (6 tests)
 */

#include "unity.h"
#include "pidlp.h"
#include "unifex_stubs.h"
#include "pisock_mocks.h"
#include <stdlib.h>
#include <string.h>

void read_setUp(void) {
    mock_state_reset();
    reset_result_recorder();
}

void read_tearDown(void) {}

void test_read_sysinfo_success(void) {
    UnifexEnv env;
    mock_state.dlp_ReadSysInfo_return = 0;
    memset(&mock_state.mock_sys_info, 0, sizeof(mock_state.mock_sys_info));
    mock_state.mock_sys_info.romVersion = 0x05000000;
    mock_state.mock_sys_info.locale = 1;
    mock_state.mock_sys_info.prodIDLength = 5;
    strncpy(mock_state.mock_sys_info.prodID, "TestP", sizeof(mock_state.mock_sys_info.prodID) - 1);
    mock_state.mock_sys_info.dlpMajorVersion = 1;
    mock_state.mock_sys_info.dlpMinorVersion = 4;
    mock_state.mock_sys_info.compatMajorVersion = 1;
    mock_state.mock_sys_info.compatMinorVersion = 2;
    mock_state.mock_sys_info.maxRecSize = 0xFFFF;

    UNIFEX_TERM result = read_sysinfo(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_ReadSysInfo_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(42, result_recorder.last_result.data.client_sd);
}

void test_read_sysinfo_field_mapping(void) {
    UnifexEnv env;
    mock_state.dlp_ReadSysInfo_return = 0;
    memset(&mock_state.mock_sys_info, 0, sizeof(mock_state.mock_sys_info));
    mock_state.mock_sys_info.romVersion = 0x05000000;
    mock_state.mock_sys_info.locale = 1;
    mock_state.mock_sys_info.prodIDLength = 5;
    strncpy(mock_state.mock_sys_info.prodID, "TestP", sizeof(mock_state.mock_sys_info.prodID) - 1);
    mock_state.mock_sys_info.dlpMajorVersion = 1;
    mock_state.mock_sys_info.dlpMinorVersion = 4;
    mock_state.mock_sys_info.compatMajorVersion = 1;
    mock_state.mock_sys_info.compatMinorVersion = 2;
    mock_state.mock_sys_info.maxRecSize = 0xFFFF;

    read_sysinfo(&env, 42);

    TEST_ASSERT_NOT_NULL(captured_sys_info);
    TEST_ASSERT_EQUAL_UINT64(0x05000000, captured_sys_info->rom_version);
    TEST_ASSERT_EQUAL_UINT64(1, captured_sys_info->locale);
    TEST_ASSERT_EQUAL(5, captured_sys_info->prod_id_length);
    TEST_ASSERT_EQUAL_STRING("TestP", captured_sys_info->prod_id);
    TEST_ASSERT_EQUAL(1, captured_sys_info->dlp_major_version);
    TEST_ASSERT_EQUAL(4, captured_sys_info->dlp_minor_version);
    TEST_ASSERT_EQUAL(1, captured_sys_info->compat_major_version);
    TEST_ASSERT_EQUAL(2, captured_sys_info->compat_minor_version);
    TEST_ASSERT_EQUAL_UINT64(0xFFFF, captured_sys_info->max_rec_size);
}

void test_read_sysinfo_error(void) {
    UnifexEnv env;
    mock_state.dlp_ReadSysInfo_return = -1;

    UNIFEX_TERM result = read_sysinfo(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_ReadSysInfo_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(42, result_recorder.last_result.data.client_sd);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}

void test_get_sys_date_time_success(void) {
    UnifexEnv env;
    mock_state.dlp_GetSysDateTime_return = 0;
    mock_state.mock_sys_date_time = 1700000000;

    UNIFEX_TERM result = get_sys_date_time(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_GetSysDateTime_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(1700000000, result_recorder.last_result.data.palm_date_time);
}

void test_get_sys_date_time_error(void) {
    UnifexEnv env;
    mock_state.dlp_GetSysDateTime_return = -1;

    UNIFEX_TERM result = get_sys_date_time(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_GetSysDateTime_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}

void test_read_user_info_success(void) {
    UnifexEnv env;
    mock_state.dlp_ReadUserInfo_return = 0;
    memset(&mock_state.mock_pilot_user, 0, sizeof(mock_state.mock_pilot_user));
    mock_state.mock_pilot_user.passwordLength = 4;
    strncpy(mock_state.mock_pilot_user.username, "testuser", 128);
    strncpy(mock_state.mock_pilot_user.password, "pass", 128);
    mock_state.mock_pilot_user.userID = 100;
    mock_state.mock_pilot_user.viewerID = 200;
    mock_state.mock_pilot_user.lastSyncPC = 300;
    mock_state.mock_pilot_user.successfulSyncDate = 1700000000;
    mock_state.mock_pilot_user.lastSyncDate = 1700000100;

    UNIFEX_TERM result = read_user_info(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_ReadUserInfo_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(42, result_recorder.last_result.data.client_sd);
}

void test_read_user_info_field_mapping(void) {
    UnifexEnv env;
    mock_state.dlp_ReadUserInfo_return = 0;
    memset(&mock_state.mock_pilot_user, 0, sizeof(mock_state.mock_pilot_user));
    mock_state.mock_pilot_user.passwordLength = 4;
    strncpy(mock_state.mock_pilot_user.username, "testuser", 128);
    strncpy(mock_state.mock_pilot_user.password, "pass", 128);
    mock_state.mock_pilot_user.userID = 100;
    mock_state.mock_pilot_user.viewerID = 200;
    mock_state.mock_pilot_user.lastSyncPC = 300;
    mock_state.mock_pilot_user.successfulSyncDate = 1700000000;
    mock_state.mock_pilot_user.lastSyncDate = 1700000100;

    read_user_info(&env, 42);

    TEST_ASSERT_NOT_NULL(captured_pilot_user);
    TEST_ASSERT_EQUAL_UINT64(4, captured_pilot_user->password_length);
    TEST_ASSERT_EQUAL_STRING("testuser", captured_pilot_user->username);
    TEST_ASSERT_EQUAL_STRING("pass", captured_pilot_user->password);
    TEST_ASSERT_EQUAL_UINT64(100, captured_pilot_user->user_id);
    TEST_ASSERT_EQUAL_UINT64(200, captured_pilot_user->viewer_id);
    TEST_ASSERT_EQUAL_UINT64(300, captured_pilot_user->last_sync_pc);
    TEST_ASSERT_EQUAL_UINT64(1700000000, captured_pilot_user->successful_sync_date);
    TEST_ASSERT_EQUAL_UINT64(1700000100, captured_pilot_user->last_sync_date);
}

void test_read_user_info_error(void) {
    UnifexEnv env;
    mock_state.dlp_ReadUserInfo_return = -1;

    UNIFEX_TERM result = read_user_info(&env, 42);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_ReadUserInfo_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
}
