/*
 * test_pidlp_write.c — DLP write function tests.
 * Contract: §6 C3 (11 tests)
 */

#include "unity.h"
#include "pidlp.h"
#include "unifex_stubs.h"
#include "pisock_mocks.h"
#include <stdlib.h>
#include <string.h>

void write_setUp(void) {
    mock_state_reset();
    reset_result_recorder();
}

void write_tearDown(void) {}

static pilot_user make_test_pilot_user(void) {
    pilot_user u;
    memset(&u, 0, sizeof(u));
    u.password_length = 4;
    u.username = strdup("testuser");
    u.password = strdup("pass");
    u.user_id = 100;
    u.viewer_id = 200;
    u.last_sync_pc = 300;
    u.successful_sync_date = 1700000000;
    u.last_sync_date = 1700000100;
    return u;
}

static appointment make_test_appointment(void) {
    appointment a;
    memset(&a, 0, sizeof(a));
    a.event = 0;
    a.begin = (timehtm){.tm_sec=0, .tm_min=0, .tm_hour=9, .tm_mday=14,
                        .tm_mon=4, .tm_year=126, .tm_wday=3, .tm_yday=134, .tm_isdst=1};
    a.end = (timehtm){.tm_sec=0, .tm_min=0, .tm_hour=10, .tm_mday=14,
                      .tm_mon=4, .tm_year=126, .tm_wday=3, .tm_yday=134, .tm_isdst=1};
    a.alarm = 1;
    a.alarm_advance = 5;
    a.alarm_advance_units = 0;
    a.repeat_type = 0;
    a.repeat_forever = 0;
    a.repeat_end = (timehtm){0};
    a.repeat_frequency = 0;
    a.repeat_day = 0;
    static int days[7];
    memset(days, 0, sizeof(days));
    a.repeat_days = days;
    a.repeat_days_length = 7;
    a.repeat_weekstart = 0;
    a.exceptions_count = 0;
    a.exceptions_actual = NULL;
    a.exceptions_actual_length = 0;
    a.description = strdup("Test appointment");
    a.note = strdup("Test note");
    a.location = NULL;
    a.rec_id = 0;
    return a;
}

void test_write_user_info_field_mapping(void) {
    UnifexEnv env;
    pilot_user u = make_test_pilot_user();
    mock_state.dlp_WriteUserInfo_return = 0;

    write_user_info(&env, 42, u);

    TEST_ASSERT_EQUAL(1, mock_state.dlp_WriteUserInfo_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    free(u.username);
    free(u.password);
}

void test_write_user_info_success(void) {
    UnifexEnv env;
    pilot_user u = make_test_pilot_user();
    mock_state.dlp_WriteUserInfo_return = 0;

    UNIFEX_TERM result = write_user_info(&env, 42, u);

    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    free(u.username);
    free(u.password);
}

void test_write_user_info_error(void) {
    UnifexEnv env;
    pilot_user u = make_test_pilot_user();
    mock_state.dlp_WriteUserInfo_return = -1;

    UNIFEX_TERM result = write_user_info(&env, 42, u);

    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(-1, result_recorder.last_result.data.result);
    free(u.username);
    free(u.password);
}

void test_write_datebook_record_success(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    mock_state.pack_Appointment_return = 16;
    mock_state.dlp_WriteRecord_return = 0;
    mock_state.mock_new_rec_id = 42;

    UNIFEX_TERM result = write_datebook_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.pack_Appointment_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.dlp_WriteRecord_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_free_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(42, result_recorder.last_result.data.rec_id);
    free(a.description);
    free(a.note);
}

void test_write_datebook_record_pack_failure(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    mock_state.pack_Appointment_return = -1;

    UNIFEX_TERM result = write_datebook_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.pack_Appointment_call_count);
    TEST_ASSERT_EQUAL(0, mock_state.dlp_WriteRecord_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    free(a.description);
    free(a.note);
}

void test_write_datebook_record_note_blank(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    free(a.note);
    a.note = strdup("   ");
    mock_state.pack_Appointment_return = 16;
    mock_state.dlp_WriteRecord_return = 0;

    UNIFEX_TERM result = write_datebook_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(1, mock_state.pack_Appointment_call_count);
    free(a.description);
    free(a.note);
}

void test_write_datebook_record_buffer_freed(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    mock_state.pack_Appointment_return = 16;
    mock_state.dlp_WriteRecord_return = 0;

    write_datebook_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_new_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_free_call_count);
    free(a.description);
    free(a.note);
}

void test_write_calendar_record_success(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    a.location = strdup("Conference Room");
    mock_state.pack_CalendarEvent_return = 16;
    mock_state.dlp_WriteRecord_return = 0;
    mock_state.mock_new_rec_id = 99;

    UNIFEX_TERM result = write_calendar_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.new_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pack_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.dlp_WriteRecord_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.free_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_free_call_count);
    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    TEST_ASSERT_EQUAL(99, result_recorder.last_result.data.rec_id);
    free(a.description);
    free(a.note);
    free(a.location);
}

void test_write_calendar_record_pack_failure(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    mock_state.pack_CalendarEvent_return = -1;

    UNIFEX_TERM result = write_calendar_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.pack_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(0, mock_state.dlp_WriteRecord_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.free_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_free_call_count);
    TEST_ASSERT_EQUAL(RESULT_ERROR, result_recorder.last_result.data.kind);
    free(a.description);
    free(a.note);
}

void test_write_calendar_record_location_blank(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    a.location = strdup("   ");
    mock_state.pack_CalendarEvent_return = 16;
    mock_state.dlp_WriteRecord_return = 0;

    UNIFEX_TERM result = write_calendar_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(RESULT_OK, result_recorder.last_result.data.kind);
    free(a.description);
    free(a.note);
    free(a.location);
}

void test_write_calendar_record_resources_freed(void) {
    UnifexEnv env;
    appointment a = make_test_appointment();
    a.location = strdup("Room A");
    mock_state.pack_CalendarEvent_return = 16;
    mock_state.dlp_WriteRecord_return = 0;

    write_calendar_record(&env, 10, 1, a);

    TEST_ASSERT_EQUAL(1, mock_state.new_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.free_CalendarEvent_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_new_call_count);
    TEST_ASSERT_EQUAL(1, mock_state.pi_buffer_free_call_count);
    free(a.description);
    free(a.note);
    free(a.location);
}
