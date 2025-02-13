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
        const pixel_count = @as(u16, width) * @as(u16, height);
        std.debug.print("Pixel count: {}\n", .{pixel_count});
        const pixels = try allocator.alloc(Color, pixel_count);
        for (pixels) |*pixel| {
            pixel.* = .{};
        }
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
            const isBlack = pixel.r == 0 and pixel.g == 0 and pixel.b == 0;
            if (isBlack) std.debug.print("x", .{}) else std.debug.print(".", .{});

            if ((i + 1) % self.width == 0)
                std.debug.print("\n", .{});
        }
    }

    pub fn toP3(self: *Image) ![]u8 {
        var buffer: [786444]u8 = undefined; // Absolute maximum filesize for a 256x256 image
        var written_length: usize = 0;
        const written_header_slice = try std.fmt.bufPrint(&buffer, "P3\n{} {} 255\n", .{ self.width, self.height });

        written_length += written_header_slice.len;

        for (self.pixels, 0..) |pixel, i| {
            const written_color_slice = try std.fmt.bufPrint(buffer[written_length..], "{} {} {}", .{ pixel.r, pixel.g, pixel.b });
            written_length += written_color_slice.len;

            if ((i + 1) % self.width == 0) _ = try std.fmt.bufPrint(buffer[written_length..], "\n", .{}) else _ = try std.fmt.bufPrint(buffer[written_length..], " ", .{});

            written_length += 1;
        }

        //std.debug.print("Buffer:\n{s}{s}{s}", .{"start", buffer[0..written_length], "end"});

        return buffer[0..written_length]; //This will cause a dangling pointer.
    }
};

//NOTE: firguring out calculating this as a float maybe :<
//      Could be cool to automagically detirmine and return the minimum sized float needed to represet the distance correctly,
//      even when it's passed an int. Might be a cool project function to learn comptime later on
pub fn distance(fp_x: anytype, fp_y: anytype, sp_x: anytype, sp_y: anytype) @TypeOf(fp_x) {
    //switch (@typeInfo(@TypeOf(fp_x))){
    //    .int => {
    //        std.debug.print("Calculating info for integer", .{})
    //        },
    //    else => {},
    //}

    //const fp_x_float: f32 = @floatFromInt(fp_x);
    //const fp_y_float: f32 = @floatFromInt(fp_y);
    //const sp_x_float: f32 = @floatFromInt(sp_x);
    //const sp_y_float: f32 = @floatFromInt(sp_y);

    const distance_x = @abs(fp_x - sp_x);
    const distance_y = @abs(fp_y - sp_y);
    const distance_between_points = std.math.sqrt((distance_x * distance_x) + (distance_y * distance_y));
    return distance_between_points;
}

pub fn isPointInCircle(x: i16, y: i16, circle_x: i16, circle_y: i16, circle_radius: u16) bool {
    const distance_from_origin = distance(x, y, circle_x, circle_y);
    return (distance_from_origin < circle_radius);
}

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var img = try Image.create(64, 48, allocator);
    defer allocator.free(img.pixels);
    const white = Color{ .r = 255, .g = 255, .b = 255 };

    const circle_x = img.width / 2;
    const circle_y = img.height / 2;
    const circle_radius = 7;

    for (0..img.width) |x| {
        for (0..img.height) |y| {
            if (isPointInCircle(@intCast(x), @intCast(y), circle_x, circle_y, circle_radius)) {
                try img.setPixel(@intCast(x), @intCast(y), white);
            }
        }
    }

    const p3_parsed_image = try img.toP3();
    const file_path = "test.ppm";

    // Writing to a file
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writeAll(p3_parsed_image);
}
