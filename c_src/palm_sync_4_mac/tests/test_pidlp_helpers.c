/*
 * test_pidlp_helpers.c — Pure-data function tests.
 * Contract: §6 C1 (11 tests)
 * These tests call helper functions directly, no UnifexEnv or mock state needed.
 */

#include "unity.h"
#include "pidlp.h"
#include <stdlib.h>
#include <string.h>

void helpers_setUp(void) {}

void helpers_tearDown(void) {}

void test_is_blank_null(void) {
    TEST_ASSERT_TRUE(is_blank(NULL));
}

void test_is_blank_empty(void) {
    TEST_ASSERT_TRUE(is_blank(""));
}

void test_is_blank_whitespace_only(void) {
    TEST_ASSERT_TRUE(is_blank("   "));
}

void test_is_blank_nonwhitespace(void) {
    TEST_ASSERT_FALSE(is_blank("abc"));
}

void test_is_blank_mixed(void) {
    TEST_ASSERT_FALSE(is_blank("  abc  "));
}

void test_timehtm_to_tm_all_fields(void) {
    timehtm t = {.tm_sec = 30, .tm_min = 15, .tm_hour = 10,
                 .tm_mday = 14, .tm_mon = 4, .tm_year = 126,
                 .tm_wday = 3, .tm_yday = 134, .tm_isdst = 1};
    struct tm result = timehtm_to_tm(t);
    TEST_ASSERT_EQUAL(30, result.tm_sec);
    TEST_ASSERT_EQUAL(15, result.tm_min);
    TEST_ASSERT_EQUAL(10, result.tm_hour);
    TEST_ASSERT_EQUAL(14, result.tm_mday);
    TEST_ASSERT_EQUAL(4, result.tm_mon);
    TEST_ASSERT_EQUAL(126, result.tm_year);
    TEST_ASSERT_EQUAL(3, result.tm_wday);
    TEST_ASSERT_EQUAL(134, result.tm_yday);
    TEST_ASSERT_EQUAL(1, result.tm_isdst);
}

void test_timehtm_to_tm_zeroed(void) {
    timehtm t = {0};
    struct tm result = timehtm_to_tm(t);
    TEST_ASSERT_EQUAL(0, result.tm_sec);
    TEST_ASSERT_EQUAL(0, result.tm_min);
    TEST_ASSERT_EQUAL(0, result.tm_hour);
    TEST_ASSERT_EQUAL(0, result.tm_mday);
    TEST_ASSERT_EQUAL(0, result.tm_mon);
    TEST_ASSERT_EQUAL(0, result.tm_year);
    TEST_ASSERT_EQUAL(0, result.tm_wday);
    TEST_ASSERT_EQUAL(0, result.tm_yday);
    TEST_ASSERT_EQUAL(0, result.tm_isdst);
}

void test_timehtm_list_null_input(void) {
    struct tm *result = timehtm_list_to_tm_list(NULL, 5);
    TEST_ASSERT_NULL(result);
}

void test_timehtm_list_zero_count(void) {
    timehtm src[1] = {{0}};
    struct tm *result = timehtm_list_to_tm_list(src, 0);
    TEST_ASSERT_NULL(result);
}

void test_timehtm_list_allocation(void) {
    timehtm src[3] = {{0}};
    struct tm *result = timehtm_list_to_tm_list(src, 3);
    TEST_ASSERT_NOT_NULL(result);
    size_t expected_size = sizeof(struct tm) * 3;
    TEST_ASSERT_TRUE(expected_size > 0);
    free(result);
}

void test_timehtm_list_maps_each_element(void) {
    timehtm src[2] = {
        {.tm_sec = 1, .tm_min = 2, .tm_hour = 3, .tm_mday = 4,
         .tm_mon = 5, .tm_year = 6, .tm_wday = 7, .tm_yday = 8, .tm_isdst = 9},
        {.tm_sec = 10, .tm_min = 11, .tm_hour = 12, .tm_mday = 13,
         .tm_mon = 14, .tm_year = 15, .tm_wday = 16, .tm_yday = 17, .tm_isdst = 18}
    };
    struct tm *result = timehtm_list_to_tm_list(src, 2);
    TEST_ASSERT_NOT_NULL(result);
    TEST_ASSERT_EQUAL(1, result[0].tm_sec);
    TEST_ASSERT_EQUAL(2, result[0].tm_min);
    TEST_ASSERT_EQUAL(10, result[1].tm_sec);
    TEST_ASSERT_EQUAL(11, result[1].tm_min);
    free(result);
}
