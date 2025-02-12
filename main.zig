const std = @import("std");

const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
};

pub const ImageError = error{
    PixelOutOfBounds,
};

const Image = struct {
    width: u8,
    height: u8,
    pixels: []Color,

    pub fn create(width: u8, height: u8, allocator: std.mem.Allocator) !Image {
        const pixel_count = width * height;
        const pixels = try allocator.alloc(Color, pixel_count);
        std.mem.zeroInit(Color, pixels);
        return Image{
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, color: Color) !void {
        if (x >= self.width or y >= self.height) {
            return error.PixelOutOfBounds;
        }
        const index = y * self.width + x;
        self.pixels[index] = color;
    }

    pub fn print(self: *Image) void {
        for (self.pixels, 0..) |pixel, i| {
            std.debug.print("Pixel {}: {},{},{}\n", .{ i, pixel.r, pixel.g, pixel.b });
        }
    }
};

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var img = try Image.create(3, 2, allocator);
    defer allocator.free(img.pixels);

    img.print();
}
