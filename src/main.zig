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

pub const Ray = struct {
    origin: @Vector(3, f32),
    direction: @Vector(3, f32),
};

pub const Light = struct {
    position: @Vector(3, f32),
    color: @Vector(3, f32),
};

pub const Sphere = struct {
    origin: @Vector(3, f32),
    radius: f32,
    color: @Vector(3, f32),

    pub fn getRayIntersection(self: *const Sphere, ray: Ray) ?f32 {
        const distance_to_origin = ray.origin - self.origin;

        const a = 1; //dotProduct(self.direction, self.direction); //Always 1???
        const b = 2 * dotProduct(ray.direction, distance_to_origin);
        const c = dotProduct(distance_to_origin, distance_to_origin) - (self.radius * self.radius);

        const solved_quadratic = solveQuadratic(a, b, c) orelse return null;
        if (solved_quadratic[0] < 0) {
            if (solved_quadratic[1] < 0) return null; // Both t0 and t1 are negative.
            return solved_quadratic[1];
        }
        return solved_quadratic[0];
    }

    pub fn getNormalAtPoint(self: *const Sphere, point: @Vector(3, f32)) @Vector(3, f32) {
        return normalizeVector(point - self.origin);
    }
};

pub const Shape = union(enum) {
    sphere: Sphere,

    // Only call this where you don't need properties from the shape later on
    pub fn getRayIntersection(self: *const Shape, ray: Ray) ?f32 {
        switch (self.*) {
            .sphere => |sphere| {
                return sphere.getRayIntersection(ray);
            },
        }
    }
};

pub const Camera = struct {
    position: @Vector(3, f32),
    view_direction: @Vector(3, f32),
    focal_distance: @Vector(3, f32), //Stored as a vector for easer vector operations, could just as well be a float
    screen: Image, //Could be rendundant if the below optimization is used
    width: u16, //This data is duplicated in the image
    height: u16, //I think this will still allowed faster lookup though

    pub fn init(position: @Vector(3, f32), view_direction: @Vector(3, f32), focal_distance: f32, width: u16, height: u16, allocator: std.mem.Allocator) !Camera {
        return Camera{
            .position = position,
            .view_direction = view_direction,
            .focal_distance = @splat(focal_distance),
            .screen = try Image.init(width, height, allocator),
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *const Camera, allocator: std.mem.Allocator) void {
        self.screen.deinit(allocator);
        // allocator.free(self.closest_intersections);
    }

    pub fn getFocalCenter(self: *const Camera) @Vector(3, f32) {
        return self.position + (self.view_direction * self.focal_distance);
    }

    pub fn renderScene(self: *const Camera, scene: *const Scene) !void {
        const screen_center = self.getFocalCenter();
        const screen_width_half: f32 = @floatFromInt(self.screen.width / 2);
        const screen_height_half: f32 = @floatFromInt(self.screen.height / 2);

        self.screen.resetBuffer(.{ 0, 0, 0 });
        for (0..self.width) |x| {
            for (0..self.height) |y| {
                const xf: f32 = @floatFromInt(x);
                const yf: f32 = @floatFromInt(y);

                const pixel_divisons = subpixel_count / 2;
                var final_color: @Vector(3, f32) = @splat(0);

                const pixel_center = @Vector(3, f32){ screen_center[0] + xf - screen_width_half, screen_center[1] + yf - screen_height_half, screen_center[2] };
                const pixel_left_top = pixel_center - @Vector(3, f32){ 0.5, 0.5, 0 };

                for (0..subpixel_count) |subpixel_index| {
                    const subpixel_x = subpixel_index % (pixel_divisons);
                    const subpixel_y = @divFloor(subpixel_index, pixel_divisons);
                    const subpixel_step: f32 = 1.0 / @as(f32, @floatFromInt(subpixel_count));

                    const subpixel_steps_x = (subpixel_x * 2) + 1;
                    const subpixel_steps_y = (subpixel_y * 2) + 1;

                    const subpixel_offset_x = subpixel_step * @as(f32, @floatFromInt(subpixel_steps_x));
                    const subpixel_offset_y = subpixel_step * @as(f32, @floatFromInt(subpixel_steps_y));

                    //print("Pixel offset for pixel {},{}: {d},{d}\n", .{subpixel_x, subpixel_y, subpixel_offset_x, subpixel_offset_y});
                    const subpixel_center = pixel_left_top + @Vector(3, f32){ subpixel_offset_x, subpixel_offset_y, 0 };

                    const signed_distance_from_camera = subpixel_center - self.position;
                    const ray_direction = normalizeVector(signed_distance_from_camera);

                    const ray = Ray{ .origin = self.position, .direction = ray_direction };

                    var closest_intersection = std.math.floatMax(f32);
                    for (scene.shapes, 0..) |shapeoptional, first_shape_index| {
                        const shape = shapeoptional orelse continue;
                        switch (shape) { //TODO: Consider if keeping this is worth it or if the performance impact of doing multiple switches inside the shape tagged union is a worth tradeof.
                            .sphere => |sphere| {
                                const intersection = sphere.getRayIntersection(ray) orelse continue;

                                if (intersection < closest_intersection) {
                                    defer closest_intersection = intersection;

                                    // Steps to calculate lighting
                                    // If the ray hits the sphere, we calculate point P where it happens
                                    const intersection_point = ray.origin + ray.direction * @as(@Vector(3, f32), @splat(intersection));

                                    for (scene.lights) |lightoptional| {
                                        const light = lightoptional orelse continue;

                                        // Then we cast a ray from P to the light source L̅
                                        // R̅ is a vector of length one from P̅ to L̅: R̅ = (L̅ - P̅) / |L̅ - P̅|
                                        const light_ray_direction = normalizeVector(light.position - intersection_point);
                                        const light_ray = Ray{ .origin = intersection_point, .direction = light_ray_direction };
                                        // If this ray hits the other sphere, the point is occluded and the pixel remains dark.

                                        //Shadow casting code
                                        const intercepted = for (scene.shapes, 0..) |shapeoptional2, second_shape_index| {
                                            if (first_shape_index == second_shape_index) continue;
                                            const shape2 = shapeoptional2 orelse continue;

                                            const light_intersections = shape2.getRayIntersection(light_ray);
                                            if (light_intersections != null) {
                                                //@abs(light_ray.direction[0]) < 0.01 and @abs(light_ray.direction[1]) < 0.01
                                                break true;
                                            }
                                        } else false;

                                        if (intercepted) continue;

                                        // Otherwise, we compute the color using using the angle between normal and direction to the light.
                                        // Then, R̅ ⋅ N̅ gives us this “is the light falling straight at the surface?” coefficient between 0 and 1.
                                        // print("Light ray direction: {d} -- Normal at intersection: {d}\n", .{normal_at_intersection, light_ray_direction});
                                        const light_intensity = @max(0, dotProduct(light_ray_direction, sphere.getNormalAtPoint(intersection_point)));
                                        final_color += sphere.color * light.color * @as(@Vector(3, f32), @splat(light_intensity));
                                    }
                                }
                            },
                        }
                    }
                }

                final_color = final_color / @as(@Vector(3, f32), @splat(subpixel_count));
                final_color = std.math.clamp(final_color, @as(@Vector(3, f32), @splat(0)), @as(@Vector(3, f32), @splat(1)));

                try self.screen.setPixel(@intCast(x), @intCast(y), final_color);
                //Pixel ends here

            }
        }
    }
};

const max_cameras = 5;
const max_lights = 10;
const max_shapes = 100;
const subpixel_count = 256; //Must be divisible by 4

pub const Scene = struct {
    //lights, cameras, shapes
    cameras: [max_cameras]?Camera = .{null} ** max_cameras,
    shapes: [max_shapes]?Shape = .{null} ** max_shapes,
    lights: [max_lights]?Light = .{null} ** max_lights,
    camera_count: u8 = 0,
    light_count: u8 = 0,
    shape_count: u8 = 0,

    pub fn render(self: *const Scene) !void {
        for (self.cameras) |camera| {
            if (camera == null) continue;
            try camera.?.renderScene(self);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    defer print("Has memory leak {any}", .{gpa.detectLeaks()});

    var scene = Scene{};
    scene.shapes[0] = Shape{ .sphere = Sphere{ .origin = .{ -50, 0, 100 }, .radius = 50, .color = .{ 1, 1, 1 } } };
    scene.shapes[1] = Shape{ .sphere = Sphere{ .origin = .{ 0, 0, 100 }, .radius = 50, .color = .{ 1, 1, 1 } } };
    scene.shapes[2] = Shape{ .sphere = Sphere{ .origin = .{ 50, 0, 100 }, .radius = 50, .color = .{ 1, 1, 1 } } };
    //scene.shapes[2] = Shape{ .sphere = Sphere{ .origin = .{ 0, -50, -150 }, .radius = 40, .color = .{ 0, 1, 1 }}};

    const camera = try Camera.init(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 200, 640, 480, allocator);
    defer camera.deinit(allocator);

    scene.cameras[0] = camera;

    scene.lights[0] = Light{ .position = .{ 0, 0, 0 }, .color = .{ 0.5, 0.5, 0.5 } };
    scene.lights[1] = Light{ .position = .{ -100, -100, 0 }, .color = .{ 1, 0, 0 } };
    scene.lights[2] = Light{ .position = .{ 100, -100, 0 }, .color = .{ 0, 0, 1 } };
    try scene.render();

    const p3_parsed_image = try scene.cameras[0].?.screen.toP3(allocator);
    defer allocator.free(p3_parsed_image);
    const file_path = "test.ppm";

    // Writing to a file
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.writeAll(p3_parsed_image);
}
