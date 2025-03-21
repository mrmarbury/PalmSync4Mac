defmodule Palmsync4mac.Dlp.DlpArg do
  defstruct [:id, :len, :data, :freed]

  def new(arg_id, len) when is_integer(len) and len >= 0 do
    data =
      if len > 0 do
        :binary.copy(<<0>>, len)
      else
        <<>>
      end

    %__MODULE__{id: arg_id, len: len, data: data}
  end

  def free(%__MODULE__{} = arg) do
    %__MODULE__{arg | data: <<>>, len: 0, freed: true}
  end
end
