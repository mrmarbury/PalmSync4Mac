defmodule PalmSync4Mac.Comms.Pidlp.PilotSysInfo do
  @moduledoc """
  Elixir struct that mirrors the Palm SysInfo returned by read_sysinfo NIF.
  rom_version is the key field: >= 0x05020000 means Palm OS 5.2+ (CalendarDB-PDat support).
  """
  use TypedStruct

  typedstruct do
    plugin(TypedStructLens)
    plugin(TypedStructNimbleOptions)

    field(:rom_version, non_neg_integer(),
      default: 0,
      doc: "ROM version of the Palm OS. 0x05020000 = Palm OS 5.2 (CalendarDB threshold)"
    )

    field(:locale, non_neg_integer(),
      default: 0,
      doc: "Device locale"
    )

    field(:prod_id_length, non_neg_integer(),
      default: 0,
      doc: "Length of the product ID string"
    )

    field(:prod_id, String.t(),
      default: "",
      doc: "Product ID string (e.g., \"Palm TX\")"
    )

    field(:dlp_major_version, non_neg_integer(),
      default: 0,
      doc: "DLP protocol major version"
    )

    field(:dlp_minor_version, non_neg_integer(),
      default: 0,
      doc: "DLP protocol minor version"
    )

    field(:compat_major_version, non_neg_integer(),
      default: 0,
      doc: "Compatibility major version"
    )

    field(:compat_minor_version, non_neg_integer(),
      default: 0,
      doc: "Compatibility minor version"
    )

    field(:max_rec_size, non_neg_integer(),
      default: 0,
      doc: "Maximum record size the device supports"
    )
  end
end
