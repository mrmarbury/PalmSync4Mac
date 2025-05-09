module PalmSync4Mac.Comms.Pidlp

  interface [NIF]

  type datebook_type :: :v1

  type pilot_user :: %PilotUser {
    password_length: uint64, # size_t -> unsigned long
  	username: string, # char
  	password: string, # char
    user_id: uint64, # unsigned long
    viewer_id: uint64, # unsigned long
    last_sync_pc: uint64, # unsigned long
    successful_sync_date: uint64, # time_t
    last_sync_date: uint64, # time_t
  }

  type sys_info :: %PilotSysInfo{
    rom_version: uint64,         # unsigned long
    locale: uint64,              # unsigned long
    prod_id_length: unsigned,    # unsigned char → promoted to unsigned int
    prod_id: string,             # array of char → best match is `string`
    dlp_major_version: unsigned, # unsigned short → promoted to unsigned int
    dlp_minor_version: unsigned,
    compat_major_version: unsigned,
    compat_minor_version: unsigned,
    max_rec_size: uint64         # unsigned long
  }

  type timehtime :: %TimeHTime {
    sec: int,
    min: int,
    hour: int,
    mday: int,
    mon: int,
    year: int,
    wday: int,
    yday: int,
    isdst: int
  }

  type repeat_type :: :none | :daily | :weekly | :monthly_by_day | :monthly_by_date | :yearly
  type day_of_month_type ::
    :dom_1st_sun | :dom_1st_mon | :dom_1st_tue | :dom_1st_wen | :dom_1st_thu |
    :dom_1st_fri | :dom_1st_sat |
    :dom_2nd_sun | :dom_2nd_mon | :dom_2nd_tue | :dom_2nd_wen | :dom_2nd_thu |
    :dom_2nd_fri | :dom_2nd_sat |
    :dom_3rd_sun | :dom_3rd_mon | :dom_3rd_tue | :dom_3rd_wen | :dom_3rd_thu |
    :dom_3rd_fri | :dom_3rd_sat |
    :dom_4th_sun | :dom_4th_mon | :dom_4th_tue | :dom_4th_wen | :dom_4th_thu |
    :dom_4th_fri | :dom_4th_sat |
    :dom_last_sun | :dom_last_mon | :dom_last_tue | :dom_last_wen | :dom_last_thu |
    :dom_last_fri | :dom_last_sat

  type appointment :: %DatebookAppointment {
    event: bool,               # timeless event?
    begin: timehtime,          # start time
    end: timehtime,            # end time
    alarm: bool,               # should this event have an alarm?
    alarmAdvance: int,         # how far in advance should the alarm go off?
    alarmAdvanceUnits: int,    # what units should the advance be in?
    repeat_type: repeat_type,
    repeat_forevery: bool,
    repeat_end: timehtime,
    repeat_day_of_Month: day_of_month_type,
    repeat_days: [int], # use "[1, 0, 0, 1, 0, 0, 1]" with 1 to enable a weekday [Sun, Mon, Tue, Wen, Thu, Fri, Sat]
    repeat_weekstart: int, # what day did the user decide starts the day
    exceptions_count: int, # how many repetitions to ignore
    exceptions_actual: [timehtime],
    description: string,
    note: string
  }

  spec pilot_connect(port :: string) :: {:ok :: label, client_sd :: int, parent_sd :: int}
    | {:error :: label, client_sd :: int, parent_sd :: int, message :: string}

  spec pilot_disconnect(client_sd :: int, parent_sd :: int) :: {:ok :: label, client_sd :: int, parent_sd :: int}

  spec open_conduit(client_sd :: int) :: {:ok :: label, client_sd :: int, result :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec open_db(client_sd :: int, card_no :: int, mode :: int, dbname :: string)
    :: {:ok :: label, client_sd :: int, db_handle :: int}
        | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec close_db(client_sd :: int, db_handle :: int) :: {:ok :: label, client_sd :: int}

  spec end_of_sync(client_sd :: int, status :: int) :: {:ok :: label, client_sd :: int, result :: int}
    | {:error :: label, client_sd :: int, result :: int}

  spec read_sysinfo(client_sd :: int) :: {:ok :: label, client_sd :: int, sys_info :: sys_info}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec get_sys_date_time(client_sd :: int) :: {:ok :: label, client_sd :: int, palm_date_time :: uint64}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec set_sys_date_time(client_sd :: int, palm_date_time :: uint64) :: {:ok :: label, client_sd :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec read_user_info(client_sd :: int) :: {:ok :: label, client_sd :: int, user_info :: pilot_user}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec write_user_info(client_sd :: int, user_info :: pilot_user) :: {:ok :: label, client_sd :: int}
    | {:error :: label, client_sd :: int, result :: int, message :: string}

  spec write_record(client_sd :: int, db_handle :: int, record_data :: appointment)
    :: {:ok :: label, client_sd :: int}
        | {:error :: label, client_sd :: int, result :: int, message :: string}
