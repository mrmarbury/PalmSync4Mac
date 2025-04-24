module PalmSync4mac.Comms.Libpisock

  interface [NIF, CNode]

  type sys_info :: %PalmSysInfo{
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
