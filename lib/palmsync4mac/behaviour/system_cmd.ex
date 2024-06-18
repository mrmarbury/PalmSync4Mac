defmodule PalmSync4Mac.Behaviour.SystemCmd do
  @callback cmd(String.t(), [String.t()]) :: {String.t(), non_neg_integer}
end
