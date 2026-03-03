# HP-16C RPN Calculator Emulator

An emulator for the HP-16C programmable scientific calculator, written in Zig.

## Features

- 4-level RPN stack (T, Z, Y, X)
- Arithmetic operations (+, -, *, /)
- Bitwise operations (AND, OR, XOR, NOT)
- Multiple number bases (HEX, DEC, OCT, BIN)
- Configurable word size (1-128 bits)
- 16 storage registers
- Shift operations (left/right)
- Carry and overflow flags

## Requirements

- Zig 0.15.0 or later

## Building

```bash
zig build
```

## Running

```bash
zig build run
```

## Running Tests

```bash
zig build test
```

## Usage

### Basic Example

```
> 10
> ENTER
> 5
> +
```

Result: 15 in X register

### Commands

| Command | Description |
|---------|-------------|
| `[number]` | Enter number in current base |
| `ENTER` | Push X to stack |
| `DROP` | Remove X from stack |
| `SWAP` | Exchange X and Y |
| `RV` | Roll stack down |
| `R^` | Roll stack up |
| `CLR` | Clear all registers |
| `HELP` | Show help |
| `QUIT` | Exit |

### Arithmetic

| Command | Description |
|---------|-------------|
| `+` | Add Y + X |
| `-` | Subtract Y - X |
| `*` | Multiply Y * X |
| `/` | Divide Y / X |

### Bitwise

| Command | Description |
|---------|-------------|
| `&` | AND |
| `|` | OR |
| `^` | XOR |
| `~` | NOT |

### Base Conversion

| Command | Description |
|---------|-------------|
| `HEX` | Hexadecimal |
| `DEC` | Decimal |
| `OCT` | Octal |
| `BIN` | Binary |

### Word Size

| Command | Description |
|---------|-------------|
| `WS [n]` | Set word size (1-128 bits) |

### Shift Operations

| Command | Description |
|---------|-------------|
| `SL [n]` | Shift left n positions |
| `SR [n]` | Shift right n positions |

### Memory

| Command | Description |
|---------|-------------|
| `STO [n]` | Store X in register n (0-15) |
| `RCL [n]` | Recall register n to stack |

## License

MIT
