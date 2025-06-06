// ********************************************************************************
//  https://github.com/PatrickTorgerson
//  Copyright (c) 2025 Patrick Torgerson
//  MIT license, see LICENSE for more information
// ********************************************************************************

const std = @import("std");

pub const Vector = @Vector(2, f32);

pub const zero: Vector = .{ 0, 0 };
pub const left: Vector = .{ -1, 0 };
pub const right: Vector = .{ 1, 0 };
pub const up: Vector = .{ 0, -1 };
pub const down: Vector = .{ 0, 1 };

pub fn scale(v: *Vector, s: f32) void {
    v.* *= splat(s);
}

pub fn scaled(v: Vector, s: f32) Vector {
    return v * splat(s);
}

pub fn normalize(v: *Vector) void {
    v.* /= splat(length(v.*));
}

pub fn normalized(v: Vector) Vector {
    return v / splat(length(v));
}

pub fn lengthSqrd(v: Vector) f32 {
    return @reduce(.Add, v * v);
}

pub fn length(v: Vector) f32 {
    return @sqrt(lengthSqrd(v));
}

pub fn distSqrd(l: Vector, r: Vector) f32 {
    return lengthSqrd(l - r);
}

pub fn dist(l: Vector, r: Vector) f32 {
    return @sqrt(distSqrd(l, r));
}

pub fn invert(v: *Vector) void {
    v.* *= splat(-1);
}

pub fn inverted(v: Vector) Vector {
    return v * splat(-1);
}

pub fn abs(v: Vector) Vector {
    return .{ @abs(v[0]), @abs(v[1]) };
}

pub fn min(l: Vector, r: Vector) Vector {
    return .{ @min(l[0], r[0]), @min(l[1], r[1]) };
}

pub fn max(l: Vector, r: Vector) Vector {
    return .{ @max(l[0], r[0]), @max(l[1], r[1]) };
}

pub fn dot(l: Vector, r: Vector) f32 {
    return l[0] * r[0] + l[1] * r[1];
}

pub fn cross(l: Vector, r: Vector) f32 {
    return l[0] * r[1] - l[1] * r[0];
}

pub fn crossSV(s: f32, v: Vector) Vector {
    return .{ -s * v[1], s * v[0] };
}

pub fn crossVS(v: Vector, s: f32) Vector {
    return .{ s * v[1], -s * v[0] };
}

pub fn rotatedByNormal(v: Vector, n: Vector) Vector {
    return .{
        v[0] * n[0] - v[1] * n[1],
        v[0] * n[1] + v[1] * n[0],
    };
}

pub fn rotateByNormal(v: *Vector, n: Vector) void {
    v[0] = v[0] * n[0] - v[1] * n[1];
    v[1] = v[0] * n[1] + v[1] * n[0];
}

pub fn rotatedByAngle(v: Vector, a: f32) Vector {
    return rotatedByNormal(v, normalFromAngle(a));
}

pub fn rotateByAngle(v: *Vector, a: f32) void {
    rotateByNormal(v, normalFromAngle(a));
}

pub fn normalFromAngle(a: f32) Vector {
    return .{ @cos(a), @sin(a) };
}

pub fn angle(v: Vector) f32 {
    return std.math.atan2(f32, v[1], v[0]);
}

pub fn perpendicularCW(v: Vector) Vector {
    return .{ -v[1], v[0] };
}

pub fn perpendicularCCW(v: Vector) Vector {
    return .{ v[1], -v[0] };
}

/// calculate angle between l and r
/// assumes l and r have length 1
pub fn signedAngleBetweenNormals(l: Vector, r: Vector) f32 {
    return std.math.atan2(f32, cross(l, r), dot(l, r));
}

/// calculate angle between l and r
/// uses calculated normalized l and r
pub fn signedAngle(l: Vector, r: Vector) f32 {
    return signedAngleBetweenNormals(normalized(l), normalized(r));
}

pub fn splat(s: f32) Vector {
    return @splat(s);
}
