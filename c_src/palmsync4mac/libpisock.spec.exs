module PalmSync4mac.Comms.Libpisock

  interface [NIF]

  type sys_info :: %SysInfo{
    rom_version: uint64,
    locale: unsigned,
    prod_id_length: unsigned,
    prod_id: string,
    dlp_major_version: unsigned,
    dlp_minor_version: unsigned,
    compat_major_version: unsigned,
    compat_minor_version: unsigned,
    max_rec_size: unsigned
  }


  spec pilot_connect(port :: string) :: {:ok :: label, client_sd :: int, parent_sd :: int}
    | {:error :: label, client_sd :: int, parent_sd :: int, message :: string}

  spec pilot_disconnect(client_sd :: int, parent_sd :: int) :: {:ok :: label, client_sd :: int, parent_sd :: int}

  spec read_sysinfo(client_sd :: int) :: {:ok :: label, client_sd :: int, sys_info :: sys_info}
    | {:error :: label, client_sd :: int, result :: int, message :: string}
