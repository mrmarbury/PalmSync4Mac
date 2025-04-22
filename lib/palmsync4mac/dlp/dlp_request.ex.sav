defmodule Palmsync4mac.Dlp.DlpRequest do
  alias Palmsync4mac.Dlp.DlpArg

  # Replace with actual constant if needed
  @pi_dlp_arg_first_id 0x00

  def request_new(cmd, sizes) when is_list(sizes) do
    argc = length(sizes)

    with {:ok, argv} <- build_args(sizes) do
      {:ok,
       %DLPRequest{
         cmd: cmd,
         argc: argc,
         argv: argv
       }}
    else
      {:error, {:failed_at, i, built}} ->
        cleaned = Enum.map(built, &DlpArg.free/1)
        {:error, {:arg_allocation_failed, i, cleaned}}
    end
  end

  defp build_args(sizes) do
    Enum.reduce_while(Enum.with_index(sizes), {:ok, []}, fn {size, i}, {:ok, acc} ->
      arg_id = @pi_dlp_arg_first_id + i

      case DlpArg.new(arg_id, size) do
        %DlpArg{} = arg ->
          {:cont, {:ok, [arg | acc]}}

        _ ->
          {:halt, {:error, {:failed_at, i, Enum.reverse(acc)}}}
      end
    end)
    |> case do
      {:ok, args} -> {:ok, Enum.reverse(args)}
      error -> error
    end
  end
end
