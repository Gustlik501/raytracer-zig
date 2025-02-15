const std = @import("std");

pub const ImageError = error{
    PixelOutOfBounds,
    InvalidColorFormat,
};

pub const Image = struct {
    width: u16,
    height: u16,
    pixels: []@Vector(3, u8),

    pub fn init(width: u16, height: u16, allocator: std.mem.Allocator) !Image {
        const pixel_count = @as(u32, width) * @as(u32, height);
        std.debug.print("Pixel count: {}\n", .{pixel_count});
        const pixels = try allocator.alloc(@Vector(3, u8), pixel_count);
        @memset(pixels, @splat(0));
        return Image{
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: *const Image, allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn resetBuffer(self: *const Image, color: @Vector(3, u8)) void {
        @memset(self.pixels, color);
    }

    pub fn setPixel(self: *const Image, x: u32, y: u32, color: anytype) ImageError!void {
        if (x >= self.width or y >= self.height) {
            return error.PixelOutOfBounds;
        }
        const index = y * self.width + x;
        switch (@TypeOf(color)) {
            @Vector(3, u8) => self.pixels[index] = color,
            @Vector(3, f32) => self.pixels[index] = @intFromFloat(color * @as(@Vector(3, f32), @splat(255))),
            else => return ImageError.InvalidColorFormat,
        }
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
