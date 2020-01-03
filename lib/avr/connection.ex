defmodule AVR.Connection do
  @moduledoc false

  @type t :: atom() | pid()

  @callback open(port_name :: String.t(), opts :: Keyword.t()) :: {:ok, t()} | {:error, term()}

  @callback close(conn :: t()) :: :ok | {:error, term()}

  @callback send(conn :: t(), data :: binary()) :: :ok | {:error, term()}

  @callback recv(conn :: t()) :: {:ok, binary()} | {:error, term()}

  @callback recv(conn :: t(), timeout :: non_neg_integer()) :: {:ok, binary()} | {:error, term()}

  @callback drain(conn :: t()) :: :ok | {:error, term()}
end
