module(PalmSync4Mac.Comms.Pidlp)

interface([NIF])

type(
  pilot_user :: %PalmSync4Mac.Comms.Pidlp.PilotUser{
    # size_t -> unsigned long
    password_length: uint64,
    # char
    username: string,
    # char
    password: string,
    # unsigned long
    user_id: uint64,
    # unsigned long
    viewer_id: uint64,
    # unsigned long
    last_sync_pc: uint64,
    # time_t
    successful_sync_date: uint64,
    # time_t
    last_sync_date: uint64
  }
)

type(
  sys_info :: %PilotSysInfo{
    # unsigned long
    rom_version: uint64,
    # unsigned long
    locale: uint64,
    # unsigned char → promoted to unsigned int
    prod_id_length: unsigned,
    # array of char → best match is `string`
    prod_id: string,
    # unsigned short → promoted to unsigned int
    dlp_major_version: unsigned,
    dlp_minor_version: unsigned,
    compat_major_version: unsigned,
    compat_minor_version: unsigned,
    # unsigned long
    max_rec_size: uint64
  }
)

# tm is defined in time.h
type(
  timehtm :: %PalmSync4Mac.Comms.Pidlp.TM{
    tm_sec: int,
    tm_min: int,
    tm_hour: int,
    tm_mday: int,
    tm_mon: int,
    tm_year: int,
    tm_wday: int,
    tm_yday: int,
    tm_isdst: int
  }
)

type(
  appointment :: %PalmSync4Mac.Comms.Pidlp.DatebookAppointment{
    # timeless event?
    event: bool,
    # start time
    begin: timehtm,
    # end time
    end: timehtm,
    # should this event have an alarm?
    alarm: bool,
    # how far in advance should the alarm go off?
    alarm_advance: int,
    # what units should the advance be in?
    alarm_advance_units: int,
    repeat_type: int,
    repeat_forever: bool,
    repeat_end: timehtm,
    # how many times to repeat
    repeat_frequency: int,
    repeat_day: int,
    # use "[1, 0, 0, 1, 0, 0, 1]" with 1 to enable a weekday [Sun, Mon, Tue, Wen, Thu, Fri, Sat]
    repeat_days: [int],
    # what day did the user decide starts the day
    repeat_weekstart: int,
    # how many repetitions to ignore
    exceptions_count: int,
    exceptions_actual: [timehtm],
    description: string,
    note: string,
    location: string,
    rec_id: int
  }
)

spec(
  pilot_connect(port :: string, wait_timeout :: int) ::
    {:ok :: label, client_sd :: int, parent_sd :: int}
    | {:error :: label, client_sd :: int, parent_sd :: int, message :: string}
)

spec(
  pilot_disconnect(client_sd :: int, parent_sd :: int) ::
    {:ok :: label, client_sd :: int, parent_sd :: int}
)

spec(
  open_conduit(client_sd :: int) ::
    {:ok :: label, client_sd :: int, result :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  open_db(client_sd :: int, card_no :: int, mode :: int, dbname :: string) ::
    {:ok :: label, client_sd :: int, db_handle :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(close_db(client_sd :: int, db_handle :: int) :: {:ok :: label, client_sd :: int})

spec(
  end_of_sync(client_sd :: int, status :: int) ::
    {:ok :: label, client_sd :: int, result :: int}
    | {:error :: label, client_sd :: int, result :: int}
)

spec(
  read_sysinfo(client_sd :: int) ::
    {:ok :: label, client_sd :: int, sys_info :: sys_info}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  get_sys_date_time(client_sd :: int) ::
    {:ok :: label, client_sd :: int, palm_date_time :: uint64}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  set_sys_date_time(client_sd :: int, palm_date_time :: uint64) ::
    {:ok :: label, client_sd :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  read_user_info(client_sd :: int) ::
    {:ok :: label, client_sd :: int, user_info :: pilot_user}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  write_user_info(client_sd :: int, user_info :: pilot_user) ::
    {:ok :: label, client_sd :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  write_datebook_record(client_sd :: int, db_handle :: int, record_data :: appointment) ::
    {:ok :: label, client_sd :: int, result :: int, rec_id :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)

spec(
  write_calendar_record(client_sd :: int, db_handle :: int, record_data :: appointment) ::
    {:ok :: label, client_sd :: int, result :: int, rec_id :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
)
