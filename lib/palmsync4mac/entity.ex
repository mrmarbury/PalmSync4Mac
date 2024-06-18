defmodule PalmSync4Mac.Entity do
  @moduledoc """
    The PalmSync4Mac Entity domain
  """
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Entity.Calendar)
  end
end
