defmodule AVR.IHex do
  @moduledoc false

  use Bitwise

  defstruct regions: nil

  defmodule State do
    @moduledoc false
    defstruct buffer: nil, type: nil, nextaddr: nil, eof: nil, baseaddr: nil, startaddr: nil
  end

  @type baseaddr :: non_neg_integer()
  @type region :: {baseaddr(), binary()}

  @type t :: %__MODULE__{
          regions: [region()]
        }

  @spec parse_file(hex_path :: String.t(), opts :: Keyword.t()) :: {:ok, t()} | {:error, term()}
  def parse_file(hex_path, opts \\ []) do
    try do
      baseaddr = opts[:baseaddr] || 0

      state = %State{
        baseaddr: baseaddr,
        nextaddr: baseaddr,
        eof: false
      }

      regions =
        hex_path
        |> File.stream!()
        |> Stream.map(&parse_line/1)
        |> Stream.map(&parse_fields/1)
        |> Stream.transform(state, &parse_records/2)
        |> Enum.to_list()

      {:ok, %__MODULE__{regions: regions}}
    rescue
      _ ->
        {:error, :parse_file}
    end
  end

  @spec to_regions(ihex :: t()) :: [region()]
  def to_regions(%__MODULE__{regions: regions}),
    do: regions

  @spec size(ihex :: t()) :: non_neg_integer()
  def size(%__MODULE__{regions: regions}),
    do: Enum.reduce(regions, 0, fn {_, data}, acc -> acc + byte_size(data) end)

  defp parse_records({:data, offset, data}, state) do
    %{
      baseaddr: baseaddr,
      nextaddr: nextaddr,
      startaddr: startaddr,
      buffer: buffer
    } = state

    if baseaddr + offset != nextaddr do
      # Non consecutive segment found!
      if is_nil(buffer) do
        # Start with first segment

        state = %{
          state
          | buffer: data,
            startaddr: baseaddr + offset,
            nextaddr: baseaddr + offset + byte_size(data)
        }

        {[], state}
      else
        # New segment 
        state1 = %{
          state
          | startaddr: baseaddr + offset,
            buffer: data,
            nextaddr: baseaddr + offset + byte_size(data)
        }

        {[{startaddr, buffer}], state1}
      end
    else
      buffer = buffer || <<>>
      startaddr = startaddr || nextaddr

      state = %{
        state
        | buffer: <<buffer::binary, data::binary>>,
          nextaddr: nextaddr + byte_size(data),
          startaddr: startaddr
      }

      {[], state}
    end
  end

  defp parse_records({:ext_lin_addr, _, <<addr::16-unsigned-integer>>}, state) do
    addr = addr * 0x10000

    state1 = %{
      state
      | buffer: nil,
        baseaddr: addr,
        nextaddr: addr,
        startaddr: nil
    }

    {[{state.startaddr, state.buffer}], state1}
  end

  defp parse_records({:ext_seg_addr, _, <<addr::16-unsigned-integer>>}, state) do
    addr = addr * 0x10

    state1 = %{
      state
      | buffer: nil,
        baseaddr: addr,
        nextaddr: addr,
        startaddr: nil
    }

    {[{state.startaddr, state.buffer}], state1}
  end

  defp parse_records({:eof, _, _}, state) do
    state1 = %{state | buffer: nil, eof: true}
    {[{state.startaddr, state.buffer}], state1}
  end

  defp parse_records({_, _addr, _data}, state) do
    {[], state}
  end

  defp parse_fields(
         {:ok,
          <<
            count::8-integer,
            address::16-integer-big,
            type_value::8-integer,
            data::binary-size(count),
            _checksum::8-integer
          >>}
       ) do
    {type_to_atom(type_value), address, data}
  end

  defp parse_line(<<":", hex::binary>>) do
    hex
    |> String.replace(~r/\r|\n/, "")
    |> Base.decode16()
  end

  defp type_to_atom(0), do: :data
  defp type_to_atom(1), do: :eof
  defp type_to_atom(2), do: :ext_seg_addr
  defp type_to_atom(3), do: :start_seg_addr
  defp type_to_atom(4), do: :ext_lin_addr
  defp type_to_atom(5), do: :start_lin_addr
end
