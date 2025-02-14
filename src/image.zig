const std = @import("std");

pub const ImageError = error{
    PixelOutOfBounds,
};

pub const Image = struct {
    width: u8,
    height: u8,
    pixels: []@Vector(3, u8),

    pub fn create(width: u8, height: u8, allocator: std.mem.Allocator) !Image {
        const pixel_count = @as(u16, width) * @as(u16, height);
        std.debug.print("Pixel count: {}\n", .{pixel_count});
        const pixels = try allocator.alloc(@Vector(3, u8), pixel_count);
        @memset(pixels, @splat(0));
        return Image{
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, color: @Vector(3, u8)) !void {
        if (x >= self.width or y >= self.height) {
            return error.PixelOutOfBounds;
        }
        const index = y * self.width + x;
        self.pixels[index] = color;
    }

    pub fn print(self: *Image) void {
        for (self.pixels, 0..) |pixel, i| {
            const isBlack = pixel.r == 0 and pixel.g == 0 and pixel.b == 0;
            if (isBlack) std.debug.print("x", .{}) else std.debug.print(".", .{});

            if ((i + 1) % self.width == 0)
                std.debug.print("\n", .{});
        }
    }

    pub fn toP3(self: *Image, allocator: std.mem.Allocator) ![]u8 {
        var string = std.ArrayList(u8).init(allocator);
        const writer = string.writer();

        try writer.print("P3\n{} {} 255\n", .{ self.width, self.height });

        for (self.pixels, 0..) |pixel, i| {
            try writer.print("{} {} {}", .{ pixel[0], pixel[1], pixel[2] });
            if ((i + 1) % self.width == 0)
                try writer.print("\n", .{})
            else
                try writer.print(" ", .{});
        }

        const s = try string.toOwnedSlice();
        return s;
    }
};
