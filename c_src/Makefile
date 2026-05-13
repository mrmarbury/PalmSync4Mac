CC      ?= gcc
CSTD    ?= c11
CFLAGS  := -std=$(CSTD) -g -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable

PILOT_LINK_INCLUDE ?= /opt/homebrew/include

SRC_DIR   = palm_sync_4_mac
MOCK_DIR  = $(SRC_DIR)/mocks
TEST_DIR  = $(SRC_DIR)/tests
UNITY_DIR = $(MOCK_DIR)/unity
BUILD_DIR = build

INCLUDES = -I$(MOCK_DIR) \
           -I$(UNITY_DIR) \
           -I$(PILOT_LINK_INCLUDE) \
           -I$(SRC_DIR) \
           -I$(SRC_DIR)/_generated/nif

FORCE_INCLUDE = -include $(MOCK_DIR)/pidlp.h

PIDLP_SRC    = $(SRC_DIR)/pidlp.c
MOCK_SRC     = $(MOCK_DIR)/pisock_mocks.c
STUBS_SRC    = $(MOCK_DIR)/unifex_stubs.c
UNITY_SRC    = $(UNITY_DIR)/unity.c

TEST_HELPERS     = $(TEST_DIR)/test_pidlp_helpers.c
TEST_READ        = $(TEST_DIR)/test_pidlp_read.c
TEST_WRITE       = $(TEST_DIR)/test_pidlp_write.c
TEST_CONNECTION  = $(TEST_DIR)/test_pidlp_connection.c
TEST_RUNNER      = $(TEST_DIR)/test_runner.c

PIDLP_O       = $(BUILD_DIR)/pidlp.o
MOCK_O        = $(BUILD_DIR)/pisock_mocks.o
STUBS_O       = $(BUILD_DIR)/unifex_stubs.o
UNITY_O       = $(BUILD_DIR)/unity.o
TEST_HELPERS_O    = $(BUILD_DIR)/test_helpers.o
TEST_READ_O       = $(BUILD_DIR)/test_read.o
TEST_WRITE_O      = $(BUILD_DIR)/test_write.o
TEST_CONNECTION_O = $(BUILD_DIR)/test_connection.o
TEST_RUNNER_O     = $(BUILD_DIR)/test_runner.o

TEST_BIN = $(BUILD_DIR)/test_pidlp

.PHONY: test clean

test: $(TEST_BIN)
	@echo "Running C unit tests..."
	@./$(TEST_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(PIDLP_O): $(PIDLP_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) $(FORCE_INCLUDE) -DTEST_BUILD -c $< -o $@

$(MOCK_O): $(MOCK_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(STUBS_O): $(STUBS_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(UNITY_O): $(UNITY_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TEST_HELPERS_O): $(TEST_HELPERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TEST_READ_O): $(TEST_READ) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TEST_WRITE_O): $(TEST_WRITE) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TEST_CONNECTION_O): $(TEST_CONNECTION) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TEST_RUNNER_O): $(TEST_RUNNER) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TEST_BIN): $(PIDLP_O) $(MOCK_O) $(STUBS_O) $(UNITY_O) \
             $(TEST_HELPERS_O) $(TEST_READ_O) $(TEST_WRITE_O) \
             $(TEST_CONNECTION_O) $(TEST_RUNNER_O)
	$(CC) $^ -o $@

clean:
	rm -rf $(BUILD_DIR)
