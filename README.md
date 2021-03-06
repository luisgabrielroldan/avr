# AVR
[![CircleCI](https://circleci.com/gh/luisgabrielroldan/avr.svg?style=svg)](https://circleci.com/gh/luisgabrielroldan/avr)
[![Hex version](https://img.shields.io/hexpm/v/avr.svg "Hex version")](https://hex.pm/packages/avr)

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

## Auto-reset

Arduino boards needs to be reseted to enable the programing mode. The reset is performed automatically using the DTR line when the board is connected by USB.

To use the RPi hardware serial port you need to configure a GPIO pin to work as a reset line using the `gpio_reset` option:

```elixir
AVR.upload("foo/bar/binary.compiled.hex", "ttyACM0", :uno, gpio_reset: 4)
```

On this case, the `GPIO04` will be connected to the reset pin.

**NOTE:** The reset works putting the RESET pint to LOW for a few milliseconds. For this reason you have to use the GPIOs with pull-up resistors (GPIO0-GPIO8).

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

