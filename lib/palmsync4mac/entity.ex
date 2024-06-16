defmodule Palmsync4mac.Entity do
  use Ash.Domain

  resources do
    resource(Palmsync4mac.Entity.Calendar)
  end
end
