defmodule AVR.IHexTest do
  use ExUnit.Case

  alias AVR.IHex

  @test_file "test/fixtures/test.simple.hex"
  @blink_file "test/fixtures/blink.atmega328p.hex"
  @blink_with_bootloader_file "test/fixtures/blink.with_bootloader.atmega328p.hex"

  test "parse test file" do
    assert {:ok, %IHex{} = ihex} = IHex.parse_file(@test_file)

    assert IHex.size(ihex) == 42

    assert IHex.to_regions(ihex) == [
             {0x00000000, <<0x01, 0x01, 0x02, 0x02, 0x02, 0x02>>},
             {0x00000100, <<0x03, 0x03, 0x04, 0x04>>},
             {0xFFFF0000, <<0x05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>},
             {0xFFFF0100, <<0x06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
           ]
  end

  test "parse blink hex" do
    assert {:ok, %IHex{} = ihex} = IHex.parse_file(@blink_file)

    assert IHex.size(ihex) == 928

    assert [{0x00000000, _}] = IHex.to_regions(ihex)
  end

  test "parse blink hex with bootloader" do
    assert {:ok, %IHex{} = ihex} = IHex.parse_file(@blink_with_bootloader_file)

    assert IHex.size(ihex) == 2860

    assert [
             {0x00000000, _},
             {0x00007800, _}
           ] = IHex.to_regions(ihex)
  end
end
