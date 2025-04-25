#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <utime.h>

#include <stdarg.h>

#include <pi-dlp.h>
#include <pi-file.h>
#include <pi-memo.h>
#include <pi-socket.h>
#include <pi-source.h>

#include "pidlp.h"

/*pilot-connect*/
UNIFEX_TERM pilot_connect(UnifexEnv *env, char *port) {
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
      /*  *BAD* practice - cannot recover from within Java if exit() here.
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
    client_sd = pi_accept_to(parent_sd, 0, 0, 5);
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
 * Retireves the time from the Palm Device and returns the correct unix time in
 * seconds
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
