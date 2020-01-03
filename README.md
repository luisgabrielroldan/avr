# AVR
[![CircleCI](https://circleci.com/gh/luisgabrielroldan/avr.svg?style=svg)](https://circleci.com/gh/luisgabrielroldan/avr)

AVR Firmware Uploader (Only Arduino targets are supported).

## Why?

Usually in my projects I need hard realtime (e.g. Send/Receive IR signals) which is a complicated
task to achieve with Nerves because you have the erlang scheduler plus the OS multitasking.
So for those times where realtime is needed the simplest solution is to have hardware that supports it like an Arduino.

But wait... what if I want to also update my little Arduino companion firmware as easy as I update my app firmware?

### The Goal

To accomplish this goal I need:
- **The firmware loader**:  This is done (At least for the Arduino models I use).
- **Firmware version check mechanism**: A way to check the current companion firmware version installed (Maybe storing the version on the EEPROM or reading and comparing the firmware in the device).
- **Automated updater**: An app to be included in the project to update (Maybe at boot time) the companion/s firmware when is necessary.
- **Compiler task** (Optional): To include the Arduino source in the Nerves project and compile the `hex` file on build.

## Usage

```elixir
AVR.upload("foo/bar/binary.compiled.hex", "ttyACM0", :uno)
```

**IMPORTANT! The hex file has to be compiled to match the target hardware (MCU and Clock speed)**

## Supported boards:
 - `:uno`: Arduino Uno
 - `:pro8MHzatmega328p`: Arduino Pro or Pro Mini ATmega328 (3.3V, 8 MHz)
 - `:pro16MHzatmega328p`: Arduino Pro or Pro Mini ATmega328 (5V, 16 MHz)
 - `:atmega328`: Generic ATmega328
 - `:atmega328p`: Generic ATmega328P

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `avr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:avr, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/avr](https://hexdocs.pm/avr).

