defmodule PalmSync4Mac.Utils.SystemCmd do
  @behaviour PalmSync4Mac.Behaviour.SystemCmd

  @impl true
  def cmd(command, args) do
    System.cmd(command, args)
  end
end
