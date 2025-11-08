Pretty printer for Zig data structures to help with debugging.

![zig-spew output](docs/images/screenshot.png)

## Badges

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/omissis/zig-spew?style=for-the-badge)](https://github.com/omissis/zig-spew/releases/latest)
[![GitHub Workflow Status (event)](https://img.shields.io/github/actions/workflow/status/omissis/zig-spew/development.yaml?style=for-the-badge&branch=main)](https://github.com/omissis/zig-spew/actions?workflow=development)
[![License](https://img.shields.io/github/license/omissis/zig-spew?style=for-the-badge)](/LICENSE)
[![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/omissis/zig-spew?style=for-the-badge)](https://github.com/omissis/zig-spew)
[![GitHub repo file count (file type)](https://img.shields.io/github/directory-file-count/omissis/zig-spew?style=for-the-badge)](https://github.com/omissis/zig-spew)
[![GitHub all releases](https://img.shields.io/github/downloads/omissis/zig-spew/total?style=for-the-badge)](https://github.com/omissis/zig-spew)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/y/omissis/zig-spew?style=for-the-badge)](https://github.com/omissis/zig-spew/commits)

## Example usage

```Zig
const std = @import("std");
const spew = @import("spew.zig");

pub fn main() !void {
    const d = spew.Dumper{};

    const Currency = struct {
        Name: []const u8,
        Symbol: []const u8,
    };
    const Money = struct {
        Amount: u32,
        Currency: Currency,
    };
    const m = Money{
        .Amount = 1000,
        .Currency = .{
            .Name = "Euro",
            .Symbol = "€",
        },
    };

    try d.print(m);

    try spew.dump(m);
}
```
