const std = @import("std");
const print = std.debug.print;

const Image = @import("image.zig").Image;

pub fn normalizeVector(vector: anytype) @TypeOf(vector) {
    const vector_length: @TypeOf(vector) = @splat(@sqrt(@reduce(.Add, vector * vector)));
    const normalized_vector = vector / vector_length;
    return normalized_vector;
}

pub fn dotProduct(vector1: anytype, vector2: anytype) f32 {
    return @reduce(.Add, vector1 * vector2);
}

pub fn solveQuadratic(a: f32, b: f32, c: f32) ?[2]f32 {
    var solutions = [2]f32{ 0, 0 };
    const discr: f32 = b * b - 4 * a * c;
    if (discr < 0) return null else if (discr == 0) {
        solutions = .{ -0.5 * b / a, -0.5 * b / a };
    } else {
        const q: f32 = if (b > 0) -0.5 * (b + @sqrt(discr)) else -0.5 * (b - @sqrt(discr));
        solutions = .{ q / a, c / q };
    }
    if (solutions[0] > solutions[1]) {
        std.mem.swap(f32, &solutions[0], &solutions[1]);
    }
    return solutions;
}

pub const Sphere = struct {
    position: @Vector(3, f32),
    radius: f32,
    color: @Vector(3, u8),
};

pub const Ray = struct {
    origin: @Vector(3, f32),
    direction: @Vector(3, f32),

    pub fn getSphereIntersections(self: *const Ray, sphere: Sphere) ?[2]f32 {
        const distance_to_origin = self.origin - sphere.position;

        const a = 1; //dotProduct(self.direction, self.direction); //Always 1???
        const b = 2 * dotProduct(self.direction, distance_to_origin);
        const c = dotProduct(distance_to_origin, distance_to_origin) - (sphere.radius * sphere.radius);

        return solveQuadratic(a, b, c);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    defer print("Has memory leak {any}", .{gpa.detectLeaks()});

    var img = try Image.create(640, 480, allocator);
    defer allocator.free(img.pixels);

    var spheres = std.ArrayList(Sphere).init(allocator);
    defer spheres.deinit();

    _ = try spheres.append(Sphere{ .position = .{ 0, 0, -100 }, .radius = 50, .color = .{ 255, 100, 255 } });
    _ = try spheres.append(Sphere{ .position = .{ 0, -50, -50 }, .radius = 50, .color = .{ 0, 255, 255 } });

    const camera_position = @Vector(3, f32){ 0, 0, -200 };

    const view_direction = @Vector(3, f32){ 0, 0, 1 };
    const focal_distance: @Vector(3, f32) = @splat(100);

    const screen_center = camera_position + (view_direction * focal_distance);
    const screen_width_half: f32 = @floatFromInt(img.width / 2);
    const screen_height_half: f32 = @floatFromInt(img.height / 2);

    const closestIntersections = try allocator.alloc(f32, @as(u32, img.width) * img.height);
    @memset(closestIntersections, std.math.floatMax(f32));
    defer allocator.free(closestIntersections);

    for (0..img.width) |x| {
        for (0..img.height) |y| {
            const xf: f32 = @floatFromInt(x);
            const yf: f32 = @floatFromInt(y);
            const current_pixel = @Vector(3, f32){ screen_center[0] + xf - screen_width_half, screen_center[1] + yf - screen_height_half, screen_center[2] };

            const signed_distance_from_camera = current_pixel - camera_position;
            const ray_direction = normalizeVector(signed_distance_from_camera);

            const ray = Ray{ .origin = camera_position, .direction = ray_direction };

            for (spheres.items) |sphere| {
                const intersections = ray.getSphereIntersections(sphere);
                if (intersections != null) {
                    const index = y * img.width + x;
                    const first_intersection = intersections.?[0];
                    if (first_intersection < closestIntersections[index]) {
                        try img.setPixel(@intCast(x), @intCast(y), sphere.color);
                        closestIntersections[index] = first_intersection;
                    }
                }
            }

            // const intersections = ray.getSphereIntersections(sphere1);
            // if (intersections != null) {
            //     //print("Checking pixel {},{}: ray_direction: {d} - distance_from_camera: {d}\n", .{x,y,ray_direction, signed_distance_from_camera});
            //     //print("Found intersection at pixel: {},{} -- Intersection points: {d},{d}\n", .{ x, y , intersections.?[0], intersections.?[1]});
            //     try img.setPixel(@intCast(x), @intCast(y), sphere1.color);
            // }
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
