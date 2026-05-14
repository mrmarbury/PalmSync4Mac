#define _POSIX_C_SOURCE 200809L /* strdup, strndup, unsetenv */

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <utime.h>

#include <stdarg.h>

#include <pi-datebook.h>
#include <pi-calendar.h>
#include <pi-dlp.h>
#include <pi-file.h>
#include <pi-memo.h>
#include <pi-socket.h>
#include <pi-source.h>

#include "pidlp.h"

bool is_blank(const char *str) {
  if (str == NULL)
    return true;

  while (*str != '\0') {
    if (!isspace((unsigned char)*str)) {
      return false;
    }
    str++;
  }

  return true;
}

/* FIXME: this might create errors when t is null */
struct tm timehtm_to_tm(timehtm t) {
  struct tm result;
  result.tm_sec = t.tm_sec;
  result.tm_min = t.tm_min;
  result.tm_hour = t.tm_hour;
  result.tm_mday = t.tm_mday;
  result.tm_mon = t.tm_mon;
  result.tm_year = t.tm_year;
  result.tm_wday = t.tm_wday;
  result.tm_yday = t.tm_yday;
  result.tm_isdst = t.tm_isdst;
  return result;
}

struct tm *timehtm_list_to_tm_list(timehtm *src, unsigned int count) {
  if (src == NULL || count == 0) {
    return NULL;
  }

  struct tm *result = malloc(sizeof(struct tm) * count);
  if (!result) {
    return NULL; // Caller must handle null
  }

  for (unsigned int i = 0; i < count; i++) {
    result[i] = timehtm_to_tm(src[i]);
  }

  return result;
}


/*pilot-connect*/
UNIFEX_TERM pilot_connect(UnifexEnv *env, char *port, int wait_timeout) {
  UNIFEX_TERM res_term = {0};
  int parent_sd = -1, /* Parent socket, formerly sd   */
      client_sd = -1, /* Client socket, formerly sd2  */
      result;
  struct stat attr;
  static char defport[] = "/dev/pilot";
  int bProceed = 1;

  if (port == NULL && (port = getenv("PILOTPORT")) == NULL) {

    int err = 0;

    port = defport;
    err = stat(port, &attr);

    /* Moved err check inside if() block - err only meaningful here */
    if (err) {
      res_term = pilot_connect_result_error(env, client_sd, parent_sd,
                                            strerror(errno));
      bProceed = 0;
    }
  }

  /* At this point, either bProceed is 0, or port != NULL, further checks are
   * unnecesary */

  if (bProceed &&
      (parent_sd = pi_socket(PI_AF_PILOT, PI_SOCK_STREAM, PI_PF_DLP)) < 0) {
    /*
                fprintf(stderr, "\n   Unable to create socket '%s'\n",
                        port ? port : getenv("PILOTPORT"));
                return -1;
    */
    /* Throw exception here to inform nature of connection failure. */
    const char *sTemplate = "Unable to create socket '%s'";
    size_t sMessage_len = strlen(sTemplate) + strlen(port) + 1;
    char *sMessage = (char *)malloc(sMessage_len);
    if (sMessage != NULL)
      snprintf(sMessage, sMessage_len, sTemplate, port);
    res_term = pilot_connect_result_error(env, client_sd, parent_sd,
                                          (sMessage != NULL) ? sMessage : port);
    if (sMessage != NULL)
      free(sMessage);

    bProceed = 0;
  }

  if (bProceed) {
    result = pi_bind(parent_sd, port);
  }

  if (bProceed && result < 0) {
    int save_errno = errno;
    const char *sTemplate = "Unable to bind to port %s - (%d) %s%s";
    const char *sFailureReason;
    char *sMessage;

    switch (save_errno) {
    case 2:
      sFailureReason = "; Device does not exist (use mknod to fix)";
      break;
    case 13:
      sFailureReason = "; Access denied on device (use chmod to fix)";
      break;
    case 19:
      sFailureReason = "; HotSync button must be pressed first";
      break;
    case 21:
      sFailureReason = "; Device name appears to be a directory";
      break;
    default:
      sFailureReason = "";
      break;
    }
    sMessage =
        (char *)malloc(strlen(sTemplate) + strlen(port) + 16 +
                       strlen(strerror(save_errno)) + strlen(sFailureReason));
    if (sMessage != NULL) {
      snprintf(sMessage,
               strlen(sTemplate) + strlen(port) + 16 +
                   strlen(strerror(save_errno)) + strlen(sFailureReason),
               sTemplate, port, save_errno, strerror(save_errno),
               sFailureReason);
      res_term =
          pilot_connect_result_error(env, client_sd, parent_sd, sMessage);
      free(sMessage);
    } else {
      /* Unable to malloc(), inform of errno string */
      res_term = pilot_connect_result_error(env, client_sd, parent_sd,
                                            strerror(save_errno));
    }

    pi_close(parent_sd);
    pi_close(client_sd);
    bProceed = 0;
  }

  if (bProceed && pi_listen(parent_sd, 1) == -1) {
    char error_buffer[100];
    snprintf(error_buffer, sizeof(error_buffer), "\n  Error listening on %s\n",
             port);
    res_term =
        pilot_connect_result_error(env, client_sd, parent_sd, error_buffer);
    pi_close(parent_sd);
    pi_close(client_sd);
    bProceed = 0;
  }

  if (bProceed) {
    client_sd = pi_accept_to(parent_sd, 0, 0, wait_timeout);
    if (client_sd == -1) {
      char error_buffer[100];
      snprintf(error_buffer, sizeof(error_buffer),
               "\n  Error read system info on %s\n", port);
      res_term =
          pilot_connect_result_error(env, client_sd, parent_sd, error_buffer);
      pi_close(parent_sd);
      pi_close(client_sd);
      bProceed = 0;
    }
  }
  if (bProceed) {
    dlp_OpenConduit(client_sd);
    res_term = pilot_connect_result_ok(env, client_sd, parent_sd);
  }
  return res_term;
}

UNIFEX_TERM pilot_disconnect(UnifexEnv *env, int client_sd, int parent_sd) {
  pi_close(client_sd);
  pi_close(parent_sd);
  return pilot_disconnect_result_ok(env, client_sd, parent_sd);
}

UNIFEX_TERM open_conduit(UnifexEnv *env, int client_sd) {
  UNIFEX_TERM res_term;
  int result = dlp_OpenConduit(client_sd);
  if (result < 0) {
    res_term = open_conduit_result_error(env, client_sd, result,
                                         "Unable to open conduit");
  } else {
    res_term = open_conduit_result_ok(env, client_sd, result);
  }
  return res_term;
}

UNIFEX_TERM open_db(UnifexEnv *env, int client_sd, int cardno, int mode,
                    char *dbname) {
  UNIFEX_TERM res_term;
  int db_handle;

  int result = dlp_OpenDB(client_sd, cardno, mode, dbname, &db_handle);
  if (result < 0) {
    res_term =
        open_db_result_error(env, client_sd, result, "Unable to open database");
  } else {
    res_term = open_db_result_ok(env, client_sd, db_handle);
  }
  return res_term;
}

UNIFEX_TERM close_db(UnifexEnv *env, int client_sd, int dbhandle) {
  dlp_CloseDB(client_sd, dbhandle);
  return close_db_result_ok(env, client_sd);
}

UNIFEX_TERM end_of_sync(UnifexEnv *env, int client_sd, int status) {
  UNIFEX_TERM res_term;
  int result = dlp_EndOfSync(client_sd, status);
  if (result < 0) {
    res_term = end_of_sync_result_error(env, client_sd, result);
  } else {
    res_term = end_of_sync_result_ok(env, client_sd, result);
  }
  return res_term;
}

UNIFEX_TERM read_sysinfo(UnifexEnv *env, int client_sd) {
  UNIFEX_TERM res_term;
  struct SysInfo sys_info;
  struct sys_info_t palm_info;
  char *prod_id_copy = NULL;

  int result = dlp_ReadSysInfo(client_sd, &sys_info);
  if (result < 0) {
    return read_sysinfo_result_error(env, client_sd, result,
                                     "Unable to get system info");
  }

  prod_id_copy = strndup(sys_info.prodID, sys_info.prodIDLength);
  if (prod_id_copy == NULL) {
    return read_sysinfo_result_error(env, client_sd, -1,
                                     "Out of memory");
  }

  palm_info.rom_version = (uint64_t)sys_info.romVersion;
  palm_info.locale = (uint64_t)sys_info.locale;
  palm_info.prod_id_length = (unsigned int)sys_info.prodIDLength;
  palm_info.prod_id = prod_id_copy;
  palm_info.dlp_major_version = (unsigned int)sys_info.dlpMajorVersion;
  palm_info.dlp_minor_version = (unsigned int)sys_info.dlpMinorVersion;
  palm_info.compat_major_version = (unsigned int)sys_info.compatMajorVersion;
  palm_info.compat_minor_version = (unsigned int)sys_info.compatMinorVersion;
  palm_info.max_rec_size = (uint64_t)sys_info.maxRecSize;

  res_term = read_sysinfo_result_ok(env, client_sd, palm_info);
  free(prod_id_copy);
  return res_term;
}

/*
 * Retireves the time from the Palm Device and returns the correct unix time
 * in seconds
 */
UNIFEX_TERM get_sys_date_time(UnifexEnv *env, int client_sd) {
  UNIFEX_TERM res_term;
  time_t fetched_time;
  uint64_t palm_date_time;

  int result = dlp_GetSysDateTime(client_sd, &fetched_time);
  if (result < 0) {
    res_term = get_sys_date_time_result_error(env, client_sd, result,
                                              "Unable to get system date");
  } else {
    palm_date_time = (uint64_t)fetched_time;
    res_term = get_sys_date_time_result_ok(env, client_sd, palm_date_time);
  }
  return res_term;
}

/*
 * Sets the given unix time to the palm device.
 * There is also no need to convert anything since unix time
 * is converted to palm time automagically.
 */
UNIFEX_TERM set_sys_date_time(UnifexEnv *env, int client_sd,
                              uint64_t palm_date_time) {
  time_t t = (time_t)palm_date_time;
  UNIFEX_TERM res_term;
  int result = dlp_SetSysDateTime(client_sd, t);

  if (result < 0) {
    res_term = set_sys_date_time_result_error(env, client_sd, result,
                                              "Unable to set system date");
  } else {
    res_term = set_sys_date_time_result_ok(env, client_sd);
  }
  return res_term;
}

UNIFEX_TERM read_user_info(UnifexEnv *env, int client_sd) {
  UNIFEX_TERM res_term;
  struct PilotUser user_info;
  struct pilot_user_t pilot_user;
  char *username_copy = NULL;
  char *password_copy = NULL;

  int result = dlp_ReadUserInfo(client_sd, &user_info);
  if (result < 0) {
    return read_user_info_result_error(env, client_sd, result,
                                       "Unable to get user info");
  }

  username_copy = strdup(user_info.username);
  if (username_copy == NULL) {
    return read_user_info_result_error(env, client_sd, -1,
                                       "Out of memory");
  }

  password_copy = strndup(user_info.password, user_info.passwordLength);
  if (password_copy == NULL) {
    free(username_copy);
    return read_user_info_result_error(env, client_sd, -1,
                                       "Out of memory");
  }

  pilot_user.password_length = (uint64_t)user_info.passwordLength;
  pilot_user.username = username_copy;
  pilot_user.password = password_copy;
  pilot_user.user_id = (uint64_t)user_info.userID;
  pilot_user.viewer_id = (uint64_t)user_info.viewerID;
  pilot_user.last_sync_pc = (uint64_t)user_info.lastSyncPC;
  pilot_user.successful_sync_date = (uint64_t)user_info.successfulSyncDate;
  pilot_user.last_sync_date = (uint64_t)user_info.lastSyncDate;

  res_term = read_user_info_result_ok(env, client_sd, pilot_user);
  free(username_copy);
  free(password_copy);
  return res_term;
}

UNIFEX_TERM write_user_info(UnifexEnv *env, int client_sd,
                            struct pilot_user_t pilot_user) {
  UNIFEX_TERM res_term;
  struct PilotUser user_info;
  user_info.passwordLength = (size_t)pilot_user.password_length;
  user_info.userID = (unsigned long)pilot_user.user_id;
  user_info.viewerID = (unsigned long)pilot_user.viewer_id;
  user_info.lastSyncPC = (unsigned long)pilot_user.last_sync_pc;
  user_info.successfulSyncDate = (time_t)pilot_user.successful_sync_date;
  user_info.lastSyncDate = (time_t)pilot_user.last_sync_date;

  strncpy(user_info.username, pilot_user.username,
          sizeof(user_info.username) - 1);
  user_info.username[sizeof(user_info.username) - 1] =
      '\0'; // Always null-terminate

  strncpy(user_info.password, pilot_user.password,
          sizeof(user_info.password) - 1);
  user_info.password[sizeof(user_info.password) - 1] =
      '\0'; // Always null-terminate

  int result = dlp_WriteUserInfo(client_sd, &user_info);
  if (result < 0) {
    res_term = write_user_info_result_error(env, client_sd, result,
                                            "Unable to set user info");
  } else {
    res_term = write_user_info_result_ok(env, client_sd);
  }
  return res_term;
}

UNIFEX_TERM write_datebook_record(UnifexEnv *env, int client_sd, int dbhandle, appointment appointment) {
  UNIFEX_TERM res_term;
  pi_buffer_t *buf = NULL;
  struct Appointment pilot_appointment;
  char *desc_copy = NULL;
  char *note_copy = NULL;
  struct tm *exception_list = NULL;
  recordid_t rec_id;

  memset(&pilot_appointment, 0, sizeof(pilot_appointment));

  buf = pi_buffer_new(0xffff);
  if (buf == NULL) {
    res_term = write_datebook_record_result_error(env, client_sd, -1,
                                                  "Out of memory");
    goto cleanup;
  }

  pilot_appointment.event = (int)appointment.event;
  pilot_appointment.begin = timehtm_to_tm(appointment.begin);
  pilot_appointment.end = timehtm_to_tm(appointment.end);
  pilot_appointment.alarm = (int)appointment.alarm;
  pilot_appointment.advance = (int)appointment.alarm_advance;
  pilot_appointment.advanceUnits = (int)appointment.alarm_advance_units;
  pilot_appointment.repeatType = appointment.repeat_type;
  pilot_appointment.repeatEnd = timehtm_to_tm(appointment.repeat_end);
  pilot_appointment.repeatFrequency = (int)appointment.repeat_frequency;
  pilot_appointment.repeatForever = (int)appointment.repeat_forever;
  pilot_appointment.repeatDay = appointment.repeat_day;

  for (unsigned int i = 0; i < 7u; i++) {
    pilot_appointment.repeatDays[i] =
        i < appointment.repeat_days_length ? appointment.repeat_days[i] : 0;
  }

  pilot_appointment.repeatWeekstart = (int)appointment.repeat_weekstart;
  pilot_appointment.exceptions = (int)appointment.exceptions_count;
  exception_list = timehtm_list_to_tm_list(
      appointment.exceptions_actual, appointment.exceptions_count);
  pilot_appointment.exception = exception_list;

  desc_copy = strdup(appointment.description);
  if (desc_copy == NULL) {
    res_term = write_datebook_record_result_error(env, client_sd, -1,
                                                  "Out of memory");
    goto cleanup;
  }
  pilot_appointment.description = desc_copy;

  if (!is_blank(appointment.note)) {
    note_copy = strdup(appointment.note);
    if (note_copy == NULL) {
      fprintf(stderr, "palm_sync: OOM copying note, record will be written without note\n");
    }
  }
  pilot_appointment.note = note_copy;

  rec_id = (recordid_t) appointment.rec_id;

  // some debugging printfs
  // printf("\n--- BEGIN PACK DEBUG ---\n");
  // printf("event: %d\n", pilot_appointment.event);
  // printf("begin: %02d-%02d-%04d %02d:%02d:%02d\n",
  //        pilot_appointment.begin.tm_mday, pilot_appointment.begin.tm_mon + 1,
  //        pilot_appointment.begin.tm_year + 1900,
  //        pilot_appointment.begin.tm_hour, pilot_appointment.begin.tm_min,
  //        pilot_appointment.begin.tm_sec);
  // printf("end: %02d-%02d-%04d %02d:%02d:%02d\n", pilot_appointment.end.tm_mday,
  //        pilot_appointment.end.tm_mon + 1, pilot_appointment.end.tm_year + 1900,
  //        pilot_appointment.end.tm_hour, pilot_appointment.end.tm_min,
  //        pilot_appointment.end.tm_sec);
  // printf("repeatEnd: %02d-%02d-%04d %02d:%02d:%02d\n",
  //        pilot_appointment.repeatEnd.tm_mday,
  //        pilot_appointment.repeatEnd.tm_mon + 1,
  //        pilot_appointment.repeatEnd.tm_year + 1900,
  //        pilot_appointment.repeatEnd.tm_hour,
  //        pilot_appointment.repeatEnd.tm_min,
  //        pilot_appointment.repeatEnd.tm_sec);
  // printf("alarm: %d\n", pilot_appointment.alarm);
  // printf("advance: %d\n", pilot_appointment.advance);
  // printf("advanceUnits: %d\n", pilot_appointment.advanceUnits);
  // printf("repeatType: %d\n", pilot_appointment.repeatType);
  // printf("repeatForever: %d\n", pilot_appointment.repeatForever);
  // printf("repeatFrequency: %d\n", pilot_appointment.repeatFrequency);
  // printf("repeatDay: %d\n", pilot_appointment.repeatDay);
  // printf("repeatDays: [%d %d %d %d %d %d %d]\n",
  //        pilot_appointment.repeatDays[0], pilot_appointment.repeatDays[1],
  //        pilot_appointment.repeatDays[2], pilot_appointment.repeatDays[3],
  //        pilot_appointment.repeatDays[4], pilot_appointment.repeatDays[5],
  //        pilot_appointment.repeatDays[6]);
  // printf("repeatWeekstart: %d\n", pilot_appointment.repeatWeekstart);
  // printf("exceptions: %d\n", pilot_appointment.exceptions);
  // printf("description: %s\n", pilot_appointment.description);
  // printf("note: %s\n", pilot_appointment.note);
  // printf("--- END PACK DEBUG ---\n");
  // printf("ok = %d\n", ok);
  // printf("buf->used = %zu\n", buf->used);
  // printf("Packed buffer (%zu bytes):\n", buf->used);
  // for (unsigned int i = 0; i < buf->used; i++) {
  //   printf("%02X ", ((unsigned char *)buf->data)[i]);
  //   if ((i + 1) % 16 == 0)
  //     printf("\n");
  // }
  // printf("\n");

  int ok = pack_Appointment(&pilot_appointment, buf, datebook_v1);
  if (ok == -1) {
    res_term = write_datebook_record_result_error(env, client_sd, ok,
                                                  "Failed to pack appointment");
    goto cleanup;
  }

  int result = dlp_WriteRecord(client_sd, dbhandle, 0, rec_id, 0, buf->data, buf->used, &rec_id);

  if (result < 0) {
    res_term = write_datebook_record_result_error(env, client_sd, result,
                                                  "dlp_WriteRecord failed");
    goto cleanup;
  }

  res_term = write_datebook_record_result_ok(env, client_sd, result, rec_id);

cleanup:
  free(desc_copy);
  free(note_copy);
  free(exception_list);
  pi_buffer_free(buf);
  return res_term;
}

UNIFEX_TERM write_calendar_record(UnifexEnv *env, int client_sd, int dbhandle, appointment appointment) {
  UNIFEX_TERM res_term;
  pi_buffer_t *buf = NULL;
  CalendarEvent_t cal_event;
  struct tm *exception_list = NULL;
  recordid_t rec_id;

  new_CalendarEvent(&cal_event);

  buf = pi_buffer_new(0xffff);
  if (buf == NULL) {
    res_term = write_calendar_record_result_error(env, client_sd, -1,
                                                  "Out of memory");
    goto cleanup;
  }

  cal_event.event = (int)appointment.event;
  cal_event.begin = timehtm_to_tm(appointment.begin);
  cal_event.end = timehtm_to_tm(appointment.end);
  cal_event.alarm = (int)appointment.alarm;
  cal_event.advance = (int)appointment.alarm_advance;
  cal_event.advanceUnits = (int)appointment.alarm_advance_units;
  cal_event.repeatType = appointment.repeat_type;
  cal_event.repeatEnd = timehtm_to_tm(appointment.repeat_end);
  cal_event.repeatFrequency = (int)appointment.repeat_frequency;
  cal_event.repeatForever = (int)appointment.repeat_forever;
  cal_event.repeatDay = appointment.repeat_day;

  for (unsigned int i = 0; i < 7u; i++) {
    cal_event.repeatDays[i] =
        i < appointment.repeat_days_length ? appointment.repeat_days[i] : 0;
  }

  cal_event.repeatWeekstart = (int)appointment.repeat_weekstart;
  cal_event.exceptions = (int)appointment.exceptions_count;
  exception_list = timehtm_list_to_tm_list(
      appointment.exceptions_actual, appointment.exceptions_count);
  cal_event.exception = exception_list;

  cal_event.description = strdup(appointment.description);
  if (cal_event.description == NULL) {
    res_term = write_calendar_record_result_error(env, client_sd, -1,
                                                  "Out of memory");
    goto cleanup;
  }

  if (!is_blank(appointment.note)) {
    cal_event.note = strdup(appointment.note);
    if (cal_event.note == NULL) {
      fprintf(stderr, "palm_sync: OOM copying note, record will be written without note\n");
    }
  }
  if (!is_blank(appointment.location)) {
    cal_event.location = strdup(appointment.location);
    if (cal_event.location == NULL) {
      fprintf(stderr, "palm_sync: OOM copying location, record will be written without location\n");
    }
  }
  cal_event.tz = NULL;

  rec_id = (recordid_t)appointment.rec_id;

  int ok = pack_CalendarEvent(&cal_event, buf, calendar_v1);
  if (ok == -1) {
    res_term = write_calendar_record_result_error(env, client_sd, ok,
                                                  "Failed to pack calendar event");
    goto cleanup;
  }

  int result = dlp_WriteRecord(client_sd, dbhandle, 0, rec_id, 0, buf->data, buf->used, &rec_id);

  if (result < 0) {
    res_term = write_calendar_record_result_error(env, client_sd, result,
                                                  "dlp_WriteRecord failed");
    goto cleanup;
  }

  res_term = write_calendar_record_result_ok(env, client_sd, result, rec_id);

cleanup:
  free(exception_list);
  free_CalendarEvent(&cal_event);
  pi_buffer_free(buf);
  return res_term;
}
