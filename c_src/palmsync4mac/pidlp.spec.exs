module PalmSync4mac.Comms.Pidlp

  interface [NIF]

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

  spec pilot_connect(port :: string) :: {:ok :: label, client_sd :: int, parent_sd :: int}
    | {:error :: label, client_sd :: int, parent_sd :: int, message :: string}

  spec pilot_disconnect(client_sd :: int, parent_sd :: int) :: {:ok :: label, client_sd :: int, parent_sd :: int}

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
