defmodule PalmSync4Mac.Comms.Pidlp.PilotUser do
  @moduledoc """
  Elixir struct that mirrors the Palm PilotUser_t
  """
  use TypedStruct

  typedstruct do
    plugin(TypedStructLens)
    plugin(TypedStructNimbleOptions)

    field(:password_length, non_neg_integer(),
      doc:
        "Length of the password used to secure the Palm. This must match the actual length of the :password field"
    )

    field(:username, String.t(), doc: "Human readable name of the device")

    field(:password, String.t(), doc: "The password used to secure the Palm device")

    field(:user_id, non_neg_integer(),
      doc:
        "Id of the Palm user/device. This is unique for each palm since it will be set on first hot sync. If this is changed, then the Palm is seen as a new device"
    )

    field(:viewer_id, non_neg_integer(),
      doc: "Identifies the Client used for the last sync",
      default: Application.fetch_env!(:palm_sync_4_mac, :palm_viewer_id)
    )

    field(:last_sync_pc, non_neg_integer(),
      doc:
        "Id or name of the PC used in the last sync. Should be set to the current hostname when writing. Will contain the last used hostname when reading."
    )

    field(:successful_sync_date, non_neg_integer(),
      doc: "Non-negative Integer representing the last successfull sync date"
    )

    field(:last_sync_date, non_neg_integer(),
      doc: "General date describing when the last sync was no matter if successfull or not"
    )
  end
end
