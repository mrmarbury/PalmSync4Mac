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

  // Skip leading whitespace
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

/* enum repeatTypes map_repeat_type(enum RepeatType_t val) {
  switch (val) {
  case REPEAT_TYPE_REPEATNONE:
    return repeatNone;
  case REPEAT_TYPE_REPEATDAILY:
    return repeatDaily;
  case REPEAT_TYPE_REPEATWEEKLY:
    return repeatWeekly;
  case REPEAT_TYPE_REPEATMONTHLYBYDAY:
    return repeatMonthlyByDay;
  case REPEAT_TYPE_REPEATMONTHLYBYDATE:
    return repeatMonthlyByDate;
  case REPEAT_TYPE_REPEATYEARLY:
    return repeatYearly;
  default:
    return repeatNone; // Fallback or error case
  }
}

DayOfMonthType map_day_of_month(enum DayOfMonthType_t val) {
  switch (val) {
  case DAY_OF_MONTH_TYPE_DOM_1ST_SUN:
    return dom1stSun;
  case DAY_OF_MONTH_TYPE_DOM_1ST_MON:
    return dom1stMon;
  case DAY_OF_MONTH_TYPE_DOM_1ST_TUE:
    return dom1stTue;
  case DAY_OF_MONTH_TYPE_DOM_1ST_WEN:
    return dom1stWen;
  case DAY_OF_MONTH_TYPE_DOM_1ST_THU:
    return dom1stThu;
  case DAY_OF_MONTH_TYPE_DOM_1ST_FRI:
    return dom1stFri;
  case DAY_OF_MONTH_TYPE_DOM_1ST_SAT:
    return dom1stSat;

  case DAY_OF_MONTH_TYPE_DOM_2ND_SUN:
    return dom2ndSun;
  case DAY_OF_MONTH_TYPE_DOM_2ND_MON:
    return dom2ndMon;
  case DAY_OF_MONTH_TYPE_DOM_2ND_TUE:
    return dom2ndTue;
  case DAY_OF_MONTH_TYPE_DOM_2ND_WEN:
    return dom2ndWen;
  case DAY_OF_MONTH_TYPE_DOM_2ND_THU:
    return dom2ndThu;
  case DAY_OF_MONTH_TYPE_DOM_2ND_FRI:
    return dom2ndFri;
  case DAY_OF_MONTH_TYPE_DOM_2ND_SAT:
    return dom2ndSat;

  case DAY_OF_MONTH_TYPE_DOM_3RD_SUN:
    return dom3rdSun;
  case DAY_OF_MONTH_TYPE_DOM_3RD_MON:
    return dom3rdMon;
  case DAY_OF_MONTH_TYPE_DOM_3RD_TUE:
    return dom3rdTue;
  case DAY_OF_MONTH_TYPE_DOM_3RD_WEN:
    return dom3rdWen;
  case DAY_OF_MONTH_TYPE_DOM_3RD_THU:
    return dom3rdThu;
  case DAY_OF_MONTH_TYPE_DOM_3RD_FRI:
    return dom3rdFri;
  case DAY_OF_MONTH_TYPE_DOM_3RD_SAT:
    return dom3rdSat;

  case DAY_OF_MONTH_TYPE_DOM_4TH_SUN:
    return dom4thSun;
  case DAY_OF_MONTH_TYPE_DOM_4TH_MON:
    return dom4thMon;
  case DAY_OF_MONTH_TYPE_DOM_4TH_TUE:
    return dom4thTue;
  case DAY_OF_MONTH_TYPE_DOM_4TH_WEN:
    return dom4thWen;
  case DAY_OF_MONTH_TYPE_DOM_4TH_THU:
    return dom4thThu;
  case DAY_OF_MONTH_TYPE_DOM_4TH_FRI:
    return dom4thFri;
  case DAY_OF_MONTH_TYPE_DOM_4TH_SAT:
    return dom4thSat;

  case DAY_OF_MONTH_TYPE_DOM_LAST_SUN:
    return domLastSun;
  case DAY_OF_MONTH_TYPE_DOM_LAST_MON:
    return domLastMon;
  case DAY_OF_MONTH_TYPE_DOM_LAST_TUE:
    return domLastTue;
  case DAY_OF_MONTH_TYPE_DOM_LAST_WEN:
    return domLastWen;
  case DAY_OF_MONTH_TYPE_DOM_LAST_THU:
    return domLastThu;
  case DAY_OF_MONTH_TYPE_DOM_LAST_FRI:
    return domLastFri;
  case DAY_OF_MONTH_TYPE_DOM_LAST_SAT:
    return domLastSat;

  default:
    return dom1stSun; // or handle error
  }
} */
/*pilot-connect*/
UNIFEX_TERM pilot_connect(UnifexEnv *env, char *port, int wait_timeout) {
  UNIFEX_TERM res_term;
  int parent_sd = -1, /* Parent socket, formerly sd   */
      client_sd = -1, /* Client socket, formerly sd2  */
      result;
  struct pi_sockaddr addr;
  struct stat attr;
  struct SysInfo sys_info;
  const char *defport = "/dev/pilot";
  int bProceed = 1;

  if (port == NULL && (port = getenv("PILOTPORT")) == NULL) {

    /* err seems to be used for stat() only */
    int err = 0;

    /* Commented out debug code */
    /*
                fprintf(stderr, "   No $PILOTPORT specified and no -p "
                        "<port> given.\n"
                        "   Defaulting to '%s'\n", defport);
    */
    port = defport;
    err = stat(port, &attr);

    /* Moved err check inside if() block - err only meaningful here */
    if (err) {
      /*  *BAD* practice - cannot recover if exit() here.
          Should create && throw exception instead.
       */
      /*
                          fprintf(stderr, "   ERROR: %s (%d)\n\n",
         strerror(errno), errno); fprintf(stderr, "   Error accessing: '%s'.
         Does '%s' exist?\n", port, port);
                          //fprintf(stderr, "   Please use --help for more
         information\n\n"); exit(1);
      */

      /* Throw an exception - FileNotFoundException seems appropriate here */
      res_term = pilot_connect_result_error(env, client_sd, parent_sd,
                                            strerror(errno));
      bProceed = 0;
    }
  }

  /* At this point, either bProceed is 0, or port != NULL, further checks are
   * unnecesary */

  /* Check bProceed to account for previous exceptions */
  if (bProceed &&
      !(parent_sd = pi_socket(PI_AF_PILOT, PI_SOCK_STREAM, PI_PF_DLP))) {
    /*
                fprintf(stderr, "\n   Unable to create socket '%s'\n",
                        port ? port : getenv("PILOTPORT"));
                return -1;
    */
    /* Throw exception here to inform nature of connection failure. */
    const char *sTemplate = "Unable to create socket '%s'";
    char *sMessage = (char *)malloc(strlen(sTemplate) + strlen(port) + 1);
    if (sMessage != NULL)
      sprintf(sMessage, sTemplate, port);
    res_term = pilot_connect_result_error(env, client_sd, parent_sd,
                                          (sMessage != NULL) ? sMessage : port);
    if (sMessage != NULL)
      free(sMessage);

    bProceed = 0;
  }

  /* Check bProceed to account for previous exceptions */
  if (bProceed) {
    result = pi_bind(parent_sd, port);
  }

  if (bProceed && result < 0) {
    int save_errno = errno;
    /*
                const char *portname;

                portname = (port != NULL) ? port : getenv("PILOTPORT");
                if (portname) {
                        fprintf(stderr, "\n");
                        errno = save_errno;
                        fprintf(stderr, "   ERROR: %s (%d)\n\n",
       strerror(errno), errno);

                        if (errno == 2) {
                                fprintf(stderr, "   The device %s does not
       exist..\n", portname); fprintf(stderr, "   Possible solution:\n\n\tmknod
       %s c "
                                        "<major> <minor>\n\n", portname );

                        } else if (errno == 13) {
                                fprintf(stderr, "   Please check the "
                                        "permissions on %s..\n",   portname );
                                fprintf(stderr, "   Possible
       solution:\n\n\tchmod 0666 "
                                        "%s\n\n", portname );

                        } else if (errno == 19) {
                                fprintf(stderr, "   Press the HotSync button
       first and " "relaunch this conduit..\n\n"); } else if (errno == 21) {
                                fprintf(stderr, "   The port specified must
       contain a " "device name, and %s was a directory.\n" "   Please change
       that to reference a real " "device, and try again\n\n", portname );
                        }

                        fprintf(stderr, "   Unable to bind to port: %s\n",
                                portname) ;
                        fprintf(stderr, "   Please use --help for more "
                                "information\n\n");
                } else
                        fprintf(stderr, "\n   No port specified\n");
    */
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
      sprintf(sMessage, sTemplate, port, save_errno, strerror(save_errno),
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

  /* Removed debug message, maybe add notification framework to invoke here
      fprintf(stderr,
              "\n   Listening to port: %s\n\n   Please press the HotSync "
              "button now... ",
              port ? port : getenv("PILOTPORT"));
  */
  /* Check bProceed to account for previous exceptions */
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

  /* Check bProceed to account for previous exceptions */
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
  /* Removed debug message, maybe add notification framework to invoke here */
  /*        printf("Opening counduit...\n"); */
  dlp_OpenConduit(client_sd);
  /* Why should parent_sd remain open after connect? Nobody receives it. */
  /*   pi_close(parent_sd); */
  res_term = pilot_connect_result_ok(env, client_sd, parent_sd);
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

  int result = dlp_ReadSysInfo(client_sd, &sys_info);
  if (result < 0) {
    res_term = read_sysinfo_result_error(env, client_sd, result,
                                         "Unable to get system info");
  } else {

    palm_info.rom_version = (uint64_t)sys_info.romVersion;
    palm_info.locale = (uint64_t)sys_info.locale;
    palm_info.prod_id_length = (unsigned int)sys_info.prodIDLength;
    palm_info.prod_id = strndup(sys_info.prodID, sys_info.prodIDLength);
    palm_info.dlp_major_version = (unsigned int)sys_info.dlpMajorVersion;
    palm_info.dlp_minor_version = (unsigned int)sys_info.dlpMinorVersion;
    palm_info.compat_major_version = (unsigned int)sys_info.compatMajorVersion;
    palm_info.compat_minor_version = (unsigned int)sys_info.compatMinorVersion;
    palm_info.max_rec_size = (uint64_t)sys_info.maxRecSize;

    res_term = read_sysinfo_result_ok(env, client_sd, palm_info);
  }
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

  int result = dlp_ReadUserInfo(client_sd, &user_info);
  if (result < 0) {
    res_term = read_user_info_result_error(env, client_sd, result,
                                           "Unable to get user info");
  } else {
    pilot_user.password_length = (uint64_t)user_info.passwordLength;
    pilot_user.username = strdup(user_info.username);
    pilot_user.password = strndup(user_info.password, user_info.passwordLength);
    pilot_user.user_id = (uint64_t)user_info.userID;
    pilot_user.viewer_id = (uint64_t)user_info.viewerID;
    pilot_user.last_sync_pc = (uint64_t)user_info.lastSyncPC;
    pilot_user.successful_sync_date = (uint64_t)user_info.successfulSyncDate;
    pilot_user.last_sync_date = (uint64_t)user_info.lastSyncDate;

    res_term = read_user_info_result_ok(env, client_sd, pilot_user);
  }
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
  pi_buffer_t *buf = pi_buffer_new(0xffff);
  struct Appointment pilot_appointment;
  recordid_t rec_id;

  pilot_appointment.event = (int)appointment.event;
  pilot_appointment.begin = timehtm_to_tm(appointment.begin);
  pilot_appointment.end = timehtm_to_tm(appointment.end);
  pilot_appointment.alarm = (int)appointment.alarm;
  pilot_appointment.advance = (int)appointment.alarm_advance;
  pilot_appointment.advanceUnits = (int)appointment.alarm_advance_units;
  /* pilot_appointment.repeatType = map_repeat_type(appointment.repeat_type); */
  pilot_appointment.repeatType = appointment.repeat_type;
  pilot_appointment.repeatEnd = timehtm_to_tm(appointment.repeat_end);
  pilot_appointment.repeatFrequency = (int)appointment.repeat_frequency;
  pilot_appointment.repeatForever = (int)appointment.repeat_forever;
  /* pilot_appointment.repeatDay = map_day_of_month(appointment.repeat_day); */
  pilot_appointment.repeatDay = appointment.repeat_day;

  for (int i = 0; i < 7; i++) {
    pilot_appointment.repeatDays[i] =
        i < appointment.repeat_days_length ? appointment.repeat_days[i] : 0;
  }

  pilot_appointment.repeatWeekstart = (int)appointment.repeat_weekstart;
  pilot_appointment.exceptions = (int)appointment.exceptions_count;
  pilot_appointment.exception = timehtm_list_to_tm_list(
      appointment.exceptions_actual, appointment.exceptions_count);
  pilot_appointment.description = strdup(appointment.description);
  pilot_appointment.note =
      is_blank(appointment.note) ? NULL : strdup(appointment.note);

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

  int ok = pack_Appointment(&pilot_appointment, buf, datebook_v1);
  printf("ok = %d\n", ok);
  if (ok == -1) {
    return write_datebook_record_result_error(env, client_sd, ok,
                                              "Failed to pack appointment");
  }
  printf("buf->used = %zu\n", buf->used);

  printf("Packed buffer (%d bytes):\n", buf->used);
  for (int i = 0; i < buf->used; i++) {
    printf("%02X ", ((unsigned char *)buf->data)[i]);
    if ((i + 1) % 16 == 0)
      printf("\n");
  }
  printf("\n");

  int result = dlp_WriteRecord(client_sd, dbhandle, 0, rec_id, 0, buf->data, buf->used, &rec_id);

  pi_buffer_free(buf);

  if (result < 0) {
    return write_datebook_record_result_error(env, client_sd, result,
                                              "dlp_WriteRecord failed");
  }

  return write_datebook_record_result_ok(env, client_sd, result, rec_id);
}

UNIFEX_TERM write_calendar_record(UnifexEnv *env, int client_sd, int dbhandle, appointment appointment) {
  UNIFEX_TERM res_term;
  pi_buffer_t *buf = pi_buffer_new(0xffff);
  CalendarEvent_t cal_event;
  recordid_t rec_id;

  new_CalendarEvent(&cal_event);

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

  for (int i = 0; i < 7; i++) {
    cal_event.repeatDays[i] =
        i < appointment.repeat_days_length ? appointment.repeat_days[i] : 0;
  }

  cal_event.repeatWeekstart = (int)appointment.repeat_weekstart;
  cal_event.exceptions = (int)appointment.exceptions_count;
  cal_event.exception = timehtm_list_to_tm_list(
      appointment.exceptions_actual, appointment.exceptions_count);
  cal_event.description = strdup(appointment.description);
  cal_event.note =
      is_blank(appointment.note) ? NULL : strdup(appointment.note);
  cal_event.location =
      is_blank(appointment.location) ? NULL : strdup(appointment.location);
  cal_event.tz = NULL;

  rec_id = (recordid_t)appointment.rec_id;

  int ok = pack_CalendarEvent(&cal_event, buf, calendar_v1);
  if (ok == -1) {
    free_CalendarEvent(&cal_event);
    pi_buffer_free(buf);
    return write_calendar_record_result_error(env, client_sd, ok,
                                              "Failed to pack calendar event");
  }

  int result = dlp_WriteRecord(client_sd, dbhandle, 0, rec_id, 0, buf->data, buf->used, &rec_id);

  free_CalendarEvent(&cal_event);
  pi_buffer_free(buf);

  if (result < 0) {
    return write_calendar_record_result_error(env, client_sd, result,
                                              "dlp_WriteRecord failed");
  }

  return write_calendar_record_result_ok(env, client_sd, result, rec_id);
}
