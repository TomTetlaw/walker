

Bounding_Box :: struct {
    min, max: V3;
}

grow_bounding_box :: (box: *Bounding_Box, position: V3) {
    box.min = min(box.min, position);
    box.max = max(box.max, position);
}

bounding_box_area :: (box: Bounding_Box) -> float {
    e := box.max - box.min;
    return e.x * e.y + e.y * e.z + e.z * e.x;
}

Triangle :: struct {
    p0, p1, p2: V3;
}

Ray :: struct {
    origin: V3;
    direction: V3;
}

ray_intersects_box :: (box: Bounding_Box, ray: Ray) -> bool {
    inv_dir := v3(1.0) / ray.direction;

    t1 := (box.min.x - ray.origin.x) * inv_dir.x;
    t2 := (box.max.x - ray.origin.x) * inv_dir.x;

    t_min := min(t1, t2);
    t_max := max(t1, t2);

    for 0..2 {
        t1 = (box.min[it] - ray.origin[it]) * inv_dir[it];
        t2 = (box.max[it] - ray.origin[it]) * inv_dir[it];

        t_min = max(t_min, min(t1, t2));
        t_max = min(t_max, max(t1, t2));
    }

    return t_max > max(t_min, 0.0);
}

Ray_Triangle_Intersection :: struct {
    t: float;
    point: V3;
    tri: BVH_Triangle;
}

ray_intersects_triangles :: (tris: [] BVH_Triangle, ray: Ray) -> bool, Ray_Triangle_Intersection {
    best_t := FLOAT32_MAX;
    best_hit: Ray_Triangle_Intersection;

    e :: 0.00001;

    for tris {
        h := cross(ray.direction, it.e1);
        a := dot(it.e0, h);
        if abs(a) < e continue;

        f := 1.0 / a;
        s := ray.origin - it.p0;
        u := f * dot(s, h);
        if u < 0.0 || u > 1.0 continue;

        q := cross(s, it.e0);
        v := f * dot(ray.direction, q);
        if v < 0.0 || u + v > 1.0 continue;

        t := f * dot(it.e1, q);
        if t > e {
            if t < best_t {
                best_t = t;
                best_hit = .{t, ray.origin + t * ray.direction, it};
            }
        }
    }

    if best_t < FLOAT32_MAX {
        return true, best_hit;
    }

    return false, .{};
}

BVH_Triangle :: struct {
    p0, p1, p2: V3;
    e0, e1: V3;
    centroid: V3;
    source_index: u32;
}

BVH_Node :: struct {
    bounds: Bounding_Box;
    tri_count: u32;
    left_or_first_tri: u32;
}

BVH :: struct {
    nodes: [] BVH_Node;
    tri_index: [] int;
    triangles: [] BVH_Triangle;
    nodes_used: int;
}

create_bvh_from_models :: (arena: *Arena, models: [] Model) -> BVH {
    tri_count := 0;

    for models {
        for mesh_index: 0..it.meshCount - 1 {
            tri_count += it.meshes[mesh_index].triangleCount;
        }
    }

    tris := push_view(arena, Triangle, tri_count);

    for models {
        base_tri := 0;
        for mesh_index: 0..it.meshCount - 1 {
            mesh := it.meshes[mesh_index];

            for tri_index: 0..mesh.triangleCount - 1 {
                i0 := tri_index * 3 + 0;
                i1 := tri_index * 3 + 1;
                i2 := tri_index * 3 + 2;

                if mesh.indices {
                    i0 = mesh.indices[i0];
                    i1 = mesh.indices[i1];
                    i2 = mesh.indices[i2];
                }

                p0 := v3(mesh.vertices[i0 * 3 + 0], mesh.vertices[i0 * 3 + 1], mesh.vertices[i0 * 3 + 2]);
                p1 := v3(mesh.vertices[i1 * 3 + 0], mesh.vertices[i1 * 3 + 1], mesh.vertices[i1 * 3 + 2]);
                p2 := v3(mesh.vertices[i2 * 3 + 0], mesh.vertices[i2 * 3 + 1], mesh.vertices[i2 * 3 + 2]);

                tris[base_tri + tri_index] = .{p0, p1, p2};
            }

            base_tri += mesh.triangleCount;
        }
    }

    bvh := build_bvh(arena, tris);
    return bvh;
}

build_bvh :: (arena: *Arena, triangles: [] Triangle) -> BVH {
    assert(triangles.count < U32_MAX);

    result: BVH;

    result.nodes = push_view(arena, BVH_Node, triangles.count * 2 - 1);
    result.triangles = push_view(arena, BVH_Triangle, triangles.count);
    for * result.triangles {
        tri := triangles[it_index];
        it.p0 = tri.p0;
        it.p1 = tri.p1;
        it.p2 = tri.p2;
        it.centroid = (tri.p0 + tri.p1 + tri.p2) / v3(3.0);
        it.source_index = xx it_index;
        it.e0 = tri.p1 - tri.p0;
        it.e1 = tri.p2 - tri.p0;
    }

    result.tri_index = push_view(arena, int, triangles.count);
    for * result.tri_index {
        it.* = xx it_index;
    }

    result.nodes[0].left_or_first_tri = 0;
    result.nodes[0].tri_count = xx triangles.count;

    update_bounds(*result, 0);
    subdivide(*result, 0);

    result.nodes.count = result.nodes_used + 1;
    return result;
}

query_bvh :: (bvh: BVH, ray: Ray) -> [] BVH_Triangle {
    triangles := tarray(BVH_Triangle);

    stack := tarray(int);
    array_add(*stack, 0);

    while stack.count > 0 {
        index := stack[stack.count - 1];
        stack.count -= 1;

        node := *bvh.nodes[index];
        if !ray_intersects_box(node.bounds, ray) continue;

        if node.tri_count == 0 {
            array_add(*stack, node.left_or_first_tri);
            array_add(*stack, node.left_or_first_tri + 1);
        } else {
            for 0..node.tri_count-1 {
                tri := bvh.triangles[bvh.tri_index[node.left_or_first_tri + it]];
                array_add(*triangles, tri);
            }
        }
    }

    return triangles;
}

#scope_file

subdivide :: (bvh: *BVH, index: int, depth := 0) {
    node := *bvh.nodes[index];

    if node.tri_count <= 2 {
        return;
    }

    axis := depth % 2;
    mid := (node.bounds.min + node.bounds.max) * .5;
    split_pos := mid[axis];

    i := node.left_or_first_tri;
    j := i + node.tri_count - 1;
    while i <= j {
        tri := bvh.triangles[bvh.tri_index[i]];

        if tri.centroid[axis] < split_pos {
            i += 1;
        } else {
            bvh.tri_index[i], bvh.tri_index[j] = bvh.tri_index[j], bvh.tri_index[i];
            j -= 1;
        }
    }

    left_count := i - node.left_or_first_tri;

    if left_count == 0 || left_count == node.tri_count {
        return;
    }

    right_count := node.tri_count - left_count;
    left_index := bvh.nodes_used + 1;
    right_index := bvh.nodes_used + 2;
    bvh.nodes_used += 2;

    left_node := *bvh.nodes[left_index];
    left_node.left_or_first_tri = node.left_or_first_tri;
    left_node.tri_count = left_count;

    update_bounds(bvh, left_index);
    subdivide(bvh, left_index, depth + 1);

    right_node := *bvh.nodes[right_index];
    right_node.left_or_first_tri = i;
    right_node.tri_count = right_count;

    update_bounds(bvh, right_index);
    subdivide(bvh, right_index, depth + 1);

    node.left_or_first_tri = xx left_index;
    node.tri_count = 0;
}

update_bounds :: (bvh: *BVH, index: int) {
    node := *bvh.nodes[index];

    box: Bounding_Box;
    box.min = v3(FLOAT32_MAX);
    box.max = v3(-FLOAT32_MAX);

    for 0..node.tri_count-1 {
        tri := bvh.triangles[bvh.tri_index[node.left_or_first_tri + it]];
        box.min = min(box.min, min(min(tri.p0, tri.p1), tri.p2));
        box.max = max(box.max, max(max(tri.p0, tri.p1), tri.p2));
    }

    node.bounds = box;
}