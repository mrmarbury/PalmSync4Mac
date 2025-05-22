defmodule PalmSync4Mac.Entity.Device do
  @moduledoc """
  The PalmSync4Mac Device domain
  """
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Entity.Device.Palm)
  end
end
