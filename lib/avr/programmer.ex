defmodule AVR.Programmer do
  @moduledoc false

  alias AVR.Board

  defstruct port: nil, meta: []

  @programmers [
    arduino: AVR.Programmer.Arduino,
    stk500: AVR.Programmer.Stk500
  ]

  @type t :: %__MODULE__{
          port: term(),
          meta: Keyword.t()
        }

  @type id :: :arduino | :stk500

  @type target_addr :: {Board.mem_type(), non_neg_integer()}
  @type signature :: <<_::24, _::_*8>>
  @type cmd :: <<_::32, _::_*8>>
  @type cmd_result :: <<_::32, _::_*8>>

  @callback paged_read(
              pgm :: t(),
              page_size :: non_neg_integer(),
              baseaddr :: target_addr(),
              n_bytes :: non_neg_integer()
            ) ::
              {:ok, binary()} | {:error, term()}

  @callback paged_write(
              pgm :: t(),
              page_size :: non_neg_integer(),
              baseaddr :: target_addr(),
              data :: binary()
            ) ::
              :ok | {:error, term()}

  @callback read_sig_bytes(pgm :: t()) :: {:ok, signature} | {:error, term()}

  @callback cmd(pgm :: t(), cmd :: cmd()) ::
              {:ok, cmd_result()} | {:error, term()}

  @callback initialize(pgm :: t()) :: {:ok, t()} | {:error, term()}

  @callback open(pgm :: t(), port_name :: String.t(), opts :: Keyword.t()) ::
              {:ok, t()} | {:error, term()}

  @callback close(pgm :: t()) :: :ok

  @callback init_pgm(opts :: Keyword.t()) ::
              {:ok, t()} | {:error, term()}

  def lookup(programmer) when is_atom(programmer) do
    case Keyword.get(@programmers, programmer) do
      nil -> {:error, :unknown_programmer}
      res -> {:ok, res}
    end
  end
end
