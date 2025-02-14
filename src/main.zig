const std = @import("std");
const print = std.debug.print;

const Image = @import("image.zig").Image;

//NOTE: firguring out calculating this as a float maybe :<
//      Could be cool to automagically detirmine and return the minimum sized float needed to represet the distance correctly,
//      even when it's passed an int. Might be a cool project function to learn comptime later on
pub fn distance(fp_x: anytype, fp_y: anytype, sp_x: anytype, sp_y: anytype) @TypeOf(fp_x) {
    //switch (@typeInfo(@TypeOf(fp_x))){
    //    .int => {
    //        print("Calculating info for integer", .{})
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    defer print("Has memory leak {any}", .{gpa.detectLeaks()});

    var img = try Image.create(64, 48, allocator);
    defer allocator.free(img.pixels);

    const circle_x = img.width / 2;
    const circle_y = img.height / 2;
    const circle_radius = 7;

    for (0..img.width) |x| {
        for (0..img.height) |y| {
            if (isPointInCircle(@intCast(x), @intCast(y), circle_x, circle_y, circle_radius)) {
                try img.setPixel(@intCast(x), @intCast(y), .{ 255, 255, 255 });
            }
        }
    }

    const p3_parsed_image = try img.toP3(allocator);
    defer allocator.free(p3_parsed_image);
    const file_path = "test.ppm";

    // Writing to a file
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writeAll(p3_parsed_image);
}
