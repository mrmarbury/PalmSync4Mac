defmodule DatebookDbPdb do
  @moduledoc """
  A module for parsing Palm PDB files, specifically the DatebookDB.pdb.
  """

  @pdb_header_size 78

  def read_pdb(file_path) do
    binary = File.read!(file_path)

    # Parse the header
    {header, rest} = parse_header(binary)

    # Parse the record list
    {records_info, rest} = parse_record_list(rest, header.num_records)

    # Parse the records
    records = parse_records(binary, records_info)

    # Return the data as a map
    %{header: header, records: records}
  end

  defp parse_header(<<
         name::binary-size(32),
         attributes::big-unsigned-integer-size(16),
         version::big-unsigned-integer-size(16),
         creation_date::big-unsigned-integer-size(32),
         modification_date::big-unsigned-integer-size(32),
         backup_date::big-unsigned-integer-size(32),
         modification_number::big-unsigned-integer-size(32),
         app_info_id::big-unsigned-integer-size(32),
         sort_info_id::big-unsigned-integer-size(32),
         type::binary-size(4),
         creator::binary-size(4),
         unique_id_seed::big-unsigned-integer-size(32),
         next_record_list_id::big-unsigned-integer-size(32),
         num_records::big-unsigned-integer-size(16),
         rest::binary
       >>) do
    header = %{
      name: String.trim_trailing(name, <<0>>),
      attributes: attributes,
      version: version,
      creation_date: creation_date,
      modification_date: modification_date,
      backup_date: backup_date,
      modification_number: modification_number,
      app_info_id: app_info_id,
      sort_info_id: sort_info_id,
      type: type,
      creator: creator,
      unique_id_seed: unique_id_seed,
      next_record_list_id: next_record_list_id,
      num_records: num_records
    }

    {header, rest}
  end

  defp parse_record_list(binary, num_records, records_info \\ [])

  defp parse_record_list(binary, 0, records_info) do
    {Enum.reverse(records_info), binary}
  end

  defp parse_record_list(
         <<offset::big-unsigned-integer-size(32), attributes::unsigned-integer-size(8),
           unique_id::binary-size(3), rest::binary>>,
         num_records,
         records_info
       ) do
    record_info = %{
      offset: offset,
      attributes: attributes,
      unique_id: :binary.decode_unsigned(<<unique_id::binary-size(3), 0>>)
    }

    parse_record_list(rest, num_records - 1, [record_info | records_info])
  end

  defp parse_records(binary, records_info) do
    Enum.map(records_info, fn record_info ->
      offset = record_info.offset
      # Find the next record offset or end of file
      next_offset =
        records_info
        |> Enum.filter(fn r -> r.offset > offset end)
        |> Enum.map(& &1.offset)
        |> Enum.min(fn -> byte_size(binary) end)

      length = next_offset - offset

      # Extract the record data
      <<_::binary-size(offset), record_data::binary-size(length), _::binary>> = binary

      # Parse the record data
      parsed_data = parse_record_data(record_data)

      Map.put(record_info, :data, parsed_data)
    end)
  end

  defp parse_record_data(record_data) do
    # TODO: Implement actual parsing based on DatebookDB record format
    # For now, we return the raw binary data
    record_data
  end
end
