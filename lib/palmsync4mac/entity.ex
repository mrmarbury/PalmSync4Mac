defmodule PalmSync4Mac.Entity do
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Entity.Calendar)
  end
end
