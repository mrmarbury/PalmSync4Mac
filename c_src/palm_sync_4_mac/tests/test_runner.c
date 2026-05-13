/* test_runner.c — Unity main() runner for all pidlp C tests. */

#include "unity.h"
#include "unifex_stubs.h"
#include "pisock_mocks.h"
#include <stdlib.h>

extern void helpers_setUp(void);
extern void helpers_tearDown(void);
extern void read_setUp(void);
extern void read_tearDown(void);
extern void write_setUp(void);
extern void write_tearDown(void);
extern void connection_setUp(void);
extern void connection_tearDown(void);

static int current_group;

void setUp(void) {
    switch (current_group) {
    case 0: helpers_setUp(); break;
    case 1: read_setUp(); break;
    case 2: write_setUp(); break;
    case 3: connection_setUp(); break;
    }
}

void tearDown(void) {
    switch (current_group) {
    case 0: helpers_tearDown(); break;
    case 1: read_tearDown(); break;
    case 2: write_tearDown(); break;
    case 3: connection_tearDown(); break;
    }
}

extern void test_is_blank_null(void);
extern void test_is_blank_empty(void);
extern void test_is_blank_whitespace_only(void);
extern void test_is_blank_nonwhitespace(void);
extern void test_is_blank_mixed(void);
extern void test_timehtm_to_tm_all_fields(void);
extern void test_timehtm_to_tm_zeroed(void);
extern void test_timehtm_list_null_input(void);
extern void test_timehtm_list_zero_count(void);
extern void test_timehtm_list_allocation(void);
extern void test_timehtm_list_maps_each_element(void);

extern void test_read_sysinfo_success(void);
extern void test_read_sysinfo_error(void);
extern void test_get_sys_date_time_success(void);
extern void test_get_sys_date_time_error(void);
extern void test_read_user_info_success(void);
extern void test_read_user_info_error(void);

extern void test_write_user_info_field_mapping(void);
extern void test_write_user_info_success(void);
extern void test_write_user_info_error(void);
extern void test_write_datebook_record_success(void);
extern void test_write_datebook_record_pack_failure(void);
extern void test_write_datebook_record_note_blank(void);
extern void test_write_datebook_record_buffer_freed(void);
extern void test_write_calendar_record_success(void);
extern void test_write_calendar_record_pack_failure(void);
extern void test_write_calendar_record_location_blank(void);
extern void test_write_calendar_record_resources_freed(void);

extern void test_pilot_connect_null_port_uses_default(void);
extern void test_pilot_connect_stat_fails(void);
extern void test_pilot_connect_socket_fails(void);
extern void test_pilot_connect_bind_fails_enoent(void);
extern void test_pilot_connect_bind_fails_eacces(void);
extern void test_pilot_connect_bind_fails_enodev(void);
extern void test_pilot_connect_bind_fails_eisdir(void);
extern void test_pilot_connect_bind_fails_closes_sockets(void);
extern void test_pilot_connect_listen_fails(void);
extern void test_pilot_connect_accept_fails(void);
extern void test_pilot_connect_success(void);
extern void test_pilot_disconnect(void);
extern void test_open_conduit_success(void);
extern void test_open_conduit_error(void);
extern void test_open_db_success(void);
extern void test_open_db_error(void);
extern void test_close_db(void);
extern void test_end_of_sync_success(void);
extern void test_end_of_sync_error(void);

int main(void) {
    UNITY_BEGIN();

    current_group = 0;
    RUN_TEST(test_is_blank_null);
    RUN_TEST(test_is_blank_empty);
    RUN_TEST(test_is_blank_whitespace_only);
    RUN_TEST(test_is_blank_nonwhitespace);
    RUN_TEST(test_is_blank_mixed);
    RUN_TEST(test_timehtm_to_tm_all_fields);
    RUN_TEST(test_timehtm_to_tm_zeroed);
    RUN_TEST(test_timehtm_list_null_input);
    RUN_TEST(test_timehtm_list_zero_count);
    RUN_TEST(test_timehtm_list_allocation);
    RUN_TEST(test_timehtm_list_maps_each_element);

    current_group = 1;
    RUN_TEST(test_read_sysinfo_success);
    RUN_TEST(test_read_sysinfo_error);
    RUN_TEST(test_get_sys_date_time_success);
    RUN_TEST(test_get_sys_date_time_error);
    RUN_TEST(test_read_user_info_success);
    RUN_TEST(test_read_user_info_error);

    current_group = 2;
    RUN_TEST(test_write_user_info_field_mapping);
    RUN_TEST(test_write_user_info_success);
    RUN_TEST(test_write_user_info_error);
    RUN_TEST(test_write_datebook_record_success);
    RUN_TEST(test_write_datebook_record_pack_failure);
    RUN_TEST(test_write_datebook_record_note_blank);
    RUN_TEST(test_write_datebook_record_buffer_freed);
    RUN_TEST(test_write_calendar_record_success);
    RUN_TEST(test_write_calendar_record_pack_failure);
    RUN_TEST(test_write_calendar_record_location_blank);
    RUN_TEST(test_write_calendar_record_resources_freed);

    current_group = 3;
    RUN_TEST(test_pilot_connect_null_port_uses_default);
    RUN_TEST(test_pilot_connect_stat_fails);
    RUN_TEST(test_pilot_connect_socket_fails);
    RUN_TEST(test_pilot_connect_bind_fails_enoent);
    RUN_TEST(test_pilot_connect_bind_fails_eacces);
    RUN_TEST(test_pilot_connect_bind_fails_enodev);
    RUN_TEST(test_pilot_connect_bind_fails_eisdir);
    RUN_TEST(test_pilot_connect_bind_fails_closes_sockets);
    RUN_TEST(test_pilot_connect_listen_fails);
    RUN_TEST(test_pilot_connect_accept_fails);
    RUN_TEST(test_pilot_connect_success);
    RUN_TEST(test_pilot_disconnect);
    RUN_TEST(test_open_conduit_success);
    RUN_TEST(test_open_conduit_error);
    RUN_TEST(test_open_db_success);
    RUN_TEST(test_open_db_error);
    RUN_TEST(test_close_db);
    RUN_TEST(test_end_of_sync_success);
    RUN_TEST(test_end_of_sync_error);

    return UNITY_END();
}
