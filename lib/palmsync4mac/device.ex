defmodule PalmSync4Mac.Device do
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Device.Palm)
  end
end
