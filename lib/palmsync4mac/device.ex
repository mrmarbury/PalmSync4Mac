defmodule PalmSync4Mac.Device do
  @moduledoc """
  The PalmSync4Mac Device domain
  """
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Device.Palm)
  end
end
